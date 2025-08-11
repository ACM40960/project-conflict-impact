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

# ---------------- Orchestrator ----------------
make_all_plots <- function(){
  .ensure_dir(OUT_DIR)
  p1  <- plot_totals()
  p2  <- plot_daily_bands()
  p3  <- plot_component_stacked_totals()
  p3b <- plot_component_area_daily()
  invisible(list(F1 = p1, F2 = p2, F3 = p3, F3b = p3b))
}

# Run if sourced directly
if (sys.nframe() == 0) make_all_plots()
