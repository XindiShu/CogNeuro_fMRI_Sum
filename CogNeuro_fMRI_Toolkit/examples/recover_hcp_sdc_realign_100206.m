%RECOVER_HCP_SDC_REALIGN_100206 复用已完成的 SPM 运动估计，不重复耗时 realign。
% 源 r*.nii 保留 NaN 以记录 SPM 共同视野掩膜；新目录只保存有限值副本和 QC。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'),'D:\matlab\atoolbox\spm12'); % [必查] 本机 SPM12 路径；其他电脑替换。
sourceDir=fullfile(root,'derivatives','hcp_sdc_realign_validation','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 已完成头动估计、但时间 QC 因 SPM 掩膜 NaN 停止的目录。
outDir=fullfile(root,'derivatives','hcp_sdc_realign_recovery','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 新输出目录，保留原失败分支。
source=fullfile(sourceDir,'rbold_unwarped_jac.nii'); % [示例] 原始 SPM 重采样输出，不能直接当全有限值影像。
meanFile=fullfile(sourceDir,'meanbold_unwarped_jac.nii'); % [示例] 同网格的 SPM mean 影像。
motionFile=fullfile(sourceDir,'rp_bold_unwarped_jac.txt'); % [示例] 对该 BOLD 重新估计的运动参数，不能沿用未校正分支。
cfg=toolkit_config;
r=psy.finalize_realign(source,meanFile,outDir, ...
    maskFraction=cfg.qc.maskFraction,maxNonfiniteFraction=cfg.qc.maxResliceNonfiniteFraction);
q=psy.timeseries_qc(r.cleanSeries,meanFile,motionFile,fullfile(outDir,'timeseries_qc'), ...
    maskFile=r.maskFile,fdRadiusMm=cfg.fdRadiusMm,fdFlagMm=cfg.fdFlagMm);
save(fullfile(outDir,'RECOVERY_COMPLETE.mat'),'r','q','sourceDir');
disp(r.status);disp(q);
