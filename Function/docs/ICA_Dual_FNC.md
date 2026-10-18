# 空间组 ICA、双回归与 FNC



## 一、方法在分析什么

### 1. ICA把数据拆成什么

对每run的时间×体素矩阵Y，空间ICA近似寻找 Y≈T×S：S的每行为空间成分，T的每列为成分时间曲线。独立约束针对空间分布，不代表脑区或神经源在生物学上完全独立。

程序逐run去均值/可选除体素SD，逐run PCA压缩后拼接，再组PCA和原生GIFT FastICA。nComponents是最终成分数；perRunPca是进入组分解之前每run保留的维度，不能小于成分数或超过实际秩。

### 2. 为什么还要双回归

| 阶段       | 固定什么       | 同时估计什么           |
| -------- | ---------- | ---------------- |
| 第一阶段空间回归 | 全部共享成分空间图  | 每run全部成分时序，联合OLS |
| 第二阶段时间回归 | 第一阶段全部成分时序 | 每run各成分空间图，联合OLS |
| FNC      | 所得成分时序     | 成分之间的静态Pearson相关 |

联合估计可区分共享解释的成分；不是每个成分分别与数据相关一次。normalizeStage2Timecourses改变第二阶段时序单位，因此会改变图幅度；这不是随手美化图像的开关。

### 3. 成分数与稳定性

成分多可能分出更细模式，也更易拟合噪声；成分少可能合并网络。增加maxIterations/tolerance只改变数值停止条件，不等于ICASSO稳定性或已识别伪影。本包不自动把运动/血管成分删除。

#

## 二、运行前准备

TSV为subject/session/run/data_file。每个MAT/data含y、featureIds、trSeconds；所有run须同一特征身份/顺序。体素ICA推荐先用通用准备器mode='voxels'、共同mask；或逐run调用cog.prepare_ica_nifti。

有data.space时可写NIfTI成分图；没有space时仍可算矩阵ICA，但不能凭空输出正确空间图。脑图来自何空间由使用者提供的reference决定。

| 字段                     | 形状/类型              | 具体含义               |
| ---------------------- | ------------------ | ------------------ |
| y                      | T×V                | 每run时间×同一共同特征      |
| featureIds / trSeconds | V个身份 / 秒           | 各run精确一致的特征顺序      |
| space                  | cog.load_bold返回，可选 | 有它才能把空间成分写回正确NIfTI |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_ica.m](../examples/start_ica.m)。MATLAB可用 `run('E:/my_study/start_ica.m')` 运行自己另存的脚本。

```matlab
% ica启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=ica_config;
cfg.manifestFile='E:/my_study/prepared_voxels/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/ica_run01';
cfg.giftPath='D:/matlab/atoolbox/gift_minimal_df369a2';
cfg.nComponents=5;
cfg.perRunPca=20;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_ica(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### ica_config.m

| 运行时字段                            | 实际修改/默认来源位置              | 当前默认                                                     | 候选、约束及理论/运行作用                                                                                           |
| -------------------------------- | ------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`               | config/ica_config.m 第4行  | `fullfile(root,'config','ica_runs.tsv')`                 | subject/session/run/data_file；MAT中data含y/featureIds/trSeconds；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`                 | config/ica_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_ica')` | 新绝对输出目录，不覆盖；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                 |
| `cfg.giftPath`                   | config/ica_config.m 第6行  | `''`                                                     | 含icatb_fastICA.m的官方GIFT目录；本机最小依赖在D:/matlab/atoolbox/gift_minimal_df369a2。                               |
| `cfg.execute`                    | config/ica_config.m 第7行  | `false`                                                  | false读取所有矩阵与索引校验；true实际ICA和双回归；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                               |
| `cfg.nComponents`                | config/ica_config.m 第8行  | `10`                                                     | 正整数，空间成分数，不能超过任一run数据秩。                                                                                 |
| `cfg.perRunPca`                  | config/ica_config.m 第9行  | `30`                                                     | 每run保留的PCA维度，>=成分数且<=时间/空间秩；每run同权维度拼接。                                                                 |
| `cfg.voxelVarianceNormalize`     | config/ica_config.m 第10行 | `true`                                                   | 每run每体素去时均值后除样本标准差；group与dual均用同一处理数据；true每run每体素去均值/除SD，减小幅度尺度差；false保留方差差异。                           |
| `cfg.normalizeStage2Timecourses` | config/ica_config.m 第11行 | `true`                                                   | 双回归第二阶段将stage1时序除样本标准差，影响图幅度；true先把stage1时序除样本SD再做第二阶段回归，会改变图幅度含义。                                      |
| `cfg.maxIterations`              | config/ica_config.m 第12行 | `500`                                                    | FastICA最大迭代正整数；返回完整矩阵不证明稳定性。                                                                            |
| `cfg.tolerance`                  | config/ica_config.m 第13行 | `1e-6`                                                   | FastICA停止容差，正数。                                                                                         |
| `cfg.seed`                       | config/ica_config.m 第14行 | `17`                                                     | 固定随机种子；函数退出恢复调用者RNG；随机种子；控制复现，不改变零假设、不能用挑种子优化结论。                                                        |

## 六、结果

| 文件/结构                     | 应检查什么                                    |
| ------------------------- | ---------------------------------------- |
| ICA.mat                   | 共享成分、PCA信息及所有run双回归结果                    |
| 每run/dual_fnc.mat         | 时序、空间系数、FNC和归一化设置                        |
| component_timecourses.tsv | 时间点×成分，顺序对应共享成分                          |
| ICA_COMPLETE.mat          | 完整调用成功；componentStabilityAssessed仍为false |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

此模块把逐 run PCA、时间拼接 group PCA、GIFT 的 FastICA、逐 run 双回归和静态成分间 FNC 接成可复用流程。它是显式矩阵接口和原生 FastICA 的包装，不是完整 GIFT GUI 管线。没有实现 ICASSO、自动成分数估计、Neuromark、ICA-AROMA、自动噪声成分判别、阈值化双回归或群体置换检验。

### 环境与输入准备

- 新配置在 `config/ica_config.m`。
- `giftPath` 指向含 `icatb_fastICA.m` 的官方 GIFT 路径；
- 本机已下载自含的该函数到 `D:/matlab/atoolbox/gift_minimal_df369a2`。
- 固定官方仓库 commit `df369a2f73aab06c4fe97a10ffab841320722281`，SHA256 `E4281A620BC26E11D960582EDDA1D61AAAC27241B5819096611846177379C5C8`，来源与日期保存在该目录 `PROVENANCE.json`，同时保留官方 README 和原函数版权头。
- 仓库未发现总 LICENSE，故这里不推定授权条款、不将后端源码随 Function 再分发；
- 在本机按官方公开源码运行。
- SPM 用于 NIfTI IO，本轮 SPM12 revision7771／MATLAB R2025b。

清单模板为 `config/ica_runs_template.tsv`，列 `subject/session/run/data_file`。session 可空，同一个人可有多个 session/run；所有键唯一，ID 用字母、数字、下划线或连字符。MAT 文件需含 `data`：

| 字段         | 定义                                                                   |
| ---------- | -------------------------------------------------------------------- |
| y          | 时间点×共同空间特征的有限实数矩阵                                                    |
| featureIds | 每列特征的唯一、非空 ID，全部 run 的身份及顺序必须严格一致                                    |
| trSeconds  | 该 run 的 TR，秒，正数；FNC 是零时滞相关，本流程不统一重采样不同 TR                            |
| space      | 可选，`cog.load_bold` 的空间结构；全体均提供时检查 affine、维度、掩膜索引并写 NIfTI 图，否则全体只输出矩阵 |

- NIfTI 可用 `cog.prepare_ica_nifti(bold,commonMask,trSeconds,confounds,cleanOptions,maxMatrixGiB,newMatFile)` 准备。
- 需要解压的 `.nii` 工作副本、已对齐的共同掩膜及真实 TR；
- 原始输入只读。
- `cleanOptions` 与 `function_config.m` 的 `clean` 字段一致：截距、可选趋势、混杂、可选 DCT 频率基联合投影。
- 已清理数据不要无记录地再次去噪。
- 每次写新的 MAT 文件。
- 适配器不做配准、跨空间重采样或自动寻找共同有效掩膜。

### 计算与参数

- `execute=false` 读取清单及矩阵、核对身份和空间；

- `execute=true` 实际运行。

- `outputRoot` 必须为新绝对目录。

- `nComponents` 为预先指定成分数；

- `perRunPca` 是每个 run 保留的维度，至少等于成分数且不能超过数据数值秩。

- 每个 run 至少需 `perRunPca+2` 时间点和空间特征。

- 恒定体素报错，不能在各 run 静默删除不同列。

- 每 run 去时间均值，`voxelVarianceNormalize=true` 时再除每体素样本标准差。

- 保存每 run PCA 保留方差比例；

- 把各 run 的降维分数在时间方向拼接，再 group PCA 到指定成分数，调用 GIFT 对空间维做 symmetric/tanh FastICA。

- 每 run 同样保留 PCA 维度，但多个 run 的被试会贡献多个数据块；

- 此基础流程没有按独立被试重新平衡权重。

- 原生 mixing/separating 矩阵对应原生分解尺度；

- 交付的 groupMaps 为每成分空间中心化/标准化图，并把最大绝对体素置正。

- 成分符号和排列不可识别，跨次分析需显式对齐。

`seed` 固定随机初始化并在函数退出后恢复调用者 RNG。`maxIterations/tolerance` 控制原生停止规则。完整有限矩阵只是工程检查，`componentStabilityAssessed=false`；单次分解不能代替重复初始化稳定性或 ICASSO。

- 双回归使用相同预处理数据：第一阶段把所有 group maps 加空间截距联合回归到每帧，取时间序列并去时间均值；
- 第二阶段把所有成分时序加时间截距联合回归到体素数据。
- `normalizeStage2Timecourses=true` 时，第二阶段回归列先除样本标准差，图的幅度含成分时序幅度。
- 保存原始 stage1 时序、实际 stage2 回归列、个体空间系数图和残差均方。
- 时序不满秩或恒定时拒绝，不用伪逆隐藏问题。
- FNC 为 stage1 时序的 Pearson r 与 Fisher z，保留负边，不输出显著性推断。
- 自相关、模型选择、群体设计和多重比较需要另行处理。

`run_ica(cfg)` 输出根目录 `ICA.mat`、group component 图及完成标记；各 subject/session/run 下有 `dual_fnc.mat`、时序 TSV 和个体双回归图。已有目录拒绝覆盖。没有把所有 run 的时间点当成独立被试做群体统计。
