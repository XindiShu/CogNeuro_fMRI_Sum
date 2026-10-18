function report=run_hcp_sdc_confound_design_100206
%RUN_HCP_SDC_CONFOUND_DESIGN_100206 校正后混杂表的工程设计矩阵验证。
% 真实研究应先核查组织掩膜；任务 GLM/PPI 还要与任务回归量联合建模。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=design_config;
cfg.inputRoot=fullfile(root,'derivatives','hcp_sdc_confounds_validation'); % [示例] 校正后分支的混杂提取输出，其他研究替换。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_confound_design_validation'); % [示例] 新输出根目录，不覆盖既有设计。
cfg.motionModel='24'; % [可调] none/6/24；24 项与组织均值可能共线，程序会报告秩。
cfg.includeTissueMeans=true; % [可调] 当前组织掩膜仍含少量颈部/脑外区域，仅作工程验证。
cfg.linearTrend=true; % [可调] 加入线性趋势；截距始终保留。
cfg.addSpikes=false; % [可调] 如需超 FD 帧指示列，设 true 并核查阈值和自由度。
assert(isfile(fullfile(cfg.inputRoot,'sub-100206','tfMRI_LANGUAGE_LR','COMPLETE.mat')), ...
    '请先完成校正后混杂提取');
assert(~isfolder(cfg.outputRoot),'输出目录已存在，请核查后选择新目录');
report=psy.confound_design_batch(cfg);
assert(isscalar(report) && strcmp(report.status,'design_validated_not_regressed'), ...
    '混杂设计检查失败，请查看 batch_status.tsv');
disp(struct2table(report,'AsArray',true));
end
