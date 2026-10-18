function report=run_hcp_sdc_single_trial_100206
%RUN_HCP_SDC_SINGLE_TRIAL_100206 HCP LANGUAGE 区块级 LSA/LSS 工程验证。
% 当前事件文件含 4 个 story 区块与 8 个 math 试次/事件段；目标行粒度不同。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=single_trial_config;
cfg.manifestFile=fullfile(root,'examples','hcp_100206_sdc_single_trial.tsv'); % [示例] 校正后 BOLD/区块事件/混杂清单，其他研究逐 run 替换。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_single_trial_validation'); % [示例] 新目录；LSA 和每个 LSS 模型均写独立输出。
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] SPM12 目录，移机修改。
cfg.methods={'LSA','LSS'}; % [可调] 两种都运行；若只需要一种，删去另一种。
cfg.targetConditions={}; % [可调] 本次所有 12 行均为目标；如 {'math'} 仅估计 8 个 math 目标。
cfg.lssGrouping='all_other'; % [可调] 目标事件行 vs 其余事件行合一；也可设 by_condition。
cfg.execute=true; % [可调] true 执行全部模型；false 只准备规范，不生成 beta。
cfg.design.motionModel='24'; % [可调] 使用同一次 realign 的 24 项头动参数。
cfg.design.includeTissueMeans=false; % [限制] 本例组织掩膜含少量脑外/颈部成分，暂不放进模型。
cfg.design.linearTrend=false; % [可调] SPM 内部高通建模慢漂移。
cfg.serialCorrelation='FAST'; % [可调] 当前采样下使用 FAST；可选 AR(1) 并重新检查。
spatial=fullfile(root,'derivatives','hcp_sdc_spatial_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 校正后空间来源。
confounds=fullfile(root,'derivatives','hcp_sdc_confounds_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 同 run 混杂来源。
s=load(fullfile(spatial,'SPATIAL_COMPLETE.mat'));
assert(strcmp(s.status,'spatial_pipeline_after_susceptibility_correction'),'空间来源状态不符');
assert(isfile(fullfile(confounds,'COMPLETE.mat')),'缺少校正后混杂完成标记');
assert(~isfolder(cfg.outputRoot),'输出目录已存在，请检查后选新目录');
report=psy.single_trial_batch(cfg);
assert(isscalar(report) && strcmp(report.status,'single_trial_models_estimated'), ...
    '至少一个 LSA/LSS 模型失败，请检查 batch_status.tsv');
disp(struct2table(report,'AsArray',true));
end
