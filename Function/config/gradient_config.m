function cfg=gradient_config
%GRADIENT_CONFIG BrainSpace节点×连接特征嵌入；顺序/核/稀疏度显式。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','gradient_inputs.tsv'); % [必改] subject/session/run/data_file；MAT含data.matrix/nodeIds/featureIds。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_gradients'); % [必改] 新绝对输出目录。
cfg.brainSpacePath=''; % [必改] BrainSpace的matlab目录；本机D:/matlab/atoolbox/BrainSpace_function_20261017/matlab。
cfg.execute=false; % [可调] false预检输入/顺序，true原生嵌入/对齐。
cfg.options.kernel='na'; % [可调] na/cs/pearson/spearman/gaussian；遵循BrainSpace负亲和度置零规则。
cfg.options.approach='dm'; % [可调] dm扩散、le拉普拉斯、pca；各自特征值含义不同。
cfg.options.alignment='pa'; % [可调] none/pa/joint；pa缺省首单位为首次目标，后续迭代均值。
cfg.options.nComponents=3; % [可调] 整数>=1且<节点数-1。
cfg.options.sparsityPercent=90; % [可调] [0,100)每节点连接特征百分位阈值；不是图边密度。
cfg.options.alpha=.5; % [可调] 扩散参数[0,1]。
cfg.options.diffusionTime=0; % [可调] 非负数；0用原生多尺度缩放。
cfg.options.alignmentIterations=10; % [可调] PA迭代正整数。
cfg.options.seed=37; % [可调] 固定RNG并在退出后恢复。
cfg.options.reference=[]; % [可调] 外部节点×成分参考；调用者必须核对同一nodeIds/顺序。
cfg.spatialNullFile=''; % [可调] 空不做空间关联；MAT含spatial.nodeIds/marker/method/options，须与节点顺序相同。
cfg.spatialGradientColumn=1; % [可调] 单次检验所选已对齐梯度列；多单位/多列不自动做多重比较。
end
