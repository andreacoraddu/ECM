# Valence U27-12XP ECM Identification and Validation Package

Author: Andrea Coraddu

This package uses digitised manufacturer curves in `data/valence_digitised_curves_actual.csv`.

Run in MATLAB from this folder:

```matlab
main_00_run_all
```

Main steps:
1. import manufacturer voltage--capacity curves;
2. convert capacity used to SoC;
3. convert C-rate to current;
4. fit static ECM parameters `OCV(SOC)` and `Reff(SOC)`;
5. validate reconstructed manufacturer curves;
6. build a documented surrogate 2RC model;
7. verify all parameter tables;
8. simulate static and dynamic ECMs over time.

Important limitation:
The uploaded curves are sufficient for static/quasi-static validation and verification. They are not sufficient for rigorous dynamic 1RC/2RC parameter identification because pulse/rest relaxation data are missing.

## Text-Code Traceability

To ensure the tutorial text is reflected by the MATLAB implementation, use:

- `TEXT_CODE_TRACEABILITY.md`

This file maps the major methodology sections and equations in `ECM.tex` to the exact MATLAB files/functions, and marks each item as:

- implemented;
- partially implemented;
- conceptual (documented but not currently coded).
