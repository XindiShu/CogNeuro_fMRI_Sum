function cfg=linear_decode_config
%LINEAR_DECODE_CONFIG 原生二分类线性SVM/logistic；留一明确组，固定惩罚。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','linear_decode_data.mat'); % [必改] MAT含data.X/Y/featureIds/sampleIds/cvGroups。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_linear_decode'); % [必改] 新目录。
cfg.execute=false; % [可调] false预检，true留组预测。
cfg.options.estimator='svm'; % [可调] svm或logistic；二分类，原生fitclinear。
cfg.options.lambda=.01; % [可调] 固定严格正L2惩罚，不是SVM的C，不在测试组调参。
cfg.options.seed=163; % [可调] native solver随机状态，退出恢复。
cfg.options.dependencyNote=''; % [必改] cvGroups代表被试/run/session/family等；上游beta共享和时间依赖由调用者审查。
end
