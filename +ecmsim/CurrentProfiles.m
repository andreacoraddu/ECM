classdef CurrentProfiles
    %CURRENTPROFILES Reference current profiles for time-domain simulation.

    methods (Static)
        function [t_s, I_A] = teachingProfile()
            t_s = (0:1:3600).';
            I_A = zeros(size(t_s));
            I_A(t_s >= 120  & t_s < 600)  = 30;
            I_A(t_s >= 600  & t_s < 900)  = 70;
            I_A(t_s >= 900  & t_s < 1200) = 130;
            I_A(t_s >= 1500 & t_s < 1900) = -40;
            I_A(t_s >= 1900 & t_s < 2300) = 100;
            I_A(t_s >= 2600 & t_s < 3000) = 140;
            I_A(t_s >= 3000 & t_s < 3300) = -30;
            I_A(t_s >= 3300) = 20;
        end
    end
end
