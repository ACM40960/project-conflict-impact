#!/usr/bin/env bash
set -euo pipefail

Rscript R/component_simulation.R
Rscript R/fuel_logistics_mc.R
Rscript R/marginal_per_vehicle.R
Rscript R/phasing_mc.R
Rscript R/temporal_analysis.R
Rscript R/run_sensitivity.R
Rscript R/plot_results.R
