function cfg = preprocess_config
%PREPROCESS_CONFIG HCP 示例预设。其他研究请改 toolkit_config.m，不复制 HCP 命名规则。
root=fileparts(fileparts(mfilename('fullpath')));
cfg=toolkit_config; % 继承通用处理参数，避免维护两套计算默认值。
cfg.inputMode='hcp'; % [示例] 仅用于 HCP 目录发现，不影响通用 manifest 入口。
cfg.dataRoot='D:\IBM'; % [必查] 本机已确认的 HCP 根目录；递归发现各 <被试>_extracted 中的原始 NIfTI，换电脑/目录时才修改。
cfg.outputRoot=fullfile(root,'derivatives','hcp_unified_preproc'); % [必改] HCP 统一入口的独立输出根目录；每次修改处理参数后换一个新目录，避免覆盖旧版结果。
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] 本机已确认的 SPM12 目录；换电脑或安装目录时修改。
cfg.sdc.method='fsl_topup'; % [可调] 这批 HCP 有反向 PE SE-EPI，故示例默认走 TOPUP；若有真实 GRE 场图且填妥逐 run 元数据，可改选 SPM FieldMap 方法。
cfg.subjects={}; % [可调] {}=处理 D:\IBM 下发现的全部被试；试跑时可写 {'100206'}，多个写 {'100206','100307'}。
cfg.execute=false; % [可调] false=仅预检并写 batch_status.tsv；检查通过后改 true，才运行 TOPUP/SPM。
cfg.runNames={'tfMRI_LANGUAGE_LR','tfMRI_LANGUAGE_RL', ... % [示例] HCP 要处理的 run 名，不是通用任务限制。
    'rfMRI_REST1_LR','rfMRI_REST1_RL','rfMRI_REST2_LR','rfMRI_REST2_RL'};
cfg.hcp.echoSpacingSeconds=0.00058; % [HCP专用] HCP-YA 3T 官方示例的有效 echo spacing（秒）；不可复制到其他项目。
cfg.hcp.negativeDirection='i-'; % [HCP专用] 原始 SpinEchoFieldMap_LR 在 NIfTI i 轴的负向编码。
cfg.hcp.positiveDirection='i'; % [HCP专用] 原始 SpinEchoFieldMap_RL 在 NIfTI i 轴的正向编码。
cfg.hcp.lrBoldDirection='i-'; % [HCP专用] HCP-YA 3T 的 *_LR BOLD 方向；使用前核对该研究的仿射与协议。
cfg.hcp.rlBoldDirection='i'; % [HCP专用] HCP-YA 3T 的 *_RL BOLD 方向；不按任意项目文件名推断。
end
