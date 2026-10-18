# 预处理总使用指南

本工具包通过 MATLAB 批量调用 SPM；选择 TOPUP 时，同时调用 WSL 中的 FSL。支持多个被试、会话和 run。原始输入只读，处理结果写入独立输出目录。

本页说明整体使用流程。各步骤的具体原理、参数选项与配置行号，见对应文档。

## 1. 先选入口

| 数据情况                 | 运行入口                  | 数据从哪里读取                    | 主要修改位置                                      |
| -------------------- | --------------------- | -------------------------- | ------------------------------------------- |
| 一般研究；自行指定文件路径        | `run_toolkit.m`       | TSV 清单，每行一个 run            | `config/toolkit_config.m`、自己的 TSV 及其关联 JSON |
| 保留 HCP 原始解压目录结构的示例数据 | `run_preprocessing.m` | 在 `dataRoot` 下递归发现原始 NIfTI | `config/preprocess_config.m`；其余处理参数继承通用配置   |

**一般研究使用 `run_toolkit.m`。** 入口脚本负责读取配置和启动批处理；无需在入口脚本中逐个填写被试路径。

## 2. 准备输入

### 2.1 一般研究：填写清单

1. 将 [runs_extended_template.tsv](../config/runs_extended_template.tsv) 复制为自己的 TSV，例如 `config/runs.tsv`。
2. 用真实文件替换示例行。**每名被试每个 run 各占一行**；24 名被试、每人 2 个 run，共 48 行数据。
3. 在 `toolkit_config.m` 中，将 `cfg.manifestFile` 指向这份清单。
4. 核对清单关联的采集信息和场图信息；具体列名、格式与示例见 [数据清单填写指南](Run_Manifest_Guide.md)。

| 内容                         | 填写位置                    | 说明                                |
| -------------------------- | ----------------------- | --------------------------------- |
| 被试、会话、run、BOLD/T1/SBRef 路径 | TSV 对应列                 | 可用绝对路径，或相对 TSV 所在目录的路径；会话可留空      |
| TR、逐层采集时间、PE 方向、总读出时间      | `metadata` 列关联的采集 JSON  | 按所选步骤提供真实信息；不是所有字段在所有路线都必填        |
| 场图文件、类型、单位、TE 等            | `fieldmaps` 列关联的场图 JSON | 按所选 SDC 路线填写，见 [磁敏感畸变校正](SDC.md)  |
| 任务事件                       | 可选 `events` 列关联的 TSV    | 空间预处理不要求提供事件；提供后会检查时间信息，不自动建立 GLM |
| 已处理输入的来源                   | `provenance` 列关联的 JSON  | 使用外部已校正/已预处理数据时填写，不能把它们声明为原始输入    |

JSON 记录的是数据的真实采集信息和文件关联。内容已经正确时，不必每次预处理都修改；更换数据或发现错误时才修正。

### 2.2 HCP 示例：保留原始目录结构

在 `config/preprocess_config.m` 设置 `cfg.dataRoot`，本机示例为 `D:\IBM`。程序递归寻找：

```text
<六位被试号>/unprocessed/3T/<run>/<被试号>_3T_<run>.nii[.gz]
```

各下载包可以分别解压在 `<被试号>_extracted` 内，内部保留 HCP 目录即可。程序同时寻找对应 T1 和 SBRef；发现重复候选会报错，不会任选一份。**入口不直接读取 ZIP，也不会把官方预处理数据当成原始数据。**

`cfg.subjects={}` 选择发现的全部被试；`cfg.runNames` 指定 run 名称。HCP 预设中的 echo spacing 和 PE 方向只适用于该示例，不能照搬到其他研究。

## 3. 修改配置

### 3.1 运行前必须核对的设置

以下行号对应本发布版的 `config/toolkit_config.m`。

| 设置                              | 配置行     | 怎么填                                                          |
| ------------------------------- | ------- | ------------------------------------------------------------ |
| `cfg.manifestFile`              | 13      | 自己的 TSV 路径；一般研究使用                                            |
| `cfg.spmPath`                   | 15      | 含 `spm.m` 的 SPM 安装目录；自动寻找失败时手动指定                             |
| `cfg.outputRoot`                | 17      | 本次研究的输出根目录，例如 `D:\fMRI_Results\study_v1`                     |
| `cfg.subjects` / `cfg.runNames` | 19 / 21 | `{}` 为全部；也可填写与清单完全一致的名称列表                                    |
| `cfg.execute`                   | 23      | `false` 预检；`true` 正式处理                                       |
| `cfg.stopAfter`                 | 25      | `'realign'` 头动/QC 后结束；`'segment'` 分割后结束；`'smooth'` 继续至标准化和平滑 |
| `cfg.continueOnError`           | 27      | `true` 记录失败后继续其他 run；`false` 遇到失败停止                          |
| `cfg.resume`                    | 29      | `true` 可复用输入、配置和代码一致的已完成 run；不表示逐步骤续跑                        |

**输出目录必须位于 `D:\CogNeuro_fMRI_Toolkit` 之外。** 发布文件夹只保存代码和文档，程序也会检查这一点。通用配置和 HCP 配置的默认输出均在工具包根目录下，因此从 D 盘发布版运行前，必须先改为外部目录。

### 3.2 使用 HCP 入口时，注意配置覆盖

`preprocess_config.m` 先读取 `toolkit_config.m`，再覆盖下列设置：

| HCP 预设覆盖的内容                        | 使用 `run_preprocessing.m` 时修改哪里 |
| ---------------------------------- | ------------------------------ |
| 数据根目录、被试、run 选择、输入模式               | `config/preprocess_config.m`   |
| 输出目录、SPM 路径、`execute`、`sdc.method` | `config/preprocess_config.m`   |
| HCP 专用 echo spacing 和 PE 方向        | `config/preprocess_config.m`   |
| STC、Realign、分割、配准、标准化、平滑、QC 等未覆盖参数 | `config/toolkit_config.m`      |

例如，HCP 预设将 `cfg.sdc.method` 设为 `'fsl_topup'`。只修改通用配置中的同名值，随后会被 HCP 预设覆盖。

## 4. 运行顺序

| 顺序  | 操作                              | 检查内容                                        |
| --- | ------------------------------- | ------------------------------------------- |
| 1   | 在 MATLAB 中打开工具包根目录              | 当前目录中能看到 `run_toolkit.m`；SPM 路径正确           |
| 2   | 填好输入，选择方法和参数，设置外部输出目录           | 清单、JSON 与真实数据一致                             |
| 3   | 设置 `cfg.execute=false`，运行所选入口   | 查看 `batch_status.tsv` 中每个 run 的状态与消息        |
| 4   | 修正预检失败项                         | NIfTI 输入应为 `validated_inputs`；DICOM 的状态另见下文 |
| 5   | 设置 `cfg.execute=true`，重新运行同一个入口 | 正式处理全部选中的被试/run                             |
| 6   | 检查完成记录、QC 和图像                   | 计算完成不等于配准、覆盖和信号质量合格                         |

在 MATLAB 命令窗口二选一：

```matlab
run_toolkit          % 一般研究：先填写 TSV 与 toolkit_config.m
% run_preprocessing  % HCP 示例：先核对 preprocess_config.m
```

仅预检后，可以沿用同一输出目录正式运行。已经产生计算结果后再更改方法、参数或输入，请使用新的输出目录；失败的半成品目录也不会自动覆盖。

### 4.1 DICOM 与 dummy 帧

| 情况                 | 设置和处理方式                                                                                                                         |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| 已经是 `.nii/.nii.gz` | 保持 `cfg.dicom.enabled=false`，跳过转换                                                                                               |
| 需要 DICOM → NIfTI   | 设 `cfg.dicom.enabled=true`；每个影像路径指向一条单独的 DICOM 序列目录，BOLD 的采集 JSON 必须提供 TR                                                       |
| DICOM 预检           | `execute=false` 只检查序列清单，记录 `dicom_inventory_only`；不是完整 NIfTI/场图/事件预检。正式运行时才转换并继续检查                                              |
| 不删除初始帧             | `cfg.discardVolumes=0`                                                                                                          |
| 需要删除初始 N 帧         | 设置非负整数 N；也可由 TSV 的 `discard_volumes` 逐 run 覆盖，至少保留 2 帧                                                                          |
| 非零删帧且提供事件          | `event_reference` 或 `cfg.dummy.eventReference` 必须明确：`original_first_volume` 将 onset 减去 N×TR；`retained_first_volume` 保持 onset 不变 |

删帧发生在工作副本上，位于 STC、BOLD 畸变应用和头动校正之前；不会连带删除 T1、SBRef 或场图的帧。原始影像和事件文件保留。

### 4.2 方法决定实际处理顺序

配置文件中的章节顺序不等于执行顺序。FSL 分支先校正 BOLD 畸变，再做可选 STC 和普通 Realign；SPM 的 Apply VDM 与 Realign & Unwarp 有各自顺序。六种 SDC 选择的完整顺序见 [SDC 第十一节](SDC.md#十一把这一阶段放回完整一次运行流程)。

默认 segmentation 标准化路线在头动/QC 后继续：**T1 分割 → 平均 EPI 与 T1 配准 → MNI 标准化 → 平滑**。选择 DARTEL/Shooting 且运行到平滑时，入口会先组织全批结构像与群体模板/配准，再处理各 run，见 [标准化](Normalization.md)。

FSL 分支会自动完成 **TOPUP 估场 → 生成校正后 SE 的三维时间均值 → 配准并校正 BOLD**，无需手工准备 `se_unwarped_mean.nii.gz`，也无需新增配置。均值通过检查后才写入 TOPUP 完成记录；统一入口还将它列入 run 必需输出。具体输出与独立调用见 [SDC 附录 A](SDC.md#附录-a独立调用-topup-与-bold-畸变校正)。此交接已通过 15 项针对性测试及两个合成被试的实际 FSL 调用；本次没有重跑 HCP 全流程。旧输出不会自动补写或续跑，更新代码后验证请使用新输出目录。

## 5. 各步骤

| 步骤           | 主要配置                                       | 详细文档                                              |
| ------------ | ------------------------------------------ | ------------------------------------------------- |
| 层时间校正        | `cfg.sliceTiming.*`                        | [Slice Timing](<STC_Slice Timing Correction.md>)  |
| 磁敏感畸变校正      | `cfg.sdc.*`；逐 run 场图 JSON                  | [SDC](SDC.md)；独立 FSL 调用见文末附录                      |
| 头动校正与 Unwarp | `cfg.realign.*`、`cfg.unwarp.*`             | [Realignment](Realignment.md)                     |
| 结构像分割及原生图谱   | `cfg.segment.*`、`cfg.atlas.*`              | [Segmentation](Segmentation.md)                   |
| EPI–T1 配准    | `cfg.coreg.*`                              | [Coregistration](Coregistration.md)；当前固定 Estimate |
| 标准化          | `cfg.normalise.*` 及相应群体路线设置                | [Normalization](Normalization.md)                 |
| 空间平滑         | `cfg.smoothingFwhmMm`、`cfg.smooth.*`       | [Spatial Smoothing](<Spatial Smoothing.md>)       |
| 工程质量检查       | `cfg.fdRadiusMm`、`cfg.fdFlagMm`、`cfg.qc.*` | [Engineering QC](Engineering_QC.md)               |

统一入口不读取独立模块的 `topup_config.m`、`bold_unwarp_config.m` 或 `qc_config.m` 来替代上述设置。只有单独调用相应模块时，才使用那些配置。

## 6. 输出与完成判断

`outputRoot` 表示配置的输出根目录；`sub-<subject>` 表示被试目录。`[ses-<session>/]` 中的方括号表示这一层可选，**不是实际文件夹名称**。

| 记录         | 位置或名称                                                                    | 含义                                     |
| ---------- | ------------------------------------------------------------------------ | -------------------------------------- |
| 批次总览       | `outputRoot/batch_status.tsv`                                            | 逐 run 的状态、错误消息和输出路径；首先查看它              |
| 配置与输入清单快照  | `outputRoot/config_and_inventory.mat`                                    | 记录本次配置及选中的输入                           |
| 输入头检查      | `outputRoot/input_checks/sub-<subject>/[ses-<session>/]<run>/header.mat` | 保存影像与采集信息检查结果；不代表完成预处理                 |
| 每个 run 的结果 | `outputRoot/sub-<subject>/[ses-<session>/]<run>/`                        | 工作影像、处理计划、SPM/CAT 作业及相应 QC             |
| FSL 阶段完成记录 | `TOPUP_COMPLETE.json`、`BOLD_UNWARP_COMPLETE.json`                        | 分别表示场估计、BOLD 畸变校正完成；位于对应阶段的子目录         |
| 时序 QC      | `timeseries_qc/`                                                         | 指标、检查图和 `QC_COMPLETE.mat`；不适用时可能记录跳过原因 |
| run 完成记录   | `COMPLETE.mat`                                                           | 完成了此次配置要求的阶段；需结合 `stopAfter` 和实际方法解释   |

`validated_inputs` 只表示预检；`spm_vdm_only` 只准备 VDM；`stopAfter='realign'` 不会产生完整标准化和平滑结果。不能只凭存在 `COMPLETE.mat` 就认定所有步骤都已执行。

默认前缀下，标准化未平滑与平滑影像常见为 `w*.nii`、`sw*.nii`；自定义前缀及 DARTEL/Shooting 路线应读取实际结果记录，尤其是 `SMOOTHING_COMPLETE.mat`，不要只按文件名猜测。

## 7. 使用边界

1. 恢复机制只复用签名一致的完整成功 run，不会自动补完任意失败步骤；原始输入和已有成功结果不覆盖。
2. 多带 STC 需要真实逐层时间，不能用五种标准单带顺序猜测。
3. 自动 QC 检查工程指标；分割、配准、畸变、覆盖和信号质量仍需结合图像审核。
4. 本入口不自动完成时间去噪、滤波、scrubbing、GLM、FC、PPI 或 DCM。GLM 的独立目录为 `D:\GLM`。
5. 本工具包没有实现 HCP 官方流水线的全部梯度非线性校正、FreeSurfer 步骤或所有变换的一次联合重采样。
