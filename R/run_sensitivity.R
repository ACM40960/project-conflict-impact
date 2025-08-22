# R/run_sensitivity.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

PARAMS_CSV <- "data/parameters.csv"
EFS_CSV    <- "data/emission_factors.csv"
OUT_CSV    <- "outputs/sensitivity.csv"
OUT_DIR_P  <- "plots"

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

# ---------- helpers reused from earlier modules ----------
load_inputs <- function(params_path = PARAMS_CSV, efs_path = EFS_CSV){
  params <- read_csv(params_path, show_col_types = FALSE)
  efs    <- read_csv(efs_path, show_col_types = FALSE) |> rename(co2_per_unit = value)
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
    mutate(val_num = suppressWarnings(as.numeric(value))) |>
    select(scenario, class, param, val_num) |>
    pivot_wider(names_from = param, values_from = val_num)
  
  per_wide |>
    left_join(fuel_map, by=c("scenario","class")) |>
    left_join(efs |> select(fuel_type, co2_per_unit), by="fuel_type") |>
    left_join(globals, by="scenario")
}

# deterministic midpoint total (kg CO2) for one scenario
scenario_total_midpoint <- function(pmat_sc){
  dur <- unique(pmat_sc$duration_days)[1]; if (is.na(dur) || dur<=0) return(0)
  rows <- lapply(seq_len(nrow(pmat_sc)), function(i){
    r <- pmat_sc[i,]
    duty  <- ifelse(is.na(r$duty_cycle), 1, r$duty_cycle)
    fleet <- ifelse(is.na(r$fleet_size), 0, r$fleet_size)
    efkg  <- ifelse(is.na(r$co2_per_unit), 0, r$co2_per_unit)
    if (r$class == "aircraft"){
      hrs  <- mean(c(r$hr_day_min, r$hr_day_max), na.rm=TRUE)
      rate <- ifelse(is.na(r$fuel_eff_l_per_hr), 0, r$fuel_eff_l_per_hr)
      daily_fuel <- fleet * duty * hrs * rate
    } else {
      km   <- mean(c(r$km_day_min, r$km_day_max), na.rm=TRUE)
      rate <- ifelse(is.na(r$fuel_eff_l_per_km), 0, r$fuel_eff_l_per_km)
      idle <- ifelse(is.na(r$idle_l_per_hr), 0, r$idle_l_per_hr)
      idle_hours <- ifelse(idle>0, 1, 0)
      daily_fuel <- fleet * ( duty * km * rate + idle_hours * idle )
    }
    dur * daily_fuel * efkg
  })
  sum(unlist(rows))
}

# scale a single parameter in a copy of the long params table
scale_param <- function(params_long, scenario, class, param_key, scale){
  params_long |>
    mutate(value = ifelse(scenario==!!scenario & class==!!class & param==!!param_key,
                          as.numeric(value) * scale,
                          value))
}

# ---------- main ----------
run_sensitivity <- function(
    params_path = PARAMS_CSV,
    efs_path    = EFS_CSV,
    targets = c("fuel_eff_l_per_km","fuel_eff_l_per_hr","km_day_min","km_day_max","hr_day_min","hr_day_max","idle_l_per_hr","duty_cycle"),
    scales  = c(0.8, 1.2),
    out_csv = OUT_CSV,
    out_dir_plots = OUT_DIR_P
){
  .ensure_dir(dirname(out_csv)); .ensure_dir(out_dir_plots)
  dat <- load_inputs(params_path, efs_path)
  params0 <- dat$params; efs <- dat$efs
  
  # baseline totals per scenario
  base_pmat <- build_matrix(params0, efs)
  base_totals <- base_pmat |>
    group_by(scenario) |>
    group_split() |>
    setNames(unique(base_pmat$scenario)) |>
    lapply(scenario_total_midpoint) |>
    unlist()
  
  rows <- list()
  for (sc in unique(params0$scenario)){
    for (cl in unique(params0$class[params0$class!="global"])){
      for (param_key in targets){
        # skip if that param doesn’t exist for this class/scenario
        if (!any(params0$scenario==sc & params0$class==cl & params0$param==param_key)) next
        for (scal in scales){
          p_scaled <- scale_param(params0, sc, cl, param_key, scal)
          pm <- build_matrix(p_scaled, efs)
          tot <- pm |> filter(scenario==sc) |> scenario_total_midpoint()
          rows[[length(rows)+1]] <- data.frame(
            scenario = sc, class = cl, param = param_key, scale = scal,
            total_kgCO2 = tot, base_total_kgCO2 = base_totals[[sc]],
            pct_change = 100*(tot - base_totals[[sc]])/base_totals[[sc]]
          )
        }
      }
    }
  }
  
  df <- bind_rows(rows)
  write_csv(df, out_csv)
  message("✓ Wrote ", out_csv)
  
  # ---- Tornado plots per scenario ----
  make_tornado_plots(df, out_dir_plots)
  invisible(df)
}

make_tornado_plots <- function(df, out_dir_plots = OUT_DIR_P, top_n = 8){
  # combine +/- into a single bar height per param/class = max |pct_change|
  agg <- df |>
    group_by(scenario, class, param) |>
    summarise(effect = max(abs(pct_change), na.rm=TRUE), .groups="drop") |>
    arrange(scenario, desc(effect)) |>
    group_by(scenario) |>
    slice_head(n = top_n)
  
  # nicer labels
  pretty_param <- function(x){
    x <- gsub("_", " ", x)
    x <- gsub("km day", "km/day", x)
    x <- gsub("hr day", "hr/day", x)
    x
  }
  agg$param_lab <- factor(pretty_param(agg$param), levels = rev(pretty_param(unique(agg$param))))
  
  for (sc in unique(agg$scenario)){
    dat <- agg |> filter(scenario==sc)
    p <- ggplot(dat, aes(x = param_lab, y = effect, fill = class)) +
      geom_col(width = 0.7) +
      coord_flip() +
      scale_y_continuous("Impact on scenario total (% change)", labels = label_percent(scale = 1)) +
      labs(x = NULL, title = paste0("F4 — Tornado (Top ", top_n, ") — Scenario ", sc)) +
      theme_minimal(base_size = 13) +
      theme(panel.grid.minor = element_blank(),
            plot.title = element_text(face = "bold"),
            axis.title = element_text(face = "bold"))
    out_path <- file.path(out_dir_plots, paste0("F4_tornado_", sc, ".png"))
    ggsave(out_path, p, width = 9, height = 6, dpi = 300)
    message("✓ Saved ", out_path)
  }
  
  # combined (all scenarios)
  p_all <- ggplot(agg, aes(x = reorder(paste(class, pretty_param(param)), effect), y = effect, fill = scenario)) +
    geom_col() +
    coord_flip() +
    scale_y_continuous("Impact on scenario total (% change)", labels = label_percent(scale = 1)) +
    labs(x = NULL, title = "F4 — Tornado (Top effects across scenarios)") +
    theme_minimal(base_size = 13) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold"),
          axis.title = element_text(face = "bold"))
  ggsave(file.path(out_dir_plots, "F4_tornado.png"), p_all, width = 9, height = 6, dpi = 300)
  message("✓ Saved ", file.path(out_dir_plots, "F4_tornado.png"))
}

# run if sourced directly
if (sys.nframe() == 0) run_sensitivity()
