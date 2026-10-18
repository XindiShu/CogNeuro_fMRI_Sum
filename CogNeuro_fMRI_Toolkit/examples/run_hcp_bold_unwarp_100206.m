%RUN_HCP_BOLD_UNWARP_100206 HCP LANGUAGE LR 单 run 验证；通用计算在 +psy。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'config'),fullfile(root,'matlab'));
cfg=bold_unwarp_config;
cfg.outputRoot=fullfile(root,'derivatives','hcp_bold_unwarp_validation_v2'); % [示例] HCP 验证输出；换研究时新建目录，不覆盖原预处理。
cfg.execute=true; % [示例] 已核查示例的 SBRef、BOLD 和编码参数后运行；首次核查可改 false。
raw='D:\IBM\100206_extracted\100206_3T_tfMRI_LANGUAGE_unproc\100206\unprocessed\3T\tfMRI_LANGUAGE_LR'; % [示例] 替换为原始 run 路径。
spec.subject='100206';spec.session='';spec.run='tfMRI_LANGUAGE_LR'; % [示例] 标识输出目录；批量研究每个 run 一个 spec。
spec.topupDir=fullfile(root,'derivatives','hcp_topup_validation_v2','sub-100206','tfMRI_LANGUAGE_LR'); % [示例] 上一步已经完成的 TOPUP 输出目录。
spec.sbref=fullfile(raw,'100206_3T_tfMRI_LANGUAGE_LR_SBRef.nii.gz'); % [示例] 对应此 BOLD run 的原始 SBRef。
spec.bold=fullfile(raw,'100206_3T_tfMRI_LANGUAGE_LR.nii.gz'); % [示例] 对应原始 4D BOLD，不填官方已预处理影像。
spec.boldDirection='i-'; % [必查] NIfTI i/j/k 体素轴方向；此 HCP LR 值来自官方脚本，不能按名称套用其他数据。
spec.boldReadoutSeconds=(90-1)*0.00058; % [必查] 有效回波间隔 × (BOLD PE 轴体素数-1)，秒；其他研究自行核对。
result=psy.bold_unwarp_run(spec,cfg);
disp(result.status);disp(result.outputDir);
