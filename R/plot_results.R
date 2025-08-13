# R/plot_results.R
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(ggplot2); library(scales); library(tidyr); library(forcats)
})

# Inputs from our fixed pipeline
IN_TOTALS      <- "outputs/mc_totals.csv"
IN_BYDAY       <- "outputs/mc_summary_by_day.csv"
IN_CLASS_TOTAL <- "outputs/total_emissions_by_class.csv"
IN_SCEN_TOTAL  <- "outputs/total_emissions_by_scenario.csv"
IN_DAILY       <- "outputs/daily_emissions.csv"
OUT_DIR        <- "plots"

.ensure_dir <- function(p) if (!dir.exists(p)) dir.create(p, recursive = TRUE, showWarnings = FALSE)

theme_poster <- function(base = 14){
  theme_minimal(base_size = base) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold"),
      axis.title = element_text(face = "bold"),
      strip.text = element_text(face = "bold")
    )
}

# ---------------- F1: Scenario totals with uncertainty ----------------
plot_totals <- function(in_totals = IN_TOTALS, out_path = file.path(OUT_DIR, "F1_totals_uncertainty.png")){
  stopifnot(file.exists(in_totals)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_totals, show_col_types = FALSE)
  
  p <- ggplot(df, aes(x = scenario, y = med)) +
    geom_col(width = 0.6) +
    geom_errorbar(aes(ymin = p5, ymax = p95), width = 0.18, linewidth = 0.8) +
    scale_y_continuous(
      "Total emissions (kg CO₂)",
      labels = label_number(scale_cut = cut_si("g"), accuracy = 1)
    ) +
    labs(x = NULL, title = "F1 — Scenario totals with uncertainty (median ± 5–95%)") +
    theme_poster()
  
  ggsave(out_path, p, width = 9, height = 6, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

# ---------------- F2: Daily emissions bands ----------------
plot_daily_bands <- function(in_byday = IN_BYDAY, out_path = file.path(OUT_DIR, "F2_daily_bands.png")){
  stopifnot(file.exists(in_byday)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_byday, show_col_types = FALSE)
  
  p <- ggplot(df, aes(day, med, group = scenario)) +
    geom_ribbon(aes(ymin = p5, ymax = p95), alpha = 0.25) +
    geom_line(linewidth = 0.9) +
    facet_wrap(~ scenario, scales = "free_x") +
    scale_y_continuous(
      "Daily emissions (kg CO₂)",
      labels = label_number(scale_cut = cut_si("g"), accuracy = 1)
    ) +
    scale_x_continuous("Day", breaks = pretty) +
    labs(title = "F2 — Daily emissions (median with 5–95% band)") +
    theme_poster()
  
  ggsave(out_path, p, width = 11, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

# ---------------- F3: Component contributions (totals, stacked) ----------------
plot_component_stacked_totals <- function(
    in_class_total = IN_CLASS_TOTAL,
    out_path = file.path(OUT_DIR, "F3_component_stacked.png")
){
  stopifnot(file.exists(in_class_total)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_class_total, show_col_types = FALSE)
  
  # Optional: consistent class ordering (air tends to be largest)
  df$class <- factor(df$class, levels = c("truck","tank","aircraft"))
  
  p <- ggplot(df, aes(x = scenario, y = total_kgCO2, fill = class)) +
    geom_col(width = 0.65) +
    scale_y_continuous(
      "Total emissions by component (kg CO₂)",
      labels = label_number(scale_cut = cut_si("g"), accuracy = 1)
    ) +
    scale_fill_discrete(name = "Component") +
    labs(x = NULL, title = "F3 — Component contributions (stacked totals by scenario)") +
    theme_poster()
  
  ggsave(out_path, p, width = 9, height = 6, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

# ---------------- F3b: Daily stacked area by component ----------------
plot_component_area_daily <- function(
    in_daily = IN_DAILY,
    out_path = file.path(OUT_DIR, "F3b_component_area.png")
){
  stopifnot(file.exists(in_daily)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_daily, show_col_types = FALSE)
  
  df$class <- factor(df$class, levels = c("truck","tank","aircraft"))
  
  p <- ggplot(df, aes(x = day, y = emissions_kgCO2, fill = class)) +
    geom_area(alpha = 0.9) +
    facet_wrap(~ scenario, scales = "free_x") +
    scale_y_continuous(
      "Daily emissions by component (kg CO₂)",
      labels = label_number(scale_cut = cut_si("g"), accuracy = 1)
    ) +
    scale_x_continuous("Day", breaks = pretty) +
    scale_fill_discrete(name = "Component") +
    labs(title = "F3b — Daily emissions by component (stacked area)") +
    theme_poster()
  
  ggsave(out_path, p, width = 11, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
  }

plot_totals_distribution <- function(
    in_draws = "outputs/mc_totals_draws.csv",
    out_path = file.path(OUT_DIR, "F7_totals_distribution.png")
){
  stopifnot(file.exists(in_draws)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_draws, show_col_types = FALSE)
  
  # ---------------- F7a: Emisssions across draws ----------------
  p <- ggplot(df, aes(x = total)) +
    geom_histogram(bins = 40, alpha = 0.9, fill = "steelblue") +
    facet_wrap(~ scenario, scales = "free") +
    scale_x_continuous(
      "Scenario total emissions (kg CO₂)",
      labels = scales::label_number(scale_cut = scales::cut_si("g"), accuracy = 1)
    ) +
    ylab("Count of MC draws") +
    ggtitle("F7 — Distribution of total emissions across Monte Carlo draws") +
    theme_minimal(base_size = 14) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold"))
  ggsave(out_path, p, width = 11, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

# ---------------- F7b: Emisssions across draws-violin plot  ----------------
# F7b: Distribution of totals — violin + boxplot
plot_totals_violin_box <- function(
    in_draws = "outputs/mc_totals_draws.csv",
    out_path = file.path(OUT_DIR, "F7_totals_violin_box.png")
){
  stopifnot(file.exists(in_draws)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_draws, show_col_types = FALSE)
  
  p <- ggplot(df, aes(x = scenario, y = total, group = scenario)) +
    geom_violin(trim = TRUE, alpha = 0.6) +
    geom_boxplot(width = 0.25, outlier.alpha = 0.3) +
    scale_y_continuous(
      "Scenario total emissions (kg CO₂)",
      labels = scales::label_number(scale_cut = scales::cut_si("g"), accuracy = 1)
    ) +
    xlab(NULL) +
    ggtitle("F7b — Distribution of MC totals (violin + box)") +
    theme_minimal(base_size = 14) +
    theme(panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold"),
          axis.title = element_text(face = "bold"))
  ggsave(out_path, p, width = 9.5, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

# F10: Tanker trips/day — median with 5–95% whiskers
plot_tanker_trips <- function(
    in_summary = "outputs/fuel_logistics_mc_summary.csv",
    out_path   = file.path(OUT_DIR, "F10_tanker_trips.png")
){
  stopifnot(file.exists(in_summary)); .ensure_dir(dirname(out_path))
  df <- readr::read_csv(in_summary, show_col_types = FALSE)
  
  p <- ggplot2::ggplot(df, ggplot2::aes(x = scenario, y = trips_day_med)) +
    ggplot2::geom_col(width = 0.6) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = trips_day_p5, ymax = trips_day_p95),
                           width = 0.18, linewidth = 0.8) +
    ggplot2::scale_y_continuous(
      "Fuel tanker trips per day",
      labels = scales::label_number(accuracy = 0.1)
    ) +
    ggplot2::labs(x = NULL, title = "F10 — Tanker trips/day (median ± 5–95%)") +
    (if (exists("theme_poster")) theme_poster() else ggplot2::theme_minimal(base_size = 14)) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
  
  ggplot2::ggsave(out_path, p, width = 9, height = 6, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

plot_phase_length_distributions <- function(
    in_lengths = "outputs/phasing_mc_phase_lengths.csv",
    out_path   = "plots/F12b_phase_length_distributions.png"
){
  if (!file.exists(in_lengths)) {
    stop("Missing file: ", in_lengths, " (run run_phasing_mc() first)")
  }
  
  lengths <- readr::read_csv(in_lengths, show_col_types = FALSE)
  
  # validate columns
  need <- c("scenario","phase","days")
  miss <- setdiff(need, names(lengths))
  if (length(miss)) stop("phasing_mc_phase_lengths.csv missing: ", paste(miss, collapse=", "))
  
  # coerce types safely
  lengths <- lengths |>
    dplyr::mutate(
      scenario = as.character(scenario),
      phase    = as.integer(phase),
      days     = as.numeric(days)
    )
  
  p <- ggplot2::ggplot(lengths, ggplot2::aes(x = factor(phase), y = days)) +
    ggplot2::geom_violin(trim = FALSE, alpha = 0.5) +
    ggplot2::geom_boxplot(width = 0.12, outlier.shape = NA, alpha = 0.8) +
    ggplot2::facet_wrap(~ scenario, scales = "free_y") +
    ggplot2::labs(title = "F12b — Phase length uncertainty (days)",
                  x = "Phase", y = "Days") +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"),
                   axis.title = ggplot2::element_text(face = "bold"))
  
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(out_path, p, width = 10, height = 6.5, dpi = 300)
  message("✓ Saved ", normalizePath(out_path, winslash = "/"))
  invisible(p)
}

plot_F12_phased_bands <- function(
    in_by_day  = "outputs/phasing_mc_by_day.csv",
    in_params  = "data/parameters_final_for_code.csv",
    in_phases  = "data/phases.csv",
    out_path   = file.path(OUT_DIR, "F12_phased_bands.png"),
    show_bounds = TRUE
){
  stopifnot(file.exists(in_by_day))
  by_day <- readr::read_csv(in_by_day, show_col_types = FALSE)
  
  p <- ggplot2::ggplot(by_day, ggplot2::aes(day, med, group = scenario)) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = p5, ymax = p95), alpha = 0.25) +
    ggplot2::geom_line(linewidth = 0.9) +
    ggplot2::facet_wrap(~ scenario, scales = "free_x") +
    ggplot2::scale_y_continuous(
      "Daily emissions with phase timing & intensity uncertainty (kg CO₂)",
      labels = scales::label_number(scale_cut = scales::cut_si("g"), accuracy = 1)
    ) +
    ggplot2::scale_x_continuous("Day", breaks = scales::pretty_breaks()) +
    ggplot2::labs(title = "F12 — Tempo uncertainty from phase durations & intensities") +
    (if (exists("theme_poster")) theme_poster() else ggplot2::theme_minimal(base_size = 14)) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"),
                   axis.title = ggplot2::element_text(face = "bold"))
  
  # Add dashed phase boundaries if files exist
  if (isTRUE(show_bounds) && file.exists(in_params) && file.exists(in_phases)) {
    dur <- readr::read_csv(in_params, show_col_types = FALSE) |>
      dplyr::filter(class == "global", param == "duration_days") |>
      dplyr::transmute(scenario, days = as.integer(value))
    
    phases_raw <- readr::read_csv(in_phases, show_col_types = FALSE)
    has_share <- "share_nominal" %in% names(phases_raw)
    has_mean  <- "mean_duration_days" %in% names(phases_raw)
    if (has_share || has_mean) {
      bounds <- phases_raw |>
        dplyr::left_join(dur, by = "scenario") |>
        dplyr::group_by(scenario) |>
        dplyr::arrange(phase, .by_group = TRUE) |>
        dplyr::mutate(
          nominal_days = if (has_share) share_nominal * days else mean_duration_days,
          day_end = round(cumsum(nominal_days))
        ) |>
        dplyr::ungroup()
      
      p <- p + ggplot2::geom_vline(
        data = bounds |> dplyr::filter(day_end < days),
        ggplot2::aes(xintercept = day_end),
        linetype = "dashed", linewidth = 0.4
      )
    }
  }
  
  ggplot2::ggsave(out_path, p, width = 11, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

plot_phasing_totals_distribution <- function(
    in_totals_draws      = "outputs/phasing_mc_totals_draws.csv",
    in_baseline_draws    = "outputs/mc_totals_draws.csv",   # optional overlay
    out_path             = "plots/F13_totals_distribution.png",
    show_baseline_overlay = TRUE
){
  stopifnot(file.exists(in_totals_draws))
  ph <- readr::read_csv(in_totals_draws, show_col_types = FALSE) %>%
    dplyr::mutate(source = "With phasing", total_Mt = total_kgCO2/1e6)
  
  if (isTRUE(show_baseline_overlay) && file.exists(in_baseline_draws)) {
    base <- readr::read_csv(in_baseline_draws, show_col_types = FALSE) %>%
      dplyr::rename(total_kgCO2 = total) %>%
      dplyr::mutate(source = "Baseline MC", total_Mt = total_kgCO2/1e6)
    dat <- dplyr::bind_rows(ph, base)
  } else {
    dat <- ph
  }
  
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = total_Mt, colour = source, fill = source)) +
    ggplot2::geom_density(alpha = 0.25) +
    ggplot2::facet_wrap(~ scenario, scales = "free") +
    ggplot2::labs(
      title = "F13 — Total emissions distribution (baseline vs. phasing uncertainty)",
      x = "Total emissions (Mt CO₂)", y = "Density", colour = NULL, fill = NULL
    ) +
    (if (exists("theme_poster")) theme_poster() else ggplot2::theme_minimal(base_size = 14)) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"),
                   axis.title = ggplot2::element_text(face = "bold"))
  
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(out_path, p, width = 10, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}

# In R/plot_results.R (or your plotting helpers)

plot_marginal_per_vehicle <- function(
    in_mc    = "outputs/marginal_per_vehicle_mc.csv",
    out_path = "plots/F15_marginal_per_vehicle.png"
){
  if (!file.exists(in_mc)) {
    stop("Missing MC summary: ", in_mc, 
         ". Run compute_marginal_tables() after MC to create it.")
  }
  df <- readr::read_csv(in_mc, show_col_types = FALSE)
  
  p <- ggplot2::ggplot(df, ggplot2::aes(x = class, y = per_vehicle_total_kg_med/1000, fill = scenario)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.7), width = 0.6) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = per_vehicle_total_kg_p5/1000, ymax = per_vehicle_total_kg_p95/1000),
      position = ggplot2::position_dodge(width = 0.7), width = 0.2
    ) +
    ggplot2::labs(title = "F15 — Marginal impact of one additional vehicle (per campaign)",
                  x = "Vehicle class", y = "Tonnes CO₂ per added vehicle") +
    (if (exists("theme_poster")) theme_poster() else ggplot2::theme_minimal(base_size = 14)) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold"),
                   axis.title = ggplot2::element_text(face = "bold"))
  
  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(out_path, p, width = 10, height = 6.5, dpi = 300)
  message("✓ Saved ", out_path)
  invisible(p)
}


# ---------------- Orchestrator ----------------
make_all_plots <- function(){
  .ensure_dir(OUT_DIR)
  p1  <- plot_totals()
  p2  <- plot_daily_bands()
  p3  <- plot_component_stacked_totals()
  p3b <- plot_component_area_daily()
  p7  <- plot_totals_distribution()   # histogram version
  p7b <- plot_totals_violin_box()     # violin + box version
  p10  <- plot_tanker_trips()
  p12a <- plot_phase_length_distributions()
  p12b <- plot_F12_phased_bands()
  p13  <- plot_phasing_totals_distribution() 
  p15 <- plot_marginal_per_vehicle()
  invisible(list(F1=p1, F2=p2, F3=p3, F3b=p3b, F7=p7, F7b=p7b))
}

# Run if sourced directly
if (sys.nframe() == 0) make_all_plots()
