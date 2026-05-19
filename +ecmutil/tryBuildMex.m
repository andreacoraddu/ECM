function ok = tryBuildMex(projectRoot)
%TRYBUILDMEX Build C++ MEX kernels when possible.
% Returns true if the weighted-local core MEX is available.

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

ok = exist('ecm_weighted_local_mex', 'file') == 3;
if ok
    return;
end

buildScript = fullfile(projectRoot, 'cpp', 'build_mex.m');
if ~isfile(buildScript)
    return;
end

try
    run(buildScript);
catch ME
    warning('MEX build failed: %s', ME.message);
end

ok = exist('ecm_weighted_local_mex', 'file') == 3;
end
