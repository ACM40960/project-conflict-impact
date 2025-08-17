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