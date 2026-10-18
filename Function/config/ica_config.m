function cfg=ica_config
%ICA_CONFIG 空间ICA(每run PCA→时序拼接group PCA→GIFT FastICA)、双回归和FNC。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','ica_runs.tsv'); % [必改] subject/session/run/data_file；MAT中data含y/featureIds/trSeconds。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_ica'); % [必改] 新绝对输出目录，不覆盖。
cfg.giftPath=''; % [必改] 含icatb_fastICA.m的官方GIFT目录；本机最小依赖在D:/matlab/atoolbox/gift_minimal_df369a2。
cfg.execute=false; % [可调] false读取所有矩阵与索引校验；true实际ICA和双回归。
cfg.nComponents=10; % [可调] 正整数，空间成分数，不能超过任一run数据秩。
cfg.perRunPca=30; % [可调] 每run保留的PCA维度，>=成分数且<=时间/空间秩；每run同权维度拼接。
cfg.voxelVarianceNormalize=true; % [可调] 每run每体素去时均值后除样本标准差；group与dual均用同一处理数据。
cfg.normalizeStage2Timecourses=true; % [可调] 双回归第二阶段将stage1时序除样本标准差，影响图幅度。
cfg.maxIterations=500; % [可调] FastICA最大迭代正整数；返回完整矩阵不证明稳定性。
cfg.tolerance=1e-6; % [可调] FastICA停止容差，正数。
cfg.seed=17; % [可调] 固定随机种子；函数退出恢复调用者RNG。
end
