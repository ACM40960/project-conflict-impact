
# ==============================================================================
# File: R/MC_total_draws.R
# Purpose: Convert total Monte Carlo war-emission results into tree-equivalent
#          offsets and save a poster-ready bar chart.
#
# Inputs:
#   - outputs/mc_totals_draws.csv
#       (must contain 'scenario' and 'total' = total kgCO2 per Monte Carlo draw)
#
# Assumptions / constants:
#   - kg_per_tree = 21 kg CO2 absorbed per mature tree per year
#       (source: FAO / USDA global average estimates)
#
# Processing:
#   - Aggregate total kg CO2 by scenario (mean of all draws)
#   - Convert total emissions into number of trees required to offset
#
# Outputs:
#   - Console: summary table of total emissions and trees needed by scenario
#   - plots/trees_equivalent.png (10x6 in, 300 dpi)
#
# How to run:
#   - Ensure packages: ggplot2, dplyr
#   - Ensure 'outputs/mc_totals_draws.csv' exists
#   - From project root: source("R/MC_total_draws.R")
#
# Notes:
#   - Units: input = kg CO2; output converted to equivalent number of trees
#   - Scope: tree absorption is an average value; regional variation exists
#   - Plot labels rounded to whole trees, comma-formatted for readability
#   - Ensure 'plots/' directory exists before running ggsave()
# ==============================================================================

library(ggplot2)
library(dplyr)

# Load CSV
war_emissions <- read.csv("outputs/mc_totals_draws.csv")

# Summarize (average total per scenario)
war_emissions_summary <- war_emissions %>%
  group_by(scenario) %>%
  summarise(total_kgCO2 = mean(total))

# Tree absorption rate - Source : FAO/USDA
kg_per_tree <- 21

# Calculate required trees
war_emissions_summary$trees_needed <- war_emissions_summary$total_kgCO2 / kg_per_tree

# Prevent scientific notation
options(scipen = 999)

# Create plot
p_trees <- ggplot(war_emissions_summary, aes(x = scenario, y = trees_needed, fill = scenario)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = format(round(trees_needed, 0), big.mark = ",")), 
            vjust = -0.5, size = 4) +
  labs(
    title = expression("Trees Needed to Offset War-related CO"[2]*" Emissions"),
    x = "Scenario",
    y = "Number of Trees (mature trees per year)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Save plot for poster
ggsave("plots/trees_equivalent.png", plot = p_trees, width = 10, height = 6, dpi = 300)