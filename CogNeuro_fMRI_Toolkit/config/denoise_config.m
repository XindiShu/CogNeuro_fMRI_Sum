function cfg=denoise_config
%DENOISE_CONFIG 独立时间去噪；只用于静息态或明确的工程验证，任务 GLM 另行建模。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','denoise_runs.tsv'); % [必改] 复制 denoise_runs_template.tsv，填写逐 run 路径和用途声明。
cfg.outputRoot=fullfile(root,'derivatives','my_study_denoised'); % [必改] 新目录；不会覆盖既有影像。
cfg.spmPath=fileparts(which('spm')); % [必查] SPM 安装目录；找不到时填绝对路径。
cfg.subjects={}; % [可调] 空=全部被试；保留原始编号。
cfg.runNames={}; % [可调] 空=全部 run。
cfg.design=design_config; % [可调] 混杂模型详细参数见 design_config.m；其输入/输出目录在此不使用。
cfg.highpassHz=0.008; % [可调] DCT 频率低于此值的项联合回归；0=关闭高通，截距仍移除。
cfg.lowpassHz=0.09; % [可调] DCT 频率高于此值的项联合回归；[]=关闭低通；须低于 Nyquist。
cfg.minResidualDF=20; % [可调] 联合混杂与滤波后最低代数残差维度，不是统计推断自由度。
cfg.continueOnError=true; % [可调] 单 run 出错保存记录并继续；false=记录后停止。
end
