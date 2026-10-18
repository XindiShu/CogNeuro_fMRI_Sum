function cfg=state_config
%STATE_CONFIG 共享状态模型，run/缺帧边界显式；固定K只是工程设置。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','state_runs.tsv'); % [必改] subject/session/run/data_file；data.y/trSeconds/roiNames，可有frameIndices。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_states'); % [必改] 新绝对输出目录。
cfg.execute=false; % [可调] false输入预检，true共享模型和逐run统计。
cfg.pythonExecutable=''; % [必改若HMM] 独立GLHMM环境python.exe；本机D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe。
cfg.pythonTimeoutSeconds=600; % [可调] HMM子进程超时秒>0，超时保留失败材料并终止该子进程。
cfg.standardizeWithinRun=true; % [可调] 每run每ROI去均值/除样本SD，统一幅度尺度；不是预测训练测试隔离。
cfg.maxMatrixGiB=1; % [可调] 合并原始时序double容量GiB上限；不是总峰值承诺，HMM还需MAT-v7传输空间。
cfg.options.method='cap'; % [可调] cap幅度帧模式；leida瞬时相位主特征向量；hmm原生GLHMM高斯状态。
cfg.options.nStates=3; % [可调] 固定状态数整数>=2；本轮不做自动K选择/稳定性证明。
cfg.options.nReplicates=5; % [可调] CAP/LEiDA kmeans初始化次数，整数>=1。
cfg.options.maxIterations=200; % [可调] CAP/LEiDA kmeans最大迭代次数。
cfg.options.seed=53; % [可调] 固定随机种子并恢复调用者RNG。
cfg.options.capSeedColumn=[]; % [可调] 空=全部帧；指定ROI列时仅其标准化值高于capSeedThreshold的帧参与。
cfg.options.capSeedThreshold=1; % [可调] seed值阈值；standardizeWithinRun=true时单位为每run z。
cfg.options.leidaTrimFrames=3; % [可调] Hilbert变换在各连续段独立运行，丢弃每端指定帧数>=0；不能自动消除滤波/Hilbert全部边界效应。
cfg.options.hmmCovariance='full'; % [可调] full或diag高斯协方差。
cfg.options.hmmMean='state'; % [可调] state拟合每状态均值，no为仅协方差状态。
cfg.options.hmmMaxCycles=50; % [可调] 原生变分训练循环上限正整数。
cfg.options.hmmInitializations=3; % [可调] 原生初始化尝试次数正整数。
end
