function cfg=network_config
%NETWORK_CONFIG 正权无向社区/密度/二值零网络；独立单位一样本NBS。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','network_runs.tsv'); % [必改] subject/session/run/data_file；MAT含data.matrix/nodeIds。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_network'); % [必改] 新目录，不能覆盖既有结果。
cfg.execute=false; % [可调] false预检；true执行。
cfg.bctPath=''; % [必改] BCT函数目录；本机D:/matlab/atoolbox/BCT_function_20261017/2019_03_03_BCT。
cfg.options.negativePolicy='reject'; % [可调] reject或drop；不取绝对值，不支持signed modularity。
cfg.options.densities=[.2 .3 .4]; % [可调] (0,1]递增比例，分母为全部可能无向边，正边不足时记录实际密度。
cfg.options.gamma=1; % [可调] Louvain分辨率，严格正数。
cfg.options.communityRepeats=20; % [可调] 每密度随机重启次数整数>=1，取最大Q并保存共分配矩阵。
cfg.options.nNull=20; % [可调] 二值保度零网络数量，整数>=0；不是加权保strength null。
cfg.options.rewireIterations=10; % [可调] BCT每边重接次数整数>=1；无互异四节点边对时不调用可能死循环的原生函数。
cfg.options.seed=113; % [可调] 固定随机种子，退出恢复调用者RNG。
cfg.nbsDataFile=''; % [可调] 空则不做NBS；MAT含data.matrices(NxNxS)/nodeIds/independentUnitIds。
cfg.nbs.threshold=3.1; % [可调] 预定单个t阈值，>0；不自动选择阈值。
cfg.nbs.tail='both'; % [可调] positive/negative/both；both分别连正负成分，以同一最大零统计量校正两侧。
cfg.nbs.componentStatistic='extent'; % [可调] extent边数或excess_mass=sum(abs(t)-threshold)。
cfg.nbs.nPermutations=999; % [可调] Monte Carlo独立符号翻转数整数>=1；exact分支不用此数。
cfg.nbs.exactMaxUnits=12; % [可调] S<=此值枚举2^S符号，0禁用；范围0..16。
cfg.nbs.seed=127; % [可调] Monte Carlo种子。
cfg.nbs.exchangeabilityNote=''; % [必改若NBS] 独立单位及零假设下差值/误差符号对称的依据；家系/重复run不可充独立N。
end
