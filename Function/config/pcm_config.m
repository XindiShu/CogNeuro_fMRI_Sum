function cfg=pcm_config
%PCM_CONFIG 官方MATLAB PCM固定/成分模型；明确条件顺序和噪声结构。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','pcm_subjects.tsv'); % [必改] subject/data_file，一被试一行，可把多个session/run编码为partition。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_pcm'); % [必改] 新绝对目录。
cfg.pcmPath=''; % [必改] 含pcm_fitModelGroup.m等文件的官方PCM目录。
cfg.execute=false; % [可调] false完整数据/模型/噪声预检，true原生拟合。
cfg.conditionLabels={}; % [必改] 明确有序条件标签，与所有Gc的行列顺序一致。
cfg.models={}; % [必改] cell结构name/type/Gc；fixed=单个PSD矩阵，component=PSD矩阵的3D堆叠。
cfg.options.mode='individual'; % [可调] individual/group/individual_cv/group_cv。
cfg.options.runEffect='fixed'; % [可调] fixed或random；fixed时成分需在条件中心化空间可识别。
cfg.options.fitScale='auto'; % [可调] auto：fixed和group拟合scale；individual component不另拟合scale。也可显式logical。
cfg.options.maxIterations=100; % [可调] 正整数优化上限；有限似然不等于充分收敛。
cfg.options.allowEngineeringNoise=false; % [必查] true允许显式声明unwhitened_engineering；false需要特征噪声协方差或声明already_whitened。
end
