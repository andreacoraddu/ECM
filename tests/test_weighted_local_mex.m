%% test_weighted_local_mex.m
% Validate C++ MEX weighted-local solver against MATLAB implementation.

projectRoot = fileparts(fileparts(mfilename('fullpath')));
cd(projectRoot);
addpath(genpath(projectRoot));

ok = ecmutil.tryBuildMex(projectRoot);
assert(ok, 'MEX build failed or ecm_weighted_local_mex not found.');

dataFile = fullfile(projectRoot, 'data', 'valence_digitised_curves_actual.csv');
module = ecmdata.ValenceDataImporter.defaultModule();
curves = ecmdata.ValenceDataImporter.readWideCsv(dataFile, module);

socGrid = linspace(0.05, 0.95, 91).';
fitLabels = ["C8","C5","C3","C2","C1"];
validationLabels = ["C2x"];
data = ecmdata.ValenceDataImporter.buildMatrix(curves, socGrid, fitLabels, validationLabels);

identifier = ecmopt.ECMParameterIdentifier(module);
W = identifier.defaultWeightMatrix(data);

[modelMat, infoMat] = identifier.fitWeightedLocal(data, W, false);
[modelMex, infoMex] = identifier.fitWeightedLocal(data, W, true);

assert(strcmp(infoMat.CoreEngine, 'matlab'), 'MATLAB path did not execute as expected.');
assert(strcmp(infoMex.CoreEngine, 'ecm_weighted_local_mex'), 'MEX path did not execute as expected.');

dOCV = abs(modelMat.OCV_V - modelMex.OCV_V);
dReff = abs(modelMat.Reff_Ohm - modelMex.Reff_Ohm);

maxOCV = max(dOCV(~isnan(dOCV)));
maxReff = max(dReff(~isnan(dReff)));

assert(maxOCV < 1e-10, 'OCV mismatch too high: %g', maxOCV);
assert(maxReff < 1e-10, 'Reff mismatch too high: %g', maxReff);

fprintf('test_weighted_local_mex PASS (max OCV diff=%g, max Reff diff=%g)\n', maxOCV, maxReff);
