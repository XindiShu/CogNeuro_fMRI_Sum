function cfg = toolkit_config

%TOOLKIT_CONFIG 通用研究配置：任意目录用 TSV 指定。
%参数分段顺序，不等于程序实际执行顺序，不同预处理操作对应不同路径，详细解释见相关.md文件

root = fileparts(fileparts(mfilename('fullpath')));



%% 数据加载与基本运行设置：
cfg.inputMode = 'manifest';          % [不动] manifest=任意项目TSV；hcp=HCP原始目录适配器【开发用，勿设置】。

cfg.manifestFile = fullfile(root,'config','runs.tsv');           % [不动]提取按照教程建立的runs.tsv；未创建tsv时不能直接运行此程序。

cfg.spmPath = fileparts(which('spm'));       % [可调] 自动寻找SPM；若找不到时手动填安装目录，不能填 spm.m 文件名。

cfg.outputRoot = fullfile(root,'derivatives','my_study_preproc');          % [必改] 输出目录。

cfg.subjects = {};        % [可调] {}=全部subject；选择特定subjects：{'pilotA','pilotB'}，须与 TSV 完全一致。

cfg.runNames = {};        % [可调] {}=全部run；选择特定run： {'rest_run1','memory_run2'}，须与 TSV 完全一致。

cfg.execute = false;      % [必改] false=只检查输入与采集参数，进行初步数据检查不进行预处理；true=依次运行所选全部步骤。

cfg.stopAfter = 'smooth';         % [可调] realign=头动/QC后结束；segment=完成 T1 分割后结束；smooth=完成配准、MNI 标准化、平滑。

cfg.continueOnError = true;        % [可调] true=记录失败并继续；false=记录失败后停止

cfg.resume = true;              % [可调] 仅复用输入/配置/代码一致的完成run，不是逐步骤续跑。


cfg.dicom.enabled = false;      % [可调] false=只接收 .nii/.nii.gz，即NIfTI文件，无DICOM转为NIfTI这一步；true=允许每个bold/t1/sbref/场图 Path 填单一 DICOM 序列目录，execute=true 时调用SPM DICOM Import。

cfg.discardVolumes = 0;         % [可调] 每个 BOLD run 前端需删除的dummy帧数，非负整数；0=不删

cfg.dummy.eventReference = 'unspecified'; % [必改] cfg.discardVolumes = 0时无需修改；若删帧数非零且提供了事件时，必须二选一：original_first_volume（以原影像第一帧为 0 秒，事件减去 删帧数N×TR）或 retained_first_volume（以删帧后的第一帧为 0 秒，不平移）；也可由 TSV 的 event_reference 逐 run 覆盖。





%% 时间层校正 Slice Timing：先选 mode，再指定参考时间；HCP 多带默认关闭
cfg.sliceTiming.enabled = false;         % [不改] 旧配置兼容开关；现在应主要用 mode；enabled=false 并不会覆盖一个已设为非off的mode。

cfg.sliceTiming.seconds = [];            % [可调] 仅 mode=explicit_seconds 使用；按NIfTI 的z层顺序，填写每层采集时间，长度等于层数。

cfg.sliceTiming.referenceSeconds = 0;    % [可调] 仅 reference=seconds 使用；单位秒，须在 [0,TR) 内。

cfg.sliceTiming.mode = 'off';            % [可调] off、metadata、ascending、descending、interleaved_midtop、interleaved_bottomup、interleaved_topdown、explicit_seconds；metadata 读取逐 run JSON。

cfg.sliceTiming.acquisitionTimeSeconds = [];    % [可调]五种标准单带预设使用的TA，[]=按TR-TR/层数计算，若扫描协议提供实际TA则填实测值，须在 (0,TR) 内。

cfg.sliceTiming.reference = 'middle_time';      % [可调] middle_time、first、last、seconds，决定校正到哪个采集时刻。

cfg.sliceTiming.microtimeResolution = 16;       % [可调] 生成后续一级GLM 的建议 fmri_t/fmri_t0，默认 16，不在预处理阶段运行 GLM；正整数。







%% 磁敏感畸变校正：四种互斥方法，FSL TOPUP 与 SPM FieldMap 分开配置
%% 注意：因磁敏感畸变校正几种方法中涉及到额外SPM之外的linux系统的调用，所以将该分析的参数设置提前，根据选择方法的不同后续走不同的分析路径。
%% 故该部分下混杂有其他步骤中的参数设置，具体对应见不同步骤对应的.md文档
% 双回波相位/幅度与实虚部见对应模板；相位 Units=rad，官方 API 保留幅度，不按极值拉伸。
% 已有 VDM Units=voxel，须已对齐EPI，不重新用TE/readout/blip缩放。

cfg.distortionCorrection = 'not_applied';          % [限制] 旧版外部已校正输入标记；raw保持not_applied，通过sdc.method选择本次校正；sdc_corrected才设already_applied。

cfg.sdc.method = 'none';                           % [可选] none、fsl_topup、spm_fieldmap_unwarp、spm_fieldmap_applyvdm。头动/SDC 操作路径在这里选择。 新增 spm_unwarp=无 VDM 动态 Unwarp；spm_vdm_only=只准备 VDM，不做后续；TSV sdc_method 可逐 run 覆盖。

cfg.sdc.wslDistro = 'Ubuntu-24.04';                % [必查] 仅选择FSL分支时调用：WSL发行版，执行 wsl -l -q 核对。

cfg.sdc.fslRoot = '/home/bx210/fsl-topup';         % [必查] 仅选择FSL分支时调用：WSL内FSL安装目录。

cfg.sdc.fslConfig = '/home/bx210/fsl-topup/etc/flirtsch/b02b0.cnf';         % [可选] TOPUP配置；奇数维影像使用 b02b0_1.cnf。

cfg.sdc.threads = 4;                               % [可选] TOPUP正整数线程数；多run并发时控制总线程数。

cfg.sdc.affineTolerance = 1e-4;                    % [可选] TOPUP场图与BOLD的仿射元素比较容差；不替代人工配准检查。

cfg.sdc.registrationSearchDegrees = 10;            % [可调] FSL场图配准 SBRef 的旋转搜索范围 ±角度。

cfg.sdc.jacobianModulation = true;                 % [可调] FSL BOLD校正后是否应用Jacobian强度调制。

cfg.sdc.spm.blipDirection = 0;                     % [可调] SPM FieldMap blip 极性 -1/+1；0=未核实；逐 run 场图 JSON 的 SPMBlipDirection 优先，二者都缺失时报错。

cfg.sdc.spm.epiBased = false;                      % [可调] SPM FieldMap 来源是否为 EPI 场图；常规 GRE 相位差为 false。

cfg.sdc.spm.maskBrain = false;                     % [可调] SPM FieldMap 是否借幅度图分割生成脑掩膜；须检查掩膜质量。

cfg.sdc.spm.jacobianModulation = false;            % [可调] SPM FieldMap 的 Jacobian 调制；SPM 默认不推荐，故关闭。

cfg.sdc.spm.unwrapMethod = 'Mark3D';               % [可调] SPM 支持 Mark3D/Mark2D/Huttonish，须与相位差图质量匹配。

cfg.sdc.spm.unwrapFwhmMm = 10;                     % [可调] SPM 相位展开后加权平滑 FWHM，毫米。

cfg.sdc.spm.unwrapPadding = 0;                     % [可调] SPM FieldMap 相位展开边缘零填充宽度，非负整数；默认 0。

cfg.sdc.spm.weightedSmoothing = true;              % [可调] SPM FieldMap 是否用幅度图进行加权平滑。

cfg.sdc.spm.maskTemplate = '';                     % [可调] 空值=当前 spmPath 下 FieldMap/T1.nii；maskBrain=true 时可改为实测适合的 3D 模板路径。

cfg.sdc.spm.maskFwhmMm = 5;                        % [可调] FieldMap 脑掩膜模板匹配平滑 FWHM，毫米。

cfg.sdc.spm.maskErode = 2;                         % [可调] FieldMap 脑掩膜腐蚀次数，非负整数。

cfg.sdc.spm.maskDilate = 4;                        % [可调] FieldMap 脑掩膜膨胀次数，非负整数。

cfg.sdc.spm.maskThreshold = 0.5;                   % [可调] FieldMap 脑掩膜概率阈值，0~1。

cfg.sdc.spm.maskRegularisation = 0.02;             % [可调] FieldMap 模板分割正则化，正数。

cfg.sdc.spm.applyVdmInterpolation = 4;             % [可调] SPM Apply VDM 重采样插值阶数 0~7。


cfg.sdc.spm.matchVdm = true;                       % [可调] true=用官方MatchVDM匹配新场图到代表EPI；false=使用已对齐场图。只在 SPM y 轴模型适用；已有VDM不自动匹配，Hz无幅度图也不匹配，须先对齐。

cfg.sdc.spm.writeReferenceEpi = false;             % [可调] false=不写单幅参考校正图；true=额外输出单幅 QC EPI。

cfg.sdc.spm.referenceEpi = 'first';                % [可调] first=保留首帧；volume=下行帧；mean=SPM 按当前图像头写均值（不暗中预先 Realign）；sbref=该 run SBRef；manifest=TSV fieldmap_epi 单幅 NIfTI。

cfg.sdc.spm.referenceVolume = 1;                   % [可调] 仅referenceEpi=volume使用；删除 dummy 后的一基帧编号，正整数且不得超过保留帧数。

cfg.sdc.spm.magnitudeVolume = 1;                   % [可调] 幅度图一基回波帧编号；3D必须为 1，双回波4D可选 1/2；须核实短/长 TE 顺序。

cfg.sdc.spm.distortionAxis = 'metadata';           % [可调] metadata=按 JSON PhaseEncodingDirection 的 i/j/k；或手填 i/j/k（不能与提供的 JSON 冲突）。Unwarp 要求 j 工作轴且近似 AP/PA。

cfg.sdc.spm.resliceImages = 'all_mean';            % [可调] all_mean=全序列+均值；all=只有全序列，仅允许 stopAfter=realign，跳过需均值的时序 QC。SPM Apply VDM/Unwarp 不提供普通 Realign 的 Mean Only 菜单。

cfg.sdc.spm.outputPrefix = 'u';                   % [可调] 保存文件前缀，字母开头，可含字母/数字/下划线。






%% SPM Realign：普通头动校正；若选 spm_fieldmap_unwarp 则再用下一段参数

cfg.realign.weightImage = '';       % [可调] Estimate的空间权重图；''=不加权，或填已与参考EPI对齐的三维 .nii/.nii.gz绝对路径；须有限、非负且有 >0.01 的有效覆盖。TSV realign_weight 可逐 run 覆盖，none=该run禁用；不自动生成或配准权重图。

cfg.realign.quality = 0.9;          % [可调] 默认值为0.9，SPM Realign估计精度 0~1，越大越慢。

cfg.realign.separationMm = 4;       % [可调] 默认值为4，估计运动参数时，在参考图像中选取空间采样点的间隔，毫米。

cfg.realign.smoothingFwhmMm = 5;    % [可调] 仅头动估计时的预平滑FWHM，毫米；不是最终空间平滑。

cfg.realign.registerToMean = true;           % [可调] true：SPM Realign进行第二遍对均值图配准；false：只进行单次配准

cfg.realign.estimateInterpolation = 2;       % [可调] 默认值为2，estimate阶段的，运动参数估计时的插值，支持1-7 阶B样条；0只可用于写出阶段。

cfg.realign.writeInterpolation = 4;          % [可调] 默认值为4，Reslice阶段的，SPM头动结果重采样插值阶数 0~7。

cfg.realign.wrap = [0 0 0];                  % [可调] x/y/z 是否环绕，三个 0/1；默认[0 0 0]，即无明确依据时保持全关。

cfg.realign.mask = true;                     % [可调] SPM 共同视野掩膜；可能在边缘产生 NaN，后续有限值处理会核查。



% 仅选择 spm_fieldmap_unwarp 时参与计算
cfg.unwarp.basisFunctions = [12 12];                               % [可调] SPM可供选项：[8 8]、[10 10]、[12 12]、[14 14]；较高阶更灵活也更慢。

cfg.unwarp.regularisationOrder = 1;                                % [可调] SPM可供选项：0/1/2/3；位移场正则化阶数。

cfg.unwarp.regularisationWeight = 100000;                          % [可调] SPM可供选项：1e4/1e5/1e6；越大约束越强。

cfg.unwarp.jacobianModulation = false;                             % [可调] Jacobian强度调制；独立于 FieldMap 默认项。

cfg.unwarp.firstOrderEffects = [4 5];                              % [可调] SPM Unwarp运动参数一阶效应索引；应依采集方向审查。

cfg.unwarp.secondOrderEffects = [];                                % [可调] 二阶效应索引，默认关闭。

cfg.unwarp.smoothingFwhmMm = 4;                                    % [可调] Unwarp场估计平滑FWHM，毫米。

cfg.unwarp.reestimateMotion = true;                                % [可调] SPM Unwarp 是否重估运动参数。

cfg.unwarp.iterations = 5;                                         % [可调] SPM Unwarp迭代次数，正整数。

cfg.unwarp.expansionPoint = 'Average';                             % [可调] SPM可供选项：Average、First、Last；Taylor 展开点分别取平均/首帧/末帧。






%% 结构像分割：SPM Segment / CAT12，输入 volume、多通道及输出菜单
% 路线选择：SPM 的算法参数在下方原有九行；CAT 使用独立 cat12.* 设置。
% CAT 只支持 T1；SPM 可使用 T1+T2/PD。两路线不在同一批次中混合。

cfg.segment.backend = 'spm';               % [可调] spm=SPM12默认Segment；cat12=固定CAT12.9（需安装）；默认spm。

cfg.segment.inputVolume = 1;               % [可调] 结构NIfTI的一幅volume，从1编号；3D填1，4D可选1-帧数；不是 BOLD 帧数。

cfg.segment.channelsFile = '';             % [可选] 多通道JSON绝对路径；空=只用TSV t1；TSV anatomy_channels可逐run覆盖。见anatomy_channels_template.json。

cfg.segment.channelAlignment = 'require_aligned';          % [可调] require_aligned=已同网格且对齐（默认）；coregister_reslice=调用SPM将 T2/PD 刚体配准并重采样到T1；须人工QC。


% 以下 SPM 参数只用于 backend='spm'，affineRegistration 同时用于 CAT 初始仿射。
cfg.segment.biasRegularisation = 0.001;                           % [可调] SPM菜单可选：0/1e-5/1e-4/1e-3/1e-2/0.1/1/10；越大越限制T1偏置场。

cfg.segment.biasFwhmMm = 60;                                      % [可调] SPM菜单：30:10:150 mm 或Inf=不校正偏置场；完整链默认保留60。

cfg.segment.gaussians = [1 1 2 3 4 2];                            % [可调] 六类组织各填1-8个高斯（六元素向量）；本接口暂不支持SPM的 Inf=Nonparametric。

cfg.segment.affineRegistration = 'mni';               % [可调] SPM菜单：''=不做仿射初始化；mni=欧洲成人仿射先验；eastern=东亚成人仿射先验；subj=被试尺寸先验（均不替换 TPM）；none=做仿射但不正则化。

cfg.segment.mrf = 1;                                              % [可调]非负数；0=关闭组织图MRF清理，1=SPM 默认强度，值越大作用越强。

cfg.segment.cleanup = 1;                                          % [可调] SPM菜单：0=不清理；1=轻度；2=彻底；更强清理可能误删组织。

cfg.segment.warpRegularisation = [0 0.001 0.5 0.05 0.2];          % [可调] SPM Segment非线性形变正则化五项。

cfg.segment.warpSamplingMm = 3;                                   % [可调] 形变估计采样距离，毫米。

cfg.segment.deformationFields = 'forward';                        % [可调] none=[0 0] 无场；inverse=[1 0] 仅 iy_；forward=[0 1] 仅 y_；inverse_forward=[1 1] 两者。smooth必须含forward；none/inverse用 stopAfter='segment'。


cfg.segment.saveBias = 'corrected';                               % [可调] none=[0 0]；field=[1 0]偏置场；corrected=[0 1]校正图（默认）；both=[1 1]两者。。

cfg.segment.smoothnessMm = 0;                                     % [可调] SPM Warp的Smoothness，有限非负毫米 FWHM；默认0，不同于Bias FWHM与最后的平滑过程。

cfg.segment.nativeOutputs = {'native','native','native','none','none','none'};                 % [可调] GM/WM/CSF/骨/软组织/背景六项；每项none=[0 0]、native=[1 0]、dartel=[0 1]、native_dartel=[1 1]；默认保存前三类Native。

cfg.segment.warpedOutputs = {'none','none','none','none','none','none'};                       % [可调] 六组织每项none=[0 0]、unmodulated=[1 0]概率、modulated=[0 1]体积调制、both=[1 1]；默认none。
% dartel/native_dartel 只写 Imported(rc*)，不自动建立群体 DARTEL 模板。




% CAT12 独立设置（仅 backend='cat12' 生效）；表面重建关闭，逐 run 串行运行。CAT 不使用上方 SPM 的 gaussians/MRF/cleanup/smoothness/warpRegularisation/bias 参数。
cfg.segment.cat12.path = fullfile(cfg.spmPath,'toolbox','cat12');                       % [必查] CAT12.9 安装目录，含 cat12.m

cfg.segment.cat12.accuracy = 'default';                                                 % [可调] default=CAT accstr 0.5（推荐起点）；high=1，更慢且可能很耗时；保留CAT原生分割/偏置/Shooting 默认算法。

cfg.segment.cat12.nativeTissues = [1 1 1];                                              % [可调] GM/WM/CSF 每项 0=不写、1=写Native p1/p2/p3；默认都写；不同于SPM六类 nativeOutputs。

cfg.segment.cat12.dartelTissues = [0 0 0];                                              % [可调] GM/WM/CSF 每项 0=不写、1=CAT 刚体 DARTEL export rp*；默认全0；不建立群体模板。

cfg.segment.cat12.warpedTissues = {'none','none','none'};                               % [可调] GM/WM/CSF 每项 none/unmodulated/modulated/both；modulated 使用 CAT affine+nonlinear 调制，输出 wp*/mwp*。

cfg.segment.cat12.saveBiasCorrected = true;                                             % [可调] true=写 CAT 偏置、噪声、全局强度校正后的 mT1；false=不写；不是 SPM BiasField_ 输出。

 
% -A 可选：标准空间图谱用逆向场写到被试原生空间
cfg.atlas.enabled = false;                                                              % [可调] false=默认关闭；true=分割后自动运行 SPM Deformations；需真实图谱与匹配的标准空间声明。

cfg.atlas.manifestFile = '';                                                            % [可选] 图谱JSON 绝对路径；TSV atlases 可逐 run 覆盖；见 atlases_template.json。关闭时无需填写。

cfg.atlas.target = 't1';                                                                % [可调] t1=原生 T1 网格（segment/smooth）；bold=完成 EPI→T1 配准的未标准化均值 EPI 网格（需 stopAfter=smooth）。

cfg.atlas.ensureInverse = true;                                                         % [可调] true=启用图谱时自动追加逆向场写出；false=必须手动选 inverse/inverse_forward；不会自动追加 forward。

cfg.atlas.prefix = 'native_';                                                           % [可调] 安全输出前缀，字母开头，后续字母/数字/下划线；图谱输出至当前run/atlases/<Name>/。
% labels 固定最近邻、不平滑/调制；probability 固定线性。SPM Space=spm_tpm_mni；CAT Space=cat12_mni2009c，不可混用。







%% SPM Coregister：平均 EPI 到被试原生 T1
%% 固定Estimate；没有Reslice、Estimate & Reslice的选择
cfg.coreg.costFunction = 'nmi';                  % [可调] Coregistration代价函数：mi/nmi/ecc/ncc。

cfg.coreg.separationMm = [4 2];                  % [可调] Coregistration多尺度采样间距，毫米。

cfg.coreg.smoothingFwhmMm = [7 7];               % [可调] 参考图与源图的配准前平滑，毫米。

cfg.coreg.tolerance = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];         % [可调] SPM Coregistration十二个刚体/仿射优化容差。







%% SPM Normalise ：标准空间网格
% 标准化路线选择；DARTEL/Shooting 仍先调用 SPM Segment，程序自动追加 GM/WM Imported 输出。
cfg.normalise.method = 'segmentation';         % [可调]segmentation=现有SPM Segment/CAT场+Write（默认）；dartel=独立SPM DARTEL；shooting=独立SPM Geodesic Shooting。 后两者须cfg.segment.backend='spm'，stopAfter='smooth' 才执行。


% 标准化-A：DARTEL/Shooting共用的群体与写出选项
cfg.normalise.group.mode = 'create';                    % [可调] create=用本批唯一结构单位建立群体模板（默认）；existing=配准到已有匹配模板，不重建模板。

cfg.normalise.group.templates = {};                     % [可选] create时留空；existing时填绝对 .nii 路径cell，按粗到细排序：DARTEL为Template_1到6共6项；Shooting至少1项（通常Template_0到4）；模板须匹配Imported网格，不直接填T1或普通MNI脑图。

cfg.normalise.group.anatomyUnit = 'subject';            % [可调] subject=每被试一套T1（默认），该被试所有run须一致；subject_session=纵向每session可用不同T1。相同被试的相同T1副本会去重，不按run次数加权模板。

cfg.normalise.group.writeMethod = 'native';             % [可调] native=调用SPM DARTEL/Shoot原生MNI写出，固定三线性插值、等方性平滑；deformations=SPM合成最终场后Normalise Write，使用下方interpolation=0..7和任意三轴平滑核。两者采样/平滑实现不同，勿混为同一结果。

cfg.normalise.group.preserve = 0;                       % [可调] native写出：0=Preserve Concentrations，默认；1=Preserve Amount/Total，Jacobian组织量调制（主要用于VBM，BOLD通常不选）。deformations只允许0。1时文件为mw*/smw*，不是w*/sw*。


% 标准化-B：DARTEL 原生 Run Dartel 的六轮参数（只在 method='dartel' 生效）
cfg.normalise.dartel.regularisationForm = 0;                  % [可调] 0=Linear Elastic Energy线弹性（SPM默认）；1=Membrane Energy膜能量；2=Bending Energy弯曲能量；改变类型需同时理解regularisation三列含义。

cfg.normalise.dartel.innerIterations = [3 3 3 3 3 3];         % [可调] 六轮各自的Gauss-Newton内部迭代次数，每项1-10；默认每轮3次。

cfg.normalise.dartel.regularisation = [4 2 1e-6;2 1 1e-6;1 0.5 1e-6;0.5 0.25 1e-6;0.25 0.125 1e-6;0.25 0.125 1e-6];          % [可调] 六轮×三列正则化系数，有限非负；按所选能量解释，默认由强到弱，保持SPM默认作为起点。

cfg.normalise.dartel.timeSteps = [0 0 1 2 4 6];               % [可调] 六轮积分时间步的指数K，每项0-9；实际2^K步，默认最后64步；最终flow→形变也使用最后一项。

cfg.normalise.dartel.templateSmoothing = [16 8 4 2 1 0.5];    % [可调] create六轮模板LogOdds平滑参数slam；每项0/0.5/1/2/4/8/16/32，非BOLD毫米FWHM；existing不使用它。

cfg.normalise.dartel.lmRegularisation = 0.01;                 % [可调] Levenberg-Marquardt优化正则化，有限非负；默认0.01；0切为Gauss-Newton，SPM不推荐常规这样做。

cfg.normalise.dartel.solverCycles = 3;                        % [可调] Full Multi-grid求解循环数1-8，默认3；增加会更慢。

cfg.normalise.dartel.solverIterations = 3;                    % [可调] 每个求解循环的松弛迭代次数1-8，默认3；不是模板六轮内部迭代次数。


% 标准化-C：独立 Shooting 官方 defaults 的本次参数（只在 method='shooting' 生效）
% SPM Shoot高级参数本来放在 spm_shoot_defaults.m，不是GUI batch菜单；本工具包用本次输出目录中的私有defaults适配，调用结束/失败后恢复，不修改SPM安装。
cfg.normalise.shooting.iterations = 24;                  % [可调] Gauss-Newton配准迭代总数，整数2-1000；SPM默认24；小值仅供工程调试，不代表科研质量已足够。

cfg.normalise.shooting.regularisation = [1e-4 0.001 0.2 0.05 0.2];           % [可调] 官方rparam五项速度场正则化，有限非负；默认如左，不是Segment的warpRegularisation。

cfg.normalise.shooting.templateRegularisation = [0.0001 0.08 0.8];           % [可调] 官方sparam三项模板平滑正则化，有限非负；仅create生效，不是最终BOLD平滑核。

cfg.normalise.shooting.smoothingIterations = 16;                             % [可调] create模板平滑迭代次数，整数0-1000，默认16；existing不使用。

cfg.normalise.shooting.solverCyclesIterations = [2 2];                       % [可调] 官方cyc_its，求解循环/内部迭代两个正整数1-100；默认[2 2]。

cfg.normalise.shooting.stepScale = 0.8;                                      % [可调] Gauss-Newton更新步长比例，0<值<=1；官方默认0.8。

cfg.normalise.shooting.maxTimeSteps = 8;                                     % [可调] 最大积分步数，整数1-64，默认8；每轮eul_its按SPM原公式从较少步数递增，非DARTEL的2^K。

cfg.normalise.shooting.coarseScale = 32;                                     % [可调] 官方粗到细schedule起始尺度，有限值>=1，默认32；与scheduleDecay/iterations共同生成sched，不是体素大小。

cfg.normalise.shooting.scheduleDecay = 0.5;                                  % [可调] 官方指数schedule衰减率，有限正数，默认0.5；最后归一化到1。

cfg.normalise.shooting.symmetricTemplate = false;                            % [可调] create时false=普通群体模板（默认）；true=官方左右对称模板；existing不改变已有模板。


% 原有网格设置，interpolation仅用于segmentation及deformations写出；native固定为1。native须三轴相同平滑核。

cfg.normalise.interpolation = 4;                                               % [可调] SPM Normalise: Write重采样插值阶数 0~7。

cfg.voxelSizeMm = [2 2 2];                                                     % [可调] 标准化输出体素x/y/z大小，毫米。

cfg.boundingBoxMm = [-78 -112 -70;78 76 85];                                   % [可调]经典默认值，MNI空间中需要输出的三维范围，毫米。






%% SPM Smooth：
cfg.smoothingFwhmMm = [6 6 6];                             % [可调] 平滑核 FWHM，毫米；同时保留未平滑图。
% 三轴FWHM直接选平滑方式：[6 6 6]=各向同性；[6 6 4]=各向异性；[0 0 0]=不增加此核。
% native仅支持三项相同；需要各向异性或下方dtype/im菜单时，明确选 cfg.normalise.group.writeMethod='deformations'。

cfg.smooth.dataType = 'same';                              % [可调] 普通SPM Smooth：same=0（默认，沿用输入类型）；uint8=2；int16=4；int32=8；float32=16；float64=64。连续BOLD可按需要选float32，整数会量化。DARTEL/Shoot native仅允许same=沿用原生规则，Preserve=1仍写FLOAT32。

cfg.smooth.implicitMasking = false;                        % [可调] 普通Smooth：false=No（默认）；true=Yes，平滑后恢复输入的隐式无效位置（整数0/浮点NaN）；不是ROI内卷积，也不阻止跨组织混合。native仅允许false，按原生权重处理。

cfg.smooth.prefix = 's';                                   % [可调] 非空安全前缀，字母开头，后续字母/数字/下划线；默认s，warfunc→swarfunc，可改sm6_等。native在本次写出后重命名并记录，不另加平滑；调制时前缀加在mw*之前。





%% 质量检查：FD、时序指标、SPM 重采样后非有限体素
cfg.fdRadiusMm = 50;                                               % [可调] FD 旋转换算头半径，毫米。

cfg.fdFlagMm = 0.5;                                                % [可调] FD 标记阈值，毫米；不会自动删帧。

cfg.qc.enabled = true;                                             % [可调] 在 realign 后检查全时序并绘图。

cfg.qc.maskFraction = 0.2;                                         % [可调] 信号掩膜阈值比例，0~1；不是解剖脑掩膜。

cfg.qc.maxResliceNonfiniteFraction = 0.1;                          % [可调] SPM 共同视野外 NaN 的单帧最大比例；超过则停止并人工检查。



%% 输入状态：普通原始数据保持 raw，已畸变校正影像须有来源记录
cfg.inputStage = 'raw';                                            % [可调] raw=原始；sdc_corrected=仅已完成畸变校正、继续头动/空间处理；preprocessed=仅核查。

end
