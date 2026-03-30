install.packages(c("tidyverse", "data.table", "networkD3",
                     "htmlwidgets", "htmltools", "jsonlite", "webshot2"))

# Load libraries 

library(tidyverse)    # dplyr, tidyr, stringr — core data wrangling
library(data.table)   # fread() for fast file reading
library(networkD3)    # interactive Sankey diagrams (D3.js)
library(htmlwidgets)  # save interactive plots as HTML
library(htmltools)    # HTML rendering helpers
library(jsonlite)     # convert R objects to JSON
library(webshot2)     # screenshot HTML widgets to PNG

# CREATE EXAMPLE DATA
# Raw taxonomy strings (QIIME2 format)
taxonomy_strings <- c(
  "k__Bacteria;p__Proteobacteria;c__Gammaproteobacteria;o__Pseudomonadales;f__Pseudomonadaceae",
  "k__Bacteria;p__Proteobacteria;c__Alphaproteobacteria;o__Rhizobiales;f__Rhizobiaceae",
  "k__Bacteria;p__Proteobacteria;c__Betaproteobacteria;o__Burkholderiales;f__Burkholderiaceae",
  "k__Bacteria;p__Firmicutes;c__Bacilli;o__Lactobacillales;f__Lactobacillaceae",
  "k__Bacteria;p__Firmicutes;c__Clostridia;o__Clostridiales;f__Lachnospiraceae",
  "k__Bacteria;p__Firmicutes;c__Negativicutes;o__Selenomonadales;f__Veillonellaceae",
  "k__Bacteria;p__Actinobacteria_phylum;c__Actinobacteria;o__Corynebacteriales;f__Corynebacteriaceae",
  "k__Bacteria;p__Actinobacteria_phylum;c__Thermoleophilia;o__Solirubrobacterales;f__Conexibacteraceae",
  "k__Bacteria;p__Bacteroidetes;c__Bacteroidia;o__Bacteroidales;f__Bacteroidaceae",
  "k__Bacteria;p__Bacteroidetes;c__Sphingobacteriia;o__Sphingobacteriales;f__Sphingobacteriaceae"
)

# Raw read counts (one column per sample replicate) 
counts <- data.frame(
  `#OTU ID`   = taxonomy_strings,
  Sample_1 = c(420, 310, 200, 380, 250, 160, 290, 130, 200,  95),
  Sample_2 = c(390, 280, 220, 350, 270, 145, 310, 110, 185, 105),
  Sample_3 = c(405, 295, 210, 365, 260, 152, 300, 120, 192, 100),
  check.names      = FALSE,
  stringsAsFactors = FALSE
)
# Write collapsed-L5.csv with the QIIME2 comment line on row 1 
writeLines("# Constructed from biom file", con = "collapsed-L5.csv")
write.table(counts, file = "collapsed-L5.csv",
            sep = ",", row.names = FALSE, quote = FALSE, append = TRUE)

# Write metadata TSV
metadata_example <- data.frame(
  SampleID = c("Sample_1", "Sample_2", "Sample_3"),
  Season   = "Season",
  Forest   = "Forest",
  stringsAsFactors = FALSE
)
write.table(metadata_example, file = "metadata.tsv",
            sep = "\t", row.names = FALSE, quote = FALSE)

# PART 1: RELATIVE ABUNDANCE CALCULATION

# Step 1: Load metadata
metadata <- read.delim("metadata.tsv", stringsAsFactors = FALSE)
colnames(metadata)[1] <- "SampleID"    # standardise first column name
nrow(metadata)
# Step 2: Load the collapsed OTU/ASV table 
otu_raw <- fread("collapsed-L5.csv", skip = 1)   # skip row 1: "# Constructed from biom file"
colnames(otu_raw)[1] <- "Taxonomy"             # rename "#OTU ID" column for clarity
nrow(otu_raw)
ncol(otu_raw)
# Step 3: Parse taxonomy string into separate ranked columns
otu_tax <- otu_raw %>%
  separate(
    col  = Taxonomy,
    into = c("Kingdom", "Phylum", "Class", "Order", "Family"),
    sep  = ";",
    fill = "right"   # pad with NA on the right if fewer than 5 ranks present
  ) %>%
  mutate(across(
    c(Kingdom, Phylum, Class, Order, Family),
    ~ str_remove(.x, "^[a-z]__")   # remove "d__", "p__", "c__", "o__", "f__"
  )) %>%
  replace_na(list(
    Kingdom = "Unclassified",
    Phylum  = "Unclassified",
    Class   = "Unclassified",
    Order   = "Unclassified",
    Family  = "Unclassified"
  ))
head(otu_tax %>% select(Kingdom:Family))
# Step 4: Reshape to long (tidy) format 
otu_long <- otu_tax %>%
  pivot_longer(
    cols      = -c(Kingdom, Phylum, Class, Order, Family),
    names_to  = "SampleID",
    values_to = "Reads"
  ) %>%
  filter(Reads > 0)   # remove zero-count rows to reduce memory
 nrow(otu_long)
# Step 5: Merge with metadata 
otu_long <- otu_long %>%
  left_join(metadata, by = "SampleID")

if (any(is.na(otu_long$Season))) {
  stop("Some SampleIDs in the OTU table have no matching row in the metadata!
       Check that SampleID spelling is identical in both files.")
}
# Step 6: Calculate per-sample relative frequency 
# Relative frequency (RelFreq) = reads for one taxon / total reads in that sample.
# group_by(SampleID) scopes the calculation to each sample individually,
# so each sample's RelFreq values will sum to exactly 1.0 (= 100%).
otu_rel <- otu_long %>%
  group_by(SampleID) %>%
  mutate(RelFreq = Reads / sum(Reads)) %>%
  ungroup()
# Quick sanity check — all values should be 1.0
otu_rel %>%
  group_by(SampleID) %>%
  summarise(total = round(sum(RelFreq), 4)) %>%
  print()
# Step 7: Average relative frequency across replicates
# averages the RelFreq of each taxon across replicates to produce one value per taxon
otu_avg <- otu_rel %>%
  group_by(Season, Forest, Kingdom, Phylum, Class, Order, Family) %>%
  summarise(MeanRelFreq = mean(RelFreq), .groups = "drop")
 nrow(otu_avg)
# Step 8: Remove non-target / contaminant taxa
non_target <- c(
  "xxxx", "xxxxxxx")
otu_clean <- otu_avg %>%
  filter(
    !if_any(
      c(Kingdom, Phylum, Class, Order, Family),
      ~ str_detect(.x, paste(non_target, collapse = "|"))
    )
  ) %>%
  filter(!is.na(Family), Family != "__")   # drop rows with missing Family annotation
nrow(otu_clean)
# Save the cleaned master table
write.csv(otu_clean, file = "master_taxa_data.csv", row.names = FALSE)

# PART 2: SANKEY PLOT GENERATION
MY_SEASON <- "Season"
MY_FOREST <- "Forest"
# Create a safe filename string (replaces spaces with underscores)
plot_label <- paste0(gsub(" ", "_", MY_FOREST), "_", gsub(" ", "_", MY_SEASON))

# Step 10: Load master table and build a global colour map 
tax_data_all <- read.csv("master_taxa_data.csv", stringsAsFactors = FALSE)
all_taxa <- tax_data_all %>%
  select(Kingdom, Phylum, Class, Order, Family) %>%
  pivot_longer(everything(), values_to = "taxon") %>%
  filter(!is.na(taxon), taxon != "__") %>%
  distinct(taxon) %>%
  pull(taxon)
# Colour palette 
my_palette <- c(
  "#45B7D1", "#FF9CB4", "#FFA07A", "#98D8C8", "#BCBD22",
  "#da8ee7", "#FDAD55", "#A8E6CF", "#FF8B94", "#60af02",
  "#C7CEEA", "#DDA0DD", "#FFDD36", "#87CEFA", "#74C476",
  "#F08080", "#D3D3D3", "#FFEE8C", "#FF9CB4", "#DEAF84"
)

# Named vector: "TaxonName" → "#HEXCODE"
taxon_colors <- setNames(
  rep(my_palette, length.out = length(all_taxa)),   # recycle palette if needed
  all_taxa
)

# Convert to a D3.js colour scale (JavaScript string consumed by networkD3)
taxon_colour_scale <- JS(
  sprintf(
    "d3.scaleOrdinal()
       .domain(%s)
       .range(%s)",
    jsonlite::toJSON(names(taxon_colors)),
    jsonlite::toJSON(unname(taxon_colors))
  )
)
# Step 9: Filter to the selected Season and Forest
tax_data_filtered <- tax_data_all %>%
  filter(Season == MY_SEASON, Forest == MY_FOREST)

if (nrow(tax_data_filtered) == 0) {
  stop(sprintf(
    "No rows found for Season = '%s' and Forest = '%s'.\n  Available Seasons: %s\n  Available Forests: %s",
    MY_SEASON, MY_FOREST,
    paste(unique(tax_data_all$Season), collapse = ", "),
    paste(unique(tax_data_all$Forest), collapse = ", ")
  ))
}

# Step 11: Build Sankey links (source → target → value) 
tax_levels <- c("Kingdom", "Phylum", "Class", "Order", "Family")
all_links  <- list()

for (i in 1:(length(tax_levels) - 1)) {
  
  src <- tax_levels[i]       # left-side node  (e.g. "Phylum")
  tgt <- tax_levels[i + 1]   # right-side node (e.g. "Class")
  
  all_links[[i]] <- tax_data_filtered %>%
    group_by(across(all_of(c(src, tgt)))) %>%
    summarise(value = sum(MeanRelFreq, na.rm = TRUE), .groups = "drop") %>%
    rename(source = 1, target = 2) %>%
    arrange(desc(value))     # high-abundance flows listed first → appear at diagram top
}

links_df <- bind_rows(all_links) %>%
  filter(!is.na(value), value > 0)
head(links_df, 6)
# Step 12: Build the node table and assign integer IDs 
assign_level <- function(node_name, data) {
  for (lvl in c("Kingdom", "Phylum", "Class", "Order", "Family")) {
    if (node_name %in% data[[lvl]]) return(lvl)
  }
  return("Unknown")
}
# Sum all flow values passing through each node (used for top-to-bottom ordering)
node_abundance <- bind_rows(
  links_df %>% group_by(name = target) %>% summarise(total = sum(value)),
  links_df %>% group_by(name = source) %>% summarise(total = sum(value))
) %>%
  group_by(name) %>%
  summarise(total_abundance = sum(total))

nodes <- data.frame(
  name = unique(c(links_df$source, links_df$target)),
  stringsAsFactors = FALSE
) %>%
  left_join(node_abundance, by = "name") %>%
  mutate(
    level = sapply(name, assign_level, data = tax_data_filtered),
    level_order = case_when(
      level == "Kingdom" ~ 1,
      level == "Phylum"  ~ 2,
      level == "Class"   ~ 3,
      level == "Order"   ~ 4,
      level == "Family"  ~ 5,
      TRUE               ~ 6
    )
  ) %>%
  arrange(level_order, desc(total_abundance)) %>%   # most abundant = top of column
  mutate(id = row_number() - 1)                      # D3 uses 0-based indexing
print(nodes %>% select(id, name, level, total_abundance))
# Step 13: Replace node names with integer IDs in the links table
links_indexed <- links_df %>%
  left_join(nodes %>% select(name, id), by = c("source" = "name")) %>%
  rename(source_id = id) %>%
  left_join(nodes %>% select(name, id), by = c("target" = "name")) %>%
  rename(target_id = id) %>%
  left_join(nodes %>% select(id, source_name = name), by = c("source_id" = "id")) %>%
  select(source_id, target_id, value, source_name)
# Step 15: Build the Sankey diagram 
sankey_plot <- sankeyNetwork(
  Links       = links_indexed,
  Nodes       = nodes,
  Source      = "source_id",
  Target      = "target_id",
  Value       = "value",
  NodeID      = "name",
  NodeGroup   = "name",
  LinkGroup   = "source_name",
  units       = "Relative Frequency",
  fontSize    = 14,
  fontFamily  = "Arial, sans-serif",
  nodeWidth   = 25,
  nodePadding = 12,
  height      = 900,
  width       = 1400,
  iterations  = 0,
  sinksRight  = FALSE,
  colourScale = taxon_colour_scale
)
#Step 16: Inject column header labels via D3.js 
sankey_final <- onRender(sankey_plot, '
  function(el, x) {
    var svg = d3.select(el).select("svg");

    var levels    = ["Kingdom", "Phylum", "Class", "Order", "Family"];
    var positions = [55, 313, 575, 840, 1110];   // x-pixel position of each column

    levels.forEach(function(level, i) {
      svg.append("text")
        .attr("x", positions[i])
        .attr("y", 15)
        .attr("text-anchor", "middle")
        .attr("font-size", "14px")
        .attr("font-weight", "bold")
        .attr("font-family", "Arial, sans-serif")
        .attr("fill", "#333333")
        .text(level);
    });
  }
')


#Step 17: Display and save
sankey_final
# Save as self-contained HTML (interactive; works offline)
html_file <- paste0("sankey_", plot_label, ".html")
saveWidget(sankey_final, file = html_file, selfcontained = TRUE)
# Save as PNG 
# Needs Chrome/Chromium. If it fails: webshot2::install_phantomjs()
png_file <- paste0("sankey_", plot_label, ".png")
webshot2::webshot(url = html_file, file = png_file, vwidth = 1400, vheight = 900)
