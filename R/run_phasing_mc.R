# ==============================================================================
# File: R/run_phasing_mc.R
# Purpose: Monte Carlo tempo analysis with phase timing + intensity uncertainty
# Inputs:
#   - outputs/daily_emissions.csv              (from simulate_temporal)
#   - data/parameters.csv       (for duration_days per scenario)
#   - data/phases.csv                          (shares + multipliers; or explicit durations)
# Outputs:
#   - outputs/phasing_mc_by_day.csv            (med, p5, p95 by day & scenario)
#   - outputs/phasing_mc_totals.csv            (med, p5, p95 totals by scenario)
#   - outputs/phasing_mc_phase_lengths.csv     (sampled days per phase & draw)
# How to run:
#   source("R/run_phasing_mc.R"); run_phasing_mc()
# Notes:
#   - Timing: sample phase lengths via (truncated) normals, then renormalise to total days.
#   - Intensity: sample lognormal multipliers around nominal phase multipliers.
#   - This script writes tables only. Plotting lives in R/plot_results.R.
# ==============================================================================

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr)
})

DAILY_EMISS <- "outputs/daily_emissions.csv"
PARAMS_CSV  <- "data/parameters.csv"
PHASES_CSV  <- "data/phases.csv"
OUT_DIR     <- "outputs"

# ---- MC config ----
N_DRAWS        <- 400
SEED           <- 123
CV_DURATION    <- 0.20   # if no sd provided, use 20% of nominal as sd
MIN_PHASE_DAYS <- 2
SDLOG_MULT     <- 0.12   # ~12% lognormal sd around nominal multipliers

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# Allocate integer counts that sum to 'total' using largest fractional parts
.alloc_integer_counts <- function(real_counts, total){
  counts <- floor(real_counts)
  rem <- total - sum(counts)
  if (rem > 0) {
    frac <- real_counts - floor(real_counts)
    add  <- order(frac, decreasing = TRUE)[seq_len(rem)]
    counts[add] <- counts[add] + 1
  }
  counts
}

# Sample phase lengths (truncated normals + renormalise to total days)
.sample_phase_lengths <- function(nominal_days, sd_days, total_days, min_days = MIN_PHASE_DAYS){
  draws <- rnorm(length(nominal_days), mean = nominal_days, sd = sd_days)
  draws <- pmax(draws, min_days)                          # truncate low tail
  scaled <- draws * (total_days / sum(draws))             # renormalise to total
  scaled <- pmax(scaled, min_days)                        # enforce min after scaling
  scaled <- scaled * (total_days / sum(scaled))           # renormalise again
  .alloc_integer_counts(scaled, total_days)               # integer allocation
}

run_phasing_mc <- function(
    daily_emiss_path = DAILY_EMISS,
    params_path      = PARAMS_CSV,
    phases_path      = PHASES_CSV,
    n_draws          = N_DRAWS,
    seed             = SEED,
    out_by_day       = file.path(OUT_DIR, "phasing_mc_by_day.csv"),
    out_totals       = file.path(OUT_DIR, "phasing_mc_totals.csv"),
    out_lengths      = file.path(OUT_DIR, "phasing_mc_phase_lengths.csv")
){
  set.seed(seed); .ensure_dir(dirname(out_by_day))
  stopifnot(file.exists(daily_emiss_path), file.exists(params_path), file.exists(phases_path))
  
  base <- readr::read_csv(daily_emiss_path, show_col_types = FALSE) # scenario, day, class, emissions_kgCO2
  dur  <- readr::read_csv(params_path, show_col_types = FALSE) |>
    dplyr::filter(class=="global", param=="duration_days") |>
    dplyr::transmute(scenario, days = as.integer(value))
  
  phases_raw <- readr::read_csv(phases_path, show_col_types = FALSE) |>
    dplyr::arrange(scenario, phase)
  
  # ---- Sanity checks
  has_share <- "share_nominal"       %in% names(phases_raw)
  has_mean  <- "mean_duration_days"  %in% names(phases_raw)
  has_sd    <- "sd_duration_days"    %in% names(phases_raw)
  
  if (!has_share && !has_mean)
    stop("phases.csv must include either 'share_nominal' or 'mean_duration_days'.")
  
  if (has_share) {
    chk <- phases_raw |>
      dplyr::group_by(scenario) |>
      dplyr::summarise(s = sum(share_nominal), .groups="drop")
    if (any(abs(chk$s - 1) > 1e-6))
      stop("share_nominal must sum to 1 per scenario in data/phases.csv")
  }
  
  if (any(phases_raw$mult_truck <= 0 | phases_raw$mult_tank <= 0 | phases_raw$mult_aircraft <= 0))
    stop("Phase multipliers must be > 0 in data/phases.csv")
  
  # ---- Build nominal means & sds robustly
  phases <- phases_raw |>
    dplyr::left_join(dur, by = "scenario")
  
  if (has_mean) {
    phases <- phases |>
      dplyr::mutate(mean_duration_days = as.numeric(mean_duration_days))
  } else if (has_share) {
    phases <- phases |>
      dplyr::mutate(mean_duration_days = as.numeric(share_nominal) * days)
  }
  
  if (has_sd) {
    phases <- phases |>
      dplyr::mutate(sd_duration_days = as.numeric(sd_duration_days))
  } else {
    phases <- phases |>
      dplyr::mutate(sd_duration_days = CV_DURATION * mean_duration_days)
  }
  
  # Final guard
  if (any(is.na(phases$mean_duration_days))) stop("mean_duration_days contains NA after construction.")
  
  # ---- MC draws
  scenarios <- intersect(unique(base$scenario), unique(phases$scenario))
  all_draws      <- list()
  all_phase_lens <- list()
  
  for (sc in scenarios){
    base_sc <- base |> dplyr::filter(scenario==sc) |> dplyr::arrange(day, class)
    days_sc <- dur  |> dplyr::filter(scenario==sc) |> dplyr::pull(days)
    ph_sc   <- phases |> dplyr::filter(scenario==sc) |> dplyr::arrange(phase)
    
    draws <- lapply(seq_len(n_draws), function(d){
      # sample phase lengths (days)
      counts <- .sample_phase_lengths(
        nominal_days = ph_sc$mean_duration_days,
        sd_days      = ph_sc$sd_duration_days,
        total_days   = days_sc,
        min_days     = MIN_PHASE_DAYS
      )
      
      lens <- tibble::tibble(scenario = sc, draw = d, phase = ph_sc$phase, days = counts)
      
      # sample intensity multipliers around nominal (lognormal)
      mult <- ph_sc |>
        dplyr::mutate(
          mult_truck_s = rlnorm(dplyr::n(), meanlog = log(mult_truck),    sdlog = SDLOG_MULT),
          mult_tank_s  = rlnorm(dplyr::n(), meanlog = log(mult_tank),     sdlog = SDLOG_MULT),
          mult_air_s   = rlnorm(dplyr::n(), meanlog = log(mult_aircraft), sdlog = SDLOG_MULT)
        ) |>
        dplyr::select(phase, mult_truck_s, mult_tank_s, mult_air_s)
      
      # day->phase index from counts
      phase_idx <- rep(ph_sc$phase, counts)
      day_df <- tibble::tibble(day = seq_len(days_sc), phase = phase_idx) |>
        dplyr::left_join(mult, by = "phase")
      
      adj <- base_sc |>
        dplyr::left_join(day_df, by = "day") |>
        dplyr::mutate(
          m = dplyr::case_when(
            class == "truck"    ~ mult_truck_s,
            class == "tank"     ~ mult_tank_s,
            class == "aircraft" ~ mult_air_s,
            TRUE ~ 1
          ),
          emissions_adj = emissions_kgCO2 * m
        ) |>
        dplyr::select(scenario, day, class, emissions_adj) |>
        dplyr::mutate(draw = d)
      
      list(adj = adj, lens = lens)
    })
    
    all_draws[[sc]]      <- dplyr::bind_rows(lapply(draws, `[[`, "adj"))
    all_phase_lens[[sc]] <- dplyr::bind_rows(lapply(draws, `[[`, "lens"))
  }
  
  all <- dplyr::bind_rows(all_draws)
  lengths <- dplyr::bind_rows(all_phase_lens)
  
  summarise_phasing_totals <- function(
    in_by_day = "outputs/phasing_mc_by_day.csv",
    out_totals = "outputs/phasing_mc_totals.csv"
  ){
    stopifnot(file.exists(in_by_day))
    
    by_day <- readr::read_csv(in_by_day, show_col_types = FALSE)
    
    # aggregate per draw & scenario
    totals <- by_day |>
      dplyr::group_by(scenario, draw) |>
      dplyr::summarise(total_emissions = sum(value, na.rm = TRUE), .groups = "drop")
    
    readr::write_csv(totals, out_totals)
    message("✓ Saved totals to: ", out_totals)
    invisible(totals)
  }
  # --- Per-draw totals (needed for F13)
  totals_draws <- all %>%
    dplyr::group_by(scenario, draw) %>%
    dplyr::summarise(total_kgCO2 = sum(emissions_adj), .groups = "drop")
  
  readr::write_csv(totals_draws, file.path(OUT_DIR, "phasing_mc_totals_draws.csv"))
  
  # ---- Summaries
  by_day <- all |>
    dplyr::group_by(scenario, day) |>
    dplyr::summarise(
      med = stats::median(emissions_adj),
      p5  = stats::quantile(emissions_adj, 0.05),
      p95 = stats::quantile(emissions_adj, 0.95),
      .groups="drop"
    )
  
  totals <- all |>
    dplyr::group_by(scenario, draw) |>
    dplyr::summarise(total = sum(emissions_adj), .groups="drop") |>
    dplyr::group_by(scenario) |>
    dplyr::summarise(
      med = stats::median(total),
      p5  = stats::quantile(total, 0.05),
      p95 = stats::quantile(total, 0.95),
      .groups="drop"
    )
  
  .ensure_dir(dirname(out_by_day))
  readr::write_csv(by_day,   out_by_day)
  readr::write_csv(totals,   out_totals)
  readr::write_csv(lengths,  out_lengths)
  
  message("✓ Wrote ", out_by_day, ", ", out_totals, ", ", out_lengths)
  invisible(list(by_day = by_day, totals = totals, lengths = lengths))
}

# Run if sourced directly
if (sys.nframe() == 0) run_phasing_mc()
