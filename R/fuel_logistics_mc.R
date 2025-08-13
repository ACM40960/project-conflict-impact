# R/fuel_logistics_mc.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr)
})

PARAMS_CSV   <- "data/parameters.csv"
EFS_CSV      <- "data/emission_factors.csv"
MC_BY_CLASS  <- "outputs/mc_totals_draws_by_class.csv"

OUT_SUMMARY  <- "outputs/fuel_logistics_mc_summary.csv"
OUT_DRAWS    <- "outputs/fuel_logistics_mc_draws.csv"   # optional detailed draws

# ---- Uncertainty config (tweak as needed) ----
TANKER_CAPACITY_MEAN_L <- 30000   # typical 30 m³ road tanker
TANKER_CAPACITY_SD_L   <- 1500    # ~5% sd (accounts for spec variance)
LOAD_FACTOR_MIN        <- 0.90    # filled to 90–100%
LOAD_FACTOR_MAX        <- 1.00

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# fuel_type lookup by scenario x class AND EF (kg CO2/L)
.lookup_ef <- function(params_path = PARAMS_CSV, efs_path = EFS_CSV){
  p <- read_csv(params_path, show_col_types = FALSE)
  e <- read_csv(efs_path,    show_col_types = FALSE) |>
    rename(co2_per_unit = value)
  fmap <- p |>
    filter(class != "global", param == "fuel_type") |>
    select(scenario, class, fuel_type = value) |>
    distinct() |>
    left_join(e |> select(fuel_type, co2_per_unit), by = "fuel_type")
  
  # sanity
  if (any(is.na(fmap$co2_per_unit))) {
    stop("Missing EF for some class/fuel_type. Check parameters & emission_factors files.")
  }
  fmap
}

# one random capacity draw (apply per draw, shared across classes for simplicity)
.draw_capacity <- function(n){
  # truncated to plausible range (±15% hard cap)
  vals <- rnorm(n, mean = TANKER_CAPACITY_MEAN_L, sd = TANKER_CAPACITY_SD_L)
  pmin(pmax(vals, 0.85 * TANKER_CAPACITY_MEAN_L), 1.15 * TANKER_CAPACITY_MEAN_L)
}

# main
fuel_logistics_mc <- function(
    mc_by_class_path = MC_BY_CLASS,
    params_path = PARAMS_CSV,
    efs_path = EFS_CSV,
    out_summary = OUT_SUMMARY,
    out_draws = OUT_DRAWS
){
  stopifnot(file.exists(mc_by_class_path), file.exists(params_path), file.exists(efs_path))
  .ensure_dir(dirname(out_summary)); .ensure_dir(dirname(out_draws))
  
  # inputs
  dd   <- read_csv(mc_by_class_path, show_col_types = FALSE)   # scenario, class, draw, total_kgCO2
  fmap <- .lookup_ef(params_path, efs_path)                    # scenario, class, fuel_type, co2_per_unit
  
  # join EF
  dd2 <- dd |>
    left_join(fmap, by = c("scenario","class")) |>
    mutate(
      litres = total_kgCO2 / co2_per_unit  # convert emissions back to litres
    )
  
  # capacity + load factor uncertainty per draw
  cap_df <- dd2 |> distinct(draw) |>
    mutate(
      tanker_capacity_l = .draw_capacity(n()),
      load_factor       = runif(n(), LOAD_FACTOR_MIN, LOAD_FACTOR_MAX),
      effective_capacity_l = tanker_capacity_l * load_factor
    )
  
  dd3 <- dd2 |>
    left_join(cap_df, by = "draw") |>
    mutate(
      trips_class = litres / effective_capacity_l
    )
  
  # save per-draw detailed table (optional)
  write_csv(dd3, out_draws)
  
  # aggregate per scenario/draw, then summarise
  per_draw <- dd3 |>
    group_by(scenario, draw) |>
    summarise(
      trips_total = sum(trips_class),
      .groups = "drop"
    )
  
  # duration for trips/day: use params global duration
  params <- read_csv(params_path, show_col_types = FALSE)
  dur <- params |>
    filter(class == "global", param == "duration_days") |>
    transmute(scenario, days = as.numeric(value))
  
  per_draw <- per_draw |>
    left_join(dur, by = "scenario") |>
    mutate(trips_per_day = trips_total / days)
  
  # summary stats
  summ <- per_draw |>
    group_by(scenario) |>
    summarise(
      trips_total_med = median(trips_total),
      trips_total_p5  = quantile(trips_total, 0.05),
      trips_total_p95 = quantile(trips_total, 0.95),
      trips_day_med   = median(trips_per_day),
      trips_day_p5    = quantile(trips_per_day, 0.05),
      trips_day_p95   = quantile(trips_per_day, 0.95),
      .groups = "drop"
    )
  
  write_csv(summ,  out_summary)
  message("✓ Wrote ", out_summary, " and ", out_draws)
  invisible(list(summary = summ, draws = per_draw))
}

# run if sourced directly
if (sys.nframe() == 0) fuel_logistics_mc()
