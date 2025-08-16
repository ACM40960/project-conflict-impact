# Load libraries
library(ggplot2)
library(scales) # for comma formatting

# Example data (replace with your CSV read)
df <- data.frame(
  Scenario    = c("A", "B", "C"),
  total_kgCO2 = c(3332578.2, 2536033.3875, 856577.85)
)

# Benchmark
co2_per_phone <- 48  # kg CO₂ per smartphone

# Calculate smartphones equivalent
df$smartphones_equiv <- df$total_kgCO2 / co2_per_phone

# Plot with labels on top of bars
ggplot(df, aes(x = Scenario, y = smartphones_equiv, fill = Scenario)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = comma(round(smartphones_equiv, 0))), 
            vjust = -0.5, size = 4) +
  labs(
    title = expression("War-related CO"[2]*" in Smartphone Manufacturing Equivalents"),
    subtitle = expression("Based on 50 kg CO"[2]*" per smartphone (2025 benchmark)"),
    x = "Scenario",
    y = "Smartphones (units)"
  ) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.1))) +
  theme_minimal() +
  theme(legend.position = "none")