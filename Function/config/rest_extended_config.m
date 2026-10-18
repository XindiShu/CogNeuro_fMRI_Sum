function cfg=rest_extended_config
%REST_EXTENDED_CONFIG 同源连续时序的不同熵/ACF定义，以及显式同源配对FC。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','rest_extended_runs.tsv'); % [必改] subject/session/run/data_file；data.y/trSeconds/featureIds/frameIndices，可有pairs/space。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_rest_extended'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false输入预检，true计算。
cfg.methods={'entropy','timescales'}; % [可调] entropy/timescales/homotopic；同源配对需data.pairs和明确空间声明。
cfg.maxMatrixGiB=1; % [可调] 读入double矩阵容量上限GiB，不是进程峰值保证。
cfg.entropy.sampleM=2; % [可调] SampEn匹配模板长度整数>=1，m与m+1用相同起点集合。
cfg.entropy.delayFrames=1; % [可调] 样本/排列熵嵌入延迟帧，整数>=1；不跨缺帧。
cfg.entropy.toleranceFraction=.2; % [可调] SampEn Chebyshev容差=此值×该列样本SD；严格正值。
cfg.entropy.permutationOrder=3; % [可调] 排列阶数2..7。
cfg.entropy.tiePolicy='omit'; % [可调] omit排除有精确并列的排列窗口，stable按原时间索引打破并列，均记录。
cfg.entropy.histogramBins=16; % [可调] 幅度Shannon直方图箱数整数>=2；每列本身的min/max等宽，不能冒充时序复杂度。
cfg.entropy.maxComparisons=5e6; % [可调] 每列两组pdist所用模板对数量上限，避免无界平方内存。
cfg.timescales.maxLagSeconds=10; % [可调] ACF最大滞后秒，实际还受连续记录长度限制。
cfg.timescales.expFitMaxLagSeconds=5; % [可调] 首正ACF瓣内的log-linear拟合范围秒，至少3个正滞后点才给tau。
cfg.homotopic.mappingStatus='not_declared'; % [必改若配对] verified_symmetric或engineering_mirror；MNI标签本身不等于已验证对称配准。
cfg.homotopic.mappingNote=''; % [必改若配对] 显式同源对应/对称模板/变换来源，不自动猜。
cfg.homotopic.allowEngineeringMapping=false; % [可调] true显式允许几何镜像工程测试，scientificMappingVerified仍为false。
end
