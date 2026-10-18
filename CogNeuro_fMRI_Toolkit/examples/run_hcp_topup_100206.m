%RUN_HCP_TOPUP_100206 HCP 验证适配器；通用算法在 matlab/+psy/topup_*.m。
% 先在 MATLAB 中运行本脚本。仅估计 SE-EPI 的场，不宣称 BOLD 已校正。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'),fullfile(root,'matlab'));
cfg=topup_config;
cfg.outputRoot=fullfile(root,'derivatives','hcp_topup_validation_v2'); % [示例] HCP 验证输出；更换数据时用自己的新目录。
cfg.execute=true; % [示例] 已核对 HCP 官方示例采集参数后执行真实 TOPUP。
base='D:\IBM\100206_extracted\100206_3T_tfMRI_LANGUAGE_unproc\100206\unprocessed\3T'; % [示例] 替换为本机 HCP 解压目录。
runName='tfMRI_LANGUAGE_LR'; % [示例] 可改 RL 或循环多个 run；通用模块不依赖此名称。
scanDir=fullfile(base,runName);
spec.subject='100206'; spec.session=''; spec.run=runName; % [示例] 被试/会话/run ID，仅用于独立输出目录。
spec.negative=fullfile(scanDir,'100206_3T_SpinEchoFieldMap_LR.nii.gz'); % [示例] 负向 SE-EPI 场图，按实际文件替换。
spec.positive=fullfile(scanDir,'100206_3T_SpinEchoFieldMap_RL.nii.gz'); % [示例] 正向 SE-EPI 场图，按实际文件替换。
spec.negativeDirection='i-'; % [必查] HCP 官方示例 LR 在 NIfTI x/i 轴为负；其他数据不可照抄。
spec.positiveDirection='i'; % [必查] HCP 官方示例 RL 在 NIfTI x/i 轴为正；其他数据不可照抄。
spec.negativeReadoutSeconds=(90-1)*0.00058; % [必查] HCP 有效 echo spacing 0.00058 秒 × PE 轴 90 体素减 1；替换时按实际采集计算。
spec.positiveReadoutSeconds=spec.negativeReadoutSeconds; % [必查] 仅当反向场图采集参数相同时复用；单位秒。
spec.bold=fullfile(scanDir,'100206_3T_tfMRI_LANGUAGE_LR.nii.gz'); % [示例] 仅用于网格/方向检查，本例不应用校正。
spec.boldDirection='i-'; % [必查] HCP 官方示例 LANGUAGE LR；其他数据需按 NIfTI 轴核实。
spec.boldReadoutSeconds=(90-1)*0.00058; % [必查] BOLD 总读出时间秒；与 SE-EPI 相同仍不代表头位已配准。
result=psy.topup_run(spec,cfg);
disp(result.status); disp(result.outputDir);
