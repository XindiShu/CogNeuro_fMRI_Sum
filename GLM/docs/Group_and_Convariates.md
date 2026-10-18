# 二级 GLM：配对、两组比较与协变量回归

本步骤在已有单样本 t 的基础上加入配对 t、独立等方差两样本 t、多元回归，以及单样本/两组模型的共同斜率协变量。仍使用 SPM12 的设计指定、Classical 估计和对比生成。总参数代码为 `config/glm_config.m`，启动代码为 `run_glm.m`；可复现的全合成示例为 `examples/validate_glm_group_engineering.m`。

本次示例验证的是代码、设计矩阵、输入保护和数值一致性。所有新演示被试、组别、年龄和行为分数均为合成数据，没有给真实 HCP 被试虚构分组或人口学变量。先前真实 HCP 的单样本和一级分析结果继续保留，本轮不重新预处理或重估这些模型。

## 1. 各层级的估计单位

一级 GLM 的观测是时间点，条件/pmod/单事件项解释 BOLD 时间序列；二级 GLM 的观测是独立被试的效应图。一级的一张 `con_*.nii` 通常可作为二级输入，方向、单位和生成方法应在被试间保持一致。不能将每个 run 或每个 trial 当成一个独立被试，也不能直接用 `spmT/spmF/ess` 图替代效应图。[SPM 单样本教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/group/one_sample_ttest/)

| 目标         | `cfg.group.design` | 观测/设计                   | 本包输出的主要方向                             |
| ---------- | ------------------ | ----------------------- | ------------------------------------- |
| 群体平均效应     | `one_sample`       | 每人一图，截距                 | 均值大于/小于 0；有协变量时为指定原点上的调整均值            |
| 同一人的两种测量比较 | `paired`           | 按 ID 配对，先求每人的差值，再做单样本 t | `pairedLevels{1}` 减 `pairedLevels{2}` |
| 两个独立组比较    | `two_sample`       | 每人一图，两个组指示列             | `groupLabels{1}` 减 `groupLabels{2}`   |
| 连续变量与效应的关系 | `regression`       | 每人一图，截距及至少一个数值协变量       | 截距及每个协变量斜率的正/负 T 对比                   |

这里的二级协变量是被试间变量，与一级试次内的 pmod 是不同层级。单样本和两组模型也可添加协变量。配对分支本轮不开放协变量；多因素、超过两个水平的重复测量及混合效应模型另需实现。

## 2. 配对 t：先匹配，再求差

对第 $i$ 人，按配置的两个 `pair_level` 取图并计算：

$$
d_i(v)=y_{i,1}(v)-y_{i,2}(v),\qquad t(v)=\frac{\bar d(v)}{s_d(v)/\sqrt N},\quad df=N-1.
$$

本包在新目录保存差值图，然后交由原生 SPM 单样本模型估计。这与检验每人的配对差值均值为零等价。匹配使用 `subject` 和 `pair_level`，不使用 TSV 的相邻行、不按文件名字母顺序猜测。`session` 记录来源，两张图可以来自不同 session，也可以是同一 session 的两个被试级对比；它不自动决定配对水平。

每人必须恰好有两个配置水平的各一张图。缺测、重复水平或未配置标签直接报错，不自动删除不完整被试。所有源图的有效掩膜取交集；差值图在交集外写 NaN，交集内保留合法零值。只准备时也会生成差值图，便于检查，但不估计 SPM 模型。

如果原有两种一级对比来自同一模型，正式分析还需要判断是否应直接在一级构造差值对比。本例的通用接口不替代该设计判断。

## 3. 两独立样本：明确等方差假设

本轮两组模型采用独立观测、共同误差方差：

$$
y=X\beta+\epsilon,\quad X=[I(G_1),I(G_2)]
$$

不另加全体截距，主要对比为 `[1 -1]`。无协变量时，它对应合并方差的两样本 t：

$$
s_p^2=\frac{(n_1-1)s_1^2+(n_2-1)s_2^2}{n_1+n_2-2},\quad t=\frac{\bar y_1-\bar y_2}{s_p\sqrt{1/n_1+1/n_2}}.
$$

SPM batch 显式设置 `dept=0, variance=0, gmsca=0, ancova=0`。此实现不是 Welch 检验，也未开放 SPM 的非等方差 ReML 选项。使用者需要明确这个假设，而不是从输出文件名推断方差模型。[SPM 两样本设计与对比教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/group/two_sample_ttest/)

同一个 `subject` 不能同时进入两组。组顺序来自 `groupLabels`，不是根据样本值、组名排序或结果方向选择。每组默认至少 2 人，整项分析还须满足总人数和残差维度要求；这些下限服务于示例运行，不是正式研究的样本量建议。

## 4. 协变量：原点、共同斜率和可估性

`regression` 使用含截距的模型；例如两个变量时：

$$
y_i(v)=\beta_0(v)+\beta_1(v)(z_{i1}-c_1)+\beta_2(v)(z_{i2}-c_2)+\epsilon_i(v).
$$

`covariateCenter='overall'` 时，$c$ 是该变量全体被试的算术平均值；`none` 时 $c=0$。中心化不改变列的单位，本包不自动 z-score、不串行正交化、不插补缺失值，也不把文本类别自动编码为哑变量。若变量为年龄（年），斜率仍表示每增加一年对应的效应变化；若类别变量需要编码，应由清单明确提供数值及编码含义。

截距解释随原点变化：总体中心化时为所有协变量取其均值时的效应；不中心化时为协变量均为 0 时的效应。它可能落在样本支持范围之外，应结合数据解释。[SPM 对协变量及中心化的说明](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/group/one_sample_ttest/)

两组加协变量时采用共同斜率、无组别×协变量交互的模型：`X=[group1 group2 centered_covariates...]`，组间比较权重为 `[1 -1 0 ...]`。总体中心化不是组内中心化，本轮没有自动根据变量或结果切换中心化方式。

所有选择的协变量必须有限且有变异；缺失、常量列、线性相关、与组指示完全混淆、或残差维度不足都会报错。使用前检查整批每个效应对应的同一队列、同一人的分组和协变量是否一致。最终指定后还会比较 SPM 的实际 X 和审计 X，防止隐藏的重排/中心化改变对比含义。

## 5. 参数与输入清单

当前参数均在 `config/glm_config.m` 的 `cfg.group` 分支，一级的 `cfg.contrastWeights` 不用于这些自动生成的二级对比：

| 参数                 | 默认值                   | 修改含义                            |
| ------------------ | --------------------- | ------------------------------- |
| `design`           | `one_sample`          | 切换四种模型之一                        |
| `minSubjects`      | `3`                   | 每个效应的最少独立被试数，整数≥2               |
| `pairedLevels`     | `{'pre','post'}`      | 配对水平、方向为前减后；可设 `{'post','pre'}` |
| `groupLabels`      | `{'groupA','groupB'}` | 两组标签和比较方向                       |
| `minPerGroup`      | `2`                   | 每个独立组的最少人数                      |
| `covariateColumns` | `{}`                  | 从清单读取的数值列；回归至少一列，配对必须为空         |
| `covariateCenter`  | `overall`             | `overall/none`，见前述截距解释          |
| `minResidualDF`    | `1`                   | 二级 N-rank(X) 的下限，整数≥1；与一级同名要求分开 |

所有清单保留基本五列 `subject/session/contrast/contrast_image/mask`。`contrast` 是送入二级的效应名称，同一个批次可包含多项效应，分别估计模型。其他列必须与选择的设计及协变量配置严格对应，不能有未使用的分组/协变量列。

- 配对：另加 `pair_level`，参考 `config/glm_group_paired_template.tsv`。
- 两组：另加 `group`，参考 `config/glm_group_two_sample_template.tsv`。
- 回归/调整模型：按 `covariateColumns` 增加列，参考 `config/glm_group_regression_template.tsv`；模板分数明确为合成占位值，不是 HCP 的真实变量。

例：两组比较同时控制年龄和分数，则清单包含基本五列、`group`、`age`、`score`，配置中写 `covariateColumns={'age','score'}`。ID 按文本读取，保留前导零；相对路径以清单目录为基准。每张输入必须为同一空间网格的单张 3D 效应图，本包不自动重采样。

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab'); % [必查] 包位置
cfg=glm_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必改若不同] SPM安装目录
cfg.level='group'; % [约束] 二级模型
cfg.engine='spm_classical'; % [约束] 使用原生SPM估计
cfg.group.design='paired'; % [可调] 也可one_sample/two_sample/regression
cfg.group.pairedLevels={'post','pre'}; % [必查] 本例方向post-pre
cfg.manifestFile='E:\study\paired.tsv'; % [必改] 两水平的被试效应图清单
cfg.outputRoot='E:\study\group_paired_check'; % [必改] 新目录
cfg.execute=false; % [可调] 准备作业、配对差值和审计
report=psy.glm_batch(cfg); % 与run_glm.m相同的统一入口

cfg.outputRoot='E:\study\group_paired_fit'; % [必改] 估计使用另一新目录
cfg.execute=true; % [可调] 实际指定、估计并生成正反T对比
report=psy.glm_batch(cfg);
```

如需通过启动文件运行，修改 `glm_config.m` 对应参数后执行 `run_glm` 即可。无需修改已经定稿的 `toolkit_config.m`。

## 6. 输出与检查

每项输入效应对应 `contrast_001/` 等目录。模型指定/估计/对比的精确 batch 分别保存；已有目录一律拒绝覆盖。

| 文件                                                          | 内容                                |
| ----------------------------------------------------------- | --------------------------------- |
| `subjects_used.tsv`                                         | 本项效应最终顺序的源输入；两组先组1后组2，配对每人水平1后水平2 |
| `pairing.tsv`、`paired_differences/`                         | 仅配对：每人两张源图及新差值图；差值顺序对应设计矩阵行       |
| `design_matrix.tsv`                                         | 真正计划给 SPM 的列与数值；无自动尺度/方差加权        |
| `covariate_values.tsv`                                      | 被试、变量、原值、中心、建模值；无协变量则不生成          |
| `contrasts.tsv`                                             | 所有正负 T 权重和列顺序；每个协变量均有独立斜率对比       |
| `coverage_intersection.nii`、`mask.nii`                      | 所有源有效掩膜及可选全局掩膜的交集、SPM最终掩膜         |
| `input_hashes_before.tsv`、`input_hashes_after.tsv`          | 清单、源图和掩膜的前后字节/哈希；完成前必须一致          |
| `SPM.mat`、`beta_*.nii`、`ResMS.nii`、`con_*.nii`、`spmT_*.nii` | 实际估计的模型、系数、残差方差和未阈值化效应/T图         |
| `summary.json`、`verification.mat`、`glm_qc.json`             | 人数、输入数、比较方向、自由度、掩膜、方差假设和数值检查      |
| `GLM_GROUP_PREPARED.mat` / `GLM_GROUP_COMPLETE.mat`         | 仅准备/实际估计完成标记；错误不会生成成功标记           |

当前统一提供未阈值化 T 图，没有新增 FWE/FDR、簇推断、两侧合并 P 图或结果表。正向和反向 T 图是同一个效应的两个方向，不是独立检验样本；需要正式推断时应另外定义检验族、阈值与校正。

##
