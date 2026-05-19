classdef Dynamic2RC
    %DYNAMIC2RC Two-RC battery ECM with exact discrete RC update.

    properties
        SOCGrid
        OCV_V
        R0_Ohm
        R1_Ohm
        C1_F
        R2_Ohm
        C2_F
        Q_Ah
    end

    methods
        function obj = Dynamic2RC(Bat)
            if nargin == 0; return; end
            obj.SOCGrid = Bat.SOC_grid(:);
            obj.OCV_V = Bat.OCV_table(:);
            obj.R0_Ohm = Bat.R0_table(:);
            obj.R1_Ohm = Bat.R1_table(:);
            obj.C1_F = Bat.C1_table(:);
            obj.R2_Ohm = Bat.R2_table(:);
            obj.C2_F = Bat.C2_table(:);
            obj.Q_Ah = Bat.Q_Ah;
        end

        function y = lookup(obj, table, soc)
            soc = min(max(soc, min(obj.SOCGrid)), max(obj.SOCGrid));
            y = interp1(obj.SOCGrid, table, soc, 'linear', 'extrap');
        end

        function sim = simulate(obj, t_s, I_A, z0)
            t_s = t_s(:); I_A = I_A(:);
            N = numel(t_s);
            z = nan(N,1); vt = nan(N,1); V1 = nan(N,1); V2 = nan(N,1);
            z(1) = z0; V1(1) = 0; V2(1) = 0;

            for k = 1:N
                z(k) = min(max(z(k), min(obj.SOCGrid)), max(obj.SOCGrid));
                OCV = obj.lookup(obj.OCV_V, z(k));
                R0 = max(obj.lookup(obj.R0_Ohm, z(k)), eps);
                R1 = max(obj.lookup(obj.R1_Ohm, z(k)), eps);
                R2 = max(obj.lookup(obj.R2_Ohm, z(k)), eps);
                C1 = max(obj.lookup(obj.C1_F, z(k)), eps);
                C2 = max(obj.lookup(obj.C2_F, z(k)), eps);

                vt(k) = OCV - R0*I_A(k) - V1(k) - V2(k);

                if k < N
                    dt = t_s(k+1)-t_s(k);
                    a1 = exp(-dt/(R1*C1));
                    a2 = exp(-dt/(R2*C2));
                    V1(k+1) = a1*V1(k) + R1*(1-a1)*I_A(k);
                    V2(k+1) = a2*V2(k) + R2*(1-a2)*I_A(k);
                    z(k+1) = z(k) - dt*I_A(k)/(3600*obj.Q_Ah);
                end
            end

            sim.Type = 'dynamic2RC';
            sim.t_s = t_s;
            sim.I_A = I_A;
            sim.SOC = z;
            sim.Vt_V = vt;
            sim.V1_V = V1;
            sim.V2_V = V2;
            sim.Power_W = vt.*I_A;
        end
    end

    methods (Static)
        function obj = fromBat(Bat)
            obj = ecmmodel.Dynamic2RC(Bat);
        end
    end
end
