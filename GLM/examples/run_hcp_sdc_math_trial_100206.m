function report=run_hcp_sdc_math_trial_100206
%RUN_HCP_SDC_MATH_TRIAL_100206 仅以 math 事件行为目标的 LSA/LSS 示例。
% story 区块仍参与模型作为其他任务效应；不把它们解释为 math 试次。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=single_trial_config;
cfg.manifestFile=fullfile(root,'examples','hcp_100206_sdc_single_trial.tsv'); % [示例] 本 run 的 BOLD/事件/混杂清单；其他研究替换。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_math_trial_validation'); % [示例] 与全部事件模型分开的新输出目录。
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] SPM12 目录，移机修改。
cfg.methods={'LSA','LSS'}; % [可调] 同时估计 LSA 与 LSS；可只保留一种。
cfg.targetConditions={'math'}; % [示例] 只输出 math 目标 beta/对比；story 仍在任务设计中。
cfg.lssGrouping='by_condition'; % [可调] LSS 的其余 math 与 story 分开建模；也可选 all_other。
cfg.execute=true; % [可调] true 执行估计与全部目标对比，false 仅准备。
cfg.design.motionModel='24'; % [可调] 同 run 的 24 项 SPM 头动回归量。
cfg.design.includeTissueMeans=false; % [限制] 当前组织掩膜仍含脑外小块，不用于此示例。
cfg.serialCorrelation='FAST'; % [可调] FAST 或 AR(1)；应检查设计与残差。
assert(~isfolder(cfg.outputRoot),'输出目录已存在，请先核查再选新目录');
report=psy.single_trial_batch(cfg);
assert(isscalar(report) && strcmp(report.status,'single_trial_models_estimated'), ...
    'math 目标模型未全部成功，请查看 batch_status.tsv');
disp(struct2table(report,'AsArray',true));
end
