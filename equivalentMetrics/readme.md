# Equivalent Metrics

## Overview
These codes turn war-related CO₂ results from Monte Carlo (MC) simulations into intuitive equivalences:

- **Trees** needed to offset emissions (annual mature-tree sequestration).  
- **Smartphones** manufactured with the same CO₂ footprint.  
- **Car-year equivalents** (number of average cars driving for a year).  

The three R scripts read precomputed CSVs, aggregate by scenario, apply published benchmarks, and export poster-ready bar charts.

---

## Dependencies
All scripts use base R plus:

- `ggplot2` (plotting)  
- `dplyr` (aggregation)  
- `scales` (axis/label formatting; used in phone & car plots)  

---

## Data Inputs
- **`outputs/mc_totals_draws.csv`**  
  Per-draw totals of war-related CO₂ (kg), with at least:  
  `scenario`, `total` (kg CO₂ per draw).

- **`outputs/mc_summary_by_day.csv`**  
  Daily median emissions (kg), with at least:  
  `scenario`, `med` (median kg CO₂ per day).

- **`outputs/marginal_per_vehicle_mc.csv`**  
  Scenario totals for marginal per-vehicle emissions, with at least:  
  `scenario`, `per_vehicle_total_kg_med` (kg).

**Units note:** all inputs are **kg CO₂**. Scripts convert to tonnes or unit counts as needed.

---

## What Each Script Does

### 1) `MC_total_draws.R`
**Question:** How many trees are needed to offset the emission?  

**Goal:** Show how many mature trees (per year) are needed to offset the war-related emissions.  

**Steps**
1. Read `outputs/mc_totals_draws.csv`.  
2. Aggregate by scenario: `mean(total)` → average kg CO₂.  
3. Divide by kg absorbed per mature tree per year.  
4. Plot number of trees by scenario and save `plots/trees_equivalent.png`.  

**Key Assumption / Constant**
- `kg_per_tree = 21 kg CO₂` absorbed per mature tree per year (USDA global averages).  

**Reference**  
USDA / Arbor Day Foundation estimates show a mature tree absorbs about 48 lb CO₂/year (~22 kg/year).  
🔗 [USDA Blog – The Power of One Tree](https://www.usda.gov/about-usda/news/blog/power-one-tree-very-air-we-breathe)

**Output**  
`plots/trees_equivalent.png`

---

### 2) `MC_summary_by_day.R`
**Question:** How many smartphones can be manufactured with the same CO₂ emission?  

**Goal:** Express scenario totals as the number of smartphones whose manufacturing emits the same CO₂.  

**Steps**
1. Read `outputs/mc_summary_by_day.csv`.  
2. Aggregate by scenario: `sum(med)` → total kg CO₂ across days.  
3. Divide by CO₂ per smartphone.  
4. Plot smartphones (units) by scenario and save `plots/smartphones_equivalent.png`.  

**Key Assumption / Constant**
- `co2_per_phone = 48 kg CO₂` per smartphone (manufacturing life-cycle assessment benchmark).  

**Reference**  
🔗 [Life Cycle Assessment of a Smartphone (ResearchGate)](https://www.researchgate.net/publication/308986891_Life_Cycle_Assessment_of_a_Smartphone)

**Output**  
`plots/smartphones_equivalent.png`

---

### 3) `marginalMetrics.R`
**Question:** How many cars emit the same level of CO₂ in one year?  

**Goal:** Convert scenario totals into “cars that could drive for one year with the same CO₂”.  

**Steps**
1. Read `outputs/marginal_per_vehicle_mc.csv`.  
2. Compute tonnes per car-year:  

   - Annual distance: **15,196 km/year** (Ireland private car, CSO 2025).  
   - Tailpipe intensity: **103 g CO₂/km** (EU new-car fleet, WLTP, ICCT Feb 2025).  

   \[
   t\_per\_car = \frac{103 \text{ g/km} \times 15,196 \text{ km}}{10^6} = 1.565 \text{ t CO₂/car-year}
   \]

3. Aggregate by scenario: `sum(per_vehicle_total_kg_med)` → total kg CO₂.  
4. Convert to tonnes and divide by `t_per_car`.  
5. Plot number of cars (annual equivalent) and save `plots/cars_equivalent.png`.  

**Key Assumptions / Constants**
- **Annual km:** 15,196 km (CSO, 2025 transport snapshot).  
- **CO₂ intensity:** 103 g/km (ICCT EU fleet update, Feb 2025).  

**References**  
- [CSO Transport Statistics 2025](https://www.cso.ie/en/csolatestnews/pressreleases/2025pressreleases/pressstatement-snapshotoftransportstatisticsinireland2025/)  
- [ICCT European Market Monitor – Cars & Vans (Feb 2025)](https://theicct.org/publication/european-market-monitor-cars-vans-feb-2025-mar25/)  

**Output**  
`plots/cars_equivalent.png` (10×6 in, 300 dpi)

---

## Reproducibility & Notes
- Ensure all three input CSVs exist in `outputs/` with the required columns.  
- All plots hide legends (one bar per scenario) and write to `plots/`.  
- If you change benchmarks (e.g., new CSO/ICCT figure), update constants at the top of each script and re-run.  
- Units are **kg CO₂** and the scripts handle conversions (kg → tonnes, kg → units) internally.  

---
