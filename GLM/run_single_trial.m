% 通用 LSA/LSS 入口：先修改 config/single_trial_config.m 和逐 run 清单。
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=single_trial_config;report=psy.single_trial_batch(cfg);
disp(struct2table(report,'AsArray',true));
