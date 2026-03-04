
This workflow:
1. Reads a QIIME2 collapsed taxonomy table
2. Calculates per-sample relative abundance
3. Averages biological replicates
4. Builds hierarchical relationships between taxa
5. Produces an interactive Sankey diagram
The Sankey plot shows how abundance flows through taxonomic ranks.



# 🌿 Microbiome Taxonomic Sankey Plot
### From QIIME2 Output → Relative Abundance → Interactive Hierarchical Flow Diagram

> An open-source R workflow for visualising microbial community composition across taxonomic levels using interactive Sankey diagrams. Designed for environmental DNA (eDNA) and metabarcoding studies — beginner-friendly, fully annotated, and ready to run out of the box.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Why a Sankey Plot Instead of a Bar Chart?](#-why-a-sankey-plot-instead-of-a-bar-chart)
- [How to Read a Sankey Plot](#-how-to-read-a-sankey-plot)
- [How It Works](#-how-it-works)
- [Technical Approach](#-technical-approach)
- [Project Structure](#-project-structure)
- [Installation](#-installation)
- [Usage](#-usage)
- [Input File Format](#-input-file-format)
- [Output Files](#-output-files)
- [Pros and Cons of Sankey Plots](#-pros-and-cons-of-sankey-plots)
- [Other Use Cases for Sankey Plots](#-other-use-cases-for-sankey-plots)
- [Troubleshooting](#-troubleshooting)
- [Citation](#-citation)
- [License](#-license)

---

## 🔬 Overview

This repository contains a single, fully annotated R script that takes **raw QIIME2 output** (a collapsed taxonomy table at Family level + sample metadata) and produces an **interactive Sankey diagram** showing how microbial community abundance flows from broad to fine taxonomic resolution:

```
Kingdom  →  Phylum  →  Class  →  Order  →  Family
```

The script is written for **bachelor's and master's students** new to microbiome analysis and R programming. 
---

## ✨ Features

- **Zero setup barrier** — includes a built-in example dataset that mimics exact QIIME2 output format, so you can run the entire script before touching your own data
- **Two-variable control** — change only `MY_SEASON` and `MY_FOREST` to switch between sites or seasons; file names update automatically
- **Taxonomic hierarchy visualisation** — flows across five levels simultaneously (Kingdom → Family), something no standard bar chart can show in one view
- **Abundance-sorted layout** — nodes are automatically ranked top-to-bottom by relative abundance within each column, so the most dominant taxa always appear first
- **Global colour consistency** — each taxon is assigned a fixed colour from the full dataset, so colours remain consistent if you generate multiple plots for comparison
- **Interactive HTML output** — hover over any ribbon or node to see its exact relative frequency value; shareable as a standalone offline file
- **Publication-ready PNG** — static screenshot saved automatically for use in papers, theses, and GitHub READMEs
- **Non-target taxa filtering** — built-in filter list removes contaminant or off-target organisms (e.g. vertebrate families captured by COI primers)
- **Sanity checks** — the script validates that sample IDs match between the OTU table and metadata, and that per-sample relative frequencies sum to 1.0
- **QIIME2 command reference** — the bottom of the script includes the exact terminal commands to generate the input files from your QIIME2 pipeline

---

## 📊 Why a Sankey Plot Instead of a Bar Chart?

The most common way to visualise microbiome composition is a **stacked bar chart** — one bar per sample, stacked by taxon. While familiar and easy to make, bar charts have real limitations for hierarchical data:

| Feature | Stacked Bar Chart | Sankey Diagram |
|---|---|---|
| Shows multiple taxonomic levels at once | ❌ One level at a time | ✅ All five levels simultaneously |
| Shows parent-child relationships | ❌ Requires separate charts | ✅ Flows connect levels directly |
| Handles many taxa without clutter | ❌ Gets messy beyond ~10 taxa | ✅ Flows merge naturally |
| Compares samples side by side | ✅ Easy | ⚠️ One group per plot |
| Shows proportional abundance | ✅ Yes | ✅ Yes (ribbon width) |
| Conveys community structure / hierarchy | ❌ No | ✅ Core strength |
| Interactive exploration | ❌ Static | ✅ Hover for values |

**When to use a bar chart instead:** If your primary goal is to compare relative abundance of one taxonomic level across many samples or treatment groups, a stacked bar chart is still the better choice. Sankey plots shine when you want to communicate the *structure* of a community — how major phyla break down into classes, orders, and families — rather than compare across groups.

---

## 🗺️ How to Read a Sankey Plot

```
   ┌─────────┐         ┌────────────────┐         ┌─────────────┐
   │Bacteria │─────────│ Proteobacteria │─────────│Pseudomonads │
   │         │    ╲    └────────────────┘    ╲    └─────────────┘
   │         │     ╲   ┌────────────────┐     ╲   ┌─────────────┐
   │         │      ───│  Firmicutes    │──────── │Lactobacilli │
   │         │         └────────────────┘         └─────────────┘
   └─────────┘
   Kingdom           Phylum                       Family
```

**Nodes (rectangular blocks):** Each block represents one taxonomic group at one level. The **height** of the block is proportional to its total relative abundance — taller block = more abundant taxon.

**Ribbons (flows between nodes):** Each ribbon connects a parent taxon to one of its children. The **width** of the ribbon shows how much of the parent's abundance flows into that child. Wider ribbon = higher relative abundance of that sub-group.

**Reading direction:** Left to right, broad to fine. Start at Kingdom (always Bacteria or Eukaryota in most datasets) and follow the flows rightward to see how the community breaks down at increasing resolution.

**Colour:** Each taxon has a unique colour assigned at the Kingdom/Phylum level. The same colour flows through all downstream levels — so you can trace, for example, all Firmicutes (one colour) as they split into classes, orders, and families moving right.

**Hover interaction:** In the HTML version, hovering over any ribbon shows the exact relative frequency value for that flow. Hovering over a node shows its total abundance.

**Example interpretation:**
> "The ribbon from *Proteobacteria* to *Gammaproteobacteria* is the widest ribbon leaving the Proteobacteria node. This tells us that Gammaproteobacteria is the dominant class within Proteobacteria in this sample. The narrower ribbon going to *Alphaproteobacteria* means that class is present but less abundant."

---

## ⚙️ How It Works

The script runs in two sequential parts:

### Part 1 — Relative Abundance Calculation

```
collapsed-L5.csv          co1-metadata.tsv
(raw QIIME2 counts)       (sample metadata)
        │                        │
        ▼                        ▼
  Parse taxonomy          Load Season/Forest
  strings into            labels per sample
  separate columns              │
        │                       │
        └──────────┬────────────┘
                   ▼
          Merge into long-format
          (one row per taxon × sample)
                   │
                   ▼
          Per-sample relative frequency
          RelFreq = Reads / sum(Reads)
                   │
                   ▼
          Average across replicates
          → MeanRelFreq per taxon
                   │
                   ▼
          Filter non-target taxa
                   │
                   ▼
          master_taxa_data.csv
```

### Part 2 — Sankey Plot Generation

```
master_taxa_data.csv
        │
        ▼
  Filter to MY_SEASON
  and MY_FOREST
        │
        ▼
  Build links table          Build nodes table
  (source → target           (unique taxa with
   → MeanRelFreq)             integer IDs)
        │                        │
        └──────────┬─────────────┘
                   ▼
          sankeyNetwork()
          (networkD3 / D3.js)
                   │
                   ▼
          Inject level headers
          via D3.js onRender()
                   │
              ┌────┴────┐
              ▼         ▼
          HTML file   PNG file
       (interactive) (static)
```

---

## 🔧 Technical Approach

### Taxonomy String Parsing
QIIME2 stores taxonomy as a single semicolon-delimited string with rank prefixes:
```
d__Bacteria;p__Firmicutes;c__Bacilli;o__Lactobacillales;f__Lactobacillaceae
```
The script uses `tidyr::separate()` to split on `;` and `stringr::str_remove()` to strip the `d__`, `p__`, etc. prefixes. Partially classified taxa (fewer than 5 ranks) are filled with `"Unclassified"` using `replace_na()`.

### Relative Frequency Normalisation
Raw read counts are highly variable across samples due to differences in sequencing depth. Normalising to relative frequency (each taxon's count divided by the sample's total count) puts all samples on a common 0–1 scale before averaging.

### Node Ordering
The `iterations = 0` parameter in `sankeyNetwork()` is critical — it disables D3.js's built-in force-directed node ordering, which is automatic but biologically meaningless. Instead, nodes are pre-sorted in R by `total_abundance` (descending) within each taxonomic level, placing dominant taxa at the top of each column.

### Colour Scale
A named colour vector is built from all unique taxon names in the full dataset — not just the filtered subset — using `setNames()`. This is then converted to a D3.js `scaleOrdinal()` JavaScript string via `jsonlite::toJSON()`, ensuring the same colour maps to the same taxon regardless of which season or forest is being plotted.

### Link Colouring
Links are coloured by their **source** taxon (`LinkGroup = "source_name"`), so ribbons flowing out of Firmicutes remain Firmicutes-coloured even as they fan out into multiple classes. This makes it visually easy to trace lineages.

### Output
- `saveWidget(..., selfcontained = TRUE)` embeds all D3.js JavaScript and CSS into a single HTML file, making it portable and shareable without an internet connection.
- `webshot2::webshot()` opens the HTML in a headless Chromium browser and screenshots it to PNG at the specified resolution.

---

## 📁 Project Structure

```
.
├── microbiome_relabund_sankey_single.R   # Main analysis script
├── README.md                             # This file
│
├── [generated by the example data block]
│   ├── collapsed-L5.csv                 # Simulated QIIME2 OTU table
│   └── co1-metadata.tsv                 # Simulated sample metadata
│
└── [generated as outputs]
    ├── master_taxa_data.csv             # Cleaned relative abundance table
    ├── sankey_Neora_Valley_Pre_Monsoon.html   # Interactive Sankey plot
    └── sankey_Neora_Valley_Pre_Monsoon.png    # Static PNG
```

---

## 🛠️ Installation

### Prerequisites
- **R** ≥ 4.1.0 — [Download R](https://cran.r-project.org/)
- **RStudio** (recommended) — [Download RStudio](https://posit.co/download/rstudio-desktop/)
- **Chrome or Chromium** — required by `webshot2` for PNG export

### Install R Packages

Run this once in your R console before using the script:

```r
install.packages(c(
  "tidyverse",    # data wrangling
  "data.table",   # fast file reading
  "networkD3",    # Sankey diagrams
  "htmlwidgets",  # save HTML widgets
  "htmltools",    # HTML helpers
  "jsonlite",     # JSON conversion
  "webshot2"      # PNG screenshot
))
```

If `webshot2` cannot find Chrome/Chromium, run:
```r
webshot2::install_phantomjs()
```

### Clone the Repository

```bash
git clone https://github.com/your-username/your-repo-name.git
cd your-repo-name
```

---

## 🚀 Usage

### Quick Start (with example data)

1. Open `microbiome_relabund_sankey_single.R` in RStudio
2. Run the entire script (`Ctrl+Shift+Enter` / `Cmd+Shift+Enter`)
3. Find your outputs in the working directory:
   - `sankey_Neora_Valley_Pre_Monsoon.html` — open in any browser
   - `sankey_Neora_Valley_Pre_Monsoon.png` — ready for papers/slides

### Using Your Own QIIME2 Data

**Step 1 — Prepare your QIIME2 files**

Collapse your feature table to Family level (taxonomy level 5):
```bash
qiime taxa collapse \
  --i-table table.qza \
  --i-taxonomy taxonomy.qza \
  --p-level 5 \
  --o-collapsed-table family-table.qza
```

Export to CSV:
```bash
qiime tools export \
  --input-path family-table.qza \
  --output-path exported/

biom convert \
  -i exported/feature-table.biom \
  -o collapsed-L5.csv \
  --to-tsv
```

> **Note:** The first line of the exported TSV will be `# Constructed from biom file`. The script automatically skips this line with `fread(..., skip = 1)`.

**Step 2 — Prepare your metadata file**

Your `co1-metadata.tsv` must be a tab-separated file with at minimum these columns:

```
SampleID        Season          Forest
NV_PreMon_1     Pre Monsoon     Neora Valley
NV_PreMon_2     Pre Monsoon     Neora Valley
NV_PostMon_1    Post Monsoon    Neora Valley
```

Column names must match exactly (case-sensitive).

**Step 3 — Delete or skip the example data block**

Comment out or delete the `CREATE EXAMPLE DATA` block at the top of the script (lines 45–107). The real files will be read instead.

**Step 4 — Set your season and forest**

Near the top of Part 2, change these two lines to match your data:

```r
MY_SEASON <- "Pre Monsoon"   # must match a value in your Season column
MY_FOREST <- "Neora Valley"  # must match a value in your Forest column
```

**Step 5 — Add non-target taxa to the filter list**

In Step 8, edit the `non_target` vector to include any Phylum or Family names you want to remove from your specific dataset:

```r
non_target <- c(
  "Rotifera", "Tardigrada", "Felidae", ...  # add your own here
)
```

**Step 6 — Run the script**

```r
source("microbiome_relabund_sankey_single.R")
```

---

## 📂 Input File Format

### collapsed-L5.csv (QIIME2 OTU/ASV table)

| Column | Description |
|---|---|
| `#OTU ID` | Full taxonomy string, semicolon-delimited, with rank prefixes (`d__`, `p__`, `c__`, `o__`, `f__`) |
| `SampleID_1`, `SampleID_2`, … | Raw read counts for each sample |

Row 1 must be the comment line: `# Constructed from biom file`
Row 2 is the header row starting with `#OTU ID`

### co1-metadata.tsv (sample metadata)

| Column | Description |
|---|---|
| `SampleID` | Must match column names in `collapsed-L5.csv` exactly |
| `Season` | Sampling season (e.g. `Pre Monsoon`, `Post Monsoon`) |
| `Forest` | Sampling site (e.g. `Neora Valley`) |

Additional metadata columns are allowed and will be ignored.

---

## 📤 Output Files

| File | Description |
|---|---|
| `master_taxa_data.csv` | Cleaned, long-format table with `MeanRelFreq` per taxon per season/forest. Intermediate file used by Part 2. |
| `sankey_[Forest]_[Season].html` | Fully interactive Sankey diagram. Open in any browser. Hover over ribbons for exact values. Shareable offline. |
| `sankey_[Forest]_[Season].png` | Static PNG at 1400 × 900 px. Use in publications, theses, presentations, or this README. |

---

## ⚖️ Pros and Cons of Sankey Plots

### ✅ Advantages

- **Shows hierarchy in one view** — you see the entire Kingdom-to-Family breakdown simultaneously, which requires 4 separate bar charts to replicate
- **Proportional and intuitive** — ribbon width directly encodes abundance; no axis reading required
- **Reveals community structure** — which phyla dominate, how evenly or unevenly they are distributed across classes and orders
- **Handles many taxa gracefully** — low-abundance taxa produce thin, unobtrusive ribbons rather than cluttering a legend
- **Interactive** — the HTML version lets readers explore values without publishing a table
- **Visually memorable** — effectively communicates complex nested data in a format suitable for presentations and posters

### ❌ Limitations

- **One group per plot** — cannot directly overlay two seasons or forests; you need side-by-side plots or a different visualisation for comparisons
- **Not ideal for statistical testing** — shows patterns only; statistical significance requires separate analysis (e.g. PERMANOVA, DESeq2)
- **Can become unreadable with too many thin ribbons** — datasets with hundreds of low-abundance families produce a tangle of very thin lines; consider filtering to top-N taxa before plotting
- **Header positions need manual tuning** — the x-pixel positions of the level labels (Kingdom, Phylum…) may need adjustment for datasets with different node widths
- **Requires webshot2 + Chrome for PNG** — the interactive HTML is always generated; the PNG step can fail if Chrome is not installed

---

## 🌐 Other Use Cases for Sankey Plots

Sankey diagrams are not limited to microbiome data. Any dataset with **hierarchical or flow-based structure** is a good candidate:

| Field | Use Case | Example Flow |
|---|---|---|
| **Ecology** | Species classification | Kingdom → Phylum → Class → Family |
| **Ecology** | Energy transfer in food webs | Primary producers → Herbivores → Carnivores |
| **Genomics** | Functional annotation | Gene → Pathway → Process → Function |
| **Epidemiology** | Disease progression | Exposed → Infected → Hospitalised → Recovered/Died |
| **Conservation** | Land use change | Forest → Agriculture → Urban → Degraded |
| **Economics** | Budget allocation | Total budget → Departments → Projects → Expenses |
| **Climate science** | Carbon flow | Atmosphere → Ocean → Land → Biosphere |
| **Public health** | Patient journey | Admitted → Diagnosed → Treated → Discharged |
| **Education** | Student pathways | Enrolled → Year 1 → Year 2 → Graduated/Dropped |
| **Manufacturing** | Material flow | Raw input → Processing steps → Products → Waste |

The key requirement is that values flow from one category to the next and the proportional relationships between them are meaningful.

---

## 🔍 Troubleshooting

**`Some SampleIDs in the OTU table have no matching row in the metadata`**
> SampleID names must be character-for-character identical in both files. Check for trailing spaces, capitalisation differences, or underscore vs hyphen mismatches.

**`No rows found for Season = '...' and Forest = '...'`**
> The values in `MY_SEASON` and `MY_FOREST` do not match any entries in `master_taxa_data.csv`. Run `unique(tax_data_all$Season)` and `unique(tax_data_all$Forest)` to see exactly what values are present.

**PNG export fails or produces a blank image**
> `webshot2` requires Chrome or Chromium. Try `webshot2::install_phantomjs()` as a fallback. Alternatively, open the HTML file in Chrome and use `Ctrl+P` → Save as PDF, then convert to PNG.

**Taxonomic level headers don't align with nodes**
> Open the HTML in Chrome → press `F12` → hover over node rectangles in the Elements panel to read their pixel x-position → update the `positions` array in Step 16 of the script.

**Taxonomy not parsed correctly (columns show full strings)**
> Your QIIME2 taxonomy may use a different delimiter or prefix format. Check the raw string in the CSV and adjust the `sep` argument in `separate()` and the regex in `str_remove()` accordingly.

---

## 📄 Citation

If you use this workflow in your research, please cite:

```
[Your Name] ([Year]). Microbiome Taxonomic Sankey Plot.
GitHub: https://github.com/your-username/your-repo-name
```

If you use the underlying R packages, please also cite:
- `networkD3`: Allaire J, et al. (2017). networkD3: D3 JavaScript Network Graphs from R.
- `tidyverse`: Wickham H, et al. (2019). Welcome to the tidyverse. *Journal of Open Source Software*, 4(43), 1686.

---

## 📜 License

This project is released under the **MIT License** — free to use, modify, and distribute with attribution. See `LICENSE` for details.

---

<div align="center">

Made for the open microbiome community 🦠  
Contributions, issues, and pull requests are welcome

</div>


