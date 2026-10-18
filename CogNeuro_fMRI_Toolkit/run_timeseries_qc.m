% RUN_TIMESERIES_QC 通用批量质控；路径在 config/qc_config.m 修改。
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=qc_config; addpath(cfg.spmPath);
report=psy.qc_batch(cfg.inputRoot,cfg.outputRoot);
disp(struct2table(report,'AsArray',true));
assert(all(strcmp({report.status},'qc_completed')),'Some QC runs failed; inspect qc_batch_status.tsv');
