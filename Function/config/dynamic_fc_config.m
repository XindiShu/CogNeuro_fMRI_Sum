function cfg=dynamic_fc_config
%DYNAMIC_FC_CONFIG 单run连续片段内滑窗FC、窗长敏感性与线性平稳相位零模型。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','dynamic_runs.tsv'); % [必改] subject/session/run/data_file；MAT中data.y/trSeconds/roiNames，可有frameIndices。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_dynamic_fc'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false读输入和窗口预检，true计算。
cfg.options.windowSeconds=[30 60 90]; % [可调] 多个正数秒，round到实际帧数并记录；共同最大统计量覆盖这些窗长和全部边。
cfg.options.stepSeconds=3; % [可调] 步长秒>0，round到帧数，至少1帧。
cfg.options.taper='gaussian'; % [可调] rectangular或gaussian；高斯权重仅在本窗口截断。
cfg.options.gaussianSigmaFraction=.2; % [可调] 高斯sigma/窗口帧数，正数。
cfg.options.minWindows=3; % [可调] 同窗长至少3个窗口才计算跨窗相关SD。
cfg.options.nSurrogates=0; % [可调] 整数>=0；0不计算零分布/p值；科研需另行选充分次数。
cfg.options.seed=47; % [可调] 固定随机种子，退出恢复调用者RNG。
end
