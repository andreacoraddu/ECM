# Text-Code Traceability Matrix

This document links the methodology and definitions in `ECM.tex` to the MATLAB implementation.

## How to use this matrix

- `Implemented`: explicitly coded and executed by the current pipeline.
- `Partially implemented`: core idea exists, but one or more options described in the text are not implemented.
- `Conceptual`: described in the tutorial for completeness, but intentionally not coded in this repository.

## 1) Pipeline and data flow

| Tutorial text topic (`ECM.tex`) | MATLAB implementation | Status | Notes |
|---|---|---|---|
| Execution pipeline: load -> preprocess -> identify -> surrogate 2RC -> validate -> verify -> export (`MATLAB Implementation Structure`) | `main_00_run_all.m`, `main_01_identify_validate.m` | Implemented | The script order matches the text pipeline. |
| Data import from digitised voltage-capacity curves (`Digitised Curve Data Used`) | `+ecmdata/ValenceDataImporter.readWideCsv` | Implemented | Reads wide-format CSV and builds curve structs. |
| SoC conversion and C-rate conversion (`Voltage--Capacity Curves and C-Rate Conversion`) | `+ecmdata/ValenceDataImporter.readWideCsv` | Implemented | Uses `SOC = 1 - cap/100` and `I = Crate * Q_Ah`. |
| Identification matrix over SoC grid (`Construction of the Identification Matrix`) | `+ecmdata/ValenceDataImporter.buildMatrix` | Implemented | Interpolates each curve to common SoC grid. |

## 2) Static identification

| Tutorial text topic (`ECM.tex`) | MATLAB implementation | Status | Notes |
|---|---|---|---|
| Quasi-static model: `Vt = OCV(z) - I*Reff(z)` (`Quasi-Static ECM as the Identifiable Model`) | `+ecmmodel/StaticECM.m` | Implemented | Same equation implemented in `voltage`. |
| Local fixed-SoC least-squares (`Local Least-Squares Identification`) | `+ecmopt/ECMParameterIdentifier.fitLocal` | Implemented | Uses backslash solve (`A \ y`) at each SoC. |
| Physical constraints on identified values (voltage envelope, positive resistance) | `+ecmopt/ECMParameterIdentifier.fitLocal` | Implemented | Clamps OCV to `[Vmin, Vmax]`, enforces `Reff >= 1e-6`. |
| Weighted least-squares (`Weighted Least-Squares Formulation`) | `+ecmopt/ECMParameterIdentifier.fitWeightedLocal` | Implemented | Uses point-wise weighting with endpoint and current-aware default weights. |
| Global regularised fit with smoothness (`Global Regularised Identification`) | `+ecmopt/ECMParameterIdentifier.fitGlobalRegularized` | Partially implemented | Implemented via `quadprog` when Optimization Toolbox is available; otherwise workflow falls back to weighted local fit. |

## 3) Surrogate dynamic 2RC model

| Tutorial text topic (`ECM.tex`) | MATLAB implementation | Status | Notes |
|---|---|---|---|
| Surrogate 2RC construction (`Construction of the Surrogate 2RC Tables`) | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure` | Implemented | Builds `R0,R1,C1,R2,C2` from identified `Reff`. |
| Split of apparent resistance into `R0+R1+R2 = Reff` | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure` | Implemented | Enforced algebraically and rechecked by verification. |
| Time constants assumptions (`tau1`, `tau2`) and capacitance from `C=tau/R` | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure` | Implemented | Uses `tau1 = 20 s`, `tau2 = 600 s`. |
| Dynamic time-domain 2RC simulation | `+ecmmodel/Dynamic2RC.simulate` | Implemented | Exact discrete RC state update with exponential factors. |
| Rigorous dynamic parameter identification from pulse/rest data | N/A | Conceptual | Explicitly out of scope due to missing transient test data. |

## 4) Validation, cross-validation, verification

| Tutorial text topic (`ECM.tex`) | MATLAB implementation | Status | Notes |
|---|---|---|---|
| Curve reconstruction and residuals (`Validation of the Quasi-Static Model`) | `+ecmopt/ECMParameterIdentifier.validateStatic` | Implemented | Computes predicted voltage and residual matrices. |
| RMSE, MAE, max error, bias metrics | `+ecmutil/errorMetrics.m` | Implemented | Metrics exported through `validateStatic`. |
| Leave-one-curve-out cross-validation (`Cross-Validation by Removing One C-Rate Curve`) | `+ecmopt/ECMParameterIdentifier.leaveOneCurveOut` | Implemented | Refit after removing each training curve. |
| Full validation suite (curve/group summaries, LOCO, noise robustness, report) | `+ecmval/ValidationSuite.runAll` | Implemented | Exports `validation_*_full.csv` tables, plots, and full text report. |
| Parameter and envelope verification (`Verification Before Export`) | `+ecmopt/ECMParameterIdentifier.verify` | Implemented | Positivity checks, envelope checks, consistency checks. |

## 5) Export, plotting, reproducibility outputs

| Tutorial text topic (`ECM.tex`) | MATLAB implementation | Status | Notes |
|---|---|---|---|
| Export MATLAB structure with static and dynamic fields (`MATLAB Implementation Structure`) | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure`, `main_01_identify_validate.m` | Implemented | Saved in `outputs/valence_actual_ecm_parameters.mat`. |
| Parameter-status labelling (`Parameter-Status Labelling`) | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure` | Implemented | Uses `datasheet-extrapolated`, `identified-apparent`, `surrogate` labels. |
| CSV evidence package (`Expected Output Files`) | `+ecmopt/ECMParameterIdentifier.writeTables` | Implemented | Writes parameter/validation/loco/verification CSV files. |
| Figures for curves, tables, validation, simulation | `+ecmplot/ECMPlotter.m` | Implemented | Produces PNG figures in `figures/`. |

## 6) Current mismatch to keep explicit

The tutorial document includes methods that are broader than the present code. This is intentional, but should remain explicit:

1. Global regularised constrained optimisation requires Optimization Toolbox (`quadprog`) and otherwise falls back to weighted local fitting.
2. Dynamic branch identification from transient tests is documented as future/required experimental extension and is not implemented.

## 7) Recommended consistency rule

When updating `ECM.tex` or MATLAB code, update this file in the same commit whenever any method status changes (`Implemented`, `Partially implemented`, `Conceptual`).

## 8) Equation-Level Traceability (Execution Section)

This section maps key equation labels from `ECM.tex` (Execution, Validation, and Implementation) to the MATLAB implementation.

| Equation label in `ECM.tex` | Mathematical intent | MATLAB anchor | Status |
|---|---|---|---|
| `eq:exec_crate_current` | Convert C-rate to current | `+ecmdata/ValenceDataImporter.readWideCsv` (`I_A = Crate * Q_Ah`) | Implemented |
| `eq:exec_capacity_to_soc` | Convert used capacity percentage to SoC | `+ecmdata/ValenceDataImporter.readWideCsv` (`SOC = 1 - cap/100`) | Implemented |
| `eq:exec_soc_grid`, `eq:exec_soc_fit_range` | Define SoC identification grid and range | `main_01_identify_validate.m` (`socGrid = linspace(0.05, 0.95, 91)`) | Implemented |
| `eq:exec_voltage_matrix` | Build voltage matrix over SoC grid and current set | `+ecmdata/ValenceDataImporter.buildMatrix` | Implemented |
| `eq:exec_local_A`, `eq:exec_local_y`, `eq:exec_local_parameter`, `eq:exec_local_model_matrix` | Fixed-SoC linear model setup | `+ecmopt/ECMParameterIdentifier.fitLocal` (`A = [ones, I]`, `p = A \ y`) | Implemented |
| `eq:exec_local_ls_problem`, `eq:exec_local_ls_solution` | Least-squares solve at each SoC | `+ecmopt/ECMParameterIdentifier.fitLocal` | Implemented |
| `eq:exec_ocv_reff_from_local_fit` | Recover `OCV` and `Reff` from fit coefficients | `+ecmopt/ECMParameterIdentifier.fitLocal` (`OCV = p(1)`, `Reff = -p(2)`) | Implemented |
| `eq:exec_regularised_identification` | Global regularized constrained fit | `+ecmopt/ECMParameterIdentifier.fitGlobalRegularized` | Partially implemented |
| `eq:exec_r0_initialised`, `eq:exec_rpol_table`, `eq:exec_r1_r2_surrogate`, `eq:exec_alpha_r`, `eq:exec_tau_surrogate`, `eq:exec_c1_c2_surrogate` | Surrogate 2RC table construction from `Reff` | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure` | Implemented |
| `eq:exec_surrogate_consistency` | Enforce/check `R0 + R1 + R2 ~= Reff` | Constructed in `buildBatteryStructure`, checked in `verify` | Implemented |
| `eq:exec_validation_vhat`, `eq:exec_validation_residual` | Reconstruct voltage and residuals | `+ecmopt/ECMParameterIdentifier.validateStatic` | Implemented |
| `eq:exec_validation_rmse`, `eq:exec_validation_mae`, `eq:exec_validation_max` | Curve-wise error metrics | `+ecmutil/errorMetrics.m` (called by `validateStatic`) | Implemented |
| `eq:exec_loco_fit_set`, `eq:exec_loco_prediction`, `eq:exec_loco_error` | Leave-one-curve-out cross-validation | `+ecmopt/ECMParameterIdentifier.leaveOneCurveOut` | Implemented |
| `eq:exec_verify_resistance`, `eq:exec_verify_capacitance`, `eq:exec_verify_voltage`, `eq:exec_verify_current_range` | Verification and admissibility checks | `+ecmopt/ECMParameterIdentifier.verify` | Implemented |
| `eq:exec_matlab_static_fields`, `eq:exec_matlab_dynamic_fields`, `eq:exec_matlab_metadata_fields` | Export field definitions and metadata | `+ecmopt/ECMParameterIdentifier.buildBatteryStructure`, `main_01_identify_validate.m` (`save`) | Implemented |
| `eq:exec_simulink_static_lookup`, `eq:exec_simulink_static_voltage` | Static ECM lookup and voltage law | `+ecmmodel/StaticECM.voltage`, `+ecmmodel/StaticECM.lookup` | Implemented |
| `eq:exec_simulink_dynamic_lookup`, `eq:exec_simulink_v1`, `eq:exec_simulink_v2`, `eq:exec_simulink_terminal_voltage`, `eq:exec_simulink_soc`, `eq:exec_simulink_soc_saturation` | Dynamic 2RC states, terminal voltage, SoC dynamics | `+ecmmodel/Dynamic2RC.simulate` | Implemented |
| `eq:exec_pack_capacity`, `eq:exec_pack_ocv`, `eq:exec_pack_resistances`, `eq:exec_pack_capacitances`, `eq:exec_pack_time_constants` | Series/parallel pack scaling laws | No dedicated implementation in current repository | Conceptual |

### Notes

1. The equation labels above are concentrated in the execution section of `ECM.tex` and were chosen because they map directly to code behavior.
2. Where multiple equations map to one function, the function implements a compact algorithmic block covering that mathematical sequence.
3. Conceptual entries are intentionally documented in the text even though the code currently targets the datasheet-based static workflow plus surrogate dynamic extension.
