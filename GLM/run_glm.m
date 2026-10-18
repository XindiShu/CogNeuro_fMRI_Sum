% 可组合GLM：修改glm_config.m；run/subject读run清单，group读被试对比清单；默认仅准备。
root=fileparts(mfilename('fullpath')); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=glm_config; report=psy.glm_batch(cfg); disp(struct2table(report,'AsArray',true));
