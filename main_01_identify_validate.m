%% main_01_identify_validate.m
% Identify OCV(SOC) and Reff(SOC) from Valence manufacturer curves,
% then run validation, verification, and export steps.
% Author: Andrea Coraddu

clear; close all; clc;

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

dataFile = fullfile(projectRoot, 'data', 'valence_digitised_curves_actual.csv');
outDir = fullfile(projectRoot, 'outputs');
figDir = fullfile(projectRoot, 'figures');
ecmutil.ensureDir(outDir);
ecmutil.ensureDir(figDir);

module = ecmdata.ValenceDataImporter.defaultModule();
curves = ecmdata.ValenceDataImporter.readWideCsv(dataFile, module);

socGrid = linspace(0.05, 0.95, 91).';
fitLabels = ["C8","C5","C3","C2","C1"];
validationLabels = ["C2x"];

data = ecmdata.ValenceDataImporter.buildMatrix(curves, socGrid, fitLabels, validationLabels);

identifier = ecmopt.ECMParameterIdentifier(module);
W = identifier.defaultWeightMatrix(data);
[localModel, fitInfoLocal] = identifier.fitWeightedLocal(data, W);

staticModel = localModel;
fitInfo = fitInfoLocal;
selectionReason = 'weighted local fit retained';

try
    [regModel, fitInfoReg] = identifier.fitGlobalRegularized(data, W, 1e-2, 1e-3, 1e-6);
    valLocal = identifier.validateStatic(data, localModel, true(size(data.I_A)));
    valReg = identifier.validateStatic(data, regModel, true(size(data.I_A)));
    rmseLocal = mean([valLocal.metrics.RMSE_V]);
    rmseReg = mean([valReg.metrics.RMSE_V]);

    if rmseReg <= 1.03 * rmseLocal
        staticModel = regModel;
        fitInfo = fitInfoReg;
        fitInfo.BaselineWeightedLocalRMSE_V = rmseLocal;
        fitInfo.SelectedRegularizedRMSE_V = rmseReg;
        fitInfo.SelectionRule = 'regularized accepted when mean RMSE <= 103% of weighted local';
        selectionReason = 'regularized fit selected (smoothness gain with controlled RMSE)';
    else
        fitInfo.BaselineWeightedLocalRMSE_V = rmseLocal;
        fitInfo.RejectedRegularizedRMSE_V = rmseReg;
        fitInfo.SelectionRule = 'regularized rejected because mean RMSE exceeded threshold';
    end
catch ME
    fitInfo.RegularizedFitError = ME.message;
    selectionReason = 'weighted local retained (regularized fit unavailable)';
end

validation = identifier.validateStatic(data, staticModel, true(size(data.I_A)));
loco = identifier.leaveOneCurveOut(data, 'weightedlocal');
Bat = identifier.buildBatteryStructure(staticModel, data, fitInfo);
dynamicModel = ecmmodel.Dynamic2RC.fromBat(Bat);
verification = identifier.verify(Bat, validation, data);
validationFull = ecmval.ValidationSuite.runAll(data, staticModel, identifier, outDir, figDir, lower(validationFullMethodName(fitInfo)));

save(fullfile(outDir, 'valence_actual_ecm_parameters.mat'), ...
    'Bat', 'staticModel', 'dynamicModel', 'fitInfo', 'data', 'validation', 'loco', 'verification', 'validationFull');

identifier.writeTables(Bat, validation, loco, verification, outDir);

plotter = ecmplot.ECMPlotter();
plotter.plotCurves(curves, figDir);
plotter.plotTables(staticModel, dynamicModel, figDir);
plotter.plotValidation(data, validation, figDir);
plotter.plotResiduals(data, validation, figDir);

fprintf('\nStatic identification completed.\n');
fprintf('OCV range: %.3f -- %.3f V\n', min(Bat.OCV_table), max(Bat.OCV_table));
fprintf('Reff range: %.3f -- %.3f mOhm\n', 1000*min(Bat.Reff_table), 1000*max(Bat.Reff_table));
fprintf('\nValidation metrics:\n');
disp(struct2table(validation.metrics));
fprintf('\nVerification checks:\n');
disp(struct2table(verification));
fprintf('\nStatic model selection: %s\n', selectionReason);
fprintf('Full validation tables exported to outputs/validation_*_full.csv\n');
fprintf('Full validation report: outputs/validation_report_full.txt\n');

function m = validationFullMethodName(fitInfo)
method = lower(string(fitInfo.Method));
if contains(method, 'regularized')
    m = 'regularized';
elseif contains(method, 'weighted')
    m = 'weightedlocal';
else
    m = 'local';
end
end
