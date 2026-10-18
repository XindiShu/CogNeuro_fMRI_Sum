function cfg=prediction_config
%PREDICTION_CONFIG 独立被试层面的CPM/ridge嵌套分组CV。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','prediction_data.mat'); % [必改] data.x/target/subjectIds/groupIds/featureIds，可加covariates/exchangeBlocks。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_prediction'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false完整CV输入预检，true运行嵌套CV与可选置换。
cfg.options.method='ridge'; % [可调] ridge或cpm；每外折内部留一组选择超参数。
cfg.options.lambdaGrid=[.1 1 10 100]; % [可调] ridge惩罚系数，>0；目标为SSE+lambda*||w||²，不是平均损失尺度。
cfg.options.cpmPGrid=[.01 .05 .1]; % [可调] CPM训练折双侧边相关p阈值，在(0,1)；内折按MSE选择。
cfg.options.nPermutations=0; % [可调] Monte Carlo次数>=0；有协变量或重复family组时当前不支持目标置换。
cfg.options.exchangeabilityJustification=''; % [必改若置换] 写明独立被试和交换块的依据；代码不自动验证实验假设。
cfg.options.seed=43; % [可调] 固定随机种子，退出恢复调用者RNG。
end
