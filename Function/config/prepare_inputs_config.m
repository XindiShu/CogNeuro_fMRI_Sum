function cfg=prepare_inputs_config
%PREPARE_INPUTS_CONFIG 通用NIfTI清单→ROI/体素MAT与新清单，任何数据集可用。
root=fileparts(fileparts(mfilename('fullpath')));base=function_config;
cfg.manifestFile=fullfile(root,'config','analysis_runs.tsv'); % [必改] 复用analysis_runs_template.tsv的11列，路径与处理状态必须真实。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_prepared'); % [必改] 新绝对目录，保留原始影像。
cfg.execute=false; % [可调] false检查清单/文件/处理声明，true读影像并写MAT。
cfg.mode='roi'; % [可调] roi=标签区域均值，供HMM/滑窗/熵等；voxels=掩膜内逐体素，供ICA等。
cfg.maxMatrixGiB=2; % [可调] 时间×体素double矩阵上限GiB，非总峰值保证。
cfg.roiMinVoxels=3; % [可调] roi模式每区最少体素，正整数。
cfg.requireCommonFeatures=true; % [可调] true要求所有输出列身份相同；voxels同时要求同网格，不自动取交集/重采样。
cfg.clean=base.clean; % [可调] detrend/bandHz/minResidualDimensions继承function_config；只执行本次明确设置的联合投影。
end
