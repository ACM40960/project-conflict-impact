# R/run_mc.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr)
})

PARAMS_CSV <- "data/parameters.csv"
EFS_CSV    <- "data/emission_factors.csv"
OUT_DIR    <- "outputs"

# ---- Uncertainty config (tweak here) ----
MC_N_DRAWS           <- 400
MC_SEED              <- 42
BROADEN_RANGES_PCT   <- 0.20   # expand min/max by ±20%
FLEET_VAR_PCT        <- 0.10   # fleet size varies ±10% per draw
EF_SD_FRAC           <- 0.03   # emission factor sd ≈ 3% of mean
EF_TRUNC_FRAC        <- 0.10   # truncate EF to ±10% of mean
DISRUPT_PROB         <- 0.10   # 10% of days disrupted
DISRUPT_FACTOR       <- 0.50   # disrupted days run at 50% tempo

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# --------- helpers ----------
read_inputs <- function(params_path = PARAMS_CSV, efs_path = EFS_CSV) {
  params <- readr::read_csv(params_path, show_col_types = FALSE)
  efs    <- readr::read_csv(efs_path,    show_col_types = FALSE) |>
    rename(co2_per_unit = value)
  list(params=params, efs=efs)
}

build_matrix <- function(params, efs){
  globals <- params |>
    filter(class=="global", param=="duration_days") |>
    transmute(scenario, duration_days = as.integer(value))
  
  per_long <- params |> filter(class!="global")
  
  # keep text fuel_type aside
  fuel_map <- per_long |>
    filter(param=="fuel_type") |>
    select(scenario, class, fuel_type = value) |>
    distinct()
  
  # numeric wide
  per_wide <- per_long |>
    filter(param!="fuel_type") |>
    mutate(val_num = suppressWarnings(as.numeric(value)),
           low_num = suppressWarnings(as.numeric(low)),
           high_num= suppressWarnings(as.numeric(high))) |>
    select(scenario, class, param, val_num, low_num, high_num) |>
    pivot_wider(names_from = param, values_from = c(val_num, low_num, high_num),
                names_glue = "{param}__{.value}")
  
  per_wide |>
    left_join(fuel_map, by=c("scenario","class")) |>
    left_join(efs |> select(fuel_type, co2_per_unit), by="fuel_type") |>
    left_join(globals, by="scenario")
}

# triangular sampler on [a,b] with mode = m (default m = mid)
rtri <- function(n, a, b, m = (a+b)/2){
  if (is.na(a) || is.na(b) || b <= a) return(rep(NA_real_, n))
  u <- runif(n)
  Fc <- (m - a) / (b - a)
  out <- ifelse(u < Fc,
                a + sqrt(u * (b - a) * (m - a)),
                b - sqrt((1 - u) * (b - a) * (b - m)))
  out
}

# broaden [min,max] by ±pct
broaden <- function(minv, maxv, pct = BROADEN_RANGES_PCT){
  if (is.na(minv) || is.na(maxv)) return(c(NA_real_, NA_real_))
  c(minv * (1 - pct), maxv * (1 + pct))
}

# truncated normal around mean with bounds
rtruncnorm1 <- function(mean, sd, lower, upper){
  if (is.na(mean) || is.na(sd)) return(mean)
  # simple rejection sampler (fast enough for 1 draw)
  val <- rnorm(1, mean, sd)
  tries <- 0
  while ((val < lower || val > upper) && tries < 1000){
    val <- rnorm(1, mean, sd); tries <- tries + 1
  }
  if (tries >= 1000) val <- max(min(val, upper), lower)
  val
}

# ---- draw one MC realisation for a given scenario ----
simulate_one_draw <- function(pmat_sc){
  dur <- unique(pmat_sc$duration_days)[1]; if (is.na(dur) || dur <= 0) return(NULL)
  
  # EF draw per class (kg CO2 per L), truncated normal around mean
  ef_draw <- vapply(seq_len(nrow(pmat_sc)), function(i){
    mu <- pmat_sc$co2_per_unit[i]
    if (is.na(mu)) return(0)
    sigma <- EF_SD_FRAC * mu
    lower <- mu * (1 - EF_TRUNC_FRAC)
    upper <- mu * (1 + EF_TRUNC_FRAC)
    rtruncnorm1(mu, sigma, lower, upper)
  }, numeric(1))
  
  # fleet size variability per class
  fleet_draw <- vapply(seq_len(nrow(pmat_sc)), function(i){
    f <- pmat_sc$fleet_size__val_num[i]
    if (is.na(f)) f <- 0
    f * runif(1, 1 - FLEET_VAR_PCT, 1 + FLEET_VAR_PCT)
  }, numeric(1))
  
  # per-day disruption multipliers (same across classes for simplicity)
  disrupt <- if (DISRUPT_PROB > 0) {
    ifelse(rbinom(dur, 1, DISRUPT_PROB) == 1, DISRUPT_FACTOR, 1.0)
  } else rep(1.0, dur)
  
  rows <- lapply(seq_len(nrow(pmat_sc)), function(i){
    r <- pmat_sc[i,]
    duty <- ifelse(is.na(r$duty_cycle__val_num), 1, r$duty_cycle__val_num)
    
    if (r$class == "aircraft"){
      # broaden hours, then triangular
      a0 <- r$hr_day_min__val_num; b0 <- r$hr_day_max__val_num
      ab <- broaden(a0, b0, BROADEN_RANGES_PCT)
      hrs <- rtri(1, ab[1], ab[2], m = mean(c(a0,b0), na.rm = TRUE))
      # fuel rate triangular with broadened bounds
      fr_min <- ifelse(is.na(r$fuel_eff_l_per_hr__low_num), r$fuel_eff_l_per_hr__val_num, r$fuel_eff_l_per_hr__low_num)
      fr_max <- ifelse(is.na(r$fuel_eff_l_per_hr__high_num), r$fuel_eff_l_per_hr__val_num, r$fuel_eff_l_per_hr__high_num)
      fr_ab  <- broaden(fr_min, fr_max, BROADEN_RANGES_PCT)
      rate   <- rtri(1, fr_ab[1], fr_ab[2], m = r$fuel_eff_l_per_hr__val_num)
      daily_fuel <- fleet_draw[i] * duty * hrs * rate
      daily_vec  <- daily_fuel * disrupt
    } else {
      # ground: km/day triangular with broadened bounds
      kmin <- r$km_day_min__val_num; kmax <- r$km_day_max__val_num
      kab  <- broaden(kmin, kmax, BROADEN_RANGES_PCT)
      km   <- rtri(1, kab[1], kab[2], m = mean(c(kmin,kmax), na.rm=TRUE))
      # fuel rate triangular with broadened bounds
      fr_min <- ifelse(is.na(r$fuel_eff_l_per_km__low_num), r$fuel_eff_l_per_km__val_num, r$fuel_eff_l_per_km__low_num)
      fr_max <- ifelse(is.na(r$fuel_eff_l_per_km__high_num), r$fuel_eff_l_per_km__val_num, r$fuel_eff_l_per_km__high_num)
      fr_ab  <- broaden(fr_min, fr_max, BROADEN_RANGES_PCT)
      rate   <- rtri(1, fr_ab[1], fr_ab[2], m = r$fuel_eff_l_per_km__val_num)
      # idle draw triangular too
      idle_min <- ifelse(is.na(r$idle_l_per_hr__low_num), r$idle_l_per_hr__val_num, r$idle_l_per_hr__low_num)
      idle_max <- ifelse(is.na(r$idle_l_per_hr__high_num), r$idle_l_per_hr__val_num, r$idle_l_per_hr__high_num)
      idle_ab  <- broaden(idle_min, idle_max, BROADEN_RANGES_PCT)
      idle_lph <- ifelse(!is.na(idle_min) && !is.na(idle_max), rtri(1, idle_ab[1], idle_ab[2], m = r$idle_l_per_hr__val_num), 0)
      idle_hours <- ifelse(!is.na(idle_lph) && idle_lph > 0, 1, 0)
      
      fuel_per_day <- duty * km * rate + idle_hours * idle_lph
      daily_fuel <- fleet_draw[i] * fuel_per_day
      daily_vec  <- daily_fuel * disrupt
    }
    
    tibble(
      scenario = r$scenario,
      class    = r$class,
      day      = seq_len(dur),
      emissions_kgCO2 = daily_vec * ef_draw[i]
    )
  })
  
  bind_rows(rows)
}

run_mc <- function(n_draws = MC_N_DRAWS, seed = MC_SEED,
                   params_path = PARAMS_CSV, efs_path = EFS_CSV, out_dir = OUT_DIR){
  set.seed(seed); .ensure_dir(out_dir)
  dat  <- read_inputs(params_path, efs_path)
  pmat <- build_matrix(dat$params, dat$efs)
  
  all <- lapply(unique(pmat$scenario), function(sc){
    sub <- pmat |> filter(scenario==sc)
    draws <- lapply(seq_len(n_draws), function(d){
      dd <- simulate_one_draw(sub); dd$draw <- d; dd
    })
    bind_rows(draws)
  }) |> bind_rows()
  
  by_day <- all |>
    group_by(scenario, day) |>
    summarise(med = median(emissions_kgCO2),
              p5  = quantile(emissions_kgCO2, 0.05),
              p95 = quantile(emissions_kgCO2, 0.95),
              .groups="drop")
  
  totals <- all |>
    group_by(scenario, draw) |>
    summarise(total = sum(emissions_kgCO2), .groups="drop") |>
    group_by(scenario) |>
    summarise(med = median(total),
              p5  = quantile(total, 0.05),
              p95 = quantile(total, 0.95),
              .groups="drop")
  
  write_csv(by_day, file.path(out_dir, "mc_summary_by_day.csv"))
  write_csv(totals, file.path(out_dir, "mc_totals.csv"))
  message("✓ Wrote outputs/mc_summary_by_day.csv and outputs/mc_totals.csv")
  invisible(list(by_day=by_day, totals=totals))
}

# Run if sourced directly
if (sys.nframe() == 0) run_mc()
