%% build_mex.m
% Build C++ MEX kernels used by the ECM pipeline.

cppDir = fileparts(mfilename('fullpath'));
projectRoot = fileparts(cppDir);
srcWrapper = fullfile(cppDir, 'ecm_weighted_local_mex.c');
srcCore = fullfile(cppDir, 'ecm_weighted_local_core.cpp');
objCore = fullfile(cppDir, 'ecm_weighted_local_core.o');

if ~isfile(srcWrapper)
    error('Missing source file: %s', srcWrapper);
end
if ~isfile(srcCore)
    error('Missing source file: %s', srcCore);
end

fprintf('Building ecm_weighted_local_mex...\n');

compileCmd = sprintf('clang++ -O3 -std=c++17 -c "%s" -o "%s"', srcCore, objCore);
[status, out] = system(compileCmd);
if status ~= 0
    error('C++ core compile failed:\n%s', out);
end

mex('-O', srcWrapper, objCore, '-outdir', projectRoot, '-output', 'ecm_weighted_local_mex');

fprintf('Build complete: %s\n', fullfile(projectRoot, ['ecm_weighted_local_mex.' mexext]));
