%RUN_HCP_SDC_SPATIAL_100206 复用已完成的校正后头动输出，继续独立空间分支。
% HCP 仅用于验证；通用计算在 psy.spatial_steps 和 psy.reuse_anatomy。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=toolkit_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] 本机 SPM12 目录，其他研究替换。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_spatial_validation'); % [示例] 独立新输出目录；不能覆盖未校正分支。
cfg.inputStage='sdc_corrected'; % [限制] 输入必须是已完成畸变校正及头动校正的有限值副本。
cfg.distortionCorrection='already_applied'; % [限制] 来源校正完成记录位于 hcp_bold_unwarp_validation_v2。
cfg.stopAfter='smooth'; % [可调] 执行 EPI–T1 配准、MNI 标准化、平滑；不重复 TOPUP/头动估计。
source=fullfile(root,'derivatives','hcp_sdc_realign_recovery','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 已完成 316 帧 QC 的校正后头动目录。
prior=fullfile(root,'derivatives','hcp_sdc_realign_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 保存原始输入清单与 SPM 运动估计的目录。
anatomy=fullfile(root,'derivatives','language_spatial_validation','sub-100206','tfMRI_LANGUAGE_LR','anat'); % [示例] 同一原始 T1 的已完成分割；代码将逐字节核实。
out=fullfile(cfg.outputRoot,'sub-100206','tfMRI_LANGUAGE_LR');
assert(isfile(fullfile(source,'RECOVERY_COMPLETE.mat')),'先完成校正后头动恢复和 QC');
assert(~isfolder(out),'输出已存在，检查后选择新目录');
loaded=load(fullfile(prior,'input_info.mat'));
run=loaded.run; info=loaded.info; run.anatomyReuseDir=anatomy;
addpath(cfg.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
mkdir(out);
realigned=fullfile(out,'realigned_finite.nii'); % [示例] 本 run 的私有副本；SPM 配准会改变工作副本头信息。
meanImage=fullfile(out,'meanbold_unwarped_jac.nii'); % [示例] 与 realigned 同一原生网格的 SPM mean。
copyfile(fullfile(source,'realigned_finite.nii'),realigned);
copyfile(fullfile(prior,'meanbold_unwarped_jac.nii'),meanImage);
save(fullfile(out,'input_info.mat'),'run','info','cfg','source','prior');
outputs=psy.spatial_steps(run,cfg,out,realigned,meanImage,info.nVolumes);
assert(all(cellfun(@isfile,outputs)),'期望的空间处理输出缺失');
status='spatial_pipeline_after_susceptibility_correction';
qc=psy.verify_spatial(out);
save(fullfile(out,'SPATIAL_COMPLETE.mat'),'outputs','status','cfg','source','prior','qc');
disp(status);disp(qc);
