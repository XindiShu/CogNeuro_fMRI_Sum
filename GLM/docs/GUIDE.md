# GLM使用流程：从输入到结果导出

按本页完成数据准备、模型估计、统计图和beta/ROI导出。方法选择及必改参数见 [Methods_Summary](Methods_Summary.md)，`glm_config.m`各字段含义见 [逐行说明](Line_by_Line_Explanation.md)

## 1. 两个入口

| 任务                    | 总参数                                                    | 启动入口                                                    |
| --------------------- | ------------------------------------------------------ | ------------------------------------------------------- |
| 指定和估计GLM              | [glm_config.m](../config/glm_config.m)                 | [run_glm.m](../run_glm.m)；自定义cfg时调用`psy.glm_batch(cfg)` |
| 读取已有模型，导出统计图、beta和ROI | [glm_outputs_config.m](../config/glm_outputs_config.m) | [run_glm_outputs.m](../run_glm_outputs.m)               |

运行前把包根目录、`config`、`matlab`和SPM加入MATLAB路径。输出使用包外的新目录；修改数据或模型后另开目录，已有成功结果保留。



## 2. 准备自己的输入

复制模板到个人项目目录，再填写真实文件。表内相对路径以该表所在目录为基准。

| 输入    | 模板与要求                                                                                                                                                                                           |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| run清单 | [glm_runs_template.tsv](../config/glm_runs_template.tsv)：`subject/session/run/bold/events/confounds/temporal_state`，可加`mask`；每行一个run，session可空                                                  |
| 事件表   | [glm_events_template.tsv](../config/glm_events_template.tsv)：`onset/duration/trial_type`；其他估计单元所需ID见方法指南                                                                                        |
| 混杂表   | 与BOLD帧数、帧序一致，包含`cfg.design`实际选择的头动、组织信号等列                                                                                                                                                       |
| 二级清单  | 按设计选[单样本](../config/glm_group_template.tsv)、[配对](../config/glm_group_paired_template.tsv)、[两组](../config/glm_group_two_sample_template.tsv)或[回归](../config/glm_group_regression_template.tsv)模板 |

事件时间用秒，零点对应当前BOLD第一帧；TR及时间单位须正确。BOLD应已完成相应空间处理，时间状态须实际符合`unfiltered_unregressed`：本模型需要的滤波和混杂回归在拟合时联合处理。掩膜还需核对网格、覆盖与来源。



## 3. 估计模型

下面以两个条件的run模型为例。路径和条件名均须替换；其他模型按Methods_Summary成套设置。

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必查] 包和SPM位置
cfg=glm_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必改若不同] SPM安装目录
cfg.manifestFile='E:\study\runs.tsv'; % [必改] 已填好的run清单
cfg.outputRoot='E:\study\glm_prepare'; % [必改] 包外的新目录
cfg.conditions={'A','B'}; % [必改] 完整条件集合，顺序固定
cfg.contrastNames={'A_minus_B'}; % [必改] 与权重的行对应
cfg.contrastWeights=[1 -1]; % [必改] 列依次对应A、B
cfg.model.unit='condition'; % [方法选择] 条件共同响应
cfg.fit.strategy='joint'; % [约束] condition仅支持joint
cfg.level='run'; % [方法选择] 每个run独立
cfg.design.includeTissueMeans=false; % [示例] 本例不使用组织均值；启用前核实其来源
cfg.execute=false; % [步骤] 先准备和检查
report=psy.glm_batch(cfg);
disp(report); % 查看逐项状态，再决定是否进入估计

% 查看准备结果，修正输入和设置后，再实际估计。
cfg.outputRoot='E:\study\glm_fit'; % [必改] 估计另用新目录
cfg.execute=true; % [步骤] 实际指定、估计并生成对比
report=psy.glm_batch(cfg);
```

也可直接编辑`glm_config.m`后运行`run_glm`。该脚本每次重读配置文件；若使用上面的内存cfg，继续调用`psy.glm_batch(cfg)`。

同一人跨run的SPM模型用`level='subject'`，当前限condition+joint，可带pmod或FIR；各run独立建任务、混杂、截距和高通，匹配的run效应等权平均。二级改用相应效应图清单及`level='group'`，配对按人提供两个水平；输入有符号效应图，通常为con。详见[跨run](Cross_run_group_GLM.md)和[二级设计](Group_and_Convariates.md)。

GLMsingle仍通过同一入口选择；本接口要求subject层级、event/trial单元、joint、共同正时长、合格的时间格点与显式覆盖掩膜。默认去噪/ridge还需各留出run具有训练集中出现的重复身份，具体设置见[GLMsingle](GLMsingle_ABCD.md)。

### 怎样确认完成、怎样理解图像

先检查`batch_status.tsv`及失败信息，再看对应模型目录：

| 路线            | 估计完成标记                       |
| ------------- | ---------------------------- |
| SPM run框架     | `GLM_FRAMEWORK_COMPLETE.mat` |
| SPM subject联合 | `GLM_SUBJECT_COMPLETE.mat`   |
| SPM二级         | `GLM_GROUP_COMPLETE.mat`     |
| GLMsingle     | `GLMSINGLE_COMPLETE.mat`     |

`PREPARED`仅表示准备，不表示已估计。完成后仍需检查实际设计、列映射、mask和模型诊断；框架中的`model_outputs.tsv`、`unit_mapping.tsv`、`event_mapping.tsv`用于定位目标，不能按beta文件序号猜事件。

SPM的`beta_*.nii`是设计列系数，混杂和截距也有beta；`con_*.nii`是线性效应，`spmT/spmF`是检验量。F没有一个对应的有符号幅度。GLMsingle B/C/D的`event_betas.nii`第四轴是事件索引，由`beta_mapping.tsv`对应；A为总体on/off模型。



## 4. 导出统计图与ROI

先填写[结果清单](../config/glm_results_template.tsv)：`id/spm_mat/contrast_index`，明确读取哪个已完成模型的哪项T/F对比。

```matlab
cfg=glm_outputs_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必改若不同] SPM位置
cfg.mode='results'; % [选择] 导出统计图
cfg.results.manifestFile='E:\study\results.tsv'; % [必改] 已完成模型与对比清单
cfg.results.correction='fdr'; % [可调] none/fwe/fdr
cfg.results.tail='two_sided'; % [可调] 此例为T双侧；F须用positive
cfg.results.roiManifestFile=''; % [可调] 提取ROI时改为已填写的ROI清单路径
cfg.outputRoot='E:\study\results_export'; % [必改] 包外新目录
report=run_glm_outputs(cfg);
```

| 参数或选择              | 怎样使用                                                            |
| ------------------ | --------------------------------------------------------------- |
| `correction`       | 默认fwe；none为未校正p，fdr为BH体素FDR，fwe使用源SPM模型的RESEL和高度阈值；缺有效RESEL时报错  |
| `alpha`、`tail`     | 默认0.05和positive；alpha在(0,0.5)内；T可正/负/双侧，F仅positive上尾            |
| 检验族                | 每个对比的完整模型mask；合法零统计值参与。双侧BH调整双侧p，双侧FWE每侧alpha/2；不跨对比、模型或ROI自动校正 |
| `minClusterVoxels` | 默认0，只过滤显示簇的大小；当前不做簇水平推断或拓扑峰FDR                                  |
| `roiManifestFile`  | 非空时，从T对比的未阈值化con提取ROI效应；F不提供有符号ROI效应                            |

[ROI模板](../config/glm_roi_template.tsv)包含`roi/mask_file/label`。label=0取所有正值体素，正整数选分区标签；ROI须与结果同网格。计算ROI与有效覆盖交集的均值、空间标准差和体素数；空间标准差不是被试间标准误。体素不足默认写NaN及状态，也可用`cfg.roi.emptyPolicy='error'`，最少体素数由`cfg.roi.minVoxels`指定。

输出位于`results/<id>/`：

| 文件                                                                  | 用途                                                 |
| ------------------------------------------------------------------- | -------------------------------------------------- |
| `p_uncorrected.nii`、`q_voxel_fdr.nii`                               | 完整模型mask内的p/q，域外NaN；q是体素FDR                        |
| `display_mask.nii`、`cluster_labels.nii`、`thresholded_statistic.nii` | 通过阈值及显示簇过滤的范围、簇编号和统计图；未显示的mask内统计值为0，域外NaN         |
| `clusters.tsv`、可选`voxels.tsv`                                       | 每簇一个峰及其体素p/q/FWE、大小、坐标；可选表列出全部显示体素，并非SPM GUI全部局部峰表 |
| `orthogonal_overlay.png`、`roi_effects.tsv`                          | 请求时生成切面图或未阈值化ROI效应                                 |
| `summary.json`                                                      | 实际方向、自由度、搜索域、阈值与显示数量                               |

空结果仍保留说明和表头。PNG沿I/J/K格点显示，物理位置以源affine和表中世界坐标为准；背景图仅按affine采样，需保证同一物理空间。绘图、6/18/26邻接、体素表等完整选项见后处理配置的中文注释。



## 5. 导出逐单元beta

填写[beta来源清单](../config/glm_beta_sources_template.tsv)：`id/engine/source_dir/variant`。source_dir指向完成根目录。

| engine       | variant | 来源                                   |
| ------------ | ------- | ------------------------------------ |
| framework    | auto    | 统一框架的逐单元run结果；通过目标映射读取SPM canonical列 |
| single_trial | LSA或LSS | 早期入口已经完成的结果                          |
| glmsingle    | B、C或D   | 被试combined结果；A不用于逐事件目录               |

```matlab
cfg=glm_outputs_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必改若不同] SPM位置
cfg.mode='betas'; % [选择] 只读取逐单元beta
cfg.betas.manifestFile='E:\study\beta_sources.tsv'; % [必改] 来源清单
cfg.betas.roiManifestFile=''; % [可调] 提取ROI beta时填写ROI清单
cfg.outputRoot='E:\study\beta_export'; % [必改] 包外新目录
report=run_glm_outputs(cfg);
data=load(fullfile(cfg.outputRoot,'betas','beta_matrix.mat'));
```

`cfg.mode='both'`可同时请求统计图和beta，此时两份清单都要填写。结果和beta各有自己的ROI清单。

`betas/`中，`beta_catalog.tsv`每行一个估计，保存来源、方法、单元、单位、图像及帧号；`event_links.tsv`连接原事件，一个item可对应多行事件。`beta_matrix.mat`为single矩阵，行按catalog，列为所有所选估计的共同掩膜体素，附IJK、世界坐标和affine；`roi_betas.tsv`在请求时生成。

条件平均/FIR条件结果走上一节统计接口。SPM保留源模型尺度，GLMsingle保留百分BOLD或输入单位；统一目录不统一数值尺度，也不自动平均、配准或归一化。不同网格报错，共同掩膜内合法零值保留，NaN/Inf报错。

默认`writeMatrix=true`、`maxMatrixGiB=1`；预算只限制single矩阵大小，不保证峰值内存。只生成目录时设`writeMatrix=false`且不请求ROI。需要较大覆盖时，可按被试/方法先选择catalog行，再读这些来源的交集：

```matlab
catalog=psy.glm_read_table('E:\study\beta_export\betas\beta_catalog.tsv');
catalog.volume_index=str2double(catalog.volume_index); % [必做] TSV读入后转为数值
selected=catalog.subject=="p01"; % [必改] 选择所需来源，不按结果好坏筛选
[betaMatrix,space]=psy.glm_beta_read(catalog(selected,:),1); % [可调] 矩阵预算GiB
```

后处理全部请求成功后写`GLM_OUTPUTS_COMPLETE.mat`。统一beta接口提供后续分析输入，RSA/MVPA算法需另行安排。

##
