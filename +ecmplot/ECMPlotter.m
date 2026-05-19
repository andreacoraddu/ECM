classdef ECMPlotter
    %ECMPLOTTER Plot identification, validation and simulation results.

    methods
        function obj = ECMPlotter()
            set(groot,'defaultTextInterpreter','latex');
            set(groot,'defaultAxesTickLabelInterpreter','latex');
            set(groot,'defaultLegendInterpreter','latex');
            set(groot,'defaultAxesFontSize',11);
            set(groot,'defaultLineLineWidth',2.0);
        end

        function plotCurves(~, curves, figDir)
            ecmutil.ensureDir(figDir);
            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f); hold(ax, 'on');
            cmap = ecmplot.ECMPlotter.pastelPalette(max(numel(curves), 3));
            for j = 1:numel(curves)
                plot(ax, curves(j).SOC, curves(j).Voltage_V, 'Color', cmap(j,:), ...
                    'DisplayName', sprintf('%s (%.2fC)', curves(j).Name, curves(j).Crate));
            end
            ecmplot.ECMPlotter.styleAxes(ax);
            set(ax,'XDir','reverse');
            xlabel(ax, 'State of charge $z$ [-]');
            ylabel(ax, 'Terminal voltage $V_T$ [V]');
            legend(ax, 'Location', 'southwest', 'NumColumns', 2);
            title(ax, 'Digitised manufacturer voltage curves by C-rate');
            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig01_digitised_curves');
        end

        function plotTables(~, staticModel, dynamicModel, figDir)
            ecmutil.ensureDir(figDir);
            z = staticModel.SOCGrid;
            p = ecmplot.ECMPlotter.pastelPalette(8);

            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f); hold(ax, 'on');
            plot(ax, z, staticModel.OCV_V, 'Color', p(1,:));
            ecmplot.ECMPlotter.styleAxes(ax);
            set(ax,'XDir','reverse');
            xlabel(ax, 'State of charge $z$ [-]');
            ylabel(ax, '$V_{\mathrm{OC}}$ [V]');
            title(ax, sprintf('Identified OCV table (range %.3f to %.3f V)', min(staticModel.OCV_V), max(staticModel.OCV_V)));
            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig02_ocv');

            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f); hold(ax, 'on');
            plot(ax, z, 1000*staticModel.Reff_Ohm, 'Color', p(2,:), 'DisplayName','$R_{\mathrm{eff}}$');
            plot(ax, z, 1000*dynamicModel.R0_Ohm, '--', 'Color', p(3,:), 'DisplayName','$R_0$');
            plot(ax, z, 1000*dynamicModel.R1_Ohm, '-.', 'Color', p(4,:), 'DisplayName','$R_1$');
            plot(ax, z, 1000*dynamicModel.R2_Ohm, ':', 'Color', p(5,:), 'DisplayName','$R_2$');
            ecmplot.ECMPlotter.styleAxes(ax);
            set(ax,'XDir','reverse');
            xlabel(ax, 'State of charge $z$ [-]');
            ylabel(ax, 'Resistance [m$\Omega$]');
            legend(ax, 'Location', 'best');
            title(ax, 'Resistance tables and surrogate decomposition');
            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig03_resistances');
        end

        function plotValidation(~, data, validation, figDir)
            ecmutil.ensureDir(figDir);
            f = figure('Color','w', 'Position', [120 120 1120 620]);
            t = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
            p = ecmplot.ECMPlotter.pastelPalette(max(sum(data.FitMask)+2, 8));

            ax1 = nexttile(t, 1); hold(ax1, 'on');
            k = 0;
            for j = find(data.FitMask)
                k = k + 1;
                plot(ax1, data.SOCGrid, data.V(:,j), 'Color', p(k,:), 'DisplayName', data.Names(j) + " measured");
                plot(ax1, data.SOCGrid, validation.Vhat(:,j), '--', 'Color', 0.85*p(k,:), 'DisplayName', data.Names(j) + " model");
            end

            ecmplot.ECMPlotter.styleAxes(ax1);
            set(ax1,'XDir','reverse');
            xlabel(ax1, 'State of charge $z$ [-]');
            ylabel(ax1, 'Terminal voltage [V]');
            legend(ax1, 'Location', 'southwest', 'NumColumns', 2);
            title(ax1, 'Fit-curve reconstruction');

            ax2 = nexttile(t, 2); hold(ax2, 'on');
            holdIdx = find(data.ValidationMask);
            if ~isempty(holdIdx)
                j = holdIdx(1);
                plot(ax2, data.SOCGrid, data.V(:,j), '-', 'Color', p(6,:), 'DisplayName', data.Names(j) + " measured");
                plot(ax2, data.SOCGrid, validation.Vhat(:,j), '--', 'Color', p(7,:), 'DisplayName', data.Names(j) + " model");
                met = ecmutil.errorMetrics(data.V(:,j), validation.Vhat(:,j));
                txt = sprintf('RMSE = %.1f mV\nR2 = %.3f', 1000*met.RMSE_V, met.R2);
                text(ax2, 0.14, min(data.V(:,j))+0.18, txt, 'FontSize', 10, ...
                    'BackgroundColor', [1 1 1 0.65], 'Margin', 6, 'Interpreter', 'none');
            end
            ecmplot.ECMPlotter.styleAxes(ax2);
            set(ax2,'XDir','reverse');
            xlabel(ax2, 'State of charge $z$ [-]');
            ylabel(ax2, 'Terminal voltage [V]');
            legend(ax2, 'Location', 'southwest');
            title(ax2, 'Reserved holdout curve');

            title(t, 'Static ECM validation: fit and holdout content');
            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig04_validation');
        end

        function plotResiduals(~, data, validation, figDir)
            ecmutil.ensureDir(figDir);
            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f); hold(ax, 'on');
            p = ecmplot.ECMPlotter.pastelPalette(max(sum(data.FitMask), 3));
            k = 0;
            for j = find(data.FitMask)
                k = k + 1;
                plot(ax, data.SOCGrid, 1000*validation.Residual(:,j), 'Color', p(k,:), 'DisplayName', data.Names(j));
            end
            yline(ax, 0, '--', 'Color', [0.35 0.35 0.35]);
            yline(ax, 50, ':', 'Color', [0.82 0.55 0.55], 'DisplayName', '$\pm 50$ mV band');
            yline(ax, -50, ':', 'Color', [0.82 0.55 0.55], 'HandleVisibility', 'off');
            ecmplot.ECMPlotter.styleAxes(ax);
            set(ax,'XDir','reverse');
            xlabel(ax, 'State of charge $z$ [-]');
            ylabel(ax, 'Residual [mV]');
            legend(ax, 'Location', 'best');
            title(ax, 'Voltage residuals on fit curves');
            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig05_residuals');
        end

        function plotSimulation(~, simStatic, simDynamic, figDir)
            ecmutil.ensureDir(figDir);
            t = simStatic.t_s/60;
            p = ecmplot.ECMPlotter.pastelPalette(6);

            f = figure('Color','w', 'Position', [120 120 980 560]);
            ax = axes(f); hold(ax, 'on');
            area(ax, t, simStatic.I_A, 'FaceColor', p(1,:), 'EdgeColor', p(2,:), 'FaceAlpha', 0.65);
            plot(ax, t, simStatic.I_A, 'Color', p(2,:));
            ecmplot.ECMPlotter.styleAxes(ax);
            xlabel(ax, 'Time [min]'); ylabel(ax, 'Current [A]');
            title(ax, 'Current profile (discharge positive)');
            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig06_current');

            f = figure('Color','w', 'Position', [120 120 980 560]);
            tlo = tiledlayout(f, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
            ax1 = nexttile(tlo, 1); hold(ax1, 'on');
            plot(ax1, t, simStatic.Vt_V, 'Color', p(3,:), 'DisplayName','static');
            plot(ax1, t, simDynamic.Vt_V, '--', 'Color', p(4,:), 'DisplayName','dynamic 2RC');
            ecmplot.ECMPlotter.styleAxes(ax1);
            ylabel(ax1, '$V_T$ [V]');
            legend(ax1, 'Location', 'best');
            title(ax1, 'Terminal voltage trajectories');

            ax2 = nexttile(tlo, 2); hold(ax2, 'on');
            dV_mV = 1000*(simDynamic.Vt_V - simStatic.Vt_V);
            plot(ax2, t, dV_mV, 'Color', p(5,:));
            yline(ax2, 0, '--', 'Color', [0.35 0.35 0.35]);
            ecmplot.ECMPlotter.styleAxes(ax2);
            xlabel(ax2, 'Time [min]');
            ylabel(ax2, '$\Delta V$ [mV]');
            title(ax2, sprintf('Dynamic-static voltage difference (max %.1f mV)', max(abs(dV_mV))));

            ecmplot.ECMPlotter.saveFigure(f, figDir, 'matlab_fig07_voltage_simulation');
        end
    end

    methods (Static, Access = private)
        function styleAxes(ax)
            grid(ax, 'on');
            grid(ax, 'minor');
            box(ax, 'on');
            ax.GridAlpha = 0.22;
            ax.MinorGridAlpha = 0.12;
            ax.LineWidth = 1.0;
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
    end
end
