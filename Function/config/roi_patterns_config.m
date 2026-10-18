function cfg=roi_patterns_config
%ROI_PATTERNS_CONFIG beta目录→ROI内模式分析，不重跑GLM。
root=fileparts(fileparts(mfilename('fullpath')));o=pattern_config;
cfg.catalogFile=fullfile(root,'config','beta_catalog.tsv'); % [必改] 每行独立估计单元；兼容GLM统一beta目录schema。
cfg.roiFile=''; % [必改] 与beta同网格整数ROI标签NIfTI。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_patterns'); % [必改] 新输出目录。
cfg.execute=false; % [可调] false只检查清单；true读取beta计算。
cfg.sourceId=''; % [必改若目录多源] 单个source_id，避免同一事件LSA/LSS重复进入样本。
cfg.methods={'beta_series','decode','rsa'}; % [可调] beta_series/decode/rsa。
cfg.targetColumn='condition'; % [可调] 解码目标列，分类字符串或回归数值。
cfg.partitionColumns={'run'}; % [可调] 每个subject/session内部的独立分区字段；默认留一run。
cfg.maxMatrixGiB=2; % [可调] double beta矩阵上限GiB，>0。
cfg.roiMinVoxels=3; % [可调] 每ROI最少有效体素，正整数。
cfg.options=o; % [可调] 分类/ridge/RSA/最少trial选项在pattern_config中逐项说明。
end
