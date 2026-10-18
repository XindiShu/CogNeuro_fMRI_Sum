function cfg=glm_config
%GLM_CONFIG与前置的预处理通用

%%详细每一行解释与参数选择见文档
root=fileparts(fileparts(mfilename('fullpath')));


cfg.manifestFile=fullfile(root,'config','glm_runs.tsv');             % [必改] 指向对应的.tsv文件（其中内容需自己填写）run/subject用glm_runs_template.tsv；group用subject_contrasts.tsv或glm_group_template.tsv。

cfg.outputRoot=fullfile(root,'derivatives','my_study_glm');          % [必改] 输出目录。

cfg.spmPath=fileparts(which('spm'));                                 % [必改] SPM安装目录，代码设置自动查找，找不到则手动添加。

cfg.execute=false;                                                   % [可调] false=只进行预检查；true=正式开始估计模型。 


cfg.conditions={'conditionA','conditionB'};                          % [必改] 事件表中所有trial_type条件名称，例如{'story','math'}，注意填写顺序需固定，顺序决定下面权重的列顺序。

cfg.contrastNames={'A_minus_B'};                                     % [条件模式必改] T对比名称，可用多个不重复、非空名字，例{'story_minus_math','math_minus_story'}，与权重contrastWeights每一行对应。

cfg.contrastWeights=[1 -1];                                          % [条件模式必改] 每行一个T对比；列顺序等于conditions，不含混杂/截距；其他单元自动输出各目标。



%% beta含义

cfg.model.unit='condition';                          % [可调]condition/event/trial/item/block/phase/trial_phase

cfg.model.targetConditions={};                       % [可调] 空=输出所有单元的目标效应；否则只选列出的条件，其他事件仍进入模型；condition模型必须空；GLMsingle当前也必须空。

cfg.events.expression='duration';                    % [可调] duration=保留事件表时长；impulse=显式全部设为0；fixed=统一指定时长。GLMsingle不接受impulse。

cfg.events.fixedDurationSeconds=1;                   % [可调] 仅fixed模式生效；单位秒，有限且>=0；原始事件表不改写。

cfg.hrf.type='canonical';                            % [可调] SPM:canonical/canonical_time/canonical_time_dispersion/fir；GLMsingle:canonical/library。


cfg.hrf.fir.windowSeconds=20;                        % [可调] FIR响应窗的长度，单位秒；每bin宽必须是TR/microtimeResolution的整数倍。

cfg.hrf.fir.nBins=10;                                % [可调] FIR时间bin数，正整数；窗口从事件0秒开始，不自动平移onset。

cfg.hrf.fir.summaryBins=[];                          % [可调] 空=所有bin等权平均；也可在此指定要平均的整数编号，如 [3 4 5]。

cfg.hrf.fir.includeOmnibus=true;                     % [可调] FIR额外生成跨所有bin的整体F检验；false=不做这一项



%% LSS LSA 涉及参数

cfg.pmod.enabled=false;                                                         % [可调] 是否检验"事件数值变化是否伴随BOLD幅度变化"；当前支持condition+joint的canonical及其导数模型。关闭时modulators必须为空；开启时必须填写，不能仅打开开关。

cfg.pmod.modulators=struct('condition',{},'column',{},'name',{},'poly',{});     % [必改] condition=在哪个条件内使用，column=事件表中的数值列，name=这项效应的名字，poly=最高多项式阶数1到6。顺序会影响开启串行正交化时的解释

cfg.pmod.center='within_condition';                                             % [可调] within_condition=各run各条件的调节值减去均值；none=原数值零点，主效应解释随之改变。

cfg.pmod.scale='none';                                                          % [可调] none=原单位；zscore=除以各run各条件样本标准差；必须同时within_condition中心化。

cfg.pmod.orthogonalize=false;                                                   % [可调] false=配置列共同进入模型，所有列同时解释；true=SPM按配置顺序串行正交化，后列解释剩余变异，因此换顺序可能换解释。

cfg.fit.strategy='joint';                                                       % [可调] joint=全部估计单元放入一个模型；lss=每目标分别拟合；condition/phase仅支持joint。

cfg.fit.lssGrouping='condition';                                                % [可调] lss时 pooled=其余事件合一；condition=按原trial_type分别合并。



%% 统计级别、组统计

cfg.level='run';                                     % [可调] run=每个run单独分析；subject=同被试多run联合；group=读取被试对比清单作二级组统计。

cfg.subject.combineSessions=false;                   % [可调] false=每个subject/session分别合并run；true=同被试所有session合并，须有科学依据。

cfg.group.design='one_sample';                       % [可调] one_sample/paired/two_sample/regression；配对先按ID求差，两组为独立等方差模型。

cfg.group.minSubjects=3;                             % [必改] 每项组对比至少多少个独立被试，整数>=2。

cfg.group.pairedLevels={'pre','post'};               % [配对必改] 清单pair_level的两个标签；方向为第1减第2，与session列独立。

cfg.group.groupLabels={'groupA','groupB'};           % [两组必改] 清单group的两个标签；方向为第1组减第2组。

cfg.group.minPerGroup=2;                             % [必改] 每组至少多少人，整数>=2；仅two_sample使用，不允许一人同时进两组。

cfg.group.covariateColumns={};                       % [回归必改] 清单中的数值协变量列名，如{'score','age'}；regression至少1列，paired暂不支持协变量。

cfg.group.covariateCenter='overall';                 % [可调] overall=各列全体被试去均值；none=保留原点；不标准化、不串行正交化、不自动插补。

cfg.group.minResidualDF=1;                           % [必改] 二级模型最小残差维度=被试数−设计矩阵秩，正整数；不等于下面一级cfg.minResidualDF。

cfg.engine='spm_classical';                          % [必改] 选择实际计算后端：spm_classical调用SPM经典GLM，glmsingle调用随包固定版本GLMsingle。。



%% GLMsingle专属参数

cfg.glmsingle.path=fullfile(root,'external','glmsingle');            % [必改] 随包提供的固定版本官方MATLAB依赖根目录。

cfg.glmsingle.identityColumn='stimulus_id';                          % [必改] 事件表中哪一列定义"重复身份"；不可把不同刺激无依据地视为相同刺激。

cfg.glmsingle.wantDenoise=true;                                      % [可调] true执行GLMdenoise，利用共同噪声的主成分（PC）作回归量，并交叉验证选PC数量；false不执行。

cfg.glmsingle.wantRidge=true;                                        % [可调] true做fractional ridge，通过收缩逐事件系数降低不稳定性，生成D；false不做。

cfg.glmsingle.fracs=fliplr(.05:.05:1);                               % [可调] ridge候选，0<值<=1；本接口要求至少两个不同候选以明确执行交叉验证。

cfg.glmsingle.maxPCs=10;                                             % [可调] GLMdenoise最多尝试的PC数；实际选择可为0。

cfg.glmsingle.noiseR2Threshold=[];                                   % [可调] 决定哪些低ONOFF拟合度体素可进入候选噪声池。空让官方自动估计，或给一个有限数值。

cfg.glmsingle.pcR2Threshold=[];                                      % [可调] 空=官方自动选择用于PC评估的R2阈值；或有限百分数。

cfg.glmsingle.maxPolyDegree=[];                                      % [可调] 空=官方round(run时长分钟/2)；或所有run共用的非负整数；不使用SPM高通。

cfg.glmsingle.onsetMode='strict';                                    % [可调] strict=要求onset在TR格点；nearest=显式允许最近TR舍入并记录误差。

cfg.glmsingle.maxOnsetErrorSeconds=0.05;                             % [可调] 仅nearest时允许的绝对舍入误差上限，秒，>=0；不重采样BOLD。

cfg.glmsingle.minEndBufferSeconds=8;                                 % [可调] 最后onset格点之后保留的最短时间，秒，>=0；不自动删尾部事件。

cfg.glmsingle.chunkVoxels=5000;                                      % [可调] 一次处理多少个体素；仅影响计算与内存。

cfg.glmsingle.maxInputGiB=4;                                         % [可调] 全部run掩膜内single输入矩阵的体积上限，GiB；不等于峰值内存保证。

cfg.glmsingle.wantPercentBold=true;                                  % [可调] true=官方按绝对meanvol换算百分信号；false=输入强度单位。

cfg.glmsingle.randomSeed=0;                                          % [可调] 固定MATLAB随机种子，0-2^32-1；结束后恢复调用前状态。


%% 掩膜、SPM时间参数等等

cfg.explicitMask='';                    % [可调] 空=SPM隐式掩膜，不提供额外全局显式掩膜；否则同网格3D非负有限掩膜的绝对路径；清单mask列可逐run覆盖。

cfg.qc.plot=true;                       % [可调] true保存模型诊断图；SPM估计后的数值设计/采样残差诊断不因关闭绘图而跳过，仅execute=true时生成。

cfg.qc.maxResidualVoxels=32;            % [可调] SPM残差诊断最多确定性抽取多少个掩膜内体素，正整数；不代表全脑残差已逐体素审查。

cfg.highpassSeconds=128;                % [可调] SPM 高通截止周期，秒；不是在影像上预先滤波。

cfg.serialCorrelation='FAST';           % [可调] SPM FAST 或 AR(1)

cfg.microtimeResolution=16;             % [可调] 每 TR 的 HRF 微时间格数，正整数。

cfg.microtimeOnset=8;                   % [可调] 选择的参考微时间格，1-resolution；应与实际切片时间参考一致。


cfg.design=design_config;               % [可调] 头动与组织均值选择来自 design_config；不使用其路径配置。

cfg.design.linearTrend=false;           % [可调] 默认以 SPM 高通处理慢漂移；可另加显式线性项。

cfg.maskThreshold=0.8;                  % [可调] SPM隐式相对阈值，0-1；与显式掩膜共同限制覆盖，须核查mask.nii。

cfg.minResidualDF=20;                   % [可调] 高通后联合设计最少代数残差维度，非最终统计自由度。

cfg.continueOnError=true;               % [可调] 记录当前run/被试/组对比失败后继续；group不会自动删除失败被试。

end
