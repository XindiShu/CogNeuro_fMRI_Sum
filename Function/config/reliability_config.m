function cfg=reliability_config
%RELIABILITY_CONFIG 完整平衡ICC或显式项目分半；不默默删缺失。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','reliability_data.mat'); % [必改] MAT含data.y(独立单位xoccasion/item x特征)/unitIds/featureIds及occasionIds或itemIds。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_reliability'); % [必改] 新目录。
cfg.execute=false; % [可调] false预检，true计算。
cfg.method='icc'; % [可调] icc或split_half。
cfg.options.nBootstrap=0; % [可调] ICC独立单位整行percentile bootstrap次数整数>=0；小N优先仅点估计。
cfg.options.alpha=.05; % [可调] ICC边际区间尾部概率，总alpha在(0,1)。
cfg.options.nSplits=100; % [可调] 随机平衡分半次数整数>=1。
cfg.options.splitPolicy='odd_even'; % [可调] odd_even固定项目顺序，或random_balanced；不跨单位改变项目分组。
cfg.options.seed=149; % [可调] 重采样种子，退出恢复RNG。
cfg.options.designNote=''; % [必改] 单位/测量者/时段/项目和可比性；分半Spearman-Brown依赖平行半测假设。
end
