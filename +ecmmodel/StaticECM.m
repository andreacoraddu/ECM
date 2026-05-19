classdef StaticECM
    %STATICECM Static ECM: Vt = OCV(SOC) - I*Reff(SOC).

    properties
        SOCGrid
        OCV_V
        Reff_Ohm
        Q_Ah
    end

    methods
        function obj = StaticECM(socGrid, ocv, reff, Q_Ah)
            if nargin == 0; return; end
            obj.SOCGrid = socGrid(:);
            obj.OCV_V = ocv(:);
            obj.Reff_Ohm = reff(:);
            obj.Q_Ah = Q_Ah;
        end

        function y = lookup(obj, table, soc)
            soc = min(max(soc, min(obj.SOCGrid)), max(obj.SOCGrid));
            y = interp1(obj.SOCGrid, table, soc, 'linear', 'extrap');
        end

        function vt = voltage(obj, I_A, soc)
            vt = obj.lookup(obj.OCV_V, soc) - I_A(:).*obj.lookup(obj.Reff_Ohm, soc);
        end

        function sim = simulate(obj, t_s, I_A, z0)
            t_s = t_s(:); I_A = I_A(:);
            N = numel(t_s);
            z = nan(N,1); vt = nan(N,1);
            z(1) = z0;
            for k = 1:N
                z(k) = min(max(z(k), min(obj.SOCGrid)), max(obj.SOCGrid));
                vt(k) = obj.voltage(I_A(k), z(k));
                if k < N
                    dt = t_s(k+1)-t_s(k);
                    z(k+1) = z(k) - dt*I_A(k)/(3600*obj.Q_Ah);
                end
            end
            sim.Type = 'static';
            sim.t_s = t_s;
            sim.I_A = I_A;
            sim.SOC = z;
            sim.Vt_V = vt;
            sim.Power_W = vt.*I_A;
        end
    end

    methods (Static)
        function obj = fromBat(Bat)
            obj = ecmmodel.StaticECM(Bat.SOC_grid, Bat.OCV_table, Bat.Reff_table, Bat.Q_Ah);
        end
    end
end
