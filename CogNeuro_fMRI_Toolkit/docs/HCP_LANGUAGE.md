# HCP 语言任务数据接入计划

核查日期：2026-09-30。

## 官方入口与权限

- [BALSA](https://balsa.wustl.edu/)：注册并登录，进入 ConnectomeDB，选择 HCP-Young Adult 2025，阅读并接受其数据使用条款。
- [官方访问说明](https://www.humanconnectome.org/study/hcp-young-adult/article/updated-hcp-young-adult-data-released-connectomedb-powered-balsa)。账户注册和条款接受由使用者完成；不把密码或令牌写入代码库。
- [2025 文件目录说明](https://humanconnectome.org/storage/app/media/documentation/HCP-YA2025/HCP-YA_2025_Release_Appendix_III.pdf)。2025 与旧 S1200 处理版本不能混用。下载时记录 release、被试 ID、包名、大小及校验值；具体可用文件以账户内清单为准。
- [任务背景](https://www.humanconnectome.org/storage/app/media/documentation/tutorials/Connectome_WB_Tutorial_UserGuide_beta_v0.83.pdf)：LANGUAGE 包含听故事与听觉心算，可定义 story > math；该差异不能直接解释为纯语言特异效应。

## 建议选取

先选一个具有完整 3T LANGUAGE LR/RL、结构像和事件的被试验证导入，再扩展至 3–5 人检查批处理。这是工程测试样本，不用于正式组水平结论。尚未指定被试，不把文档示例 ID 当成已确认可下载的数据。

第一批优先选择 LANGUAGE LR/RL 原始扫描、对应 SBRef 和反向编码场图、T1w（条件允许时同时保留 T2w），以及 E-Prime/EV 事件。另取同一人的官方预处理语言数据、脑掩膜和运动信息用于下游测试。门户包可能包含全部任务；登录后先核对包大小，不能承诺能只下载某个任务。

初期面向体积 NIfTI。CIFTI 需要独立适配，不能当作普通体积 NIfTI 交给 SPM。2025 官方去噪数据与自行预处理数据的步骤不同，不要求结果逐体素一致。

原始 EV 通常位于：
`<id>/unprocessed/3T/tfMRI_LANGUAGE_<LR|RL>/LINKED_DATA/EPRIME/EVs/`

官方衍生数据 EV 通常位于：
`<id>/MNINonLinear/Results/tfMRI_LANGUAGE_<LR|RL>/EVs/`

保留原始目录结构。条件文件使用 story.txt、math.txt；不要把区块 EV 与其细分事件同时全部放进同一个模型。LR/RL 为不同 run，不能直接拼接为单次连续扫描。事件时间与丢弃初始体积的处理必须一致。

## 验证边界与后续实现

1. 导入：文件清单、NIfTI 维度/TR、事件时长、运动行数、处理版本核对。
2. 原始预处理：空间配准与质量报告。HCP 的反向相位编码畸变校正需评估 FSL/TOPUP 或等价后端；仅 MATLAB/SPM 的常规流程不能宣称完整复现 HCP Pipelines。不能从 LR/RL 名称推断 NIfTI 轴和读出时间。
3. GLM：分别建模各 run、story/math 条件与混杂，检查设计矩阵与对比。
4. FC/PPI：分别定义任务背景连接与条件调制；不把任务时间序列相关当成静息态 FC。
5. DCM：先固定有理论依据的节点、输入和连接假设，验证时序、模型拟合和参数可识别性；不能因程序收敛就认定模型有效。静息态 FC/spectral DCM 另取 rfMRI，语言任务数据不能替代静息态。

当前状态：访问入口和文件结构已确认，等待账户权限。所有影像相关流程均未进行真实数据验证。

