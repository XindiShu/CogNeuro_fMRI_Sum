% 批量构造混杂设计；先修改 config/design_config.m 的目录和模型参数。
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=design_config; report=psy.confound_design_batch(cfg);
disp(struct2table(report,'AsArray',true));
