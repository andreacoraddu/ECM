classdef ValidationSuite
    %VALIDATIONSUITE Comprehensive validation experiments and reporting.

    methods (Static)
        function results = runAll(data, staticModel, identifier, outDir, figDir, methodName)
            if nargin < 6 || isempty(methodName)
                methodName = 'weightedlocal';
            end

            ecmutil.ensureDir(outDir);
            ecmutil.ensureDir(figDir);

            base = identifier.validateStatic(data, staticModel, true(size(data.I_A)));
            curveTable = struct2table(base.metrics);
            curveTable.Crate = curveTable.Current_A / identifier.Module.Q_Ah;

            fitLabels = string(data.Labels(data.FitMask));
            valLabels = string(data.Labels(data.ValidationMask));
            curveTable.Group = repmat("other", height(curveTable), 1);
            curveTable.Group(ismember(string(curveTable.Label), fitLabels)) = "fit";
            curveTable.Group(ismember(string(curveTable.Label), valLabels)) = "holdout";

            groupSummary = ecmval.ValidationSuite.summarizeByGroup(curveTable);
            loco = identifier.leaveOneCurveOut(data, methodName);
            locoTable = struct2table(loco);
            extrapTable = ecmval.ValidationSuite.extrapolationHoldoutExperiment(data, identifier, methodName);

            [noiseTrials, noiseSummary] = ecmval.ValidationSuite.noiseRobustnessExperiment(data, identifier, methodName);
            methodSummary = ecmval.ValidationSuite.methodSummary(curveTable, groupSummary, locoTable, noiseSummary, methodName);
            gateTable = ecmval.ValidationSuite.evaluateAcceptanceGates(methodSummary, groupSummary, extrapTable);

            writetable(curveTable, fullfile(outDir, 'validation_curve_metrics_full.csv'));
            writetable(groupSummary, fullfile(outDir, 'validation_group_summary_full.csv'));
            writetable(locoTable, fullfile(outDir, 'validation_loco_full.csv'));
            writetable(extrapTable, fullfile(outDir, 'validation_extrapolation_holdout_full.csv'));
            writetable(noiseTrials, fullfile(outDir, 'validation_noise_trials_full.csv'));
            writetable(noiseSummary, fullfile(outDir, 'validation_noise_summary_full.csv'));
            writetable(methodSummary, fullfile(outDir, 'validation_method_summary_full.csv'));
            writetable(gateTable, fullfile(outDir, 'validation_acceptance_gates_full.csv'));

            ecmval.ValidationSuite.plotParity(base, data, figDir);
            ecmval.ValidationSuite.plotResidualBox(base, data, figDir);
            ecmval.ValidationSuite.plotResidualHeatmap(base, data, figDir);
            ecmval.ValidationSuite.plotLOCO(locoTable, figDir);
            ecmval.ValidationSuite.plotExtrapolationHoldout(extrapTable, figDir);
            ecmval.ValidationSuite.plotNoiseRobustness(noiseSummary, figDir);

            reportFile = fullfile(outDir, 'validation_report_full.txt');
            ecmval.ValidationSuite.writeReport(reportFile, methodSummary, groupSummary, extrapTable, noiseSummary, gateTable);

            results.base = base;
            results.curveTable = curveTable;
            results.groupSummary = groupSummary;
            results.locoTable = locoTable;
            results.extrapolationHoldoutTable = extrapTable;
            results.noiseTrials = noiseTrials;
            results.noiseSummary = noiseSummary;
            results.methodSummary = methodSummary;
            results.gateTable = gateTable;
            results.reportFile = reportFile;
            results.method = methodName;
        end
    end

    methods (Static, Access = private)
        function groupSummary = summarizeByGroup(curveTable)
            groups = unique(curveTable.Group, 'stable');
            groupSummary = table('Size',[0 10], ...
                'VariableTypes', {'string','double','double','double','double','double','double','double','double','double'}, ...
                'VariableNames', {'Group','Ncurves','MeanRMSE_V','MeanMAE_V','MeanMaxAbsError_V','MeanP95AbsError_V','MeanBias_V','MeanMAPE_pct','MeanR2','MeanNRMSE_pct'});

            for k = 1:numel(groups)
                g = groups(k);
                idx = curveTable.Group == g;
                if ~any(idx)
                    continue;
                end
                row = {g, sum(idx), ...
                    mean(curveTable.RMSE_V(idx),'omitnan'), ...
                    mean(curveTable.MAE_V(idx),'omitnan'), ...
                    mean(curveTable.MaxAbsError_V(idx),'omitnan'), ...
                    mean(curveTable.P95AbsError_V(idx),'omitnan'), ...
                    mean(curveTable.Bias_V(idx),'omitnan'), ...
                    mean(curveTable.MAPE_pct(idx),'omitnan'), ...
                    mean(curveTable.R2(idx),'omitnan'), ...
                    100*mean(curveTable.NRMSE_V(idx),'omitnan')};
                groupSummary = [groupSummary; row]; %#ok<AGROW>
            end
        end

        function [trialTable, summaryTable] = noiseRobustnessExperiment(data, identifier, methodName)
            rng(42);
            sigmaList_mV = [0, 2, 5, 10];
            nTrials = 30;

            trialTable = table('Size',[0 8], ...
                'VariableTypes', {'double','double','double','double','double','double','double','double'}, ...
                'VariableNames', {'Sigma_mV','Trial','MeanRMSE_V','HoldoutRMSE_V','MeanMAE_V','OCV50_V','Reff50_mOhm','MeanR2'});

            for s = 1:numel(sigmaList_mV)
                sigmaV = sigmaList_mV(s)/1000;
                for t = 1:nTrials
                    d = data;
                    d.V = data.V + sigmaV*randn(size(data.V));

                    model = ecmval.ValidationSuite.fitByMethod(identifier, d, methodName);
                    val = identifier.validateStatic(d, model, true(size(d.I_A)));
                    mt = struct2table(val.metrics);

                    holdoutIdx = ismember(string(mt.Label), string(d.Labels(d.ValidationMask)));
                    if any(holdoutIdx)
                        holdoutRMSE = mean(mt.RMSE_V(holdoutIdx), 'omitnan');
                    else
                        holdoutRMSE = NaN;
                    end

                    row = {sigmaList_mV(s), t, ...
                        mean(mt.RMSE_V, 'omitnan'), ...
                        holdoutRMSE, ...
                        mean(mt.MAE_V, 'omitnan'), ...
                        interp1(model.SOCGrid, model.OCV_V, 0.5, 'linear', 'extrap'), ...
                        1000*interp1(model.SOCGrid, model.Reff_Ohm, 0.5, 'linear', 'extrap'), ...
                        mean(mt.R2, 'omitnan')};
                    trialTable = [trialTable; row]; %#ok<AGROW>
                end
            end

            summaryTable = table('Size',[0 9], ...
                'VariableTypes', {'double','double','double','double','double','double','double','double','double'}, ...
                'VariableNames', {'Sigma_mV','MeanRMSE_V','StdRMSE_V','MeanHoldoutRMSE_V','MeanMAE_V','StdMAE_V','MeanOCV50_V','MeanReff50_mOhm','MeanR2'});

            for s = 1:numel(sigmaList_mV)
                idx = trialTable.Sigma_mV == sigmaList_mV(s);
                row = {sigmaList_mV(s), ...
                    mean(trialTable.MeanRMSE_V(idx), 'omitnan'), ...
                    std(trialTable.MeanRMSE_V(idx), 0, 'omitnan'), ...
                    mean(trialTable.HoldoutRMSE_V(idx), 'omitnan'), ...
                    mean(trialTable.MeanMAE_V(idx), 'omitnan'), ...
                    std(trialTable.MeanMAE_V(idx), 0, 'omitnan'), ...
                    mean(trialTable.OCV50_V(idx), 'omitnan'), ...
                    mean(trialTable.Reff50_mOhm(idx), 'omitnan'), ...
                    mean(trialTable.MeanR2(idx), 'omitnan')};
                summaryTable = [summaryTable; row]; %#ok<AGROW>
            end
        end

        function model = fitByMethod(identifier, data, methodName)
            W = identifier.defaultWeightMatrix(data);
            switch lower(methodName)
                case 'local'
                    [model, ~] = identifier.fitLocal(data);
                case 'weightedlocal'
                    [model, ~] = identifier.fitWeightedLocal(data, W);
                case 'regularized'
                    try
                        [model, ~] = identifier.fitGlobalRegularized(data, W, 1e-2, 1e-3, 1e-6);
                    catch
                        [model, ~] = identifier.fitWeightedLocal(data, W);
                    end
                otherwise
                    [model, ~] = identifier.fitWeightedLocal(data, W);
            end
        end

        function extrapTable = extrapolationHoldoutExperiment(data, identifier, methodName)
            extrapTable = table('Size',[0 12], ...
                'VariableTypes', {'string','string','double','double','double','double','double','double','double','double','double','double'}, ...
                'VariableNames', {'Scenario','PredictedLabel','PredictedCurrent_A','PredictedCrate','MaxTrainCrate','ExtrapolationGapCrate','RMSE_V','MAE_V','MaxAbsError_V','P95AbsError_V','Bias_V','R2'});

            scenarios = struct([]);
            scenarios(1).Name = "holdout_1C";
            scenarios(1).TrainLabels = ["C8","C5","C3","C2"];
            scenarios(1).PredLabel = "C1";
            scenarios(2).Name = "holdout_2C";
            scenarios(2).TrainLabels = ["C8","C5","C3","C2","C1"];
            scenarios(2).PredLabel = "C2x";

            for s = 1:numel(scenarios)
                d = data;
                d.FitMask = ismember(string(d.Labels), scenarios(s).TrainLabels);

                model = ecmval.ValidationSuite.fitByMethod(identifier, d, methodName);

                predMask = string(data.Labels) == scenarios(s).PredLabel;
                val = identifier.validateStatic(data, model, predMask);
                mt = struct2table(val.metrics);
                if isempty(mt)
                    continue;
                end

                predCrate = mt.Current_A(1) / identifier.Module.Q_Ah;
                trainCrates = abs(d.I_A(d.FitMask)) / identifier.Module.Q_Ah;
                maxTrainCrate = max(trainCrates);

                row = {scenarios(s).Name, string(mt.Label(1)), mt.Current_A(1), predCrate, ...
                    maxTrainCrate, predCrate - maxTrainCrate, ...
                    mt.RMSE_V(1), mt.MAE_V(1), mt.MaxAbsError_V(1), mt.P95AbsError_V(1), mt.Bias_V(1), mt.R2(1)};
                extrapTable = [extrapTable; row]; %#ok<AGROW>
            end
        end

        function gateTable = evaluateAcceptanceGates(methodSummary, groupSummary, extrapTable)
            th = ecmval.ValidationSuite.defaultAcceptanceThresholds();

            fitR2 = NaN;
            holdoutR2 = NaN;
            idxFit = groupSummary.Group == "fit";
            idxHold = groupSummary.Group == "holdout";
            if any(idxFit)
                fitR2 = groupSummary.MeanR2(idxFit);
            end
            if any(idxHold)
                holdoutR2 = groupSummary.MeanR2(idxHold);
            end

            ext1_rmse = NaN; ext1_r2 = NaN;
            ext2_rmse = NaN; ext2_r2 = NaN;
            idx1 = extrapTable.Scenario == "holdout_1C";
            idx2 = extrapTable.Scenario == "holdout_2C";
            if any(idx1)
                ext1_rmse = extrapTable.RMSE_V(idx1);
                ext1_r2 = extrapTable.R2(idx1);
            end
            if any(idx2)
                ext2_rmse = extrapTable.RMSE_V(idx2);
                ext2_r2 = extrapTable.R2(idx2);
            end

            gateTable = table('Size',[0 6], ...
                'VariableTypes', {'string','double','double','string','logical','string'}, ...
                'VariableNames', {'Gate','Value','Threshold','Comparator','Pass','Comment'});

            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('fit_rmse_max', methodSummary.FitRMSE_V, th.FitRMSE_max, '<=', 'mean fit RMSE gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('holdout_rmse_max', methodSummary.HoldoutRMSE_V, th.HoldoutRMSE_max, '<=', 'main holdout RMSE gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('loco_rmse_max', methodSummary.LOCO_RMSE_V, th.LOCO_RMSE_max, '<=', 'leave-one-curve-out RMSE gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('fit_r2_min', fitR2, th.FitR2_min, '>=', 'mean fit R2 gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('holdout_r2_min', holdoutR2, th.HoldoutR2_min, '>=', 'main holdout R2 gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('noise_5mv_rmse_max', methodSummary.Noise5mV_MeanRMSE_V, th.Noise5mV_RMSE_max, '<=', 'noise robustness RMSE gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('extrap_1c_rmse_max', ext1_rmse, th.Extrap1C_RMSE_max, '<=', '1C extrapolation RMSE gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('extrap_1c_r2_min', ext1_r2, th.Extrap1C_R2_min, '>=', '1C extrapolation R2 gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('extrap_2c_rmse_max', ext2_rmse, th.Extrap2C_RMSE_max, '<=', '2C extrapolation RMSE gate')]; %#ok<AGROW>
            gateTable = [gateTable; ecmval.ValidationSuite.makeGate('extrap_2c_r2_min', ext2_r2, th.Extrap2C_R2_min, '>=', '2C extrapolation R2 gate')]; %#ok<AGROW>
        end

        function th = defaultAcceptanceThresholds()
            th.FitRMSE_max = 0.03;
            th.HoldoutRMSE_max = 0.35;
            th.LOCO_RMSE_max = 0.08;
            th.FitR2_min = 0.98;
            th.HoldoutR2_min = 0.00;
            th.Noise5mV_RMSE_max = 0.09;
            th.Extrap1C_RMSE_max = 0.08;
            th.Extrap1C_R2_min = 0.90;
            th.Extrap2C_RMSE_max = 0.35;
            th.Extrap2C_R2_min = 0.00;
        end

        function row = makeGate(name, value, threshold, comp, comment)
            pass = false;
            if isfinite(value) && isfinite(threshold)
                switch comp
                    case '<='
                        pass = value <= threshold;
                    case '>='
                        pass = value >= threshold;
                end
            end
            row = {string(name), value, threshold, string(comp), pass, string(comment)};
        end

        function methodSummary = methodSummary(curveTable, groupSummary, locoTable, noiseSummary, methodName)
            fitIdx = curveTable.Group == "fit";
            holdoutIdx = curveTable.Group == "holdout";

            fitRMSE = mean(curveTable.RMSE_V(fitIdx), 'omitnan');
            holdoutRMSE = mean(curveTable.RMSE_V(holdoutIdx), 'omitnan');
            locoRMSE = mean(locoTable.RMSE_V, 'omitnan');
            noiseRMSEat5mV = noiseSummary.MeanRMSE_V(noiseSummary.Sigma_mV == 5);
            if isempty(noiseRMSEat5mV)
                noiseRMSEat5mV = NaN;
            end

            maxErr = max(curveTable.MaxAbsError_V, [], 'omitnan');
            minR2 = min(curveTable.R2, [], 'omitnan');
            meanP95 = mean(curveTable.P95AbsError_V, 'omitnan');

            methodSummary = table(string(methodName), fitRMSE, holdoutRMSE, locoRMSE, ...
                noiseRMSEat5mV, maxErr, minR2, meanP95, ...
                'VariableNames', {'Method','FitRMSE_V','HoldoutRMSE_V','LOCO_RMSE_V','Noise5mV_MeanRMSE_V','WorstCurveMaxAbsError_V','MinCurveR2','MeanCurveP95AbsError_V'});

            if ~isempty(groupSummary)
                groupSummary = sortrows(groupSummary, 'Group'); %#ok<NASGU>
            end
        end

        function plotParity(base, data, figDir)
            p = ecmval.ValidationSuite.pastelPalette(6);
            measured = data.V(:);
            pred = base.Vhat(:);
            valid = isfinite(measured) & isfinite(pred);
            measured = measured(valid);
            pred = pred(valid);

            f = figure('Color','w', 'Position', [120 120 880 700]);
            ax = axes(f); hold(ax, 'on');
            scatter(ax, measured, pred, 13, 'filled', ...
                'MarkerFaceColor', p(1,:), 'MarkerFaceAlpha', 0.24, 'MarkerEdgeAlpha', 0.14);
            mn = min([measured; pred]);
            mx = max([measured; pred]);
            plot(ax, [mn mx], [mn mx], '--', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.4);
            em = ecmutil.errorMetrics(measured, pred);
            txt = sprintf('RMSE = %.1f mV\nR2 = %.3f\nP95 = %.1f mV', ...
                1000*em.RMSE_V, em.R2, 1000*em.P95AbsError_V);
            text(ax, mn + 0.05*(mx-mn), mx - 0.16*(mx-mn), txt, ...
                'FontSize', 10, 'BackgroundColor', [1 1 1 0.70], 'Margin', 6, 'Interpreter', 'none');
            ecmval.ValidationSuite.styleAxes(ax);
            xlabel(ax, 'Measured voltage [V]');
            ylabel(ax, 'Reconstructed voltage [V]');
            title(ax, 'Parity plot: measured vs reconstructed voltage');
            axis(ax, 'equal');
            xlim(ax, [mn mx]);
            ylim(ax, [mn mx]);
            ecmval.ValidationSuite.saveFigure(f, figDir, 'matlab_fig08_validation_parity');
        end

        function plotResidualBox(base, data, figDir)
            p = ecmval.ValidationSuite.pastelPalette(6);
            M = size(base.Residual, 1);
            N = size(base.Residual, 2);
            r = 1000*base.Residual(:);
            g = strings(M*N,1);
            labels = string(data.Names);
            for j = 1:N
                g((j-1)*M + (1:M)) = labels(j);
            end
            valid = isfinite(r);

            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f); hold(ax, 'on');
            boxchart(ax, categorical(g(valid)), r(valid), 'BoxFaceColor', p(2,:));
            yline(ax, 0, '--', 'Color', [0.35 0.35 0.35]);
            yline(ax, 50, ':', 'Color', [0.82 0.55 0.55]);
            yline(ax, -50, ':', 'Color', [0.82 0.55 0.55]);
            ecmval.ValidationSuite.styleAxes(ax);
            ylabel(ax, 'Residual [mV]');
            xlabel(ax, 'Curve');
            title(ax, 'Residual distribution by curve with $\pm 50$ mV reference');
            ecmval.ValidationSuite.saveFigure(f, figDir, 'matlab_fig09_validation_residual_boxplot');
        end

        function plotResidualHeatmap(base, data, figDir)
            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f);
            imagesc(ax, 1:numel(data.I_A), data.SOCGrid, 1000*base.Residual);
            set(ax, 'YDir', 'normal');
            colormap(ax, ecmval.ValidationSuite.pastelDivergingMap(256));
            caxis(ax, [-max(abs(1000*base.Residual(:))), max(abs(1000*base.Residual(:)))]);
            ecmval.ValidationSuite.styleAxes(ax);
            xlabel(ax, 'Curve index');
            ylabel(ax, 'State of charge [-]');
            title(ax, 'Residual heatmap [mV] across SoC and curve index');
            cb = colorbar(ax);
            cb.Label.String = 'Residual [mV]';
            ecmval.ValidationSuite.saveFigure(f, figDir, 'matlab_fig10_validation_residual_heatmap');
        end

        function plotLOCO(locoTable, figDir)
            if isempty(locoTable)
                return;
            end
            p = ecmval.ValidationSuite.pastelPalette(6);
            f = figure('Color','w', 'Position', [120 120 860 520]);
            ax = axes(f);
            vals = 1000*locoTable.RMSE_V;
            b = bar(ax, categorical(string(locoTable.RemovedCurve)), vals);
            b.FaceColor = p(3,:);
            b.EdgeColor = 0.7*p(3,:);
            for i = 1:numel(vals)
                text(ax, i, vals(i)+0.8, sprintf('%.1f', vals(i)), 'HorizontalAlignment', 'center', 'FontSize', 10);
            end
            ecmval.ValidationSuite.styleAxes(ax);
            ylabel(ax, 'RMSE [mV]');
            xlabel(ax, 'Removed curve');
            title(ax, 'Leave-one-curve-out RMSE with bar labels');
            ecmval.ValidationSuite.saveFigure(f, figDir, 'matlab_fig11_validation_loco_rmse');
        end

        function plotExtrapolationHoldout(extrapTable, figDir)
            if isempty(extrapTable)
                return;
            end
            p = ecmval.ValidationSuite.pastelPalette(6);

            f = figure('Color','w', 'Position', [120 120 1040 500]);
            tiledlayout(1,2, 'TileSpacing', 'compact', 'Padding', 'compact');

            nexttile;
            valsRMSE = 1000*extrapTable.RMSE_V;
            b1 = bar(categorical(string(extrapTable.Scenario)), valsRMSE);
            b1.FaceColor = p(4,:);
            ax1 = gca;
            ecmval.ValidationSuite.styleAxes(ax1);
            ylabel(ax1, 'RMSE [mV]');
            xlabel(ax1, 'Scenario');
            title(ax1, 'Extrapolation holdout RMSE');
            for i = 1:numel(valsRMSE)
                text(ax1, i, valsRMSE(i)+4, sprintf('%.1f', valsRMSE(i)), 'HorizontalAlignment', 'center', 'FontSize', 10);
            end

            nexttile;
            valsR2 = extrapTable.R2;
            b2 = bar(categorical(string(extrapTable.Scenario)), valsR2);
            b2.FaceColor = p(1,:);
            ax2 = gca;
            ecmval.ValidationSuite.styleAxes(ax2);
            ylabel(ax2, 'R2 [-]');
            xlabel(ax2, 'Scenario');
            title(ax2, 'Extrapolation holdout R2');
            for i = 1:numel(valsR2)
                text(ax2, i, valsR2(i)+0.02, sprintf('%.3f', valsR2(i)), 'HorizontalAlignment', 'center', 'FontSize', 10);
            end

            ecmval.ValidationSuite.saveFigure(f, figDir, 'matlab_fig13_validation_extrapolation_holdout');
        end

        function plotNoiseRobustness(noiseSummary, figDir)
            if isempty(noiseSummary)
                return;
            end
            p = ecmval.ValidationSuite.pastelPalette(6);
            f = figure('Color','w', 'Position', [120 120 900 560]);
            ax = axes(f); hold(ax, 'on');
            errorbar(ax, noiseSummary.Sigma_mV, 1000*noiseSummary.MeanRMSE_V, 1000*noiseSummary.StdRMSE_V, ...
                '-o', 'LineWidth', 1.8, 'Color', p(5,:), 'MarkerFaceColor', p(5,:));
            plot(ax, noiseSummary.Sigma_mV, 1000*noiseSummary.MeanHoldoutRMSE_V, '--s', ...
                'LineWidth', 1.6, 'Color', p(2,:), 'MarkerFaceColor', p(2,:), ...
                'DisplayName', 'holdout RMSE');
            ecmval.ValidationSuite.styleAxes(ax);
            xlabel(ax, 'Injected noise std [mV]');
            ylabel(ax, 'RMSE [mV]');
            legend(ax, {'mean RMSE $\pm$ std', 'holdout RMSE'}, 'Location', 'northwest');
            title(ax, 'Noise robustness experiment with holdout trend');
            ecmval.ValidationSuite.saveFigure(f, figDir, 'matlab_fig12_validation_noise_robustness');
        end

        function writeReport(fileName, methodSummary, groupSummary, extrapTable, noiseSummary, gateTable)
            fid = fopen(fileName, 'w');
            if fid < 0
                return;
            end
            c = onCleanup(@() fclose(fid)); %#ok<NASGU>

            fprintf(fid, 'Full Validation Report\n');
            fprintf(fid, '======================\n\n');

            fprintf(fid, 'Selected method: %s\n', methodSummary.Method);
            fprintf(fid, 'Fit RMSE: %.6f V\n', methodSummary.FitRMSE_V);
            fprintf(fid, 'Holdout RMSE: %.6f V\n', methodSummary.HoldoutRMSE_V);
            fprintf(fid, 'LOCO RMSE: %.6f V\n', methodSummary.LOCO_RMSE_V);
            fprintf(fid, 'Worst max abs error: %.6f V\n', methodSummary.WorstCurveMaxAbsError_V);
            fprintf(fid, 'Minimum curve R2: %.4f\n', methodSummary.MinCurveR2);
            fprintf(fid, 'Mean curve P95 abs error: %.6f V\n\n', methodSummary.MeanCurveP95AbsError_V);

            fprintf(fid, 'Group summary\n');
            fprintf(fid, '-------------\n');
            for i = 1:height(groupSummary)
                fprintf(fid, '%s: RMSE=%.6f V, MAE=%.6f V, MAPE=%.3f %%, R2=%.4f\n', ...
                    groupSummary.Group(i), groupSummary.MeanRMSE_V(i), groupSummary.MeanMAE_V(i), ...
                    groupSummary.MeanMAPE_pct(i), groupSummary.MeanR2(i));
            end

            fprintf(fid, '\nExtrapolation holdout summary\n');
            fprintf(fid, '----------------------------\n');
            for i = 1:height(extrapTable)
                fprintf(fid, '%s (predict %s, gap %.2fC): RMSE=%.6f V, MAE=%.6f V, R2=%.4f\n', ...
                    extrapTable.Scenario(i), extrapTable.PredictedLabel(i), extrapTable.ExtrapolationGapCrate(i), ...
                    extrapTable.RMSE_V(i), extrapTable.MAE_V(i), extrapTable.R2(i));
            end

            fprintf(fid, '\nNoise robustness summary\n');
            fprintf(fid, '------------------------\n');
            for i = 1:height(noiseSummary)
                fprintf(fid, 'sigma=%g mV: mean RMSE=%.6f V (+/- %.6f V), holdout RMSE=%.6f V\n', ...
                    noiseSummary.Sigma_mV(i), noiseSummary.MeanRMSE_V(i), noiseSummary.StdRMSE_V(i), noiseSummary.MeanHoldoutRMSE_V(i));
            end

            fprintf(fid, '\nAcceptance gates (pass/fail)\n');
            fprintf(fid, '-----------------------------\n');
            for i = 1:height(gateTable)
                status = 'FAIL';
                if gateTable.Pass(i)
                    status = 'PASS';
                end
                fprintf(fid, '%s: value=%.6f %s %.6f -> %s\n', ...
                    gateTable.Gate(i), gateTable.Value(i), gateTable.Comparator(i), gateTable.Threshold(i), status);
            end

            overallPass = all(gateTable.Pass);
            if overallPass
                fprintf(fid, '\nOverall validation decision: PASS\n');
            else
                fprintf(fid, '\nOverall validation decision: FAIL\n');
            end
        end

        function styleAxes(ax)
            grid(ax, 'on');
            grid(ax, 'minor');
            box(ax, 'on');
            ax.GridAlpha = 0.22;
            ax.MinorGridAlpha = 0.12;
            ax.LineWidth = 1.0;
            ax.FontSize = 11;
            ax.Color = [0.985 0.985 0.99];
        end

        function saveFigure(f, figDir, baseName)
            exportgraphics(f, fullfile(figDir, [baseName '.png']), 'Resolution', 220, 'BackgroundColor', 'white');
            exportgraphics(f, fullfile(figDir, [baseName '.pdf']), 'ContentType', 'vector', 'BackgroundColor', 'white');
        end

        function cmap = pastelPalette(n)
            base = [
                0.56 0.73 0.93
                0.93 0.66 0.71
                0.70 0.86 0.72
                0.86 0.77 0.93
                0.96 0.83 0.62
                0.61 0.83 0.83
                0.93 0.74 0.59
                0.73 0.76 0.93
            ];
            if n <= size(base,1)
                cmap = base(1:n,:);
            else
                x = linspace(1, size(base,1), size(base,1));
                xi = linspace(1, size(base,1), n);
                cmap = [interp1(x, base(:,1), xi, 'pchip')', ...
                        interp1(x, base(:,2), xi, 'pchip')', ...
                        interp1(x, base(:,3), xi, 'pchip')'];
                cmap = min(max(cmap, 0), 1);
            end
        end

        function cmap = pastelDivergingMap(n)
            anchor = [
                0.45 0.63 0.88
                0.74 0.84 0.95
                0.97 0.97 0.98
                0.95 0.82 0.84
                0.86 0.60 0.66
            ];
            x = linspace(1, size(anchor,1), size(anchor,1));
            xi = linspace(1, size(anchor,1), n);
            cmap = [interp1(x, anchor(:,1), xi, 'pchip')', ...
                    interp1(x, anchor(:,2), xi, 'pchip')', ...
                    interp1(x, anchor(:,3), xi, 'pchip')'];
            cmap = min(max(cmap, 0), 1);
        end
    end
end
