# GLMsingle：HCP LANGUAGE 代码跑通示例

本页记录一个明确采用近似的**教学/工程示例**。目的在于让真实预处理影像通过事件适配、HRF 库、GLMdenoise、fractional ridge 和 beta 导出，方便学习代码及替换自己的数据。这里的配置由工具包作者为示例选定，不要求使用者逐项批准研究假设。

通用 `glm_config.m` 与严格适用性检查保持原样；近似只在独立的 `config/glmsingle_demo_config.m` 和 `run_glmsingle_demo.m` 中启用。之前严格预检留下的阻断记录描述的是原事件/音频身份配置，本例另建目录，不覆盖该记录或已有成功模型。

## 1. HCP 数据在这里代表什么

HCP LANGUAGE 包含听故事和听数学题等任务阶段。当前交接事件的 onset 是扫描第一帧对应零点下的秒数，duration 覆盖事件起点至相应响应期结束，并非纯音频长度。故事行包含较长内容及相关任务阶段，不能将一行解释为一个词语级试次。该任务的日志字段与阶段含义见 [HCP E-Prime 数据字典第 6 页](https://humanconnectome.org/storage/app/media/documentation/s1200/HCP_S1200_Release_Appendix_VI.pdf)。

因此本例的 beta 单元是“一个源 EV 事件行”。`story/math` 用来定义交叉验证中的重复条件，每次事件仍有独立 beta。它们不是同一个故事或同一道数学题的重复呈现；音频文件名在审计中另列，不能与类别标签混淆。GLMsingle 用条件重复来选择 PC 数量和 ridge 程度，条件内不重复的变化可能被当作噪声；本例接受这一近似以验证运行路径。[官方重复条件说明](https://glmsingle.readthedocs.io/en/latest/wiki.html)

## 2. 示例主动采用的选择

| 选择 | 参数位置：`config/glmsingle_demo_config.m` | 含义 |
| --- | --- | --- |
| 事件身份 | `cfg.glmsingle.identityColumn='trial_type'` | story/math 是交叉验证身份；每行 beta 不合并 |
| 统一时长 | `cfg.events.expression='fixed'`、`fixedDurationSeconds=20` | 所有保留事件按 20 秒生成 HRF；源时长约 9.8–29.6 秒，20 秒只是代表尺度，并非估计出的最佳值 |
| 最近 TR 对齐 | `onsetMode='nearest'`、`maxOnsetErrorSeconds=0.37` | 当前 TR 约 0.72 秒，半 TR 约 0.36 秒；记录有符号误差，不再次减 Sync、不改变 BOLD 时间零点 |
| 末尾事件筛选 | `minEndBufferSeconds=16` | 格点 onset 至最后一帧不足 16 秒的事件只从新事件副本中排除；每行保留原因，不补零、不添帧 |
| HRF | `cfg.hrf.type='library'` | 使用固定依赖中的 20 个候选 HRF；另可显式设 canonical |
| 去噪和正则化 | `wantDenoise=true`、`wantRidge=true`、`maxPCs=2`、`fracs=[1 .75 .5]` | 实际执行留一 run 交叉验证；最终 PC 可为 0，fraction=1 表示不收缩 |
| 候选噪声池 | `noiseR2Threshold=100`、`pcR2Threshold=-1e6` | 几乎全部选定体素可进入噪声池，并用于 PC 评估；是简化示例，包含任务信号的风险由此保留 |
| 空间范围 | `demo.maxVoxelsPerSubject=4096` | 在同一被试各 run 掩膜交集内，按线性索引均匀抽样；0 使用全部交集体素。不是功能 ROI 或已验证的纯解剖脑掩膜 |
| 混杂与漂移 | `cfg.design.motionModel='24'`、`includeTissueMeans=false`、`linearTrend=false` | 使用交接表的 24 头动项；GLMsingle 自带逐 run 多项式，不使用 SPM FAST/高通，也不先回归 BOLD |

官方允许通过舍入或重采样处理设计和采样网格的不一致；本例只舍入设计。官方同时指出，持续时长差异会改变响应形状；把本例的长短事件统一成 20 秒不会保留原始可变时长模型的解释。[官方时间与时长讨论](https://glmsingle.readthedocs.io/en/latest/wiki.html#how-do-i-deal-with-experimental-conditions-with-different-durations)

16 秒是本例的显式筛选阈值，不是“完整 HRF 已被观察”的保证。本次首次尝试保留全部末尾事件时，部分候选 HRF 的事件列不可估；筛选后通过了所有候选 HRF 的设计秩/残差维度检查。排除事件仍发生在 BOLD 中，其活动在这个简化模型内没有单独建模。用于正式研究时应重新决定持续时长、末尾建模、掩膜及交叉验证身份。

## 3. 怎么运行

`glmsingle_demo_config.m` 是示例的总参数代码，`run_glmsingle_demo.m` 是启动函数；底层仍调用通用 `psy.glm_batch` 和原有 GLMsingle 适配层，没有另写一个估计算法。配置行均有中文说明。

先准备标准 run 清单，可参考 `config/glm_runs_template.tsv`，增加 `mask` 列。必需列为 `subject/session/run/bold/events/confounds/temporal_state`；每人至少两个有共享条件的 run。影像须已预处理且保留正基线，`temporal_state` 为 `unfiltered_unregressed`。每 run 显式提供同网格有效掩膜；也可通过 `cfg.explicitMask` 指定全局掩膜。相对输入路径按源清单目录解析。

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab'); % [必查] 发布包位置
[cfg,demo]=glmsingle_demo_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必改若不同] SPM 安装目录
cfg.manifestFile='E:\my_study\language_runs.tsv'; % [必改] 原始事件/已预处理影像/混杂/掩膜清单
cfg.outputRoot='E:\my_study\glmsingle_demo_check'; % [必改] 新目录
cfg.execute=false; % [可调] 准备事件副本、掩膜、审计和设计检查，不估计
report=run_glmsingle_demo(cfg,demo);

cfg.outputRoot='E:\my_study\glmsingle_demo_fit'; % [必改] 实际估计必须使用另一个新目录
cfg.execute=true; % [可调] 开始实际估计；默认4096体素快速示例
report=run_glmsingle_demo(cfg,demo);
```

要扩大空间范围，可先设置 `demo.maxVoxelsPerSubject=0`。这会增加计算和内存，当前本例的真实数据验证范围仍为每人 4096 体素。没有必要为了跑本例重新做预处理，也不需要让不同被试共用一次估计。

## 4. 输入保护与输出核对

启动函数拒绝已有输出目录。原清单、BOLD、事件、混杂和源掩膜分别计算运行前后 SHA-256；只在新输出目录生成事件副本和教学掩膜。若失败，保留 `GLMSINGLE_DEMO_FAILED.mat` 和已经生成的检查记录，不生成完成标记。

| 文件/目录 | 查看内容 |
| --- | --- |
| `demo_configuration.mat` | 使用者传入的配置和原清单 |
| `prepared/runs.tsv`、`run_*_demo_events.tsv` | 指向原 BOLD/混杂的新清单；筛选后的事件副本保留原 onset/duration/音频身份和 `original_event_index` |
| `prepared/group_*_demo_mask.nii`、`demo_mask_audit.tsv` | 原掩膜交集大小与本例实际抽样数 |
| `demo_assumptions.json` | 选择理由、固定时长、时间误差、末端排除数及示例用途 |
| `demo_event_audit.tsv` | 所有原事件，含原始行号、音频身份、原/建模时长、舍入误差、是否纳入、排除原因、准备表行号及被试内 `beta_index`；排除事件的 beta_index 为 NaN |
| `input_hashes_before.tsv`、`input_hashes_after.tsv` | 原输入字节数/哈希，二者必须一致 |
| `models/sub-*/combined/` | 官方 A/B/C/D 原生结果、设计、导出图像、逐事件映射与数值 QC |
| `demo_summary.json`、`GLMSINGLE_DEMO_COMPLETE.mat` | 所有请求被试估计成功及输入保护检查通过后才写入；只准备则写 PREPARED 标记 |

B/C/D 的 `event_betas.nii` 第四轴是 **beta_index**，不是采集时间。每人分别从 1 编号；对照根目录审计可以找回源事件行和真实音频名。导出仍保留源影像网格，未抽样位置为 NaN，不能把整张 NIfTI 当作全脑估计。A 是 on/off 模型，不提供逐事件 beta。

## 5. 本次实际执行范围

实际根目录：`C:\Users\bx210\Documents\ChatGPT\psy_skill\derivatives\glmsingle_hcp_demo_20261016_131115`，结果在其中的 `hcp_example/`。使用 100307、100408 的 LANGUAGE LR/RL 共 4 个已完整预处理 run，每 run 316 帧、TR 约 0.72 秒。没有重新预处理影像。

| 被试 | 输入事件 | 保留/排除事件 | 分析体素 | 官方模型 | CV 选择 PC 数 |
| --- | --- | --- | --- | --- | --- |
| 100307 | 27 | 25 / 2 | 4096 | A/B/C/D 均实际完成 | 1 |
| 100408 | 27 | 25 / 2 | 4096 | A/B/C/D 均实际完成 | 2 |

各 run 排除最后一个数学事件，全部排除行均留在审计表；合计原 54 行、保留 50 行。实际最大绝对 onset 舍入误差约 0.356 秒，15 个唯一源文件的前后哈希一致。每人 B/C/D 各有 25 个 beta；四模型是逐步估计结果，不能当作四份独立样本。

本轮针对性测试 **13/13 通过，Failed=0、Incomplete=0**：原有通用 GLMsingle 10 项通过，新示例 3 项在修正测试脚本的字符串路径/导入逻辑列索引后全部通过，按不同测试计数，不累加复测次数。覆盖事件副本/尾部筛选与原行映射、原输入不变、确定性掩膜抽样、准备/实际估计标记、完整官方模型与交叉验证、非法示例配置及排除全部事件时的失败记录。现有通用 GLMsingle 的严格阻断测试仍保留；本轮没有更改第三方源码、通用默认值或重新计算先前 SPM 结果。三个 MATLAB 文件静态检查无语法错误，启动函数有一处小表拼接的性能建议。

可在 MATLAB 执行 `runtests({'tests/test_glmsingle.m','tests/test_glmsingle_demo.m'})`。本页陈述的是代码运行与输入/输出检查，不代表该近似方案得到可靠任务效应、全脑结果或适合组推断的统计量。
