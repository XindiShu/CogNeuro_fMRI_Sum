# 现成工具包接口对照

此表记录原包入口、配置和调用目标。实际安装文件由toolkit_catalog.py只读核对；方法选项读取原包当前配置和文档。示例/开发校验单列，不作为普通研究默认入口。

| method_id | 作用 | 原生目标 | 配置 | 角色 |
| --- | --- | --- | --- | --- |
| `preprocessing.preprocess` | 通用预处理／SDC／分割／标准化／平滑 | `psy.preprocess_batch` | `config/toolkit_config.m` | analysis |
| `preprocessing.confounds` | 组织信号与运动混杂提取 | `psy.confounds_batch` | `config/confounds_config.m` | analysis |
| `preprocessing.confound_design` | 混杂设计矩阵 | `psy.confound_design_batch` | `config/design_config.m` | analysis |
| `preprocessing.denoise` | 时间去噪 | `psy.denoise_batch` | `config/denoise_config.m` | analysis |
| `preprocessing.timeseries_qc` | 已处理时序的批量QC | `psy.qc_batch` | `config/qc_config.m` | analysis |
| `preprocessing.topup` | 独立TOPUP场图估计 | `psy.topup_batch` | `config/topup_config.m` | analysis |
| `preprocessing.bold_unwarp` | 独立TOPUP场图到BOLD校正 | `psy.bold_unwarp_batch` | `config/bold_unwarp_config.m` | analysis |
| `preprocessing.hcp_example` | HCP示例入口 | `psy.preprocess_hcp` | `config/preprocess_config.m` | example |
| `preprocessing.validation` | 开发验证脚本 | `validate_preprocessing` | `config/preprocess_config.m` | validation |
| `glm.model` | 可组合GLM／LSA/LSS／pmod/FIR／跨run／组统计／GLMsingle | `psy.glm_batch` | `config/glm_config.m` | analysis |
| `glm.single_trial` | 原有逐事件LSA/LSS入口 | `psy.single_trial_batch` | `config/single_trial_config.m` | analysis |
| `glm.outputs` | 已估计GLM结果／beta目录／ROI导出 | `run_glm_outputs` | `config/glm_outputs_config.m` | analysis |
| `glm.glmsingle_demo` | GLMsingle专用工程示例 | `run_glmsingle_demo` | `config/glmsingle_demo_config.m` | example |
| `function.function` | 连续时序：FC／ALFF/fALFF／ReHo | `run_function` | `config/function_config.m` | analysis |
| `function.prepare_inputs` | BOLD到ROI/体素MAT准备 | `run_prepare_inputs` | `config/prepare_inputs_config.m` | analysis |
| `function.dynamic_fc` | 滑动窗口连接 | `run_dynamic_fc` | `config/dynamic_fc_config.m` | analysis |
| `function.states` | HMM／CAP／LEiDA与状态统计 | `run_states` | `config/state_config.m` | analysis |
| `function.ica` | 组ICA／双回归／FNC | `run_ica` | `config/ica_config.m` | analysis |
| `function.gradients` | 连接梯度／对齐／空间零模型 | `run_gradients` | `config/gradient_config.m` | analysis |
| `function.network` | 网络拓扑／社区／保度零网络／NBS | `run_network` | `config/network_config.m` | analysis |
| `function.dcm` | 任务／谱DCM与模型比较 | `run_dcm` | `config/dcm_config.m` | analysis |
| `function.dcm_group` | PEB／BMR／BMA | `run_dcm_group` | `config/dcm_group_config.m` | analysis |
| `function.pcm` | 固定／多成分PCM与交叉验证 | `run_pcm` | `config/pcm_config.m` | analysis |
| `function.behavior` | RW／Softmax／DDM行为模型 | `run_behavior` | `config/behavior_config.m` | analysis |
| `function.rest_extended` | 熵／时间尺度／同源连接 | `run_rest_extended` | `config/rest_extended_config.m` | analysis |
| `function.regularized_fc` | OAS收缩连接 | `run_regularized_fc` | `config/regularized_fc_config.m` | analysis |
| `function.background_fc` | 任务背景连接 | `run_background_fc` | `config/background_config.m` | analysis |
| `function.ppi` | 单模型PPI／gPPI | `run_ppi` | `config/ppi_config.m` | analysis |
| `function.ppi_batch` | 多被试/session/run PPI／gPPI | `run_ppi_batch` | `config/ppi_config.m` | analysis |
| `function.prepare_dcm_spm` | 已估计任务SPM到私有VOI/DCM输入 | `cog.prepare_dcm_spm` | 原始参数签名 | preparation |
| `function.prediction` | 嵌套CPM／Ridge预测 | `run_prediction` | `config/prediction_config.m` | analysis |
| `function.encoding` | Ridge／Banded Ridge编码 | `run_encoding` | `config/encoding_config.m` | analysis |
| `function.multivariate` | PLS／CCA／中介分析 | `run_multivariate` | `config/multivariate_config.m` | analysis |
| `function.naturalistic` | ISC／ISFC／SRM／事件分段 | `run_naturalistic` | `config/naturalistic_config.m` | analysis |
| `function.transfer` | 冻结模型跨域泛化 | `run_transfer` | `config/transfer_config.m` | analysis |
| `function.reliability` | ICC／分半信度 | `run_reliability` | `config/reliability_config.m` | analysis |
| `function.linear_decode` | 线性SVM／逻辑回归 | `run_linear_decode` | `config/linear_decode_config.m` | analysis |
| `function.rsa_ceiling` | RSA噪声天花板／被试Bootstrap | `run_rsa_ceiling` | `config/rsa_ceiling_config.m` | analysis |
| `function.roi_patterns` | Beta-series／ROI解码／RSA | `run_roi_patterns` | `config/roi_patterns_config.m` | analysis |
| `function.searchlight` | Searchlight解码／RSA | `run_searchlight` | `config/searchlight_config.m` | analysis |

GLM的多种估计单元、HRF、拟合策略、层级及后端是glm.model现成配置的组合，不拆成新算法实现。Function各入口的methods/options同理。
若安装目录新增入口，catalog会列出unmapped_entrypoints供继续接线；已有方法的实现状态不由skill目录决定。
