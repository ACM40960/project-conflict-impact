# Define 3 scenarios with vehicle counts and duration
scenarios <- list(
  A = list(duration = 7, trucks = 20, tanks = 5, aircraft = 0),
  B = list(duration = 30, trucks = 100, tanks = 20, aircraft = 5),
  C = list(duration = 90, trucks = 500, tanks = 200, aircraft = 30)
)
# Base operation profiles
vehicle_params <- list(
  truck = list(km_day = c(80, 120), fuel_rate = c(2.3, 2.7), ef = c(2.6, 2.7)),   # L/km
  tank = list(hr_day = c(4, 8), fuel_rate = c(230, 270), ef = c(2.6, 2.7)),        # L/hr
  aircraft = list(hr_day = c(1, 3), fuel_rate = c(2800, 3200), ef = c(2.5, 2.6))   # L/hr
)
simulate_scenario <- function(scenario, params, n = 1000) {
  total_emissions <- numeric(n)
  
  for (i in 1:n) {
    # Trucks
    truck_km <- runif(1, params$truck$km_day[1], params$truck$km_day[2]) * scenario$duration
    truck_fuel <- truck_km * runif(1, params$truck$fuel_rate[1], params$truck$fuel_rate[2])
    truck_emissions <- truck_fuel * runif(1, params$truck$ef[1], params$truck$ef[2]) * scenario$trucks
    
    # Tanks
    tank_hours <- runif(1, params$tank$hr_day[1], params$tank$hr_day[2]) * scenario$duration
    tank_fuel <- tank_hours * runif(1, params$tank$fuel_rate[1], params$tank$fuel_rate[2])
    tank_emissions <- tank_fuel * runif(1, params$tank$ef[1], params$tank$ef[2]) * scenario$tanks
    
    # Aircraft
    aircraft_hours <- runif(1, params$aircraft$hr_day[1], params$aircraft$hr_day[2]) * scenario$duration
    aircraft_fuel <- aircraft_hours * runif(1, params$aircraft$fuel_rate[1], params$aircraft$fuel_rate[2])
    aircraft_emissions <- aircraft_fuel * runif(1, params$aircraft$ef[1], params$aircraft$ef[2]) * scenario$aircraft
    
    # Total
    total_emissions[i] <- truck_emissions + tank_emissions + aircraft_emissions
  }
  
  return(total_emissions)
}
set.seed(42)
results <- list(
  A = simulate_scenario(scenarios$A, vehicle_params),
  B = simulate_scenario(scenarios$B, vehicle_params),
  C = simulate_scenario(scenarios$C, vehicle_params)
)
library(ggplot2)
library(dplyr)

# Combine for plotting
df <- bind_rows(
  data.frame(scenario = "A", emissions = results$A),
  data.frame(scenario = "B", emissions = results$B),
  data.frame(scenario = "C", emissions = results$C)
)

# Summary stats
summary_df <- df %>%
  group_by(scenario) %>%
  summarise(mean = mean(emissions),
            sd = sd(emissions),
            q25 = quantile(emissions, 0.25),
            q75 = quantile(emissions, 0.75))

# Plot
ggplot(df, aes(x = scenario, y = emissions)) +
  geom_boxplot(fill = "lightblue") +
  labs(title = "Estimated CO₂ Emissions by Scenario",
       y = "Emissions (kg CO₂)", x = "Conflict Scenario") +
  theme_minimal()

