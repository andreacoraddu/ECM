classdef ValenceDataImporter
    %VALENCEDATAIMPORTER Import digitised Valence voltage-capacity curves.

    methods (Static)
        function module = defaultModule()
            module.Name = 'Valence U27-12XP';
            module.Q_Ah = 138;
            module.Vnom_V = 12.8;
            module.Vmin_V = 10.0;
            module.Vmax_V = 14.6;
            module.ImaxCont_A = 150;
            module.ImaxPeak_A = 300;
            module.RdcMax_Ohm = 5e-3;
            module.Source = 'Valence U-Charge XP datasheet, digitised voltage profiles';
        end

        function defs = curveDefinitions()
            defs = struct([]);
            defs(1).Label = "C8";  defs(1).Name = "C/8"; defs(1).Crate = 1/8;
            defs(2).Label = "C5";  defs(2).Name = "C/5"; defs(2).Crate = 1/5;
            defs(3).Label = "C3";  defs(3).Name = "C/3"; defs(3).Crate = 1/3;
            defs(4).Label = "C2";  defs(4).Name = "C/2"; defs(4).Crate = 1/2;
            defs(5).Label = "C1";  defs(5).Name = "1C";  defs(5).Crate = 1;
            defs(6).Label = "C2x"; defs(6).Name = "2C";  defs(6).Crate = 2;
        end

        function curves = readWideCsv(fileName, module)
            if nargin < 2
                module = ecmdata.ValenceDataImporter.defaultModule();
            end
            T = readtable(fileName);
            defs = ecmdata.ValenceDataImporter.curveDefinitions();
            curves = struct([]);

            for j = 1:numel(defs)
                capName = "cap_pct_" + defs(j).Label;
                vName = "V_" + defs(j).Label;
                if ~ismember(capName, string(T.Properties.VariableNames)) || ...
                   ~ismember(vName, string(T.Properties.VariableNames))
                    warning('Missing columns for %s. Skipping.', defs(j).Label);
                    continue;
                end

                cap = T.(capName);
                V = T.(vName);
                valid = isfinite(cap) & isfinite(V);
                cap = cap(valid);
                V = V(valid);

                [cap, idx] = sort(cap(:));
                V = V(idx);
                [cap, idxUnique] = unique(cap, 'stable');
                V = V(idxUnique);

                k = numel(curves) + 1;
                curves(k).Label = defs(j).Label;
                curves(k).Name = defs(j).Name;
                curves(k).Crate = defs(j).Crate;
                curves(k).I_A = defs(j).Crate * module.Q_Ah;
                curves(k).CapacityUsed_pct = cap;
                curves(k).SOC = 1 - cap/100;
                curves(k).Voltage_V = V;
            end
        end

        function data = buildMatrix(curves, socGrid, fitLabels, validationLabels)
            labels = strings(1, numel(curves));
            names = strings(1, numel(curves));
            I_A = zeros(1, numel(curves));
            V = nan(numel(socGrid), numel(curves));

            for j = 1:numel(curves)
                labels(j) = curves(j).Label;
                names(j) = curves(j).Name;
                I_A(j) = curves(j).I_A;

                soc = curves(j).SOC(:);
                volt = curves(j).Voltage_V(:);
                valid = isfinite(soc) & isfinite(volt);
                soc = soc(valid);
                volt = volt(valid);

                [soc, idx] = sort(soc);
                volt = volt(idx);
                [soc, idxUnique] = unique(soc, 'stable');
                volt = volt(idxUnique);

                V(:,j) = interp1(soc, volt, socGrid, 'pchip', 'extrap');
            end

            data.SOCGrid = socGrid(:);
            data.V = V;
            data.I_A = I_A;
            data.Labels = labels;
            data.Names = names;
            data.FitMask = ismember(labels, fitLabels);
            data.ValidationMask = ismember(labels, validationLabels);
        end
    end
end
