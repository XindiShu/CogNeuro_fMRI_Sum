function cfg=transfer_config
%TRANSFER_CONFIG 源域训练后冻结，目标域仅应用与评分。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','transfer_data.mat'); % [必改] MAT含train/test结构，各含X/featureIds/sampleIds/independentUnitIds/domainId；train.Y必需，test.Y可省略。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_transfer'); % [必改] 新输出目录。
cfg.execute=false; % [可调] false身份/边界预检；true拟合和冻结预测。
cfg.options.estimator='diaglda'; % [可调] diaglda分类或ridge回归；固定模型设置，不在目标域调参。
cfg.options.lambda=1; % [可调] ridge的严格正L2惩罚，目标均值仅来自源域。
cfg.options.unitPolicy='disjoint_units'; % [可调] 跨人用disjoint_units；同人跨任务/时段用matched_units_distinct_domains。
cfg.options.dependencyNote=''; % [必改] 任务/时段/被试及上游估计独立性和限制；domainId必须显式不同。
end
