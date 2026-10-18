function cfg=single_trial_config
%SINGLE_TRIAL_CONFIG 通用逐事件行 LSA/LSS；继承一级 GLM 的滤波、混杂和估计参数。
cfg=glm_config;
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','single_trial_runs.tsv'); % [必改] 复制 glm_runs_template.tsv；每行一个 subject/session/run。
cfg.outputRoot=fullfile(root,'derivatives','my_study_single_trial'); % [必改] 全新输出根目录；逐事件模型会占用较多磁盘。
cfg.methods={'LSA','LSS'}; % [可调] {'LSA'}、{'LSS'} 或两者；LSA 为一个模型，LSS 每事件行一个模型。
cfg.targetConditions={}; % [可调] 空=所有事件行；如 {'math'} 仅输出 math 目标，其他条件仍作为干扰回归量。
cfg.lssGrouping='all_other'; % [可调] all_other=全部非目标事件合一；by_condition=其余事件按原条件分别合并。
cfg.execute=false; % [可调] false 只写模型规范；true 估计所有选择的模型及目标对比。
cfg.design.includeTissueMeans=false; % [可调] 当前示例组织掩膜有脑外成分；其他研究核查后可改 true。
end
