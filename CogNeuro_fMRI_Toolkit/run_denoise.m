% 通用时间去噪入口：修改 denoise_config.m 和逐 run 的 denoise_runs.tsv。
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=denoise_config; report=psy.denoise_batch(cfg);
disp(struct2table(report,'AsArray',true));
