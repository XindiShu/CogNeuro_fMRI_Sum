function cfg=ppi_config
%PPI_CONFIG 原生SPM VOI/反卷积/模型估计；一个显式模型session。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.spmMat=''; % [必改] 已估计SPM.mat，只读。
cfg.seedMask=''; % [必改] 与BOLD同网格3D非负种子掩膜。
cfg.analysisMask=''; % [可调] 空复用原模型mask；非空为同网格目标mask，须为原mask子集。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_ppi'); % [必改] 新结果目录。
cfg.execute=false; % [可调] false仅预检；true计算VOI、PPI及新模型。
cfg.sessionIndex=1; % [可调] SPM内session索引，整数>=1。
cfg.mode='gppi'; % [可调] ppi=单心理对比；gppi=每条件一交互。
cfg.conditionIndices=[]; % [可调] []全部Sess.U；或明确条件编号，不含pmod列。
cfg.psychologicalWeights=[]; % [ppi必改] 与条件等长非全零权重；gppi忽略。
cfg.highpassSeconds=128; % [可调] 交互模型高通秒，有限>0。
cfg.serialCorrelation='FAST'; % [可调] FAST或AR(1)。
cfg.estimate=true; % [可调] true估计及T对比；false仅指定新模型。
end
