# Battery Equivalent Circuit Model Identification from Manufacturer Discharge Curves

<p align="center">
    <img src="assets/ecm-icon.svg" alt="ECM repository icon" width="170"/>
</p>

<p align="center">
    <b>B6390 — Hybrid and Electric Marine Propulsion</b><br>
    Alma Mater Studiorum — Università di Bologna
</p>

<p align="center">
    Author: Prof. Andrea Coraddu
</p>

---

# Overview

This repository provides a reproducible framework for identifying an Equivalent Circuit Model (ECM) of the Valence U27-12XP lithium-ion battery module from digitised manufacturer discharge curves.

The methodology originates from the tutorial and lecture material developed for the course:

**B6390 — Hybrid and Electric Marine Propulsion**
Alma Mater Studiorum — Università di Bologna
Academic Year 2025–2026

The work addresses a common practical limitation in battery modelling: detailed laboratory characterisation data are often unavailable during early-stage engineering design and feasibility studies. In many engineering applications, only manufacturer discharge curves are available, preventing direct estimation of transient electrochemical dynamics.

The implemented methodology therefore adopts a physics-aware and data-constrained identification strategy in which:

- quasi-static electrical characteristics are inferred from multi-rate discharge curves;
- dynamic ECM parameters are represented through constrained surrogate models;
- validation and verification procedures ensure physical consistency and reproducibility.

The resulting framework enables rapid generation of simulation-ready battery models for:

- hybrid and electric marine propulsion systems;
- energy management strategy development;
- system-level power simulations;
- digital twin applications;
- preliminary design optimisation;
- MATLAB and Simulink implementation.

---

# Scientific Contributions

The repository provides the following capabilities.

## State-dependent quasi-static parameter identification

Multi-rate manufacturer discharge curves are used to estimate:

$$
V_{\mathrm{OC}}^{\mathrm{fit}}(z)
$$

and

$$
R_{\mathrm{eff}}(z)
$$

across the complete state-of-charge range.

---

## Physics-constrained identification

The parameter estimation procedure incorporates:

- smoothness regularisation;
- admissibility constraints;
- positivity constraints.

These prevent unrealistic oscillations and non-physical parameter values.

---

## Dynamic surrogate model generation

A reduced-order two-branch Thevenin ECM structure is generated despite the absence of pulse-characterisation measurements.

---

## Reproducible validation framework

Automated validation routines assess:

- reconstruction accuracy;
- leave-one-curve-out performance;
- parameter smoothness;
- physical feasibility;
- consistency with manufacturer operating limits.

---

# Input Dataset

The repository currently uses:

```text
data/valence_digitised_curves_actual.csv
```

containing digitised manufacturer discharge curves of the Valence U27-12XP battery module at multiple discharge rates.

---

# Repository Assets

Available graphical assets:

```text
assets/ecm-icon.svg
assets/ecm-icon-dark.svg
assets/ecm-icon-minimal.svg
assets/ecm-icon-avatar.svg
```

---

# Mathematical Formulation

## Quasi-static Battery Representation

Under sustained discharge conditions, the battery terminal voltage is approximated as:

$$
\hat V_T(z,I)
=
V_{\mathrm{OC}}^{\mathrm{fit}}(z)
-
I\,R_{\mathrm{eff}}(z)
$$

where:

- $z$ denotes state of charge;
- $V_{\mathrm{OC}}^{\mathrm{fit}}(z)$ denotes datasheet-extrapolated open-circuit voltage;
- $R_{\mathrm{eff}}(z)$ denotes apparent sustained-discharge resistance.

The formulation assumes that discharge curves primarily contain quasi-static information.

---

## Local Parameter Identification

At a given state-of-charge value:

$$
V_T(z_i,I_j)
=
\alpha_i
+
\beta_i I_j
+
\varepsilon_{ij}
$$

where:

$$
V_{\mathrm{OC}}^{\mathrm{fit}}(z_i)
=
\alpha_i
$$

and

$$
R_{\mathrm{eff}}(z_i)
=
-\beta_i
$$

with

$$
\varepsilon_{ij}
$$

representing digitisation and measurement uncertainty.

---

## Weighted Least-Squares Estimation

The identification problem is formulated as:

$$
\hat{\theta}_i
=
\arg\min_{\theta_i}
\left\|
W_i^{1/2}
(v_i-A_i\theta_i)
\right\|_2^2
$$

with

$$
\theta_i
=
\begin{bmatrix}
\alpha_i\\
\beta_i
\end{bmatrix}
$$

and

$$
A_i
=
\begin{bmatrix}
1&I_1\\
1&I_2\\
\vdots&\vdots\\
1&I_n
\end{bmatrix}
$$

---

## Regularised Global Identification

Smooth state-dependent parameter profiles are obtained through:

$$
\min_{v_{\mathrm{OC}},r_{\mathrm{eff}}}
J_{\mathrm{fit}}
+
\lambda_{\mathrm{OC}}
\|D_2v_{\mathrm{OC}}\|_2^2
+
\lambda_R
\|D_2r_{\mathrm{eff}}\|_2^2
$$

subject to

$$
V_{\min}
\le
V_{\mathrm{OC}}(z)
\le
V_{\max}
$$

and

$$
R_{\mathrm{eff}}(z)
>
0
$$

where:

$$
D_2
$$

is the second-order finite-difference operator.

---

## Dynamic Extension for Time-Domain Simulation

For simulation purposes, the identified quasi-static representation is extended through a two-branch Thevenin structure:

$$
V_T
=
V_{\mathrm{OC}}^{\mathrm{fit}}(z)
-
R_0(z)I
-
V_1
-
V_2
$$

with dynamic branch states:

$$
\dot V_k
=
-
\frac{1}{R_kC_k}
V_k
+
\frac{1}{C_k}I,
\qquad
k\in\{1,2\}
$$

subject to:

$$
R_0(z)
+
R_1(z)
+
R_2(z)
=
R_{\mathrm{eff}}(z)
$$

---

# Model Identifiability and Limitations

Manufacturer discharge curves alone cannot uniquely identify transient electrochemical dynamics.

Consequently:

Directly identified quantities:

$$
V_{\mathrm{OC}}^{\mathrm{fit}}(z),
\qquad
R_{\mathrm{eff}}(z)
$$

Surrogate quantities:

$$
R_0,
R_1,
C_1,
R_2,
C_2
$$

remain constrained approximations rather than experimentally identified quantities.

Rigorous dynamic identification would require:

- pulse-current tests;
- relaxation experiments;
- temperature-dependent measurements;
- electrochemical characterisation.

Therefore, the generated dynamic ECM should be interpreted as a simulation-oriented engineering approximation.

---

# Computational Workflow

Run from MATLAB:

```matlab
main_00_run_all
```

Pipeline:

1. Import and preprocess manufacturer discharge curves

2. Convert discharged capacity into state of charge

3. Convert C-rates into current values

4. Identify

$$
V_{\mathrm{OC}}^{\mathrm{fit}}(z)
$$

and

$$
R_{\mathrm{eff}}(z)
$$

5. Generate surrogate dynamic parameters

6. Perform validation and holdout analysis

7. Verify physical consistency

8. Export outputs

9. Execute static and dynamic simulations

---

# Repository Structure

```text
main_00_run_all.m
│
├── main_01_identify_validate.m
├── main_02_simulate_time_domain.m
├── main_03_generate_report_figures.m
│
├── +ecmdata/
├── +ecmopt/
├── +ecmmodel/
├── +ecmval/
├── +ecmplot/
│
├── data/
├── outputs/
└── Figures/
```

---

# Main Outputs

```text
outputs/
├── valence_actual_ecm_parameters.mat
├── identified_parameter_tables_from_matlab.csv
├── validation_metrics_from_matlab.csv
├── leave_one_curve_out_from_matlab.csv
├── verification_checks_from_matlab.csv
├── validation_*_full.csv
└── time_simulation_results.mat
```

---

# Reproducibility Statement

The framework is deterministic under fixed:

- input datasets;
- weighting matrices;
- identification settings;
- optimisation constraints;
- regularisation parameters.

Changing any of these requires regeneration of:

```text
outputs/
Figures/
```

to preserve numerical reproducibility.

---

# References

[1] Coraddu, A.
*Battery Equivalent-Circuit Parameter Identification: Valence U-Charge XP Datasheet Example.*
B6390 — Hybrid and Electric Marine Propulsion.
Alma Mater Studiorum — Università di Bologna.
Academic Year 2025–2026.

[2] Coraddu, A.
*Hybrid and Electric Marine Propulsion Lecture Notes.*
B6390 — Hybrid and Electric Marine Propulsion.
Alma Mater Studiorum — Università di Bologna.
Academic Year 2025–2026.


---

# Citation

```bibtex
@misc{coraddu_ecm_repository_2026,
author={Coraddu, Andrea},
title={Battery Equivalent Circuit Model Identification from Manufacturer Discharge Curves},
year={2026},
note={Educational and research repository developed within B6390 -- Hybrid and Electric Marine Propulsion, Alma Mater Studiorum -- Università di Bologna}
}
```

---
