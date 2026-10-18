function cfg=naturalistic_config
%NATURALISTIC_CONFIG 明确共同刺激/时间网格的跨被试分析；不把同TR当时间对齐证据。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','naturalistic_data.mat'); % [必改] data.series(cell时间×特征)/subjectIds/featureIds/timeSeconds/stimulusId/alignmentNote，可有testSeries/testTimeSeconds/testStimulusId。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_naturalistic'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false身份/时间/方法预检，true计算。
cfg.maxArrayGiB=1; % [可调] 输入double及主要ISFC结果的容量上限GiB，不承诺总峰值；全脑ISC不要自动请求ISFC平方矩阵。
cfg.methods={'isc','isfc','srm','eventseg'}; % [可调] 仅运行明确列出方法；ISC/ISFC/原空间group eventseg需要共同特征身份。
cfg.isc.standardizeSubjects=true; % [可调] 各被试每特征在该epoch标准化，再计算leave-one-subject-out均值参考。
cfg.isc.nSurrogates=0; % [可调] 循环时间移位次数整数>=0；不是被试群体随机效应检验。
cfg.isc.minShiftFrames=3; % [可调] 排除接近0/完整周期的循环偏移，整数>=1且<=时间点数/2。
cfg.isc.seed=67; % [可调] 固定零模型RNG并恢复。
cfg.srm.nFeatures=3; % [可调] 共享维度，正整数，不超过任一被试特征数或训练时间秩。
cfg.srm.maxIterations=100; % [可调] 确定性正交SRM交替最小二乘上限。
cfg.srm.tolerance=1e-7; % [可调] 目标相对变化阈值>0。
cfg.srm.scaleFeatures=true; % [可调] 每被试特征只按训练epoch均值/SD缩放，held-out复用，不重新拟合映射。
cfg.events.nEvents=3; % [可调] 固定顺序事件数整数>=2；只允许保持/进入下一个事件。
cfg.events.maxIterations=100; % [可调] 同方差Gaussian EM上限，未做BrainIAK退火/多链/分裂合并。
cfg.events.tolerance=1e-7; % [可调] 相对似然变化阈值。
cfg.events.minVariance=.001; % [可调] 共同观测方差下限>0，尺度依赖预处理。
end
