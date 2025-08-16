library(ggplot2)

# Data
war_emissions <- data.frame(
  Scenario    = c("A", "B", "C"),
  total_kgCO2 = c(3332578.2, 2536033.3875, 856577.85)
)

# Tree absorption rate (kg CO2/year per mature tree)
kg_per_tree <- 21  # FAO / USDA

# Calculate required trees
war_emissions$trees_needed <- war_emissions$total_kgCO2 / kg_per_tree

# Prevent scientific notation
options(scipen = 999)

# Plot
ggplot(war_emissions, aes(x = Scenario, y = trees_needed, fill = Scenario)) +
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