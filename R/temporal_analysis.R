# ---- Define Scenarios ----
scenarios <- list(
  list(name = "Scenario A", duration = 60, trucks = 100, tanks = 50, aircraft = 10),
  list(name = "Scenario B", duration = 45, trucks = 150, tanks = 30, aircraft = 15),
  list(name = "Scenario C", duration = 30, trucks = 200, tanks = 20, aircraft = 5)
)

# ---- Vehicle Parameters ----
vehicle_params <- list(
  truck = list(
    km_day = c(100, 300),            # Range of daily km per truck
    fuel_eff = 0.3,                  # Litres per km
    co2_per_litre = 2.7              # kg CO₂ per litre
  ),
  tank = list(
    hr_day = c(2, 6),                # Range of hours operated per tank per day
    fuel_rate = 100,                 # Litres per hour
    co2_per_litre = 3.2              # kg CO₂ per litre
  ),
  aircraft = list(
    hr_day = c(1, 4),                # Range of hours flown per aircraft per day
    fuel_rate = 2500,               # Litres per hour
    co2_per_litre = 3.1              # kg CO₂ per litre
  )
)

simulate_temporal_emissions <- function(scenario, vehicle_params) {
  # Extract duration
  days <- scenario$duration
  name <- ifelse(!is.null(scenario$name), scenario$name, "Unnamed")
  
  # Preallocate daily emissions dataframe
  daily_emissions <- data.frame(
    day = 1:days,
    truck = numeric(days),
    tank = numeric(days),
    aircraft = numeric(days),
    total = numeric(days),
    cumulative = numeric(days),
    scenario = name
  )
  
  # Loop through each day
  for (d in 1:days) {
    # Sample daily operational parameters safely
    truck_km <- runif(1, min(vehicle_params$truck$km_day), max(vehicle_params$truck$km_day))
    tank_hr  <- runif(1, min(vehicle_params$tank$hr_day), max(vehicle_params$tank$hr_day))
    aircraft_hr <- runif(1, min(vehicle_params$aircraft$hr_day), max(vehicle_params$aircraft$hr_day))
    
    # Calculate emissions
    truck_emission <- scenario$trucks * truck_km * vehicle_params$truck$fuel_eff * vehicle_params$truck$co2_per_litre
    tank_emission  <- scenario$tanks * tank_hr * vehicle_params$tank$fuel_rate * vehicle_params$tank$co2_per_litre
    aircraft_emission <- scenario$aircraft * aircraft_hr * vehicle_params$aircraft$fuel_rate * vehicle_params$aircraft$co2_per_litre
    
    # Assign
    daily_emissions$truck[d] <- truck_emission
    daily_emissions$tank[d] <- tank_emission
    daily_emissions$aircraft[d] <- aircraft_emission
    daily_emissions$total[d] <- truck_emission + tank_emission + aircraft_emission
  }
  
  # Add cumulative sum and return
  daily_emissions$cumulative <- cumsum(daily_emissions$total)
  return(daily_emissions)
}

# Apply to all predefined scenarios
temporal_outputs <- lapply(scenarios, simulate_temporal_emissions, vehicle_params = vehicle_params)
df_temporal <- dplyr::bind_rows(temporal_outputs)

# Save results
saveRDS(df_temporal, "data/temporal_emissions.rds")

#Cumulative Emissions Line Plot
library(ggplot2)

ggplot(df_temporal, aes(x = day, y = cumulative, color = scenario)) +
  geom_line(size = 1.2) +
  labs(
    title = "Cumulative CO₂ Emissions Over Time",
    x = "Day of Conflict",
    y = "Cumulative Emissions (kg CO₂)",
    color = "Scenario"
  ) +
  theme_minimal(base_size = 14)

#Daily Emissions Area Plot
ggplot(df_temporal, aes(x = day, y = total, fill = scenario)) +
  geom_area(alpha = 0.5, position = "identity") +
  labs(
    title = "Daily CO₂ Emissions During Conflict",
    x = "Day of Conflict",
    y = "Daily Emissions (kg CO₂)",
    fill = "Scenario"
  ) +
  theme_minimal(base_size = 14)
#Save plots for poster
ggsave("plots/cumulative_emissions.png", width = 10, height = 6, dpi = 300)
ggsave("plots/daily_emissions.png", width = 10, height = 6, dpi = 300)
