function cfg=searchlight_config
%SEARCHLIGHT_CONFIG beta目录→毫米球邻域，独立subject/session内分析。
root=fileparts(fileparts(mfilename('fullpath')));p=pattern_config;
cfg.catalogFile=fullfile(root,'config','beta_catalog.tsv'); % [必改] 现有GLM统一beta目录，不重估GLM。
cfg.sourceId=''; % [必改若多源] 只允许一个source_id，避免相同事件不同估计器重复。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_searchlight'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false清单/列预检，true读取beta和计算。
cfg.centerMaskFile=''; % [可调] 空=全部共同掩膜体素；非空为同网格3D中心掩膜，邻居仍来自完整数据掩膜。
cfg.partitionColumns={'run'}; % [可调] 每被试/session内CV/RSA分区，多个列组成联合分区键。
cfg.exchangeabilityColumns={'run'}; % [可调] 分类/回归目标仅在这些列的联合块内打乱；不能据此自动证明可交换性。
cfg.targetColumn='condition'; % [可调] 解码目标；分类文本、回归数值；RSA使用condition列。
cfg.maxMatrixGiB=2; % [可调] beta矩阵double容量上限GiB，不是总峰值承诺。
cfg.options.mode='decode'; % [可调] decode或rsa。
cfg.options.radiusMm=6; % [可调] 球半径毫米>0，用完整affine映射后的欧氏距离，支持非等方体素。
cfg.options.minFeatures=3; % [可调] 邻域最少特征，整数>=2；不足输出NaN和覆盖数。
cfg.options.decode=p.decode; % [可调] diagLinear分类或固定lambda ridge回归；缩放在训练折内。
cfg.options.rsa=p.rsa; % [可调] correlation/euclidean/crossnobis，后者须提供全特征协方差再按邻域截取。
cfg.options.rsaScore='mean_distance'; % [可调] mean_distance为描述性平均条件距离；model_spearman需>=3条件/单个有变化modelRDM。
cfg.options.nPermutations=0; % [可调] Monte Carlo置换整数>=0；0不生成p图；mean_distance不支持置换。
cfg.options.permutationScope='engineering'; % [必查] engineering只验计算链；assumed_exchangeable是调用者自行负责的可交换性假设。
cfg.options.exchangeabilityJustification=''; % [必改若做置换] 记录样本/条件为何能交换，或明确说明仅工程模拟。
cfg.options.seed=29; % [可调] 非负整数随机种子，退出后恢复RNG。
end
