%% main_02_simulate_time_domain.m
% Time-domain simulation of static and dynamic ECMs.
% Author: Andrea Coraddu

clear; close all; clc;

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

outDir = fullfile(projectRoot, 'outputs');
figDir = fullfile(projectRoot, 'figures');
paramFile = fullfile(outDir, 'valence_actual_ecm_parameters.mat');

if ~isfile(paramFile)
    error('Parameter file not found. Run main_01_identify_validate.m first.');
end

load(paramFile, 'Bat');

staticModel = ecmmodel.StaticECM.fromBat(Bat);
dynamicModel = ecmmodel.Dynamic2RC.fromBat(Bat);

[t_s, I_A] = ecmsim.CurrentProfiles.teachingProfile();
z0 = 0.85;

simStatic = staticModel.simulate(t_s, I_A, z0);
simDynamic = dynamicModel.simulate(t_s, I_A, z0);

save(fullfile(outDir, 'time_simulation_results.mat'), 'simStatic', 'simDynamic');

plotter = ecmplot.ECMPlotter();
plotter.plotSimulation(simStatic, simDynamic, figDir);

fprintf('\nTime-domain simulation completed.\n');
fprintf('Static final SoC:  %.4f\n', simStatic.SOC(end));
fprintf('Dynamic final SoC: %.4f\n', simDynamic.SOC(end));
