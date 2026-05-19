classdef ECMParameterIdentifier
    %ECMPARAMETERIDENTIFIER Identify and validate ECM parameters.
    % Traceability note:
    % - Local fixed-SoC LS: ECM.tex -> "Local Least-Squares Identification"
    % - Weighted local LS: ECM.tex -> "Weighted Least-Squares Formulation"
    % - Global regularized fit: ECM.tex -> "Global Regularised Identification"
    % - Surrogate 2RC tables: ECM.tex -> "Construction of the Surrogate 2RC Tables"
    % - Validation/LOCO/verification: ECM.tex -> corresponding execution subsections

    properties
        Module
    end

    methods
        function obj = ECMParameterIdentifier(module)
            obj.Module = module;
        end

        function [model, fitInfo] = fitLocal(obj, data)
            z = data.SOCGrid(:);
            M = numel(z);
            fitIdx = find(data.FitMask);
            OCV = nan(M,1);
            Reff = nan(M,1);
            R2local = nan(M,1);

            for i = 1:M
                y = data.V(i,fitIdx).';
                I = data.I_A(fitIdx).';
                valid = isfinite(y) & isfinite(I);
                A = [ones(sum(valid),1), I(valid)];
                p = A \ y(valid);
                OCV(i) = min(max(p(1), obj.Module.Vmin_V), obj.Module.Vmax_V);
                Reff(i) = max(-p(2), 1e-6);

                yhat = A*p;
                ssRes = sum((y(valid)-yhat).^2);
                ssTot = sum((y(valid)-mean(y(valid))).^2);
                R2local(i) = 1 - ssRes/ssTot;
            end

            model = ecmmodel.StaticECM(z, OCV, Reff, obj.Module.Q_Ah);
            fitInfo.Method = 'local fixed-SoC least squares';
            fitInfo.LocalR2 = R2local;
            fitInfo.FitLabels = data.Labels(data.FitMask);
        end

        function [model, fitInfo] = fitWeightedLocal(obj, data, weightMatrix)
            % Fit each SoC slice with weighted least squares.
            if nargin < 3 || isempty(weightMatrix)
                weightMatrix = obj.defaultWeightMatrix(data);
            end

            z = data.SOCGrid(:);
            M = numel(z);
            fitIdx = find(data.FitMask);
            OCV = nan(M,1);
            Reff = nan(M,1);
            R2local = nan(M,1);

            for i = 1:M
                y = data.V(i,fitIdx).';
                I = data.I_A(fitIdx).';
                w = weightMatrix(i,fitIdx).';
                valid = isfinite(y) & isfinite(I) & isfinite(w) & (w > 0);
                A = [ones(sum(valid),1), I(valid)];
                yv = y(valid);
                wv = w(valid);

                if numel(yv) < 2
                    OCV(i) = NaN;
                    Reff(i) = NaN;
                    R2local(i) = NaN;
                    continue;
                end

                Aw = A .* sqrt(wv);
                yw = yv .* sqrt(wv);
                p = Aw \ yw;

                OCV(i) = min(max(p(1), obj.Module.Vmin_V), obj.Module.Vmax_V);
                Reff(i) = max(-p(2), 1e-6);

                yhat = A*p;
                ybar = sum(wv .* yv) / sum(wv);
                ssRes = sum(wv .* (yv - yhat).^2);
                ssTot = sum(wv .* (yv - ybar).^2);
                if ssTot <= eps
                    R2local(i) = 1;
                else
                    R2local(i) = 1 - ssRes/ssTot;
                end
            end

            model = ecmmodel.StaticECM(z, OCV, Reff, obj.Module.Q_Ah);
            fitInfo.Method = 'weighted local fixed-SoC least squares';
            fitInfo.LocalR2 = R2local;
            fitInfo.FitLabels = data.Labels(data.FitMask);
            fitInfo.Weighting = 'default endpoint/current-aware weighting';
        end

        function [model, fitInfo] = fitGlobalRegularized(obj, data, weightMatrix, lambdaV, lambdaR, epsR)
            % Fit OCV and Reff jointly with smoothness regularization and bounds.
            if nargin < 3 || isempty(weightMatrix)
                weightMatrix = obj.defaultWeightMatrix(data);
            end
            if nargin < 4 || isempty(lambdaV)
                lambdaV = 1e-2;
            end
            if nargin < 5 || isempty(lambdaR)
                lambdaR = 1e-3;
            end
            if nargin < 6 || isempty(epsR)
                epsR = 1e-6;
            end

            if exist('quadprog', 'file') ~= 2
                error('fitGlobalRegularized requires quadprog (Optimization Toolbox).');
            end

            z = data.SOCGrid(:);
            M = numel(z);
            fitIdx = find(data.FitMask);
            n = 2*M;

            H = sparse(n, n);
            f = zeros(n, 1);

            for i = 1:M
                for k = 1:numel(fitIdx)
                    j = fitIdx(k);
                    Vij = data.V(i, j);
                    Ij = data.I_A(j);
                    wij = weightMatrix(i, j);
                    if ~(isfinite(Vij) && isfinite(Ij) && isfinite(wij) && wij > 0)
                        continue;
                    end

                    a = zeros(n, 1);
                    a(i) = 1;
                    a(M + i) = -Ij;
                    H = H + 2*wij*(a*a.');
                    f = f - 2*wij*Vij*a;
                end
            end

            D2 = ecmopt.ECMParameterIdentifier.secondDifferenceMatrix(M);
            L = D2.'*D2;
            H(1:M,1:M) = H(1:M,1:M) + 2*lambdaV*L;
            H(M+1:end,M+1:end) = H(M+1:end,M+1:end) + 2*lambdaR*L;

            lb = [-inf(M,1); epsR*ones(M,1)];
            ub = [inf(M,1); inf(M,1)];
            lb(1:M) = obj.Module.Vmin_V;
            ub(1:M) = obj.Module.Vmax_V;

            opts = optimoptions('quadprog', 'Display', 'off');
            [theta, ~, exitflag] = quadprog(H, f, [], [], [], [], lb, ub, [], opts);
            if exitflag <= 0
                error('Global regularized fit failed (quadprog exitflag %d).', exitflag);
            end

            OCV = theta(1:M);
            Reff = theta(M+1:end);

            model = ecmmodel.StaticECM(z, OCV, Reff, obj.Module.Q_Ah);
            fitInfo.Method = 'global regularized constrained quadratic fit';
            fitInfo.FitLabels = data.Labels(data.FitMask);
            fitInfo.LambdaV = lambdaV;
            fitInfo.LambdaR = lambdaR;
            fitInfo.EpsR = epsR;
            fitInfo.Weighting = 'default endpoint/current-aware weighting';
        end

        function W = defaultWeightMatrix(~, data)
            % Downweight SoC endpoints and highest fit currents.
            W = ones(size(data.V));
            z = data.SOCGrid(:);

            endpointMask = (z <= 0.08) | (z >= 0.92);
            W(endpointMask, :) = 0.5;

            fitIdx = find(data.FitMask);
            if isempty(fitIdx)
                return;
            end
            I = abs(data.I_A(fitIdx));
            Imax = max(I);
            if Imax > 0
                scale = 1 + 0.35*(I/Imax);
                for k = 1:numel(fitIdx)
                    W(:, fitIdx(k)) = W(:, fitIdx(k)) ./ scale(k);
                end
            end
        end

        function validation = validateStatic(~, data, model, curveMask)
            if nargin < 4
                curveMask = true(size(data.I_A));
            end

            M = numel(data.SOCGrid);
            Vhat = nan(size(data.V));
            Residual = nan(size(data.V));
            metrics = struct([]);
            idx = find(curveMask);

            for jj = 1:numel(idx)
                j = idx(jj);
                Vhat(:,j) = model.voltage(data.I_A(j)*ones(M,1), data.SOCGrid);
                Residual(:,j) = data.V(:,j) - Vhat(:,j);
                met = ecmutil.errorMetrics(data.V(:,j), Vhat(:,j));
                metrics(jj).Curve = data.Names(j);
                metrics(jj).Label = data.Labels(j);
                metrics(jj).Current_A = data.I_A(j);
                metrics(jj).RMSE_V = met.RMSE_V;
                metrics(jj).MAE_V = met.MAE_V;
                metrics(jj).MaxAbsError_V = met.MaxAbsError_V;
                metrics(jj).Bias_V = met.Bias_V;
                metrics(jj).NRMSE_V = met.NRMSE_V;
                metrics(jj).MAPE_pct = met.MAPE_pct;
                metrics(jj).R2 = met.R2;
                metrics(jj).P95AbsError_V = met.P95AbsError_V;
                metrics(jj).N = met.N;
            end

            validation.Vhat = Vhat;
            validation.Residual = Residual;
            validation.metrics = metrics;
        end

        function loco = leaveOneCurveOut(obj, data, methodName)
            if nargin < 3 || isempty(methodName)
                methodName = 'local';
            end

            fitIdx = find(data.FitMask);
            loco = struct([]);
            W = obj.defaultWeightMatrix(data);
            for k = 1:numel(fitIdx)
                removed = fitIdx(k);
                d = data;
                d.FitMask(removed) = false;

                switch lower(methodName)
                    case 'local'
                        [m, ~] = obj.fitLocal(d);
                    case 'weightedlocal'
                        [m, ~] = obj.fitWeightedLocal(d, W);
                    case 'regularized'
                        try
                            [m, ~] = obj.fitGlobalRegularized(d, W, 1e-2, 1e-3, 1e-6);
                        catch
                            [m, ~] = obj.fitWeightedLocal(d, W);
                        end
                    otherwise
                        error('Unknown LOCO method: %s', methodName);
                end

                val = obj.validateStatic(data, m, (1:numel(data.I_A)) == removed);
                loco(k).RemovedCurve = data.Names(removed);
                loco(k).Current_A = data.I_A(removed);
                loco(k).RMSE_V = val.metrics(1).RMSE_V;
                loco(k).MAE_V = val.metrics(1).MAE_V;
                loco(k).MaxAbsError_V = val.metrics(1).MaxAbsError_V;
                loco(k).Bias_V = val.metrics(1).Bias_V;
                loco(k).Method = methodName;
            end
        end

        function Bat = buildBatteryStructure(obj, model, data, fitInfo)
            z = model.SOCGrid(:);
            Reff = model.Reff_Ohm(:);

            % Treat datasheet 5 mOhm as an upper-bound reference.
            % R0 is capped so that R0 + R1 + R2 remains equal to Reff.
            epsR = 0.1e-3;
            R0 = min(obj.Module.RdcMax_Ohm*ones(size(Reff)), max(0.5*Reff, Reff - epsR));
            Rpol = max(Reff - R0, epsR);
            alphaR = 0.35;
            R1 = alphaR*Rpol;
            R2 = (1-alphaR)*Rpol;
            tau1 = 20;
            tau2 = 600;
            C1 = tau1 ./ R1;
            C2 = tau2 ./ R2;

            Bat.Module = obj.Module.Name;
            Bat.Source = obj.Module.Source;
            Bat.Q_Ah = obj.Module.Q_Ah;
            Bat.Vnom_V = obj.Module.Vnom_V;
            Bat.Vmin_V = obj.Module.Vmin_V;
            Bat.Vmax_V = obj.Module.Vmax_V;
            Bat.ImaxCont_A = obj.Module.ImaxCont_A;
            Bat.ImaxPeak_A = obj.Module.ImaxPeak_A;
            Bat.RdcMax_Ohm = obj.Module.RdcMax_Ohm;

            Bat.SOC_grid = z;
            Bat.OCV_table = model.OCV_V(:);
            Bat.Reff_table = Reff;
            Bat.R0_table = R0;
            Bat.R1_table = R1;
            Bat.C1_table = C1;
            Bat.R2_table = R2;
            Bat.C2_table = C2;

            Bat.ValidSOCRange = [min(z), max(z)];
            Bat.ValidCurrentRange_A = [min(data.I_A(data.FitMask)), max(data.I_A(data.FitMask))];
            Bat.FitInfo = fitInfo;

            Bat.ParameterStatus.OCV = 'datasheet-extrapolated';
            Bat.ParameterStatus.Reff = 'identified-apparent';
            Bat.ParameterStatus.R0 = 'datasheet-capped initialisation';
            Bat.ParameterStatus.R1 = 'surrogate';
            Bat.ParameterStatus.C1 = 'surrogate';
            Bat.ParameterStatus.R2 = 'surrogate';
            Bat.ParameterStatus.C2 = 'surrogate';

            Bat.IdentificationNote = ['Static parameters OCV and Reff are identified from multi-rate ', ...
                'manufacturer discharge curves. Dynamic 2RC parameters are surrogate values because ', ...
                'pulse/rest relaxation data are not available.'];
        end

        function verification = verify(obj, Bat, validation, data)
            VhatFit = validation.Vhat(:, data.FitMask);
            VhatAll = validation.Vhat;
            verification.PositiveReff = all(Bat.Reff_table > 0);
            verification.PositiveR0 = all(Bat.R0_table > 0);
            verification.PositiveR1 = all(Bat.R1_table > 0);
            verification.PositiveR2 = all(Bat.R2_table > 0);
            verification.PositiveC1 = all(Bat.C1_table > 0);
            verification.PositiveC2 = all(Bat.C2_table > 0);
            verification.OCVInsideEnvelope = min(Bat.OCV_table) >= obj.Module.Vmin_V && max(Bat.OCV_table) <= obj.Module.Vmax_V;
            verification.FitVhatInsideEnvelope = min(VhatFit(:)) >= obj.Module.Vmin_V && max(VhatFit(:)) <= obj.Module.Vmax_V;
            verification.AllVhatInsideEnvelope = min(VhatAll(:)) >= obj.Module.Vmin_V && max(VhatAll(:)) <= obj.Module.Vmax_V;
            verification.SteadyResistanceConsistency = max(abs(Bat.R0_table + Bat.R1_table + Bat.R2_table - Bat.Reff_table)) < 1e-10;
            verification.MainFitWithinContinuousLimit = max(data.I_A(data.FitMask)) <= obj.Module.ImaxCont_A;
        end

        function writeTables(~, Bat, validation, loco, verification, outDir)
            ecmutil.ensureDir(outDir);

            paramTable = table(Bat.SOC_grid, Bat.OCV_table, Bat.Reff_table, ...
                1000*Bat.Reff_table, Bat.R0_table, Bat.R1_table, Bat.C1_table, ...
                Bat.R2_table, Bat.C2_table, ...
                'VariableNames', {'SOC','OCV_V','Reff_Ohm','Reff_mOhm','R0_Ohm','R1_Ohm','C1_F','R2_Ohm','C2_F'});
            writetable(paramTable, fullfile(outDir, 'identified_parameter_tables_from_matlab.csv'));

            metricsTable = struct2table(validation.metrics);
            writetable(metricsTable, fullfile(outDir, 'validation_metrics_from_matlab.csv'));

            if ~isempty(loco)
                writetable(struct2table(loco), fullfile(outDir, 'leave_one_curve_out_from_matlab.csv'));
            end

            writetable(struct2table(verification), fullfile(outDir, 'verification_checks_from_matlab.csv'));
        end
    end

    methods (Static, Access = private)
        function D2 = secondDifferenceMatrix(M)
            if M < 3
                D2 = sparse(0, M);
                return;
            end
            e = ones(M,1);
            D2 = spdiags([e -2*e e], 0:2, M-2, M);
        end
    end
end
