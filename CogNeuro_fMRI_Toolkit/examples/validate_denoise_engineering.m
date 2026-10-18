% LANGUAGE 只用于工程验证，不作为 GLM/PPI 科学分析输入。
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=denoise_config; h=preprocess_config; cfg.spmPath=h.spmPath;
cfg.manifestFile=fullfile(root,'examples','hcp_100206_denoise_engineering.tsv');
cfg.outputRoot=fullfile(root,'derivatives','denoise_engineering_validation');
cfg.lowpassHz=[]; % 示例只测高通+混杂联合回归，不对 LANGUAGE 应用默认静息态低通。
report=psy.denoise_batch(cfg);
assert(all(strcmp({report.status},'temporally_projected_spatial_limitations_unchanged')));
