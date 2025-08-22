# ==============================================================================
# File: R/mc_summary_by_day.R
# Purpose: Convert daily Monte Carlo CO2 results into smartphone-equivalent units
#          and save a poster-ready bar chart.
#
# Inputs:
#   - outputs/mc_summary_by_day.csv
#       (must contain 'scenario' and 'med' = median daily kgCO2 emissions)
#
# Assumptions / constants:
#   - co2_per_phone = 48 kg CO2 per smartphone (2025 benchmark estimate)
#
# Processing:
#   - Aggregate daily median emissions by scenario (sum of 'med' column)
#   - Convert total kg CO2 into smartphone equivalents
#
# Outputs:
#   - Console: summary table of total emissions and smartphone equivalents
#   - plots/smartphones_equivalent.png (10x6 in, 300 dpi)
#
# How to run:
#   - Ensure packages: ggplot2, scales, dplyr
#   - Ensure 'outputs/mc_summary_by_day.csv' exists
#   - From project root: source("R/mc_summary_by_day.R")
#
# Notes:
#   - Units: input = kg CO2; output converted to number of smartphones
#   - Scope: smartphone CO2 benchmark (48 kg) based on 2025 manufacturing footprint
#   - Plot labels rounded to whole smartphones, axis formatted with commas
#   - Create 'plots/' directory before running to avoid ggsave() errors
# ==============================================================================

library(ggplot2)
library(scales)
library(dplyr)

# Load CSV
df <- read.csv("outputs/mc_summary_by_day.csv")

# Summarise
df_summary <- df %>%
  group_by(scenario) %>%
  summarise(total_kgCO2 = sum(med))

# Benchmark
co2_per_phone <- 48  # kg CO2 per smartphone

# Calculate smartphones equivalent
df_summary$smartphones_equiv <- df_summary$total_kgCO2 / co2_per_phone

# Create plot
p_phones <- ggplot(df_summary, aes(x = scenario, y = smartphones_equiv, fill = scenario)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = comma(round(smartphones_equiv, 0))), 
            vjust = -0.5, size = 4) +
  labs(
    title = expression("War-related CO"[2]*" in Smartphone Manufacturing Equivalents"),
    subtitle = expression("Based on 48 kg CO"[2]*" per smartphone (2025 benchmark)"),
    x = "Scenario",
    y = "Smartphones (units)"
  ) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.1))) +
  theme_minimal() +
  theme(legend.position = "none")

# Save plot for poster
ggsave("plots/smartphones_equivalent.png", plot = p_phones, width = 10, height = 6, dpi = 300)