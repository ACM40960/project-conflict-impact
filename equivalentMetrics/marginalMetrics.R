options(scipen = 999)

library(readr)
library(dplyr)
library(ggplot2)
library(scales)

# Load file
df <- read_csv("outputs/marginal_per_vehicle_mc.csv", show_col_types = FALSE)

# 2025 metrics
annual_km <- 15196   # CSO 2025 average annual distance per private car in Ireland
gpkm      <- 103     # ICCT 2025 EU fleet-average tailpipe CO2, g/km (WLTP)
t_per_car <- (gpkm * annual_km) / 1e6  # tonnes CO2 per car-year (~1.565 t)

# Group by scenario and sum emissions
scenario_summary <- df %>%
  group_by(scenario) %>%
  summarise(total_kgCO2 = sum(per_vehicle_total_kg_med, na.rm = TRUE)) %>%
  mutate(
    total_tonnes = total_kgCO2 / 1000,
    cars_equivalent = total_tonnes / t_per_car
  )

print(scenario_summary)

# Create plot
p_cars <- ggplot(scenario_summary, aes(x = scenario, y = cars_equivalent)) +
  geom_col(fill = "steelblue") +
  geom_text(aes(label = comma(round(cars_equivalent, 0))),
            vjust = -0.3, size = 4) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.1))) +
  labs(
    title = expression("Cars That Could Drive for One Year with Same CO"[2]*" as War Scenario"),
    subtitle = expression("Based on CSO 2025 (15,196 km/year) & ICCT 2025 (103 g CO"[2]*"/km)"),
    x = "Scenario",
    y = "Number of cars (annual equivalent)"
  ) +
  theme_minimal()

# Save plots for poster
ggsave("plots/cars_equivalent.png", plot = p_cars, width = 10, height = 6, dpi = 300)