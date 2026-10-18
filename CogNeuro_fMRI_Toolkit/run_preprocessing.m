% RUN_PREPROCESSING HCP 示例入口；数据根目录在 config/preprocess_config.m 的
% cfg.dataRoot，当前为 D:\IBM。适配器递归查找已解压包内的
% <被试>/unprocessed/3T/<run>/<被试>_3T_<run>.nii[.gz]；不直接读 ZIP。
% 默认 execute=false 只预检；改 config/toolkit_config.m 后再运行本脚本。
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot,'matlab'), fullfile(projectRoot,'config'));
cfg = preprocess_config;
report = psy.preprocess_hcp(cfg);
disp(struct2table(report,'AsArray',true));
