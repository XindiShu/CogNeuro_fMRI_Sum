function cfg=function_config
%FUNCTION_CONFIG 新分析层配置；不引用或改写定稿toolkit_config。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','analysis_runs.tsv'); % [必改] 每行一个subject/session/run；模板analysis_runs_template.tsv。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_analysis'); % [必改] 新的结果根目录；不得置于原始输入目录。
cfg.spmPath=fileparts(which('spm')); % [必查] SPM安装目录；空时需先加入SPM路径。
cfg.execute=false; % [可调] false只预检；true计算并写入新目录，已有run目录拒绝覆盖。
cfg.methods={'static_fc','alff'}; % [可调] 已开放方法；METHOD_STATUS.tsv列出可用及待开发项。
cfg.continueOnError=true; % [可调] true逐run记录错误继续；false立即停止。
cfg.maxMatrixGiB=2; % [可调] 读入的double矩阵大小上限，GiB>0；不是进程峰值内存承诺。
cfg.roiMinVoxels=3; % [可调] 每ROI有效掩膜内最少体素，正整数；不足则报错。
cfg.clean.detrend=true; % [可调] 去除线性趋势；与截距/混杂/频率基联合投影。
cfg.clean.bandHz=[]; % [可调] []不带通；或[低频 高频]Hz，0<=低频<高频<=1/(2TR)。
cfg.clean.minResidualDimensions=10; % [可调] 投影后最少代数剩余维度；不等于统计有效自由度。
cfg.fc.estimator='pearson'; % [可调] pearson/spearman/partial；partial要求可逆样本协方差。
cfg.fc.seedColumns=[]; % [可调] []只做ROI矩阵；非空为ROI列号，额外输出seed-to-voxel。
cfg.spectrum.bandHz=[0.01 0.08]; % [可调] ALFF/fALFF频带Hz，须落在Nyquist范围内。
cfg.reho.neighborhood=27; % [可调] 7/19/27含中心体素；在未平滑数据上计算。
cfg.reho.minNeighbors=7; % [可调] 边界最少有效邻居数；不足输出NaN及覆盖状态。
cfg.statistics.fdrAlpha=0.05; % [可调] BH-FDR显著性水平，0<值<1；每次明确给出的检验族单独校正。
cfg.graph.threshold=0.2; % [可调] 正边绝对阈值>=0；不是网络密度阈值。
cfg.graph.negativePolicy='drop'; % [可调] drop显式丢弃负边并记录数目；reject遇负边报错。
end
