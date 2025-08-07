# ---- Load Packages ----
library(tibble)
library(dplyr)
library(ggplot2)
library(reshape2)

# ---- Define Scenarios ----
scenarios <- list(
  A = list(duration = 7, trucks = 20, tanks = 5, aircraft = 0),
  B = list(duration = 30, trucks = 100, tanks = 20, aircraft = 5),
  C = list(duration = 90, trucks = 500, tanks = 200, aircraft = 30)
)

# ---- Vehicle Parameters ----
vehicle_params <- list(
  truck = list(km_day = c(80, 120), fuel_rate = c(2.3, 2.7), ef = c(2.6, 2.7)),
  tank = list(hr_day = c(4, 8), fuel_rate = c(230, 270), ef = c(2.6, 2.7)),
  aircraft = list(hr_day = c(1, 3), fuel_rate = c(2800, 3200), ef = c(2.5, 2.6))
)

# ---- Component-wise Simulation Function ----
simulate_components <- function(scenario, params, n = 1000) {
  results <- data.frame(
    truck = numeric(n),
    tank = numeric(n),
    aircraft = numeric(n),
    total = numeric(n)
  )
  
  for (i in 1:n) {
    truck_km <- runif(1, params$truck$km_day[1], params$truck$km_day[2]) * scenario$duration
    truck_fuel <- truck_km * runif(1, params$truck$fuel_rate[1], params$truck$fuel_rate[2])
    truck_emissions <- truck_fuel * runif(1, params$truck$ef[1], params$truck$ef[2]) * scenario$trucks
    
    tank_hr <- runif(1, params$tank$hr_day[1], params$tank$hr_day[2]) * scenario$duration
    tank_fuel <- tank_hr * runif(1, params$tank$fuel_rate[1], params$tank$fuel_rate[2])
    tank_emissions <- tank_fuel * runif(1, params$tank$ef[1], params$tank$ef[2]) * scenario$tanks
    
    aircraft_hr <- runif(1, params$aircraft$hr_day[1], params$aircraft$hr_day[2]) * scenario$duration
    aircraft_fuel <- aircraft_hr * runif(1, params$aircraft$fuel_rate[1], params$aircraft$fuel_rate[2])
    aircraft_emissions <- aircraft_fuel * runif(1, params$aircraft$ef[1], params$aircraft$ef[2]) * scenario$aircraft
    
    results$truck[i] <- truck_emissions
    results$tank[i] <- tank_emissions
    results$aircraft[i] <- aircraft_emissions
    results$total[i] <- truck_emissions + tank_emissions + aircraft_emissions
  }
  
  return(results)
}

# ---- Run for All Scenarios ----
component_results <- lapply(scenarios, function(s) simulate_components(s, vehicle_params))

# ---- Reshape for Plotting ----
df_plot <- bind_rows(
  mutate(component_results$A, scenario = "A"),
  mutate(component_results$B, scenario = "B"),
  mutate(component_results$C, scenario = "C")
)

df_long <- melt(df_plot, id.vars = "scenario", measure.vars = c("truck", "tank", "aircraft"))

# ---- Plot: Boxplot by Vehicle Type ----
p <- ggplot(df_long, aes(x = scenario, y = value, fill = variable)) +
  geom_boxplot(outlier.size = 0.3, width = 0.6, alpha = 0.85) +
  labs(title = "Vehicle-wise Emissions by Scenario",
       x = "Conflict Scenario",
       y = "Emissions (kg CO₂)",
       fill = "Vehicle Type") +
  theme_minimal(base_size = 14)

# ---- Save Plot and Data ----
ggsave("plots/component_emissions.png", plot = p, width = 10, height = 6, dpi = 300)
saveRDS(component_results, "data/component_emissions.rds")

# ---- Compute Mean Emissions per Component ----
summary_df <- data.frame(
  scenario = c("A", "B", "C"),
  truck = sapply(component_results, function(x) mean(x$truck)),
  tank = sapply(component_results, function(x) mean(x$tank)),
  aircraft = sapply(component_results, function(x) mean(x$aircraft))
)

# Reshape to long format for ggplot
summary_long <- melt(summary_df, id.vars = "scenario", variable.name = "vehicle", value.name = "emissions")
# ---- Compute Percentages ----
# Total emissions per scenario
totals <- summary_long %>%
  group_by(scenario) %>%
  summarise(total = sum(emissions))

# Join totals and compute percent
summary_long <- summary_long %>%
  left_join(totals, by = "scenario") %>%
  mutate(percent = round(100 * emissions / total, 1),
         label = paste0(percent, "%"))
stacked_plot <- ggplot(summary_long, aes(x = scenario, y = emissions, fill = vehicle)) +
  geom_bar(stat = "identity") +
  geom_text(aes(label = label), position = position_stack(vjust = 0.5), color = "white", size = 5) +
  labs(title = "Mean Emissions by Vehicle Type per Scenario",
       x = "Conflict Scenario",
       y = "Mean Emissions (kg CO₂)",
       fill = "Vehicle Type") +
  theme_minimal(base_size = 14)

# Save it
ggsave("plots/component_emissions_stacked.png", plot = stacked_plot, width = 10, height = 6, dpi = 300)
