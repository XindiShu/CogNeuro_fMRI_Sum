function cfg=confounds_config
%CONFOUNDS_CONFIG 通用组织信号/头动混杂提取；不会回归、滤波或删帧。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','confounds_runs.tsv'); % [必改] 复制 confounds_runs_template.tsv，填写每个 run 的真实路径。
cfg.outputRoot=fullfile(root,'derivatives','my_study_confounds'); % [必改] 新输出目录；不覆盖既有结果。
cfg.spmPath=fileparts(which('spm')); % [必查] SPM 安装目录，若为空请填绝对路径。
cfg.subjects={}; % [可调] 空=全部；例如 {'pilotA','pilotB'}。
cfg.runNames={}; % [可调] 空=全部 run；与清单一致。
cfg.wmThreshold=0.95; % [可调] 白质后验概率阈值，(0.5,1]；不是标签编号。
cfg.csfThreshold=0.95; % [可调] CSF 后验概率阈值，(0.5,1]。
cfg.erosionMm=2; % [可调] 在 BOLD 网格按毫米球形邻域腐蚀，0=不腐蚀。
cfg.minVoxels=20; % [可调] 各组织掩膜最少体素；不足时报错，不自动降低阈值。
cfg.fdRadiusMm=50; % [可调] SPM 旋转弧度换算 FD 的头半径，毫米。
cfg.fdFlagMm=0.5; % [可调] FD 大于该值标记；不自动删帧或生成回归方案。
cfg.continueOnError=true; % [可调] 记录每个 run 失败后继续，其余 run 不受影响。
end
