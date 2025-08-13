# ==============================================================================
# File: R/cost_from_fuel.R
# Purpose: Compute fuel costs from MC emission draws using EF (kgCO2/L) and prices (€/L)
# Inputs:
#   - outputs/mc_totals_draws_by_class.csv    (scenario, draw, class, total_kgCO2)
#   - data/emission_factors.csv  (fuel_type, value=kgCO2_per_l)
#   - data/fuel_prices.csv                    (fuel_type, price_eur_per_l)
#   - data/parameters.csv      (duration_days per scenario)
# Outputs:
#   - outputs/cost_mc_draws.csv               (per-draw totals by scenario/class)
#   - outputs/cost_mc_summary.csv             (median, p5, p95 for total €/campaign and €/day)
# How to run:
#   source("R/cost_from_fuel.R"); cost_from_fuel()
# Notes:
#   - Ensure fuel_type mapping from class -> fuel_type is correct below.
# ==============================================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(stringr)
})

IN_DRAWS   <- "outputs/mc_totals_draws_by_class.csv"
EFS_CSV    <- "data/emission_factors.csv"   # expects cols: fuel_type, value (kgCO2_per_l)
PRICES_CSV <- "data/fuel_prices.csv"                     # expects cols: fuel_type, price_eur_per_l
PARAMS_CSV <- "data/parameters.csv"
OUT_DIR    <- "outputs"

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# Map classes to fuel types (adjust here if your naming differs)
.map_class_to_fuel <- function(df){
  df %>% mutate(
    fuel_type = dplyr::case_when(
      class %in% c("truck","tank") ~ "diesel",
      class %in% c("aircraft")     ~ "jet_a1",
      class %in% c("car","jeep")   ~ "petrol",
      TRUE ~ "diesel"   # sensible default; change if you have other classes
    )
  )
}

cost_from_fuel <- function(
    in_draws   = IN_DRAWS,
    efs_path   = EFS_CSV,
    prices_path= PRICES_CSV,
    params_path= PARAMS_CSV,
    out_draws  = file.path(OUT_DIR, "cost_mc_draws.csv"),
    out_sum    = file.path(OUT_DIR, "cost_mc_summary.csv")
){
  stopifnot(file.exists(in_draws), file.exists(efs_path), file.exists(prices_path), file.exists(params_path))
  .ensure_dir(dirname(out_draws))
  
  draws <- readr::read_csv(in_draws, show_col_types = FALSE)
  efs   <- readr::read_csv(efs_path, show_col_types = FALSE)
  prices<- readr::read_csv(prices_path, show_col_types = FALSE)
  dur   <- readr::read_csv(params_path, show_col_types = FALSE) %>%
    filter(class=="global", param=="duration_days") %>%
    transmute(scenario, days = as.numeric(value))
  
  # clean EF col name to kg_per_l
  if (!"value" %in% names(efs)) stop("EF file must have a 'value' column (kg CO2 per litre).")
  efs <- efs %>% rename(kg_per_l = value)
  
  # Map class -> fuel_type
  draws_fuel <- draws %>% .map_class_to_fuel()
  
  # join EF and price
  df <- draws_fuel %>%
    left_join(efs %>% select(fuel_type, kg_per_l), by = "fuel_type") %>%
    left_join(prices %>% select(fuel_type, price_eur_per_l), by = "fuel_type") %>%
    left_join(dur, by = "scenario")
  
  # sanity
  if (any(is.na(df$kg_per_l)))  stop("Missing EF (kg_per_l) for some fuel_type. Check emission_factors_with_sources.csv")
  if (any(is.na(df$price_eur_per_l))) stop("Missing price for some fuel_type. Check data/fuel_prices.csv")
  if (any(is.na(df$days))) stop("Missing duration_days in parameters file for some scenario.")
  
  # Convert kgCO2 -> litres -> cost
  out_draws_df <- df %>%
    mutate(
      litres = total_kgCO2 / kg_per_l,
      cost_eur = litres * price_eur_per_l,
      cost_eur_per_day = cost_eur / days
    ) %>%
    select(scenario, draw, class, fuel_type, litres, cost_eur, cost_eur_per_day)
  
  readr::write_csv(out_draws_df, out_draws)
  
  # Summary med & 5–95% by scenario
  sum_df <- out_draws_df %>%
    group_by(scenario, draw) %>%
    summarise(cost_total_eur = sum(cost_eur),
              cost_per_day_eur = sum(cost_eur_per_day), .groups="drop") %>%
    group_by(scenario) %>%
    summarise(
      cost_total_med   = median(cost_total_eur),
      cost_total_p5    = quantile(cost_total_eur, 0.05),
      cost_total_p95   = quantile(cost_total_eur, 0.95),
      cost_day_med     = median(cost_per_day_eur),
      cost_day_p5      = quantile(cost_per_day_eur, 0.05),
      cost_day_p95     = quantile(cost_per_day_eur, 0.95),
      .groups="drop"
    )
  
  readr::write_csv(sum_df, out_sum)
  message("✓ Wrote ", out_draws, " and ", out_sum)
  invisible(list(draws = out_draws_df, summary = sum_df))
}

# Run if sourced directly
if (sys.nframe() == 0) cost_from_fuel()
