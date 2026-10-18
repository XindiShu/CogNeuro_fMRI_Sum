function cfg=behavior_config
%BEHAVIOR_CONFIG 通用选择/奖励/RT输入；RL与DDM各自使用明确字段。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','behavior_runs.tsv'); % [必改] subject/session/run/trials_file；试次表按真实顺序，含trial_id/block_id/choice/reward/rt_seconds。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_behavior'); % [必改] 新绝对输出目录。
cfg.execute=false; % [可调] false检查输入，true拟合并保存逐试次结果。
cfg.method='rw_softmax'; % [可调] rw_softmax或ddm。
cfg.actionLabels={'left','right'}; % [必改] choice整数1..K与真实行为含义一一对应；DDM限K=2，1为上边界。
cfg.minimumTrials=8; % [可调] 每run最少完整试次数；只是工程下限。
cfg.pythonExecutable=''; % [必改若DDM] 独立PyDDM环境python.exe；本机D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe。
cfg.pythonTimeoutSeconds=600; % [可调] DDM子进程超时秒>0，仅停止自己的子进程。
cfg.rw.initialValue=.5; % [可调] 每block起始Q，单位与reward相同。
cfg.rw.rewardRange=[0 1]; % [必查] 允许奖励范围；正确率代理不等同实际反馈，需在输入记录。
cfg.rw.alphaBounds=[.001 .999]; % [可调] 学习率范围[0,1]内，拟合一份chosen-action RW率。
cfg.rw.betaBounds=[.01 20]; % [可调] softmax逆温度，单位=奖励单位的倒数，非负。
cfg.rw.lapse=.02; % [可调] 固定随机选择比例[0,1)，不参与本轮拟合。
cfg.rw.nStarts=5; % [可调] 有界fmincon多起点次数，整数>=1。
cfg.rw.maxIterations=200; % [可调] 每起点优化迭代上限；保留exitflag，不保证全局最优。
cfg.rw.seed=59; % [可调] 多起点随机种子，退出恢复RNG。
cfg.ddm.driftBounds=[-5 5]; % [可调] 常数漂移范围，固定扩散噪声=1。
cfg.ddm.boundBounds=[.3 3]; % [可调] 对称边界±B的正半宽范围。
cfg.ddm.nondecisionBounds=[0 1]; % [可调] 非决策时间秒；上限进一步限制为最小观测RT的95%。
cfg.ddm.dtSeconds=.01; % [可调] 密度时间网格秒；当前恒定DDM用原生解析求解。
cfg.ddm.dx=.02; % [可调] 空间网格；记录为原生模型设置，非决策参数单位仍为秒。
cfg.ddm.maxRtSeconds=30; % [可调] 明确的RT秒上限；超限拒绝，不静默截尾或把毫秒当秒。
cfg.ddm.mixture=.02; % [可调] 固定均匀混合比例(0,1)，降低零密度风险；不是拟合lapse。
cfg.ddm.maxIterations=40; % [可调] differential evolution循环上限；低次数只为工程验证。
cfg.ddm.populationSize=8; % [可调] 原生DE种群倍数，整数>=1。
cfg.ddm.seed=61; % [可调] 固定原生优化随机种子。
end
