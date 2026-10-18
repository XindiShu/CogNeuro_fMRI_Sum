function [cfg,demo]=glmsingle_demo_config
%GLMSINGLE_DEMO_CONFIG 教学/工程运行配置；覆盖glm_config的少量选择，不更改通用默认。
root=fileparts(fileparts(mfilename('fullpath')));
cfg=glm_config;
cfg.manifestFile=fullfile(root,'config','glm_runs.tsv'); % [必改] 已预处理run清单；每人至少两个run，含原事件/混杂及同网格mask。
cfg.outputRoot=fullfile(tempdir,['glmsingle_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); % [可调] 必须为新目录；输入/输出审计与模型保存在这里，不放入干净发布包。
cfg.execute=false; % [可调] false只准备/检查；true实际估计A/B/C/D；不是研究效益验证。
cfg.conditions={'story','math'}; % [可调] 当前HCP LANGUAGE类别；其他任务须改成完整trial_type集合。
cfg.contrastNames={'story_minus_math'}; % [说明] GLMsingle不使用此SPM对比名；保持总配置完整。
cfg.contrastWeights=[1 -1]; % [说明] 此路线不据此生成T图或组统计。
cfg.engine='glmsingle'; % [约束] 调用随包固定版本的官方GLMsingle。
cfg.level='subject'; % [约束] 每人独立合并run；不同被试不作为重复刺激。
cfg.model.unit='event'; % [约束] 每一事件行一个beta；story行是故事及相关响应期，不是词语级试次。
cfg.hrf.type='library'; % [可调] library=20个候选HRF；canonical=固定标准HRF。
cfg.events.expression='fixed'; % [约束] 教学近似：统一响应持续时长，原表不改写。
cfg.events.fixedDurationSeconds=20; % [可调] 秒，正值且0.1秒倍数；20秒是本示例选定的代表尺度，不是HCP真实统一时长。
cfg.glmsingle.identityColumn='trial_type'; % [约束] 按任务类别定义交叉验证重复，不宣称同一音频重复；每次事件仍有独立beta。
cfg.glmsingle.onsetMode='nearest'; % [约束] 舍入到最近TR；保留原onset及有符号误差，不改BOLD零点。
cfg.glmsingle.maxOnsetErrorSeconds=0.37; % [可调] 秒；HCP TR约0.72秒，半TR约0.36秒；超过上限仍阻断。
cfg.glmsingle.minEndBufferSeconds=16; % [可调] 秒；示例副本排除格点onset到最后一帧不足该时间的事件，并逐行记录；原事件表不改。
cfg.glmsingle.wantDenoise=true; % [可调] 执行PC数量的留一run交叉验证；实际选择可为0。
cfg.glmsingle.wantRidge=true; % [可调] 执行ridge候选的留一run交叉验证；每次呈现单独估计。
cfg.glmsingle.maxPCs=2; % [可调] 最多尝试2个PC，以缩短教学运行；最终数目由交叉验证选定。
cfg.glmsingle.fracs=[1 .75 .5]; % [可调] 少量候选覆盖无收缩/中等收缩；不是最优候选范围建议。
cfg.glmsingle.noiseR2Threshold=100; % [可调] 百分数；示例把几乎整个选定掩膜纳入候选噪声池，不依靠自动阈值选择噪声池。
cfg.glmsingle.pcR2Threshold=-1e6; % [可调] 百分数；示例用全部有限TYPE-A R2体素评估PC数量，不作任务激活筛选。
cfg.glmsingle.randomSeed=189; % [可调] 0..2^32-1，固定种子；结束恢复原随机状态。
cfg.design.motionModel='24'; % [可调] 现有HCP交接表提供24头动项；人工合成无头动示例可设none。
cfg.design.includeTissueMeans=false; % [约束] 本示例不要求尚未交接的组织均值；不是先对BOLD回归。
cfg.design.linearTrend=false; % [约束] 漂移交给GLMsingle逐run多项式。
cfg.continueOnError=false; % [约束] 任一被试失败即保留审计并停止，不静默删被试。
demo.maxVoxelsPerSubject=4096; % [可调] 每人按掩膜线性索引均匀抽样的体素上限；0=全部；不根据任务拟合优劣选点。
end
