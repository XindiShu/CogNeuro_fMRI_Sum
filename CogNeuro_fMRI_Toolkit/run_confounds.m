% 通用入口：编辑 config/confounds_config.m 与逐 run 清单；保留原影像。
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=confounds_config;
report=psy.confounds_batch(cfg);
disp(struct2table(report,'AsArray',true));
