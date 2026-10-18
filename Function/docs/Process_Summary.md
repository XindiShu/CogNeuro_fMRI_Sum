# **总流程**





## 一、四类文件

| 文件              | 解释                           | 例子                                                 |
| --------------- | ---------------------------- | -------------------------------------------------- |
| 配置函数config/*.m  | 提供默认值和候选说明，一般不不需要手动更正and直接运行 | function_config.m、state_config.m                   |
| 启动脚本【要自己复制修改】   | 改参位置；设置cfg，调用入口，保存分析方案       | 从examples/start_states.m另存为E:/study/start_states.m |
| 输入TSV/MAT/NIfTI | 真正数据和身份                      | prepared_runs.tsv、input.mat、bold.nii               |
| run_*.m         | 实际执行入口                       | report=run_states(cfg)                             |

例`cfg=state_config`只是得到结构体，不会分析。`run_states(cfg)`才进入该方法。MATLAB里的cfg与文件里的默认配置也不是同一个永久对象；重新运行cfg=...会重新读取默认值，所以将覆盖赋值保存在自己的启动脚本里。



## 二、第一步：打开MATLAB并加载包

```matlab
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
which run_states -all
```

which应首先指向D:/Function下的程序。如果有旧工作区版本排在前面，先处理路径优先级。无需把全部第三方工具包的所有子目录递归加入路径。



## 三、第二步：选择输入路线

表中写有各分析方法的具体运行入口、是否需要TSV清单等。所有配置路径相对D:/Function/config；入口在D:/Function根目录。

| 想做什么                  | 运行入口                        | 配置函数                                 | 是否需要TSV                          | 需要准备的对象                            |
| --------------------- | --------------------------- | ------------------------------------ | -------------------------------- | ---------------------------------- |
| 准备ROI/体素MAT           | run_prepare_inputs          | prepare_inputs_config                | analysis_runs_template.tsv       | 输出prepared_runs.tsv和每run input.mat |
| 静态FC/ALFF/ReHo/基础图    | run_function                | function_config                      | analysis_runs_template.tsv       | 4D NIfTI+mask+ROI                  |
| 任务背景FC                | run_background_fc           | background_config                    | 不需要                              | SPM.mat+mask+ROI                   |
| Beta-series/ROI解码/RSA | run_roi_patterns            | roi_patterns_config + pattern_config | 需要beta目录，示例见方法章                  | 已有beta+mask+ROI                    |
| 单run PPI/gPPI         | run_ppi                     | ppi_config                           | 不需要                              | 已估计SPM+种子mask                      |
| 多run PPI/gPPI         | run_ppi_batch(cfg,manifest) | ppi_config                           | ppi_runs_template.tsv            | 每行一个模型session                      |
| 个体task/spectral DCM   | run_dcm                     | dcm_config                           | dcm_runs_template.tsv            | ROI MAT+TE/延迟/任务输入                 |
| PEB/BMR/BMA           | run_dcm_group               | dcm_group_config                     | dcm_group_template.tsv           | 每人已估计DCM                           |
| ICA/双回归/FNC           | run_ica                     | ica_config                           | ica_runs_template.tsv            | 共同特征体素MAT                          |
| Searchlight           | run_searchlight             | searchlight_config + pattern_config  | 需要beta目录                         | beta和可选中心mask                      |
| 梯度/空间关联               | run_gradients               | gradient_config                      | gradient_inputs_template.tsv     | 连接指纹MAT/可选spatial MAT              |
| 嵌套CPM/ridge           | run_prediction              | prediction_config                    | 不需要                              | 一人一行脑/行为矩阵MAT                      |
| 滑窗FC                  | run_dynamic_fc              | dynamic_fc_config                    | dynamic_runs_template.tsv        | ROI时序MAT                           |
| HMM/CAP/LEiDA         | run_states                  | state_config                         | state_runs_template.tsv          | ROI时序MAT                           |
| PCM                   | run_pcm                     | pcm_config                           | pcm_subjects_template.tsv        | 一人一个模式/噪声MAT                       |
| Ridge/Banded编码        | run_encoding                | encoding_config                      | 不需要                              | 特征空间/脑目标/时钟MAT                     |
| RW/DDM                | run_behavior                | behavior_config                      | behavior_runs_template.tsv       | 另有每run试次TSV                        |
| ISC/ISFC/SRM/事件       | run_naturalistic            | naturalistic_config                  | 不需要                              | 多人共同刺激时序cell MAT                   |
| PLS/CCA/中介            | run_multivariate            | multivariate_config                  | 不需要                              | 样本对齐的X/Y及可选M                       |
| 熵/时间尺度/同源相关           | run_rest_extended           | rest_extended_config                 | rest_extended_runs_template.tsv  | 连续时序/可选显式配对MAT                     |
| 社区/零网络/NBS            | run_network                 | network_config                       | network_runs_template.tsv        | 每run图MAT+可选NBS单位MAT                |
| 冻结域泛化                 | run_transfer                | transfer_config                      | 不需要                              | train/test两个结构MAT                  |
| ICC/分半                | run_reliability             | reliability_config                   | 不需要                              | 单位×测量/item×特征MAT                   |
| OAS连接                 | run_regularized_fc          | regularized_fc_config                | regularized_fc_runs_template.tsv | 时序MAT                              |
| SVM/logistic          | run_linear_decode           | linear_decode_config                 | 不需要                              | 二分类模式与CV组MAT                       |
| RSA天花板/被试bootstrap    | run_rsa_ceiling             | rsa_ceiling_config                   | 不需要                              | 多条件多被试RDM MAT                      |





## 四、第三步A：若有NIfTI，怎样准备analysis_runs_template.tsv

复制D:/Function/config/analysis_runs_template.tsv到自己的tables目录。每行一个真实subject/session/run，不是每体素一行。session可空，其他身份字段不空且组合唯一。

| 列                   | 你应填什么                 | 单位/注意                       |
| ------------------- | --------------------- | --------------------------- |
| subject/session/run | 真实身份                  | 如p01/ses1/rest1；保留依赖，不合并充N  |
| bold                | 已预处理、未压缩4D .nii       | 不是原始DICOM；.nii.gz先解压到新的工作副本 |
| mask                | 固定有效mask .nii         | 3D，与BOLD同网格；不得按本次好结果挑mask   |
| roi_file            | 非负整数标签图 .nii          | 0背景，正整数区域；也须同网格             |
| tr_seconds          | 真实TR                  | 秒，如0.72，不填720               |
| temporal_state      | 输入已经做过什么              | 见下表，不能靠改声明掩盖实际处理            |
| smoothing_fwhm_mm   | 输入已经平滑多少              | 毫米；ReHo需要如实为0               |
| confounds           | 选择好的纯数值TSV或空          | 与完整BOLD同帧数；不能有字符串/首行NaN     |
| purpose             | rest/task/engineering | 来源说明，不改变算法假设                |

| temporal_state                | 含义           | confounds还能填吗？        |
| ----------------------------- | ------------ | --------------------- |
| unfiltered_unregressed        | 尚未作时间混杂回归/滤波 | 可以，必须明确选列             |
| nuisance_regressed_unfiltered | 已去混杂，未作该频段滤波 | 留空，防重复回归              |
| nuisance_regressed_highpassed | 已去混杂并高通      | 留空，后续说明上游高通           |
| denoised_bandpassed           | 已经去噪和带通      | 留空；不能再用作本入口fALFF的全谱输入 |

推荐用MATLAB写表，避免Excel把001改成1或TAB混成空格：

```matlab
subject=["p01";"p02"]; session=["s1";"s1"]; runID=["rest1";"rest1"];
bold=["E:/study/inputs/p01_bold.nii";"E:/study/inputs/p02_bold.nii"];
mask=["E:/study/inputs/p01_mask.nii";"E:/study/inputs/p02_mask.nii"];
roi=["E:/study/inputs/p01_roi.nii";"E:/study/inputs/p02_roi.nii"];
t=table(subject,session,runID,bold,mask,roi,[.72;.72], ...
 ["nuisance_regressed_highpassed";"nuisance_regressed_highpassed"], ...
 [0;0],["";""],["rest";"rest"], ...
 'VariableNames',{'subject','session','run','bold','mask','roi_file', ...
 'tr_seconds','temporal_state','smoothing_fwhm_mm','confounds','purpose'});
writetable(t,'E:/study/tables/analysis_runs.tsv','FileType','text','Delimiter','\t');
```

上面的路径必须真的存在，状态必须换成自己的真实记录。writetable的Delimiter使用反斜线t表示Tab，不用逗号CSV替代。



## 五、第三步B：准备ROI/体素MAT，再跑某个方法

新增通用入口run_prepare_inputs，用同一张11列表：

```matlab
cfg=prepare_inputs_config;
cfg.manifestFile='E:/study/tables/analysis_runs.tsv';
cfg.outputRoot='E:/study/prepared_roi'; % 新目录
cfg.mode='roi';
cfg.clean.bandHz=[]; % 本次不新增带通；上游状态仍保留
cfg.execute=false;
report=run_prepare_inputs(cfg); disp(report);
% 确认后把上一行开关改true，再运行此脚本
```

- roi模式在固定mask内清理时序，再按整数ROI求均值；输出每run input.mat，包含data.y/trSeconds/featureIds/roiNames/frameIndices/处理来源，并生成prepared_runs.tsv。已删除帧的采集数据不能用该1:T生成方式伪装连续，需要保留原始frameIndices另行整理。

- ICA想做体素分解，将mode改voxels、换prepared_voxels新目录；requireCommonFeatures=true时须所有run同网格同特征身份，不自动取交集或重采样。一次准备好的MAT可以供多个方法读取，不需要每种方法重复读整套BOLD。



## 六、第四步：复制启动脚本、按理论改参数

例：HMM启动模板为examples/start_states.m。打开后**另存**到自己的scripts目录，将manifestFile改为刚生成的prepared_runs.tsv，outputRoot改为新的results子目录，method选cap/leida/hmm，nStates填预定K。

**第一次保持execute=false**。在MATLAB运行：

```matlab
run('E:/study/start_states.m');
```

预检无错误后，**将自己脚本中的false改true**，再运行同一行。HMM另填pythonExecutable；CAP不需要为了凑配置去安装Python。

不要把完整cfg结构体只留在命令窗口；启动脚本就是你的可复现方案。方法章参数表会列默认配置文件**具体行号、候选范围、理论作用**，例如nStates改变状态容量，hmmCovariance改变是否建ROI间协方差，不只是说“可调”。



## 七、另一条路线：已有beta怎样接入

先有估计单元beta，建立目录，而不是把GLM设计表直接当beta目录：

```tsv
estimate_id	source_id	subject	session	run	condition	image_path	volume_index	mask_path	estimate_unit
p01_r1_t1	lsa	p01	s1	r1	A	E:/study/inputs/beta_0001.nii	1	E:/study/inputs/mask.nii	event
```

每个估计单元一行。至少两个适当独立partition才做CV。选择ROI模式用start_beta.m；Searchlight用start_searchlight.m。sourceId明确一种来源，不将同trial的LSA/LSS重复当两条样本。



## 八、不用TSV的方法，MAT究竟从哪里来

MAT只是把已对齐变量打包。先读自己的表/结果，建立规定字段，再save，不是把扩展名从csv改成mat。

| 方法        | 矩阵行      | MAT结构                                              | 准备来源                |
| --------- | -------- | -------------------------------------------------- | ------------------- |
| CPM/ridge | 独立被试     | data.x/target/subjectIds/groupIds/featureIds       | 每人FC边 + 同身份行为表      |
| 编码        | 估计单元或采集帧 | data.featureSpaces/y/runIds/frameIndices/cvGroups等 | 刺激特征与脑反应先按真实时钟/单元连接 |
| PLS/CCA   | 共同样本     | data.X/Y及行/列身份                                     | 脑特征和行为多指标按样本ID连接    |
| 中介        | 共同独立单位   | 上行另加data.M                                         | 同一单位的X/M/Y/协变量      |
| 自然刺激      | 共同刺激时刻   | data.series及人/特征/时钟/刺激身份                           | 多人确实共享刺激并已对齐的曲线     |
| Transfer  | 训练/目标样本  | train和test两个结构                                     | 相同特征空间、明确不同域/单位     |
| ICC/分半    | 独立人      | data.y，人×测量或匹配item×特征                              | 完整平衡可比测量，不能任意补缺失    |
| RSA天花板    | 每人的条件几何  | data.rdms，条件×条件×人                                  | 先逐人计算相同条件顺序的RDM     |

一个保存动作的完整形式：

```matlab
S=load('E:/study/prepared_roi/p01/s1/rest1/input.mat','data');
data=S.data; % 这里不是未定义的魔法变量，而是准备器的真实输出
whos data
size(data.y) % 第一维时间，第二维ROI/体素
```

一个被试预测MAT的整理形式：

```matlab
% X、behavior、subjectIds、groupIds、edgeNames需先从自己的匹配结果取得
assert(size(X,1)==numel(behavior));
assert(numel(subjectIds)==size(X,1));
data=struct('x',X,'target',behavior(:),'subjectIds',subjectIds(:), ...
 'groupIds',groupIds(:),'featureIds',edgeNames(:));
save('E:/study/inputs/prediction_data.mat','data');
```

上面不是生成真实数据的代码。先按ID合并表，再赋这些变量；仅断言行数相同不能证明身份正确。各方法章给出更完整的字段表。



## 九、如何选到具体方法章

| 方法                                 | 理论+参数+完整流程                                                                 |
| ---------------------------------- | -------------------------------------------------------------------------- |
| 功能连接：Pearson、秩相关、偏相关、种子与任务背景       | [FUNCTION_FC.md](FUNCTION_FC.md)                                           |
| 自发活动：ALFF、fALFF 与 ReHo             | [FUNCTION_ALFF_REHO.md](FUNCTION_ALFF_REHO.md)                             |
| Beta-series、ROI 解码与 RSA：从估计单元到模式   | [FUNCTION_BETA_MVPA_RSA.md](FUNCTION_BETA_MVPA_RSA.md)                     |
| PPI / gPPI：任务条件怎样调制种子关系            | [FUNCTION_PPI.md](FUNCTION_PPI.md)                                         |
| 基础网络指标、网络摘要与被试一样本统计                | [FUNCTION_BASIC_GRAPH_STATS.md](FUNCTION_BASIC_GRAPH_STATS.md)             |
| DCM、spectral DCM 与 PEB：从网络假设到参数    | [FUNCTION_DCM_AND_PEB.md](FUNCTION_DCM_AND_PEB.md)                         |
| 空间组 ICA、双回归与 FNC                   | [FUNCTION_ICA_DUAL_FNC.md](FUNCTION_ICA_DUAL_FNC.md)                       |
| 体积 Searchlight：把解码或 RSA 移动到每个局部球   | [FUNCTION_SEARCHLIGHT.md](FUNCTION_SEARCHLIGHT.md)                         |
| 连接梯度、跨人对齐与空间零模型                    | [FUNCTION_GRADIENTS_SPATIAL_NULLS.md](FUNCTION_GRADIENTS_SPATIAL_NULLS.md) |
| 被试层面的 CPM / Ridge：内折选择、外折检验        | [FUNCTION_NESTED_PREDICTION.md](FUNCTION_NESTED_PREDICTION.md)             |
| 滑窗动态连接与平稳相位零模型                     | [FUNCTION_DYNAMIC_FC.md](FUNCTION_DYNAMIC_FC.md)                           |
| HMM、CAP 与 LEiDA：状态是什么、怎样统计变化       | [FUNCTION_HMM_CAP_LEIDA.md](FUNCTION_HMM_CAP_LEIDA.md)                     |
| PCM：用第二矩描述表示结构                     | [FUNCTION_PCM.md](FUNCTION_PCM.md)                                         |
| Ridge / Banded Ridge 编码：从刺激特征预测脑反应 | [FUNCTION_ENCODING.md](FUNCTION_ENCODING.md)                               |
| RW 学习、Softmax、DDM 与潜变量事件导出         | [FUNCTION_BEHAVIOR_MODELS.md](FUNCTION_BEHAVIOR_MODELS.md)                 |
| 自然刺激：ISC、ISFC、SRM 与有序事件分段          | [FUNCTION_INTERSUBJECT_SRM_EVENTS.md](FUNCTION_INTERSUBJECT_SRM_EVENTS.md) |
| PLS、CCA 与线性中介：关联、预测和路径要分开          | [FUNCTION_PLS_CCA_MEDIATION.md](FUNCTION_PLS_CCA_MEDIATION.md)             |
| 同源配对连接、三种熵与 ACF 时间尺度               | [FUNCTION_EXTENDED_REST.md](FUNCTION_EXTENDED_REST.md)                     |
| 社区、密度敏感性、保度零网络与 NBS                | [FUNCTION_NETWORK_NBS.md](FUNCTION_NETWORK_NBS.md)                         |
| 冻结泛化、六种 ICC 与匹配项目分半                | [FUNCTION_TRANSFER_RELIABILITY.md](FUNCTION_TRANSFER_RELIABILITY.md)       |
| OAS 收缩连接、线性分类器与 RSA 噪声天花板          | [FUNCTION_REGULARIZED_FC_MVPA_RSA.md](FUNCTION_REGULARIZED_FC_MVPA_RSA.md) |

## 通用准备器本身的参数位置

| 字段                          | 位置                                  | 默认                                                            | 作用                                                                                      |
| --------------------------- | ----------------------------------- | ------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `cfg.manifestFile`          | config/prepare_inputs_config.m 第4行  | `fullfile(root,'config','analysis_runs.tsv')`                 | 复用analysis_runs_template.tsv的11列，路径与处理状态必须真实。；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`            | config/prepare_inputs_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_prepared')` | 新绝对目录，保留原始影像。；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                               |
| `cfg.execute`               | config/prepare_inputs_config.m 第6行  | `false`                                                       | false检查清单/文件/处理声明，true读影像并写MAT。；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。              |
| `cfg.mode`                  | config/prepare_inputs_config.m 第7行  | `'roi'`                                                       | roi=标签区域均值，供HMM/滑窗/熵等；voxels=掩膜内逐体素，供ICA等。                                              |
| `cfg.maxMatrixGiB`          | config/prepare_inputs_config.m 第8行  | `2`                                                           | 时间×体素double矩阵上限GiB，非总峰值保证。；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                         |
| `cfg.roiMinVoxels`          | config/prepare_inputs_config.m 第9行  | `3`                                                           | roi模式每区最少体素，正整数。；有效mask内每ROI最低体素数；太少拒绝，不会自动扩大ROI或补零。                                    |
| `cfg.requireCommonFeatures` | config/prepare_inputs_config.m 第10行 | `true`                                                        | true要求所有输出列身份相同；voxels同时要求同网格，不自动取交集/重采样。                                               |
| `cfg.clean`                 | config/prepare_inputs_config.m 第11行 | `base.clean`                                                  | detrend/bandHz/minResidualDimensions继承function_config；只执行本次明确设置的联合投影。                   |
