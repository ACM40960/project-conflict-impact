# R/simulate_temporal.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr)
})

# Fixed paths per our structure
PARAMS_CSV <- "data/parameters.csv"
EFS_CSV    <- "data/emission_factors"
OUT_DIR    <- "outputs"

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# 1) Load inputs -------------------------------------------------------------
.load_inputs <- function(params_path = PARAMS_CSV, efs_path = EFS_CSV) {
  stopifnot(file.exists(params_path), file.exists(efs_path))
  
  params <- readr::read_csv(params_path, show_col_types = FALSE) %>%
    mutate(
      scenario = as.character(scenario),
      class    = as.character(class),
      param    = as.character(param),
      value    = as.character(value)   
    )
  
  efs <- readr::read_csv(efs_path, show_col_types = FALSE) %>%
    rename(co2_per_unit = value) %>%
    mutate(fuel_type = as.character(fuel_type))
  
  list(params = params, efs = efs)
}

# 2) Build wide param matrix per scenario x class ---------------------------
.build_param_matrix <- function(params, efs) {
  # durations
  globals <- params %>%
    filter(class == "global", param == "duration_days") %>%
    transmute(scenario, duration_days = as.integer(value))
  
  per_class_long <- params %>% filter(class != "global")
  
  # 1) Keep fuel_type aside (text)
  fuel_map <- per_class_long %>%
    filter(param == "fuel_type") %>%
    select(scenario, class, fuel_type = value) %>%
    mutate(fuel_type = as.character(fuel_type)) %>%
    distinct()
  
  # 2) Pivot everything EXCEPT fuel_type to numeric columns
  per_class <- per_class_long %>%
    filter(param != "fuel_type") %>%
    mutate(val_num = suppressWarnings(as.numeric(value))) %>%
    select(scenario, class, param, val_num) %>%
    tidyr::pivot_wider(names_from = param, values_from = val_num)
  
  # 3) Attach fuel_type and EF (ensure character type)
  per_class %>%
    left_join(fuel_map, by = c("scenario","class")) %>%
    mutate(fuel_type = as.character(fuel_type)) %>%
    left_join(efs %>% select(fuel_type, co2_per_unit), by = "fuel_type") %>%
    left_join(globals, by = "scenario")
}

# 3) Deterministic midpoint daily emissions --------------------------------
.simulate_daily <- function(pmat) {
  out <- list()
  for (sc in unique(pmat$scenario)) {
    sub <- pmat %>% filter(scenario == sc)
    if (nrow(sub) == 0) next
    dur <- unique(sub$duration_days)[1] %||% 0L
    dur <- as.integer(dur)
    if (is.na(dur) || dur <= 0) stop("Invalid duration_days for scenario ", sc)
    
    rows <- lapply(seq_len(nrow(sub)), function(i) {
      r <- sub[i, ]
      cls <- r$class
      duty <- ifelse(is.na(r$duty_cycle), 1, r$duty_cycle)
      fleet <- ifelse(is.na(r$fleet_size), 0, r$fleet_size)
      efkg  <- ifelse(is.na(r$co2_per_unit), 0, r$co2_per_unit)
      
      if (identical(cls, "aircraft")) {
        hrs <- mean(c(r$hr_day_min, r$hr_day_max), na.rm = TRUE)
        rate <- ifelse(is.na(r$fuel_eff_l_per_hr), 0, r$fuel_eff_l_per_hr) # L/hr
        daily_fuel_L <- fleet * duty * hrs * rate
      } else {
        km <- mean(c(r$km_day_min, r$km_day_max), na.rm = TRUE)
        rate <- ifelse(is.na(r$fuel_eff_l_per_km), 0, r$fuel_eff_l_per_km) # L/km
        idle_lph <- ifelse(is.na(r$idle_l_per_hr), 0, r$idle_l_per_hr)     # L/hr
        idle_hours <- ifelse(idle_lph > 0, 1, 0)                           # modest 1 hr/day if defined
        daily_fuel_L <- fleet * ( duty * km * rate + idle_hours * idle_lph )
      }
      
      tibble(
        scenario = sc,
        class = cls,
        day = seq_len(dur),
        emissions_kgCO2 = rep(daily_fuel_L * efkg, dur)
      )
    })
    
    out[[sc]] <- bind_rows(rows)
  }
  bind_rows(out)
}

`%||%` <- function(a,b) if (is.null(a) || length(a)==0 || is.na(a)) b else a

# 4) Public entrypoint -------------------------------------------------------
simulate_temporal <- function(
    params_path = PARAMS_CSV,
    efs_path    = EFS_CSV,
    out_dir     = OUT_DIR
) {
  .ensure_dir(out_dir)
  dat  <- .load_inputs(params_path, efs_path)
  pmat <- .build_param_matrix(dat$params, dat$efs)
  daily <- .simulate_daily(pmat)
  
  by_class <- daily %>%
    group_by(scenario, class) %>%
    summarise(total_kgCO2 = sum(emissions_kgCO2), .groups="drop")
  
  by_scenario <- by_class %>%
    group_by(scenario) %>%
    summarise(total_kgCO2 = sum(total_kgCO2), .groups="drop")
  
  readr::write_csv(daily,       file.path(out_dir, "daily_emissions.csv"))
  readr::write_csv(by_class,    file.path(out_dir, "total_emissions_by_class.csv"))
  readr::write_csv(by_scenario, file.path(out_dir, "total_emissions_by_scenario.csv"))
  
  message("✓ Wrote outputs/daily_emissions.csv, total_emissions_by_class.csv, total_emissions_by_scenario.csv")
  invisible(list(daily=daily, by_class=by_class, by_scenario=by_scenario))
}

# Run if sourced directly
if (sys.nframe() == 0) source("R/simulate_temporal.R")
simulate_temporal(
  params_path = "data/parameters.csv",
  efs_path    = "data/emission_factors.csv",
  out_dir     = "outputs"
)

