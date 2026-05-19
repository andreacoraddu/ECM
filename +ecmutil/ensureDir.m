function ensureDir(folder)
%ENSUREDIR Create folder if it does not exist.
if ~exist(folder, 'dir')
    mkdir(folder);
end
end
