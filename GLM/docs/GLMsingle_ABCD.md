# GLMsingle：理论、输入条件与代码实践



## 1. GLMsingle 解决什么问题

在单试次设计中，每个事件有独立回归列。事件响应重叠、HRF 形状偏差和相关噪声都会使 beta 估计不稳定。GLMsingle 组合了体素级 HRF 库选择、GLMdenoise 和 fractional ridge；这三个步骤分别处理模型形状、数据驱动的共同噪声和相关预测列带来的估计方差。[Prince 等，2022，eLife 11:e77599](https://pmc.ncbi.nlm.nih.gov/articles/PMC9708069/)。

| 原生类型                     | 估计内容                                     | 本接口的选择                                               |
| ------------------------ | ---------------------------------------- | ---------------------------------------------------- |
| A / ONOFF                | 所有事件折叠为一类，使用假定 HRF，得到总体响应与拟合度            | 始终计算，供后续噪声池等步骤使用                                     |
| B / FITHRF               | 每个事件独立 beta；体素级 HRF 库选择或明确假定的 HRF        | 始终计算；本接口使用 OLS，不启用原生 B 的 LSS 特例                      |
| C / FITHRF_GLMDENOISE    | 在 B 的设计基础上加入数据驱动噪声回归量                    | `glmsingle.wantDenoise=true`                         |
| D / FITHRF_GLMDENOISE_RR | 按体素选择 fractional ridge 强度，并按原生默认作尺度/偏移校准 | `glmsingle.wantRidge=true`；若关闭 denoise，D 使用 0 个噪声 PC |

`hrf.type='library'` 使用随官方源码提供的 20 个 HRF 候选；`canonical` 使用 GLMsingle 自己的假定 HRF，而非本包 SPM 的微时间 canonical 设计。这些 HRF 在给定刺激时长下卷积并按峰值归一化。HRF 选择由完整模型拟合进行，不能称为所有步骤都对 HRF 做了留一 run 验证。

GLMdenoise 先根据平均强度和低 ONOFF R² 确定候选噪声池，逐 run 从其时序提取 PC；再利用重复条件的跨 run beta 一致性选择 PC 数量。有效 PC 数允许为 0：这表示实际交叉验证作出了选择，并非代码失败或暗中关闭步骤。噪声池、PC 评估体素、候选 PC 及交叉验证结果均保留。

普通 ridge 可写为

$$
\hat\beta_\lambda=(X^TX+\lambda I)^{-1}X^Ty.
$$

这里的 $X$、$y$ 应理解为按原生实现处理 nuisance 后的任务模型。fractional ridge 以相对 OLS 系数长度的比例来参数化正则化路径；本包 `fracs` 是该比例的候选，不是直接的 $\lambda$。ridge 用一定偏差换取方差降低，最终 beta 不自动具备 SPM Classical beta 的抽样解释。实现与精确定义见[固定版本 fracridge](https://github.com/nrdg/fracridge/tree/1ac49cae092cca3efa083451808c26989d17a3b5)及随包函数说明。



## 2. 重复的含义必须来自实验

事件表有两种不同标签：`trial_type` 表示本包的条件类别，`stimulus_id` 等列则明确说明哪些事件在交叉验证中被视为重复身份。GLMsingle 仍然为每次出现分别估计 beta，不把同身份的所有事件提前合成一列。

默认 `glmsingle.identityColumn='stimulus_id'`。相同图片/音频在不同 run 再次出现时，可使用同一身份。若研究问题有依据把类别本身视为重复条件，也可以显式指定另一列；但把不同故事都标成 story，并不证明相同刺激重复。本接口不会自动替换这种定义。

默认去噪与 ridge 的超参数选择需要跨 run 的重复：本接口采用固定的留一 run 方案，并要求**每一折**的测试 run 至少有一个身份出现在其训练 run 中。允许条件不完全平衡、只重复部分身份；这是可计算性的最低检查，不是数据充分性或功效保证。[官方 FAQ](https://glmsingle.readthedocs.io/en/latest/wiki.html)解释了重复对去噪和 ridge 超参数评估的作用。

增加被试不能补齐某一个人的跨 run 重复；不能把不同人当作同一时序实验的不同 run。一个身份也不能跨越互相矛盾的 `trial_type`；若同一刺激在不同任务情境中具有不同预期响应，应在研究设计中定义适当的复合身份。

没有重复时，可以**明确**关闭 `wantDenoise` 和 `wantRidge` 来估计 A/B，但那不等于完整 C/D 管线。官方函数可能在某些缺重复情形下发出警告后关闭步骤；本适配层在调用前阻断，并在调用后再次核对实际选项，禁止静默降级。原生固定 PC 数或单一 ridge fraction 的非交叉验证特例尚未开放。



## 3. 输入限制及预检

当前支持 `level='subject'`、`model.unit='event'` 或 `trial`、`fit.strategy='joint'`。event 表示一行一个事件；trial 额外要求每个 run 内有唯一、真实的 `trial_id`。输出都是逐事件 beta。暂不支持 item 聚合、targetConditions 筛选、pmod/FIR 与 GLMsingle 同时使用、自定义 HRF 库、原生 LSS 特例或贝叶斯引擎。

### 3.1 时长与 TR 格点

官方 MATLAB 接口接收一个共同的正刺激时长 `stimdur`，不是每行一个时长向量。本包要求原生 HRF 库使用的时长为 0.1 秒的整数倍：

- `events.expression='duration'`：所有 run 所有事件的原时长必须相同且 >0；不擅自取平均。
- `fixed`：明确采用 `events.fixedDurationSeconds` 作为统一正时长，源时长与建模时长均记录；这会改变模型假设，须有实验依据。
- `impulse`：当前接口不开放，避免把 0 秒隐式变成原生库的 0.1 秒近似。

长故事与短算术事件不能仅为适配工具就统一改成 1 秒。官方对可变时长的讨论见[GLMsingle FAQ](https://glmsingle.readthedocs.io/en/latest/wiki.html#how-do-i-deal-with-experimental-conditions-with-different-durations)。

原生二值设计每行对应一个 TR，每个 run 的事件 onset 都相对自己的第一帧：

- `onsetMode='strict'`：要求在 TR 格点上，允许 10⁻⁶ 秒浮点误差。
- `nearest`：显式舍入到最近 TR，同时受 `maxOnsetErrorSeconds` 约束，保留每行误差；不会重采样 BOLD。
- 任意两个事件舍入到同一帧均阻断，即使属于同一身份，也不会合并或丢弃事件。
- 负 onset 或舍入后落到扫描范围外均阻断，不裁剪、不平移。

`minEndBufferSeconds` 默认 8 秒，按原生最后 onset 格点到最后采集格点的间隔检查。8 秒只是最低预检门槛，不表示任意长事件的完整响应已被采到；需审查时长、HRF 支持和尾部可观测性。框架不自动删除末尾事件。

### 3.2 图像、掩膜、混杂和漂移

输入仍必须是 `unfiltered_unregressed`，同一人的不同 run 有相同 TR 和网格；不自动裁剪数据或重采样。每个 run 必须通过清单 `mask` 或全局 `explicitMask` 提供明确的覆盖/分析掩膜，最终取交集。掩膜必须有限、非负、非空且同网格；它不自动等同于解剖脑掩膜。

执行时检查全部掩膜内数据为有限值，无任何零编码缺失，并保留正基线。部分帧有值、部分帧为零的边缘体素不能靠填零混入噪声池；应提供经过审查的完整覆盖掩膜。掩膜外不会加载到原生算法。输出 beta 在掩膜外写 NaN，并另存掩膜，避免把未分析位置误作零效应。

本包 `design.*` 选择的混杂通过 `extraregressors` **联合**进入原生模型，去掉本包截距，保留 run 边界。低频漂移由原生多项式处理，默认最高阶为 `round(run时长分钟/2)`。**SPM 的 `highpassSeconds`、`serialCorrelation`、`microtimeResolution/Onset` 和 `maskThreshold` 不用于这个引擎**；不会把 FAST/AR(1) 的推断性质套给 GLMsingle。

预检对每个 run、每个 HRF 候选构建单事件列，联合多项式/混杂检查可估性及 `minResidualDF`，并为最大候选 PC 数检查剩余维度。可估并不等于精确或科学合理。原生自动 R² 阈值需要 Statistics and Machine Learning Toolbox 的 `fitgmdist`；不具备依赖时明确报错，或由研究者事先指定有依据的数值阈值。

`maxInputGiB` 检查所有 run 掩膜内 single 输入的总大小，`chunkVoxels` 控制原生计算分块。这些都不保证峰值内存；原生 HRF 评估、SVD、交叉验证和结果仍需要额外内存。



## 4. 总配置与运行

先准备含真实身份的事件表，可参考 `config/glm_events_glmsingle_template.tsv`。该模板只示范一个 run；C/D 还需要在其他 run 出现重复身份。ID 不要求连续，也不必等于文件名，但必须有来源。清单仍为 `subject/session/run/bold/events/confounds/temporal_state`，并建议逐 run 指定 `mask`。

在 `config/glm_config.m` 中修改：

```matlab
cfg.engine='glmsingle'; % [必改] 使用官方GLMsingle适配层
cfg.level='subject'; % [约束] 同一被试多个run联合输入
cfg.model.unit='event'; % [可调] event；或带真实trial_id的trial
cfg.model.targetConditions={}; % [约束] 不筛掉其他事件
cfg.fit.strategy='joint'; % [约束] 本接口不启用原生LSS特例
cfg.hrf.type='library'; % [可调] library=20候选；canonical=明确假定HRF
cfg.conditions={'conditionA','conditionB'}; % [必改] trial_type的完整类别集合
cfg.glmsingle.identityColumn='stimulus_id'; % [必改] 明确跨run重复定义
cfg.events.expression='duration'; % [可调] 原始共同正时长；或有依据的fixed
cfg.glmsingle.wantDenoise=true; % [可调] PC数量交叉验证
cfg.glmsingle.wantRidge=true; % [可调] ridge强度交叉验证
cfg.glmsingle.onsetMode='strict'; % [可调] 先严格检查，不自动舍入
cfg.execute=false; % [可调] 先预检；实际估计才设true
```

路径、输出根目录、混杂选择、分块/内存、阈值、PC 上限、`fracs`、多项式阶数、百分信号单位和随机种子也都在同一总配置中，并有中文行注释。`contrastNames/contrastWeights` 不用于 GLMsingle 的逐事件输出；本引擎不自动产生这些 SPM 条件对比。

默认 `subject.combineSessions=false`，同被试不同访视分别处理。若明确设置 true，则由清单 session 生成原生 `sessionindicator`；它仅用于超参数评估内部的 session 归一化，不会自动把最终 beta 归一化到同一访视尺度。仍须有跨访视合并的实验依据。

运行 `run_glm`。被阻断的准备会保留 `GLMSINGLE_BLOCKED.mat` 和原因；只有准备成功才写 `GLMSINGLE_PREPARED.mat`，完整估计并通过导出检查后才写 `GLMSINGLE_COMPLETE.mat`。执行模式遇到未满足条件会报错，已经成功的模型目录不覆盖。



## 5. 输出及其解释

典型位置为 `sub-*/[ses-*/]combined/`：

| 文件/目录                                                         | 含义                                                |
| ------------------------------------------------------------- | ------------------------------------------------- |
| `preflight.mat`、`summary.json`                                | 实际配置、时序、重复检查和全部阻断原因                               |
| `event_mapping.tsv`                                           | run、源事件行、身份、条件、原/建模时长、原/格点 onset、舍入误差和 beta_index |
| `identity_mapping.tsv`                                        | 身份与设计列映射、出现次数及跨 run 次数                            |
| `input_files.tsv`、`design_audit.mat`                          | 实际输入路径/字节数、候选设计秩和依赖来源                             |
| `native_call.mat`、`native_results.mat`                        | 传入的选项及官方返回的原生模型结果/设计信息                            |
| `analysis_mask.nii`                                           | 掩膜交集；有效分析范围                                       |
| `TYPEA/onoff_beta.nii`                                        | 折叠全部事件的总体响应，不是每事件 beta                            |
| `TYPEB/C/D/event_betas.nii`、`beta_mapping.tsv`                | 4D beta及逐帧事件映射；只生成实际请求的模型                         |
| 各类型 `R2.nii`、`meanvol.nii`                                    | 拟合度和基线；R² 不是显著性或留一 run 预测准确率                      |
| `HRFindex.nii`、`noisepool.nii`、`pcvoxels.nii`、`FRACvalue.nii` | 有相应原生输出时保存选择结果                                    |
| `run_*_candidate_PCs.tsv`                                     | 全部候选 PC，不表示每个都被最终选用；实际 pcnum 见 JSON/MAT           |
| `model_outputs.tsv`、`glmsingle_qc.json`                       | 模型类型、图像路径、单位及数值检查范围                               |
| `glmsingle_diagnostics.png`                                   | 本包的事件顺序/拟合度概览，非官方完整图集                             |

第四轴是 `beta_index`，**不是采集时间**；按清单 run 顺序，再按该 run 的 onset 格点排列，源表即使无序也保留原行号。调用后核对原生 `stimorder/numtrialrun/design`，禁止截短或重排后失去映射；全部导出 beta 均回读核查，掩膜内与原生结果一致、掩膜外为 NaN。

`wantPercentBold=true` 使用原生公式 `100×beta/abs(meanvol)`，否则为输入强度单位。它不同于 SPM 的 session grand mean scaling。D 的尺度/偏移校准由原生默认 `wantautoscale=1` 实现，完整结果保留 `scaleoffset`；不能把它直接视为未正则化 OLS。

适配层调用原生函数时使用 NaN 输出目录、关闭原生文件写入，把返回值自行保存到新目录，避开官方函数清空既有输出目录的行为。因此保留 A/B/C/D 原生结果和设计信息，但不声称保存了官方 RUNWISEFIR 文件及全部原生图集。

这里不产生 `SPM.mat`、T/F 图或可直接用于本包二级单样本分析的 `subject_contrasts.tsv`。将事件 beta 聚合成被试级标量、进行 RSA/MVPA 或组推断，需要另行定义估计目标与统计方法，特别要考虑正则化和选择步骤。

##
