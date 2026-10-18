function report=run_hcp_sdc_glm_100206
%RUN_HCP_SDC_GLM_100206 已校正 LANGUAGE LR 的独立一级 GLM 工程验证。
% HCP 仅为示例；多被试/session/run 由 config/glm_runs.tsv + psy.glm_batch 调度。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=rmfield(glm_config,'model'); % 历史验证入口保留原布局/状态；新模型使用统一run_glm入口。
cfg.manifestFile=fullfile(root,'examples','hcp_100206_sdc_glm.tsv'); % [示例] 本 run 的校正后 BOLD、事件和混杂路径；其他研究逐 run 替换。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_glm_validation'); % [示例] 独立新目录；不得覆盖未校正 GLM。
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] 本机 SPM12 目录，移机修改。
cfg.execute=true; % [可调] true 执行指定/估计/对比；false 仅准备作业。
cfg.conditions={'story','math'}; % [示例] 与事件 TSV 的 trial_type 一致，列顺序固定。
cfg.contrastNames={'story_minus_math','math_minus_story'}; % [示例] 两个 T 对比名称。
cfg.contrastWeights=[1 -1;-1 1]; % [示例] 每行与 conditions 顺序一致，不含混杂项。
cfg.design.motionModel='24'; % [可调] 本轮使用同 run 的 24 项头动；可选 none/6/24。
cfg.design.includeTissueMeans=false; % [限制] 组织掩膜仍有脑外/颈部成分，本轮 GLM 暂不纳入 WM/CSF 均值。
cfg.design.linearTrend=false; % [可调] 使用 SPM 高通处理慢漂移，不另加线性趋势。
cfg.highpassSeconds=128; % [可调] SPM 高通周期，秒；需依据任务周期重新评估。
cfg.serialCorrelation='FAST'; % [可调] FAST 或 AR(1)；短 TR 建议先检查估计稳定性。
spatial=fullfile(root,'derivatives','hcp_sdc_spatial_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 已完成的校正后空间分支。
confounds=fullfile(root,'derivatives','hcp_sdc_confounds_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 同 run 的校正后混杂表。
s=load(fullfile(spatial,'SPATIAL_COMPLETE.mat'));
assert(strcmp(s.status,'spatial_pipeline_after_susceptibility_correction'),'空间来源状态不符');
assert(isfile(fullfile(confounds,'COMPLETE.mat')),'缺少校正后混杂完成记录');
assert(~isfolder(cfg.outputRoot),'输出目录已存在，请检查后选新目录');
report=psy.glm_batch(cfg);
assert(isscalar(report) && strcmp(report.status,'run_glm_estimated_spatial_limitations_unchanged'), ...
    'GLM 未成功估计，请查看 batch_status.tsv');
disp(struct2table(report,'AsArray',true));
end
