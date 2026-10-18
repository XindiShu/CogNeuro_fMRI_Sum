function cfg=design_config
%DESIGN_CONFIG 混杂设计配置；任务态还需与任务设计联合建模，不能先盲目回归。
cfg.motionModel='24'; % [可调] none/6/24，SPM 头动参数；24=原值、差分及各自平方。
cfg.includeTissueMeans=true; % [可调] 加入 WM/CSF 均值；不包含全脑信号或 aCompCor。
cfg.linearTrend=true; % [可调] 加入线性趋势；截距始终保留，没有实现频域滤波。
cfg.addSpikes=false; % [可调] true=超 FD 阈值各帧一个指示列；不删行、不扩大邻近帧。
cfg.fdThresholdMm=0.5; % [可调] 只在 addSpikes=true 时使用；FD 大于阈值标记。
cfg.minResidualDF=20; % [可调] 至少保留的代数残差维度；不是自相关修正后的统计自由度。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.inputRoot=fullfile(root,'derivatives','my_study_confounds'); % [必改] 本工具包混杂提取输出根目录，递归处理全部已完成 run。
cfg.outputRoot=fullfile(root,'derivatives','my_study_design'); % [必改] 新输出根目录，必须位于输入目录之外。
end
