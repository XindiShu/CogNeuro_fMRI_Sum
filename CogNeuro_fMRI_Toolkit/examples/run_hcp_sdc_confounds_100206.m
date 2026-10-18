function report=run_hcp_sdc_confounds_100206
%RUN_HCP_SDC_CONFOUNDS_100206 校正后 LANGUAGE LR 的组织/头动混杂验证。
% HCP 仅是样例；通用多被试/session/run 计算入口为 run_confounds 和 psy.confounds_batch。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=confounds_config;
cfg.manifestFile=fullfile(root,'examples','hcp_100206_sdc_confounds.tsv'); % [示例] 校正后逐 run 清单；其他研究复制模板并逐行替换路径。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_confounds_validation'); % [示例] 新输出根目录；不能覆盖既有混杂结果。
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] 本机 SPM12 安装目录，移机需修改。
cfg.wmThreshold=0.95; % [可调] 原生 T1 白质概率阈值；与掩膜 QC 一起评估。
cfg.csfThreshold=0.95; % [可调] 原生 T1 CSF 概率阈值；不是脑室限定 ROI。
cfg.erosionMm=2; % [可调] 在 BOLD 网格以毫米腐蚀；不是通用质量阈值。
cfg.minVoxels=20; % [可调] WM/CSF 各自的最少体素数，不足时显式失败。
spatial=fullfile(root,'derivatives','hcp_sdc_spatial_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 已完成的校正后空间目录。
motion=fullfile(root,'derivatives','hcp_sdc_realign_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 同一次校正后头动估计目录。
s=load(fullfile(spatial,'SPATIAL_COMPLETE.mat'));
assert(strcmp(s.status,'spatial_pipeline_after_susceptibility_correction'),'空间分支状态不符');
assert(isfile(fullfile(spatial,'anat','ANATOMY_REUSE.json')),'缺少解剖复用来源记录');
assert(isfile(fullfile(motion,'rp_bold_unwarped_jac.txt')),'缺少同一次 realign 的运动参数');
assert(~isfolder(cfg.outputRoot),'输出目录已存在，请核查后选择新目录');
report=psy.confounds_batch(cfg);
assert(isscalar(report) && strcmp(report.status,'confounds_extracted_not_regressed'), ...
    '组织混杂提取失败，请查看 batch_status.tsv');
disp(struct2table(report,'AsArray',true));
end
