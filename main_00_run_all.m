%% main_00_run_all.m
% Run the full Valence U27-12XP ECM workflow.
% Author: Andrea Coraddu

clear; close all; clc;

projectRoot = fileparts(mfilename('fullpath'));
addpath(genpath(projectRoot));

fprintf('\n=== Identifying and validating static ECM ===\n');
main_01_identify_validate;

fprintf('\n=== Simulating static and dynamic ECM ===\n');
main_02_simulate_time_domain;

fprintf('\nWorkflow complete. Check outputs/ and figures/.\n');
