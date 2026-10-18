# D:\Function 文件说明



## 一、几类文件

| 文件或目录                 | 里面是什么                         | 平时怎样使用                                 |
| --------------------- | ----------------------------- | -------------------------------------- |
| 根目录，31 个文件            | 总入口、环境加载程序、依赖和验证记录            | 由自己的启动脚本调用 `run_*.m`；不用把所有入口依次运行       |
| `config/`，39 个文件      | 26 个默认配置函数、13 张输入清单模板         | 查看默认值；复制清单模板，填写自己的数据路径与身份              |
| `docs/`，25 个文件        | 总流程、方法说明、方法表和本文件              | 根据需要查阅；文件名以当前用户整理的版本为准                 |
| `examples/`，50 个文件    | 28 份启动模板、19 份验证程序、3 份数据准备辅助程序 | 日常使用先复制 `start_*.m`，在副本中改参数；验证程序用于开发检查 |
| `matlab/+cog/`，74 个文件 | 被入口调用的计算函数和读写工具               | 通常不需要逐个运行；MATLAB 中以 `cog.函数名(...)` 调用  |
| `scripts/`，5 个文件      | Python 后端、依赖版本表、发布脚本          | 使用对应后端或维护发布副本时才需要                      |
| `tests/`，25 个文件       | 自动测试及独立数值核对程序                 | 修改计算代码后检查；不是正式数据分析的启动入口                |

默认配置函数只返回一份 `cfg`，不会开始分析。通常的使用顺序是：**复制启动模板 → 修改副本中的路径和参数 → 由副本调用运行入口**。启动模板中的 `execute=false` 表示先预检，正式运行方式见 [Process_Summary.md](Process_Summary.md)。



## 二、根目录中的公共文件

下表列公共文件，其余 26 个 `run_*.m` 入口在第三节逐项对应。

| 文件                                          | 具体用途                                         |
| ------------------------------------------- | -------------------------------------------- |
| [setup_function.m](../setup_function.m)     | 把本包及指定的 SPM 路径加入 MATLAB 搜索路径；开始使用本包时调用       |
| [README.md](../README.md)                   | 包的简要介绍及入口导航；其中若保留旧文档名称，查阅时以当前 `docs/` 文件名为准  |
| [DEPENDENCIES.tsv](../DEPENDENCIES.tsv)     | 第三方软件的用途、来源、验证版本及是否随包提供；它不是数据输入清单            |
| [METHOD_STATUS.tsv](../METHOD_STATUS.tsv)   | 各方法的实现、自动测试和示例数据验证记录；用于区分已验证、未验证及受输入限制的部分    |
| [FILE_MANIFEST.json](../FILE_MANIFEST.json) | 发布文件的路径、大小和 SHA-256 哈希，用于检查文件是否缺失或改变；不包含分析数据 |



## 三、运行入口、默认配置与启动模板对照

同一方法的三个文件分工不同：**入口负责执行，配置函数提供默认值，启动模板保存本次要用的参数**。同一个入口或配置在多行出现，表示它可以处理多种方法，不是多份重复代码。

### 1. 数据准备、基础连接与局部活动

| 用途                              | 执行入口：根目录                                        | 默认配置：config/                                                 | 启动模板：examples/                                               |
| ------------------------------- | ----------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| 将 NIfTI 整理为 ROI 或体素时序 MAT，并生成清单 | [run_prepare_inputs.m](../run_prepare_inputs.m) | [prepare_inputs_config.m](../config/prepare_inputs_config.m) | [start_prepare_inputs.m](../examples/start_prepare_inputs.m) |
| 静态 ROI 连接、种子连接及相关网络摘要           | [run_function.m](../run_function.m)             | [function_config.m](../config/function_config.m)             | [start_fc.m](../examples/start_fc.m)                         |
| ALFF、fALFF、ReHo                 | 同上 `run_function.m`                             | 同上 `function_config.m`                                       | [start_spectrum.m](../examples/start_spectrum.m)             |
| 基础图论指标                          | 同上 `run_function.m`                             | 同上 `function_config.m`                                       | [start_graph.m](../examples/start_graph.m)                   |
| 从已估计 SPM 模型计算任务背景连接             | [run_background_fc.m](../run_background_fc.m)   | [background_config.m](../config/background_config.m)         | [start_background.m](../examples/start_background.m)         |
| 时序熵、自相关时间尺度、显式同源配对连接            | [run_rest_extended.m](../run_rest_extended.m)   | [rest_extended_config.m](../config/rest_extended_config.m)   | [start_extended.m](../examples/start_extended.m)             |
| OAS 收缩协方差、相关及偏相关                | [run_regularized_fc.m](../run_regularized_fc.m) | [regularized_fc_config.m](../config/regularized_fc_config.m) | [start_regularized.m](../examples/start_regularized.m)       |

### 2. 任务连接、DCM、分解与动态方法

| 用途                                   | 执行入口：根目录                                | 默认配置：config/                                         | 启动模板：examples/                                     |
| ------------------------------------ | --------------------------------------- | ---------------------------------------------------- | -------------------------------------------------- |
| 单个模型 session 的 PPI / gPPI            | [run_ppi.m](../run_ppi.m)               | [ppi_config.m](../config/ppi_config.m)               | [start_ppi.m](../examples/start_ppi.m)             |
| 按清单批量运行 PPI / gPPI                   | [run_ppi_batch.m](../run_ppi_batch.m)   | 同上 `ppi_config.m`                                    | [start_ppi_batch.m](../examples/start_ppi_batch.m) |
| 个体任务 DCM 或 spectral DCM，及同一数据的候选网络比较 | [run_dcm.m](../run_dcm.m)               | [dcm_config.m](../config/dcm_config.m)               | [start_dcm.m](../examples/start_dcm.m)             |
| 基于已估计个体 DCM 的 PEB / BMR / BMA        | [run_dcm_group.m](../run_dcm_group.m)   | [dcm_group_config.m](../config/dcm_group_config.m)   | [start_dcm_group.m](../examples/start_dcm_group.m) |
| 空间组 ICA、逐 run 双回归和 FNC               | [run_ica.m](../run_ica.m)               | [ica_config.m](../config/ica_config.m)               | [start_ica.m](../examples/start_ica.m)             |
| 连接梯度、梯度对齐及可选空间关联零模型                  | [run_gradients.m](../run_gradients.m)   | [gradient_config.m](../config/gradient_config.m)     | [start_gradient.m](../examples/start_gradient.m)   |
| 滑动窗口连接、窗长敏感性和相位随机化零模型                | [run_dynamic_fc.m](../run_dynamic_fc.m) | [dynamic_fc_config.m](../config/dynamic_fc_config.m) | [start_dynamic.m](../examples/start_dynamic.m)     |
| HMM、CAP、LEiDA 及状态变化统计                | [run_states.m](../run_states.m)         | [state_config.m](../config/state_config.m)           | [start_states.m](../examples/start_states.m)       |
| 社区、密度敏感性、保度零网络及可选 NBS                | [run_network.m](../run_network.m)       | [network_config.m](../config/network_config.m)       | [start_network.m](../examples/start_network.m)     |

### 3. 模式、表征、编码和统计建模

| 用途                                    | 执行入口：根目录                                      | 默认配置：config/                                               | 启动模板：examples/                                             |
| ------------------------------------- | --------------------------------------------- | ---------------------------------------------------------- | ---------------------------------------------------------- |
| 从已有 beta 目录运行 Beta-series、ROI 解码和 RSA | [run_roi_patterns.m](../run_roi_patterns.m)   | [roi_patterns_config.m](../config/roi_patterns_config.m)   | [start_beta.m](../examples/start_beta.m)                   |
| 在局部体素球内运行解码或 RSA                      | [run_searchlight.m](../run_searchlight.m)     | [searchlight_config.m](../config/searchlight_config.m)     | [start_searchlight.m](../examples/start_searchlight.m)     |
| 二分类线性 SVM / logistic，按明确分组交叉验证        | [run_linear_decode.m](../run_linear_decode.m) | [linear_decode_config.m](../config/linear_decode_config.m) | [start_linear_decode.m](../examples/start_linear_decode.m) |
| RSA 噪声天花板及被试 Bootstrap                | [run_rsa_ceiling.m](../run_rsa_ceiling.m)     | [rsa_ceiling_config.m](../config/rsa_ceiling_config.m)     | [start_rsa_ceiling.m](../examples/start_rsa_ceiling.m)     |
| 固定模型或多成分 PCM，及相应交叉验证                  | [run_pcm.m](../run_pcm.m)                     | [pcm_config.m](../config/pcm_config.m)                     | [start_pcm.m](../examples/start_pcm.m)                     |
| 被试层面的嵌套 CPM / Ridge 预测                | [run_prediction.m](../run_prediction.m)       | [prediction_config.m](../config/prediction_config.m)       | [start_prediction.m](../examples/start_prediction.m)       |
| Ridge / Banded Ridge 编码及连续时序滞后编码      | [run_encoding.m](../run_encoding.m)           | [encoding_config.m](../config/encoding_config.m)           | [start_encoding.m](../examples/start_encoding.m)           |
| RW–Softmax 或常数二选项 DDM                 | [run_behavior.m](../run_behavior.m)           | [behavior_config.m](../config/behavior_config.m)           | [start_behavior.m](../examples/start_behavior.m)           |
| ISC、ISFC、SRM、有序事件分段                   | [run_naturalistic.m](../run_naturalistic.m)   | [naturalistic_config.m](../config/naturalistic_config.m)   | [start_naturalistic.m](../examples/start_naturalistic.m)   |
| PLS、CCA、正则 CCA 或线性中介                  | [run_multivariate.m](../run_multivariate.m)   | [multivariate_config.m](../config/multivariate_config.m)   | [start_multivariate.m](../examples/start_multivariate.m)   |
| 在源域训练后冻结模型，再应用到目标域                    | [run_transfer.m](../run_transfer.m)           | [transfer_config.m](../config/transfer_config.m)           | [start_transfer.m](../examples/start_transfer.m)           |
| 平衡设计 ICC 或匹配项目分半信度                    | [run_reliability.m](../run_reliability.m)     | [reliability_config.m](../config/reliability_config.m)     | [start_reliability.m](../examples/start_reliability.m)     |

另有一份不单独启动分析的配置：

| 文件                                                    | 具体用途                                                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------- |
| [config/pattern_config.m](../config/pattern_config.m) | ROI 模式和 Searchlight 共用的基础选项：分类或 Ridge、RSA 距离、噪声协方差、理论 RDM、Beta-series 最少试次数等；由相应主配置读入 |

## 四、config/ 中的 13 张 TSV 模板

这些文件是**待填写的清单样板**，里面的示例路径不是可直接运行的真实数据。上节已经列出全部 26 个 `.m` 默认配置；本节补齐其余 13 个 `.tsv` 文件。

| 文件                                                                             | 用于什么                                            | 每行表示什么                                 |
| ------------------------------------------------------------------------------ | ----------------------------------------------- | -------------------------------------- |
| [analysis_runs_template.tsv](../config/analysis_runs_template.tsv)             | NIfTI 输入准备及基础时序分析；记录 BOLD、mask、ROI、TR、混杂和既有处理状态 | 一个 subject / session / run             |
| [behavior_runs_template.tsv](../config/behavior_runs_template.tsv)             | 指向各 run 的行为试次表；试次表本身另行准备                        | 一个行为 run                               |
| [dcm_runs_template.tsv](../config/dcm_runs_template.tsv)                       | 指向含区域时序、采集信息和可选任务输入的 DCM 数据 MAT                 | 一个 DCM 数据 run                          |
| [dcm_group_template.tsv](../config/dcm_group_template.tsv)                     | 群体 DCM：被试身份与已估计个体 DCM 路径                        | 一名独立被试                                 |
| [dynamic_runs_template.tsv](../config/dynamic_runs_template.tsv)               | 滑窗分析使用的 ROI 时序 MAT 清单                           | 一个时序 run                               |
| [gradient_inputs_template.tsv](../config/gradient_inputs_template.tsv)         | 指向连接指纹及节点、特征身份明确的 MAT                           | 一个梯度输入单元，保留 subject / session / run 身份 |
| [ica_runs_template.tsv](../config/ica_runs_template.tsv)                       | 指向共同特征空间中的体素时序 MAT                              | 一个 ICA 时序 run                          |
| [network_runs_template.tsv](../config/network_runs_template.tsv)               | 指向节点顺序明确的连接矩阵 MAT                               | 一个网络 run                               |
| [pcm_subjects_template.tsv](../config/pcm_subjects_template.tsv)               | 指向各被试的模式、条件、分区和噪声信息 MAT                         | 一名独立被试                                 |
| [ppi_runs_template.tsv](../config/ppi_runs_template.tsv)                       | 批量 PPI：已估计 SPM 模型、种子 mask 与模型内 session 编号       | 一个明确选中的模型 session                      |
| [regularized_fc_runs_template.tsv](../config/regularized_fc_runs_template.tsv) | OAS 使用的 ROI 时序 MAT 清单                           | 一个时序 run                               |
| [rest_extended_runs_template.tsv](../config/rest_extended_runs_template.tsv)   | 熵、时间尺度及可选同源配对分析的数据 MAT 清单                       | 一个时序 run                               |
| [state_runs_template.tsv](../config/state_runs_template.tsv)                   | HMM / CAP / LEiDA 使用的时序 MAT 清单                  | 一个时序 run                               |

没有在本目录提供专门模板的输入，例如 beta 目录或某方法使用的 MAT 结构，按对应方法文档准备。配置中出现某个默认文件名，不表示包内已经提供了那份数据。

## 五、docs/：按当前文件名查文档

这里记录的是你当前保留的名称，不将文档改回旧名。

| 文件                                                                   | 主要内容                                              |
| -------------------------------------------------------------------- | ------------------------------------------------- |
| [Process_Summary.md](Process_Summary.md)                             | 从打开 MATLAB、选择输入路线、准备清单到修改启动脚本和运行的总流程              |
| [Function_Overview.md](Function_Overview.md)                         | 各方法的入口、配置与主要启动模板对照                                |
| [Summary_Methods_Table.md](Summary_Methods_Table.md)                 | 仅列方法类别与方法名称的总表                                    |
| [File_Reference.md](File_Reference.md)                               | 本文件；逐项解释发布目录内各文件的用途                               |
| [FC.md](FC.md)                                                       | Pearson、Spearman、偏相关、种子连接及任务背景连接                  |
| [ALFF_REHO.md](ALFF_REHO.md)                                         | ALFF、fALFF、ReHo 的理论、输入和运行设置                       |
| [Basic_Graph_Stats.md](Basic_Graph_Stats.md)                         | 基础图论、网络摘要、被试层面一样本统计和 FDR                          |
| [Beta_MVPA_RSA.md](Beta_MVPA_RSA.md)                                 | 从 beta 估计单元进入 Beta-series、ROI 解码与 RSA             |
| [PPI_gPPI.md](PPI_gPPI.md)                                           | PPI / gPPI、单模型与批量运行                               |
| [DCM_and_PEB.md](DCM_and_PEB.md)                                     | 任务 DCM、spectral DCM、候选网络和群体 PEB / BMR / BMA       |
| [ICA_Dual_FNC.md](ICA_Dual_FNC.md)                                   | 空间组 ICA、双回归及成分间连接                                 |
| [Searchlight.md](Searchlight.md)                                     | 体积 Searchlight 解码、RSA、物理半径和置换校正                   |
| [Gradients_Spatial_Nulls.md](Gradients_Spatial_Nulls.md)             | 连接梯度、对齐及 Moran / Spin 空间零模型                       |
| [Nested_Prediction.md](Nested_Prediction.md)                         | 被试层面的 CPM / Ridge 嵌套交叉验证                          |
| [Dynamic_FC.md](Dynamic_FC.md)                                       | 滑窗连接、窗长及平稳相位零模型                                   |
| [HMM_CAP_LEiDA.md](HMM_CAP_LEiDA.md)                                 | HMM、CAP、LEiDA 的观测、状态拟合和状态统计                       |
| [PCM.md](PCM.md)                                                     | 固定或多成分表征模型、噪声结构及 PCM 交叉验证                         |
| [Encoding.md](Encoding.md)                                           | Ridge / Banded Ridge、刺激特征、滞后和编码交叉验证               |
| [Behaviour_Models.md](Behaviour_Models.md)                           | RW 学习、Softmax、DDM 与潜变量事件导出                        |
| [ISC_ISFC_SRM_Events.md](ISC_ISFC_SRM_Events.md)                     | 共同刺激下的 ISC、ISFC、SRM 和有序事件分段                       |
| [PLS_CCA_Mediation.md](PLS_CCA_Mediation.md)                         | PLS、CCA、正则 CCA 和线性中介的不同输入与用途                      |
| [Extended_Rest.md](Extended_Rest.md)                                 | 同源配对连接、三种熵及 ACF 时间尺度                              |
| [Network_NBS.md](Network_NBS.md)                                     | 社区划分、密度敏感性、保度零网络和 NBS                             |
| [Transfer_Reliability.md](Transfer_Reliability.md)                   | 冻结模型的跨域泛化、六种 ICC 和匹配项目分半                          |
| [OAS_SVM_Regulated_FC_MVPA_RSA.md](OAS_SVM_Regulated_FC_MVPA_RSA.md) | OAS 收缩连接、线性 SVM / logistic、RSA 噪声天花板和被试 Bootstrap |



## 六、examples/：启动模板之外的 22 个文件

28 份 `start_*.m` 已在第三节全部列出。它们是供你复制的通用启动模板。下面的验证程序则保存了开发时的数据适配与检查方式，通常带有本机工作区路径或 HCP 组织假设，不能直接当作你自己研究的通用启动脚本。

### 1. 三个数据准备辅助程序

| 文件                                                                       | 具体用途                                                   |
| ------------------------------------------------------------------------ | ------------------------------------------------------ |
| [export_hcp_behavior_events.m](../examples/export_hcp_behavior_events.m) | 读取既有 HCP 行为拟合结果，核对响应窗口和事件时钟后导出潜变量事件；不重新拟合行为模型          |
| [hcp_naturalistic_roi.py](../examples/hcp_naturalistic_roi.py)           | 从 HCP 压缩 BOLD 与标签图准备自然刺激示例的 ROI 时序 MAT，并检查空间、TR 和有效值   |
| [stage_nifti_prefix.py](../examples/stage_nifti_prefix.py)               | 将 NIfTI 的前若干帧复制为新的 `.nii`，保留原输入并写来源记录；用于缩小工程验证输入，不做预处理 |

### 2. 十九个验证程序

| 文件                                                                                       | 验证或示例用途                                        |
| ---------------------------------------------------------------------------------------- | ---------------------------------------------- |
| [validate_hcp_stage1_timeseries.m](../examples/validate_hcp_stage1_timeseries.m)         | 使用三名 HCP 被试的短静息序列与固定工程 ROI，检查基础时序分析链           |
| [validate_hcp_stage1_patterns.m](../examples/validate_hcp_stage1_patterns.m)             | 复用已有 GLM beta，检查 Beta-series、ROI 解码和 RSA 输入与计算 |
| [validate_hcp_stage1_ppi.m](../examples/validate_hcp_stage1_ppi.m)                       | 复用已估计 LANGUAGE 模型，检查 SPM PPI / gPPI 接口         |
| [validate_hcp_stage2_dcm.m](../examples/validate_hcp_stage2_dcm.m)                       | 检查静息 spectral DCM、群体 PEB 和任务 DCM 工程链           |
| [validate_hcp_stage2_dynamic.m](../examples/validate_hcp_stage2_dynamic.m)               | 复用已有 ROI 时序，检查滑窗连接与零模型                         |
| [validate_hcp_stage2_gradients.m](../examples/validate_hcp_stage2_gradients.m)           | 复用六节点连接矩阵，检查梯度计算和对齐接口                          |
| [validate_hcp_stage2_ica.m](../examples/validate_hcp_stage2_ica.m)                       | 使用三名被试的共同工程掩膜，检查 ICA、双回归和 FNC                  |
| [validate_hcp_stage2_searchlight.m](../examples/validate_hcp_stage2_searchlight.m)       | 复用 beta，以少量中心和低置换次数检查局部球计算链                    |
| [validate_hcp_stage3_behavior.m](../examples/validate_hcp_stage3_behavior.m)             | 将 HCP E-Prime 中的选择、准确率代理奖励和真实 RT 适配为行为模型输入     |
| [validate_hcp_stage3_encoding.m](../examples/validate_hcp_stage3_encoding.m)             | 用既有事件 beta 和条件、位置工程特征检查编码模型                    |
| [validate_hcp_stage3_generalization.m](../examples/validate_hcp_stage3_generalization.m) | 检查旧 beta 的跨被试、跨 run 冻结应用及行为摘要 ICC              |
| [validate_hcp_stage3_multivariate.m](../examples/validate_hcp_stage3_multivariate.m)     | 将三人连接与行为摘要组成工程矩阵，检查多变量分析接口                     |
| [validate_hcp_stage3_naturalistic.m](../examples/validate_hcp_stage3_naturalistic.m)     | 使用同音频故事的真实对齐数据，区分训练故事与外测故事                     |
| [validate_hcp_stage3_network.m](../examples/validate_hcp_stage3_network.m)               | 复用已有连接结果，检查社区、零网络及小样本 NBS 工程链                  |
| [validate_hcp_stage3_pcm.m](../examples/validate_hcp_stage3_pcm.m)                       | 用两名被试既有 beta 和明确的工程噪声输入检查 PCM                  |
| [validate_hcp_stage3_regularized.m](../examples/validate_hcp_stage3_regularized.m)       | 检查旧时序的 OAS 和已有模式的分类；真实条件不足的 RSA 天花板另用合成输入检查    |
| [validate_hcp_stage3_rest_extended.m](../examples/validate_hcp_stage3_rest_extended.m)   | 检查既有 ROI 的熵和时间尺度，并提供镜像体素的工程接口示例                |
| [validate_hcp_stage3_states.m](../examples/validate_hcp_stage3_states.m)                 | 复用已有三人 ROI 矩阵，分别检查 HMM、CAP 和 LEiDA             |
| [validate_prediction_synthetic.m](../examples/validate_prediction_synthetic.m)           | 用较多独立模拟被试检查嵌套预测；不把 HCP 三人当作足够的预测验证样本           |

这些程序的存在不等于每个方法都已通过真实数据验证；具体完成范围以根目录的 `METHOD_STATUS.tsv` 为准。仅查阅或整理文档时，不需要重新运行它们。



## 七、matlab/+cog/：74 个底层函数

`+cog` 是 MATLAB 的包目录，例如文件 `fc.m` 对应调用 `cog.fc(...)`。这些函数接受矩阵或明确的数据结构，通常由第三节的入口组织调用。

### 1. 读写、空间与输入整理

| 文件                                                        | 具体用途                                        |
| --------------------------------------------------------- | ------------------------------------------- |
| [read_tsv.m](../matlab/+cog/read_tsv.m)                   | 读取 TSV 并检查必需列，保留前导零身份与空 session             |
| [read_runs.m](../matlab/+cog/read_runs.m)                 | 读取基础分析 run 清单，检查 subject / session / run 组合 |
| [resolve_path.m](../matlab/+cog/resolve_path.m)           | 按清单所在目录解释相对路径，不搜索固定数据集目录                    |
| [load_bold.m](../matlab/+cog/load_bold.m)                 | 在固定掩膜内读取 BOLD，得到“时间 × 体素”矩阵与空间信息            |
| [load_betas.m](../matlab/+cog/load_betas.m)               | 按估计单元目录读取已有 beta 及身份，不重新估计 GLM              |
| [check_grid.m](../matlab/+cog/check_grid.m)               | 同时检查影像尺寸与空间仿射矩阵是否一致                         |
| [roi_extract.m](../matlab/+cog/roi_extract.m)             | 按整数标签图在固定掩膜内提取各 ROI 平均时序                    |
| [read_spm_session.m](../matlab/+cog/read_spm_session.m)   | 根据 SPM 模型中的扫描引用读取指定 session 的时序与设计          |
| [prepare_dcm_spm.m](../matlab/+cog/prepare_dcm_spm.m)     | 从 SPM 模型的私有副本准备 DCM 所需 VOI 时序与任务输入          |
| [prepare_ica_nifti.m](../matlab/+cog/prepare_ica_nifti.m) | 将明确给出的 NIfTI 和共同掩膜整理为新的 ICA 时序 MAT          |
| [verify_spm_model.m](../matlab/+cog/verify_spm_model.m)   | 只读检查已估计 SPM 模型相关图像的网格与掩膜内有效值                |
| [write_map.m](../matlab/+cog/write_map.m)                 | 按原空间信息将数值写成新的 NIfTI 结果图                     |
| [write_json.m](../matlab/+cog/write_json.m)               | 写 UTF-8 JSON 记录，先写临时文件再完成替换                 |
| [python_process.m](../matlab/+cog/python_process.m)       | 从 MATLAB 启动指定 Python 程序，保留日志并管理该子进程超时       |

### 2. 连续时序、功能连接与基础统计

| 文件                                                                          | 具体用途                             |
| --------------------------------------------------------------------------- | -------------------------------- |
| [clean_timeseries.m](../matlab/+cog/clean_timeseries.m)                     | 将趋势、混杂和频率基联合回归，得到残差时序；不自动删帧      |
| [fc.m](../matlab/+cog/fc.m)                                                 | 计算 ROI 间 Pearson、Spearman 或样本偏相关 |
| [seed_fc.m](../matlab/+cog/seed_fc.m)                                       | 计算一个或多个种子与各体素时序的 Pearson 相关      |
| [weighted_fc.m](../matlab/+cog/weighted_fc.m)                               | 按明确给出的非负时间权重计算加权残差相关             |
| [shrinkage_covariance.m](../matlab/+cog/shrinkage_covariance.m)             | 计算 OAS 收缩协方差及由其得到的连接结果           |
| [spectrum_metrics.m](../matlab/+cog/spectrum_metrics.m)                     | 从时序频谱计算本包定义的 ALFF 与 fALFF        |
| [reho.m](../matlab/+cog/reho.m)                                             | 在局部邻域计算 Kendall 一致性系数，并处理并列秩     |
| [entropy_metrics.m](../matlab/+cog/entropy_metrics.m)                       | 分别计算样本熵、排列熵和幅度直方图熵               |
| [autocorrelation_timescales.m](../matlab/+cog/autocorrelation_timescales.m) | 计算自相关函数、首正瓣面积及相应时间尺度近似           |
| [homotopic_fc.m](../matlab/+cog/homotopic_fc.m)                             | 对显式声明的同源特征对计算连接，不自动证明解剖对应        |
| [network_summary.m](../matlab/+cog/network_summary.m)                       | 按网络标签汇总网络内外边的平均相关与 Fisher z      |
| [graph_metrics.m](../matlab/+cog/graph_metrics.m)                           | 根据明确的负边和阈值策略计算无向正权基础图指标          |
| [group_summary.m](../matlab/+cog/group_summary.m)                           | 按独立被试汇总均值、置信区间、一样本 t、效应量和 FDR    |
| [bh_fdr.m](../matlab/+cog/bh_fdr.m)                                         | 对一次明确给出的检验族进行 BH-FDR 校正          |
| [bootstrap_unit_rows.m](../matlab/+cog/bootstrap_unit_rows.m)               | 按独立单位有放回抽样，同一单位内部的行一起保留          |

### 3. Beta、解码、RSA、迁移与信度

| 文件                                                        | 具体用途                                    |
| --------------------------------------------------------- | --------------------------------------- |
| [beta_series.m](../matlab/+cog/beta_series.m)             | 按被试、session、run、条件分别计算 beta 序列连接        |
| [decode.m](../matlab/+cog/decode.m)                       | 留一明确分组的 LDA 分类或固定惩罚 Ridge 回归；只在训练折学习缩放  |
| [linear_decode.m](../matlab/+cog/linear_decode.m)         | 固定 L2 惩罚的二分类线性 SVM / logistic 交叉验证      |
| [rsa.m](../matlab/+cog/rsa.m)                             | 计算相关、欧氏或 Crossnobis 条件距离及相应模型比较         |
| [rsa_noise_ceiling.m](../matlab/+cog/rsa_noise_ceiling.m) | 计算 Pearson RDM 噪声天花板与保留原被试身份的 Bootstrap |
| [searchlight.m](../matlab/+cog/searchlight.m)             | 按毫米球邻域运行解码或 RSA，并可用共享置换生成最大统计量校正        |
| [pattern_fit.m](../matlab/+cog/pattern_fit.m)             | 在训练域拟合模式模型，保存特征筛选、均值和尺度                 |
| [pattern_apply.m](../matlab/+cog/pattern_apply.m)         | 对目标数据应用冻结的模式模型，不重新学习目标域参数               |
| [transfer_check.m](../matlab/+cog/transfer_check.m)       | 检查训练域与测试域的身份、特征顺序和域边界声明                 |
| [icc.m](../matlab/+cog/icc.m)                             | 计算完整平衡设计下的六种 ICC 及独立单位 Bootstrap        |
| [split_half.m](../matlab/+cog/split_half.m)               | 对所有单位使用同一项目分半，计算半测相关和 Spearman–Brown 修正 |

### 4. DCM、ICA、梯度、动态状态与网络

| 文件                                                                    | 具体用途                              |
| --------------------------------------------------------------------- | --------------------------------- |
| [dcm_build.m](../matlab/+cog/dcm_build.m)                             | 将区域时序、采集参数和显式网络结构整理为 SPM DCM 对象   |
| [dcm_check.m](../matlab/+cog/dcm_check.m)                             | 检查已估计 DCM 的后验和模型证据是否满足基本工程条件      |
| [dcm_model_probabilities.m](../matlab/+cog/dcm_model_probabilities.m) | 在同一数据的候选网络之间，以均匀先验计算固定效应模型后验概率    |
| [ica_group.m](../matlab/+cog/ica_group.m)                             | 逐 run 降维、时间拼接与组降维后调用 GIFT FastICA |
| [dual_regression.m](../matlab/+cog/dual_regression.m)                 | 先空间回归取成分时序，再时间回归取个体成分图            |
| [gradients.m](../matlab/+cog/gradients.m)                             | 调用 BrainSpace 计算连接梯度及对齐           |
| [spatial_association.m](../matlab/+cog/spatial_association.m)         | 对空间图关联使用 Moran 或 Spin 零模型         |
| [sliding_fc.m](../matlab/+cog/sliding_fc.m)                           | 在一个 run 的连续片段内开窗计算连接，不跨缺帧开窗       |
| [phase_surrogate.m](../matlab/+cog/phase_surrogate.m)                 | 对所有节点施加共享频率相位，生成保留离散自谱与互谱的替代时序    |
| [cluster_states.m](../matlab/+cog/cluster_states.m)                   | 按不同观测构建 CAP 或 LEiDA 聚类状态          |
| [state_metrics.m](../matlab/+cog/state_metrics.m)                     | 从硬状态路径计算占有、停留和转移，保留 run 与缺段边界     |
| [network_analysis.m](../matlab/+cog/network_analysis.m)               | 调用 BCT 完成社区、参与系数、密度分析与二值保度重接      |
| [nbs_onesample.m](../matlab/+cog/nbs_onesample.m)                     | 对一样本或事先相减的配对差网络作整单位符号翻转和最大连通成分校正  |

### 5. PCM、预测与编码

| 文件                                                                        | 具体用途                                   |
| ------------------------------------------------------------------------- | -------------------------------------- |
| [pcm_fit.m](../matlab/+cog/pcm_fit.m)                                     | 按显式条件、分区和噪声结构调用原生 PCM 拟合与模型评估          |
| [pcm_individual_cv.m](../matlab/+cog/pcm_individual_cv.m)                 | 在各个体训练折拟合 PCM，再对留出部分作条件预测评分            |
| [gaussian_predictive_score.m](../matlab/+cog/gaussian_predictive_score.m) | 按训练、测试及交叉协方差计算高斯条件预测评分，供 PCM 交叉验证使用    |
| [predict_nested.m](../matlab/+cog/predict_nested.m)                       | 组织 CPM / Ridge 的内外层分组交叉验证与可选置换         |
| [prediction_fit.m](../matlab/+cog/prediction_fit.m)                       | 仅用训练数据学习预测模型的混杂回归、尺度和 CPM 边筛选          |
| [prediction_apply.m](../matlab/+cog/prediction_apply.m)                   | 将冻结的被试预测模型应用于新数据                       |
| [lag_features.m](../matlab/+cog/lag_features.m)                           | 按真实帧号构建滞后特征，不从相邻 run 或缺失段借帧            |
| [encoding_fit.m](../matlab/+cog/encoding_fit.m)                           | 拟合多输出 Ridge / Banded Ridge 编码模型，保存训练参数 |
| [encoding_apply.m](../matlab/+cog/encoding_apply.m)                       | 用冻结编码模型预测脑活动，并返回线性特征分量                 |
| [encoding_cv.m](../matlab/+cog/encoding_cv.m)                             | 组织编码交叉验证、内折参数选择及连续时序边界处理               |

### 6. 行为、多变量关联与自然刺激

| 文件                                                                | 具体用途                                          |
| ----------------------------------------------------------------- | --------------------------------------------- |
| [rw_softmax.m](../matlab/+cog/rw_softmax.m)                       | 按 RW 更新与 Softmax 选择规则计算似然及逐试次潜变量              |
| [fit_rw.m](../matlab/+cog/fit_rw.m)                               | 对 RW–Softmax 两参数进行有界多起点最大似然拟合                 |
| [parametric_events.m](../matlab/+cog/parametric_events.m)         | 将明确的秒单位时点、时长和潜变量整理为 SPM 多条件事件结构               |
| [multivariate_fit.m](../matlab/+cog/multivariate_fit.m)           | 在训练数据上拟合 PLS-C、CCA、正则 CCA 或 PLS 回归，并保存混杂与尺度参数 |
| [multivariate_apply.m](../matlab/+cog/multivariate_apply.m)       | 应用冻结多变量模型，区分双块评分与直接预测 Y                       |
| [multivariate_analysis.m](../matlab/+cog/multivariate_analysis.m) | 组织多变量关联的重拟合置换、独立单位 Bootstrap 与分组验证            |
| [mediation.m](../matlab/+cog/mediation.m)                         | 拟合无交互线性中介路径及间接效应，按独立单位 Bootstrap              |
| [intersubject.m](../matlab/+cog/intersubject.m)                   | 计算留一被试 ISC、方向 ISFC、对称 ISFC 及可选循环移位零模型         |
| [srm_fit.m](../matlab/+cog/srm_fit.m)                             | 拟合确定性正交 SRM，学习共同反应与被试映射                       |
| [srm_apply.m](../matlab/+cog/srm_apply.m)                         | 对训练中已知被试应用冻结的 SRM 映射                          |
| [ordered_events.m](../matlab/+cog/ordered_events.m)               | 拟合有序高斯事件模型，或用冻结事件模式对齐新时序                      |



## 八、scripts/：后端与发布维护

| 文件                                                          | 具体用途                                                                           |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------ |
| [ddm_bridge.py](../scripts/ddm_bridge.py)                   | MATLAB 与官方 PyDDM 之间的适配器：读取请求和试次 MAT，拟合常数二选项 DDM，写参数、密度和模型                      |
| [glhmm_bridge.py](../scripts/glhmm_bridge.py)               | MATLAB 与 GLHMM 之间的适配器：按明确连续段拟合高斯 HMM，写状态概率、硬路径和模型                              |
| [requirements_ddm.txt](../scripts/requirements_ddm.txt)     | DDM Python 环境使用的固定依赖版本；不是 MATLAB 配置                                            |
| [requirements_glhmm.txt](../scripts/requirements_glhmm.txt) | HMM Python 环境使用的固定依赖版本                                                         |
| [sync_release.ps1](../scripts/sync_release.ps1)             | 将开发源目录中的可发布文件同步到 `D:\Function` 并刷新哈希清单；默认保护既有配置和 docs 文档，`VerifyOnly` 用于核验发布文件 |

Python 适配器通常由对应入口调用。发布脚本服务于维护发布副本，不是分析流程中的必跑步骤。

## 九、tests/：25 个自动检查文件

下表说明各文件**检查什么**，不将“有测试文件”等同于“所有数据和方法变体都已经验证通过”。测试结果及真实数据验证范围仍须查 `METHOD_STATUS.tsv`。

| 文件                                                                        | 检查范围                                           |
| ------------------------------------------------------------------------- | ---------------------------------------------- |
| [test_function_adapters.m](../tests/test_function_adapters.m)             | 背景连接与批量 PPI 的输入适配和预检                           |
| [test_function_behavior.m](../tests/test_function_behavior.m)             | RW 更新与拟合、PyDDM 合成拟合、参数调制事件字段与中心化               |
| [test_function_core.m](../tests/test_function_core.m)                     | FC 已知数值、联合回归防护、ReHo 并列秩、NIfTI 读写及批次隔离          |
| [test_function_dcm.m](../tests/test_function_dcm.m)                       | DCM 网络与单位检查、多被试准备、原生 spectral 后验及模型比较防护        |
| [test_function_dynamic.m](../tests/test_function_dynamic.m)               | 滑窗不跨采集缺帧，以及共享相位零模型的谱性质                         |
| [test_function_encoding.m](../tests/test_function_encoding.m)             | 滞后不跨边界、Ridge / Banded Ridge 已知解、嵌套预测和测试目标隔离    |
| [test_function_generalization.m](../tests/test_function_generalization.m) | ICC 已知数值与负值保留、单位 Bootstrap、冻结模型、特征及域边界、项目分半    |
| [test_function_gradients.m](../tests/test_function_gradients.m)           | 原生梯度和对齐、Moran 保持性质、Spin 顶点顺序                   |
| [test_function_graph.m](../tests/test_function_graph.m)                   | 已知小图的拓扑指标与非法输入防护                               |
| [test_function_ica.m](../tests/test_function_ica.m)                       | 双回归已知结果、FastICA 合成源恢复、特征顺序及批次隔离                |
| [test_function_multivariate.m](../tests/test_function_multivariate.m)     | CCA 与原生结果对照、PLS 置换和预测隔离、中介路径与 Bootstrap        |
| [test_function_naturalistic.m](../tests/test_function_naturalistic.m)     | 对齐信号 ISC / ISFC、冻结 SRM 外测、已知事件边界恢复             |
| [test_function_network.m](../tests/test_function_network.m)               | BCT 社区与密度并列边、保度重接、NBS 符号翻转及正负成分分离              |
| [test_function_patterns.m](../tests/test_function_patterns.m)             | LDA / Ridge、训练折缩放、RSA 几何与独立分区、Beta-series 分组   |
| [test_function_pcm.m](../tests/test_function_pcm.m)                       | 原生 PCM 拟合与交叉验证、模型噪声防护、高斯评分及留出被试隔离              |
| [test_function_ppi.m](../tests/test_function_ppi.m)                       | 原生 SPM PPI 线性与反卷积、独立被试汇总                       |
| [test_function_prediction.m](../tests/test_function_prediction.m)         | 嵌套预测的信号恢复、分组保留、测试标签隔离和最少组数防护                   |
| [test_function_prepare_inputs.m](../tests/test_function_prepare_inputs.m) | 通用 ROI / 体素准备、拒绝重复去混杂、保护源影像                    |
| [test_function_regularized.m](../tests/test_function_regularized.m)       | OAS 与独立实现对照、RSA 天花板及 Bootstrap 原被试身份排除         |
| [test_function_rest_extended.m](../tests/test_function_rest_extended.m)   | 三种熵定义、AR(1) 时间尺度、缺段处理、同源相关符号与对应声明              |
| [test_function_searchlight.m](../tests/test_function_searchlight.m)       | 物理半径、受限置换和最大统计量、RSA 距离与模型置换                    |
| [test_function_states.m](../tests/test_function_states.m)                 | 状态边界和停留统计、CAP、LEiDA 分段及原生 HMM 后验               |
| [test_function_task_fc.m](../tests/test_function_task_fc.m)               | 加权连接、任务背景残差连接及网络边汇总                            |
| [ddm_native_smoke.py](../tests/ddm_native_smoke.py)                       | 由 PyDDM 模拟试次，再经过本包适配器拟合并核对密度和似然                |
| [oas_oracle.py](../tests/oas_oracle.py)                                   | 调用独立安装的 scikit-learn OAS，生成 MATLAB 数值测试所需的对照结果 |

##
