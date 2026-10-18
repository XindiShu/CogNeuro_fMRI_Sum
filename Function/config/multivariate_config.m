function cfg=multivariate_config
%MULTIVARIATE_CONFIG 关联、预测和中介分别报告；不把训练相关当外测。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','multivariate_data.mat'); % [必改] data.X/Y/sampleIds/independentUnitIds/XfeatureIds/YfeatureIds，可加covariates/cvGroups/exchangeBlocks/M。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_multivariate'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false输入与模型预检，true计算。
cfg.method='pls_covariance'; % [可调] pls_covariance/cca/pls_regression/mediation。
cfg.options.nComponents=1; % [可调] 预先指定维数，不能超过训练折的可观察秩。
cfg.options.scaleFeatures=true; % [可调] 每训练折分别对X/Y残差按样本SD缩放。
cfg.options.lambdaX=.1; % [可调] CCA X协方差ridge>=0；0要求训练特征协方差正定。
cfg.options.lambdaY=.1; % [可调] CCA Y协方差ridge>=0；均为0时经典CCA，非自动调参。
cfg.options.crossValidate=false; % [可调] 用显式cvGroups留一组；固定维度/惩罚，不是嵌套模型选择。
cfg.options.nPermutations=0; % [可调] PLS-C/CCA独立无协变量行的块内Y置换；PLS回归不支持该统计置换。
cfg.options.nBootstrap=0; % [可调] 关联权重或中介ab的独立单位cluster bootstrap次数；PLS回归此处不提供载荷CI。
cfg.options.alpha=.05; % [可调] percentile区间的双侧alpha，在(0,1)。
cfg.options.inferenceScope='engineering'; % [必查] engineering或assumed_exchangeable；代码不证明独立性/可交换性/因果识别。
cfg.options.exchangeabilityJustification=''; % [必改若置换/自助] 写明单位/依赖结构依据或明确工程目的。
cfg.options.seed=79; % [可调] 固定重采样RNG并恢复。
cfg.mediation.predictorColumn=1; % [可调] X中预先指定的单个预测列；M另为单个中介向量。
cfg.mediation.outcomeColumn=1; % [可调] Y中预先指定的单个结果列；线性无交互中介，不是二分类因果模型。
end
