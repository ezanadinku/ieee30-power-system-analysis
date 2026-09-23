% Run the IEEE 30-bus analysis from the repository root.
repo_root = fileparts(mfilename('fullpath'));
addpath(fullfile(repo_root, 'src'));
run(fullfile(repo_root, 'src', 'main_analysis.m'));
