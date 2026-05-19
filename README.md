# Battery ECM Identification from Datasheet Curves

<p align="center">
	<img src="assets/ecm-icon.svg" alt="ECM repository icon" width="170"/>
</p>

Author: Andrea Coraddu

## Overview

This project builds an Equivalent Circuit Model (ECM) for the Valence U27-12XP module using digitised manufacturer discharge curves.

The implemented workflow is intentionally physics-aware and data-limited:
- static parameters are identified from multi-rate voltage-capacity curves;
- dynamic branch parameters are provided as a constrained surrogate for simulation;
- validation and verification outputs are exported as reproducible artifacts.

Input dataset:
- data/valence_digitised_curves_actual.csv

## Brand Assets

Repository icon variants:
- assets/ecm-icon.svg: default icon for README and light backgrounds
- assets/ecm-icon-dark.svg: icon for dark backgrounds
- assets/ecm-icon-minimal.svg: minimal flat variant
- assets/ecm-icon-avatar.svg: circular avatar variant

## Theoretical Core

The identifiable model from datasheet curves is the quasi-static relation:

$$
\hat V_T(z, I) = V_{\mathrm{OC}}(z) - I\,R_{\mathrm{eff}}(z)
$$

where:
- $z$ is state of charge,
- $V_{\mathrm{OC}}(z)$ is a zero-current extrapolated voltage profile,
- $R_{\mathrm{eff}}(z)$ is an apparent sustained-discharge resistance.

At each fixed SoC point, parameters are recovered with a linear fit in current:

$$
V_T(z_i, I_j) = \alpha_i + \beta_i I_j + \varepsilon_{ij},
\qquad
V_{\mathrm{OC}}(z_i) = \alpha_i,
\qquad
R_{\mathrm{eff}}(z_i) = -\beta_i
$$

### Optimization Problem

The identification step can be written as a weighted least-squares problem at each SoC grid point:

$$
\hat{\theta}_i
=
\arg\min_{\theta_i}
\left\|W_i^{1/2}\left(v_i - A_i\theta_i\right)\right\|_2^2,
\qquad
	heta_i =
\begin{bmatrix}
\alpha_i\\
\beta_i
\end{bmatrix}
$$

with $A_i = [\mathbf{1},\, I]$ and $v_i$ the vector of measured voltages across selected C-rates.

When smoothness constraints are enabled, the project also supports a global regularized formulation:

$$
\min_{v_{\mathrm{OC}},\, r_{\mathrm{eff}}}
\; J_{\mathrm{fit}}
+ \lambda_{\mathrm{OC}}\left\|D_2 v_{\mathrm{OC}}\right\|_2^2
+ \lambda_R\left\|D_2 r_{\mathrm{eff}}\right\|_2^2
$$

subject to physical admissibility constraints such as:

$$
V_{\min} \le V_{\mathrm{OC}}(z) \le V_{\max},
\qquad
R_{\mathrm{eff}}(z) > 0
$$

### Dynamic Extension for Simulation

For time-domain simulation, a 2RC Thevenin-style structure is exported:

$$
V_T = V_{\mathrm{OC}}(z) - R_0(z)I - V_1 - V_2
$$

with branch states

$$
\dot V_k = -\frac{1}{R_k C_k}V_k + \frac{1}{C_k}I, \quad k \in \{1,2\}
$$

and consistency enforced through

$$
R_0(z) + R_1(z) + R_2(z) = R_{\mathrm{eff}}(z)
$$

## Important Interpretation Limit

Sustained discharge curves do not uniquely identify dynamic $R$-$C$ branches.

Therefore:
- $V_{\mathrm{OC}}(z)$ and $R_{\mathrm{eff}}(z)$ are identified from available data,
- $R_0, R_1, C_1, R_2, C_2$ are constrained surrogate parameters unless pulse/rest tests are provided.

## Workflow

Run from MATLAB in the repository root:

```matlab
main_00_run_all
```

Pipeline:
1. import and preprocess digitised manufacturer curves,
2. map capacity-used to SoC and C-rate to current,
3. identify $V_{\mathrm{OC}}(z)$ and $R_{\mathrm{eff}}(z)$,
4. construct surrogate 2RC tables,
5. validate reconstruction and holdout behavior,
6. verify physical admissibility,
7. export tables, figures, and MAT artifacts,
8. simulate static and dynamic responses in time domain.

## Repository Structure

- main_00_run_all.m: end-to-end workflow entry point
- main_01_identify_validate.m: identification, validation, and export
- main_02_simulate_time_domain.m: static vs dynamic simulation
- main_03_generate_report_figures.m: report-oriented figure generation
- +ecmdata: input parsing and matrix construction
- +ecmopt: parameter identification and checks
- +ecmmodel: static and dynamic ECM objects
- +ecmval: validation suite and acceptance gates
- +ecmplot: plotting utilities
- outputs: exported numerical evidence
- Figures: generated report figures

## Main Outputs

- outputs/valence_actual_ecm_parameters.mat
- outputs/identified_parameter_tables_from_matlab.csv
- outputs/validation_metrics_from_matlab.csv
- outputs/leave_one_curve_out_from_matlab.csv
- outputs/verification_checks_from_matlab.csv
- outputs/validation_*_full.csv
- outputs/time_simulation_results.mat

## Notes on Reproducibility

The project is deterministic under fixed input curves and script settings.

If input data, fitting weights, or constraints are changed, regenerate:
- all outputs in outputs,
- all figures in Figures.
