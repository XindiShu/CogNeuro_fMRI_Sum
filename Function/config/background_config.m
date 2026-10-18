function cfg=background_config
%BACKGROUND_CONFIG 显式已估计SPM设计→联合任务/混杂残差连接。
root=fileparts(fileparts(mfilename('fullpath')));shared=function_config;
cfg.spmMat=''; % [必改] 读取原始任务设计/扫描路径，不修改其SPM模型。
cfg.sessionIndex=1; % [可调] SPM内session索引，整数>=1。
cfg.maskFile=''; % [必改] 固定有效体素mask，须与所选扫描同网格。
cfg.roiFile=''; % [必改] 同网格整数ROI标签图。
cfg.temporalState='unfiltered_unregressed'; % [必查] 必须确认SPM引用的BOLD未事先时间回归/滤波。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_background'); % [必改] 新的输出目录。
cfg.execute=false; % [可调] false仅预检；true读取ROI时序并计算背景连接。
cfg.maxMatrixGiB=2; % [可调] double矩阵上限GiB，>0。
cfg.roiMinVoxels=3; % [可调] 每ROI最少体素正整数。
cfg.clean=shared.clean; % [可调] 额外趋势/频带选项；原SPM高通基会共同投影。
cfg.estimator='pearson'; % [可调] pearson/spearman/partial。
end
