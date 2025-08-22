<h1 align="center"> Conflict CO₂ Impact Simulator
 </h1>

This repository quantifies the additional CO₂ emissions attributable to armed conflict, using modular simulations of infrastructure damage, fuel logistics, temporal dynamics, and scenario analysis.

## Scope and Motivation

Vehicle fuel use is one of the most consistently measurable and universally relevant sources of CO₂ emissions in armed conflicts. Unlike many other contributing factors—such as infrastructure destruction, land-use change, or displaced population flows—fuel consumption can be quantified using relatively standardised operational parameters (fleet size, fuel efficiency, activity levels) and well-documented emission factors. 

This makes it possible to model a range of scenarios with transparency, reproducibility, and credible uncertainty estimates. Focusing on fuel also allows for deeper exploration of its operational and policy implications, including the logistical scale of supply, economic costs and emission factor sensitivities.

## Objectives

The objective of this project is to implement a modular simulation framework to estimate the CO₂ emissions associated with armed conflict. 
Specifically, the project aims to:

1. Develop component-level models for emissions from destruction and reconstruction.  
2. Incorporate modules for fuel logistics and marginal per-vehicle emissions.  
3. Implement Monte Carlo methods to propagate parameter uncertainty.  
4. Analyse temporal dynamics through phase length sampling and daily emission bands.  
5. Produce reproducible outputs (CSV summaries and figures) that allow comparison across conflict scenarios.

