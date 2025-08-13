# R/marginal_per_vehicle.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(stringr); library(tidyr)
})

IN_DAILY   <- "outputs/daily_emissions.csv"
IN_MC_CLS  <- "outputs/mc_totals_draws_by_class.csv"   # optional
PARAMS_CSV <- "data/parameters.csv"
OUT_DIR    <- "outputs"

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# Read duration_days and fleet sizes (robust to naming)
.read_params_core <- function(path = PARAMS_CSV) {
  prm <- readr::read_csv(path, show_col_types = FALSE)
  dur <- prm %>%
    filter(class == "global", param == "duration_days") %>%
    transmute(scenario, duration_days = as.numeric(value)) %>% distinct()
  
  fleets <- prm %>%
    filter(param %in% c("fleet_size","fleet","fleet_size__val_num") | str_detect(param, regex("fleet", TRUE))) %>%
    mutate(fleet_size = suppressWarnings(as.numeric(value))) %>%
    select(scenario, class, fleet_size) %>%
    group_by(scenario, class) %>%
    summarise(fleet_size = dplyr::last(na.omit(fleet_size)), .groups="drop")
  
  list(duration = dur, fleets = fleets)
}

# Deterministic table
.compute_det <- function(daily_path, params_path){
  stopifnot(file.exists(daily_path))
  core <- .read_params_core(params_path)
  dur <- core$duration; fleets <- core$fleets
  if (nrow(fleets) == 0) stop("No fleet sizes found in parameters file.")
  
  daily <- readr::read_csv(daily_path, show_col_types = FALSE)
  totals <- daily %>%
    group_by(scenario, class) %>%
    summarise(total_kg = sum(emissions_kgCO2, na.rm = TRUE),
              per_day_kg = mean(emissions_kgCO2, na.rm = TRUE), .groups="drop") %>%
    left_join(fleets, by = c("scenario","class")) %>%
    left_join(dur, by = "scenario")
  
  if (any(is.na(totals$fleet_size))) {
    miss <- totals %>% filter(is.na(fleet_size)) %>% distinct(scenario, class)
    stop("Missing fleet_size for: ", paste0(miss$scenario, "/", miss$class, collapse=", "))
  }
  if (any(is.na(totals$duration_days))) stop("Missing duration_days for some scenario.")
  
  totals %>%
    transmute(
      scenario, class,
      per_vehicle_per_day_kg = per_day_kg / fleet_size,
      per_vehicle_total_kg   = (per_day_kg * duration_days) / fleet_size,
      per_vehicle_total_tonnes = per_vehicle_total_kg / 1000
    )
}

# MC summary table (if draws exist)
.compute_mc <- function(mc_class_path, params_path){
  if (!file.exists(mc_class_path)) return(NULL)
  core <- .read_params_core(params_path)
  dur <- core$duration; fleets <- core$fleets
  if (nrow(fleets) == 0) stop("No fleet sizes found in parameters file.")
  
  mc <- readr::read_csv(mc_class_path, show_col_types = FALSE) %>%
    rename(total_kg = total_kgCO2) %>%
    left_join(fleets, by = c("scenario","class")) %>%
    left_join(dur, by = "scenario")
  
  if (any(is.na(mc$fleet_size))) {
    miss <- mc %>% filter(is.na(fleet_size)) %>% distinct(scenario, class)
    stop("Missing fleet_size for: ", paste0(miss$scenario, "/", miss$class, collapse=", "))
  }
  if (any(is.na(mc$duration_days))) stop("Missing duration_days for some scenario.")
  
  mc %>%
    mutate(
      per_vehicle_total_kg   = total_kg / fleet_size,
      per_vehicle_per_day_kg = per_vehicle_total_kg / duration_days
    ) %>%
    group_by(scenario, class) %>%
    summarise(
      per_vehicle_total_kg_med   = median(per_vehicle_total_kg),
      per_vehicle_total_kg_p5    = quantile(per_vehicle_total_kg, 0.05),
      per_vehicle_total_kg_p95   = quantile(per_vehicle_total_kg, 0.95),
      per_vehicle_per_day_kg_med = median(per_vehicle_per_day_kg),
      per_vehicle_per_day_kg_p5  = quantile(per_vehicle_per_day_kg, 0.05),
      per_vehicle_per_day_kg_p95 = quantile(per_vehicle_per_day_kg, 0.95),
      .groups="drop"
    )
}

# Public entry point (tables only)
compute_marginal_tables <- function(
    daily_path    = IN_DAILY,
    mc_class_path = IN_MC_CLS,
    params_path   = PARAMS_CSV,
    out_det       = file.path(OUT_DIR, "marginal_per_vehicle_deterministic.csv"),
    out_mc        = file.path(OUT_DIR, "marginal_per_vehicle_mc.csv")
){
  .ensure_dir(dirname(out_det))
  
  det_tbl <- .compute_det(daily_path, params_path)
  readr::write_csv(det_tbl, out_det)
  
  mc_tbl <- .compute_mc(mc_class_path, params_path)
  if (!is.null(mc_tbl)) readr::write_csv(mc_tbl, out_mc)
  
  message("✓ Wrote ", out_det, if (!is.null(mc_tbl)) paste0(" and ", out_mc) else "")
  invisible(list(deterministic = det_tbl, mc = mc_tbl))
}

# Run if sourced directly
if (sys.nframe() == 0) compute_marginal_tables()
