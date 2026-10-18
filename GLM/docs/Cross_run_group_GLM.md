# 跨 run GLM 与单样本组统计：理论、配置与实践



## 1. 实现范围

| 层级        | 当前支持                                                                    | 当前不支持                                      |
| --------- | ----------------------------------------------------------------------- | ------------------------------------------ |
| `run`     | 现有条件、event、trial、item、block、phase、trial_phase；joint 或受支持的 LSS 组合        | pmod、FIR、GLMsingle、Bayesian                |
| `subject` | 条件均值 + joint；多个 run 放入一个 SPM 一级模型；canonical HRF 及时间/弥散导数；同一对比的 run 等权平均 | 跨 run LSA/LSS 目标汇总、逆方差合并、不同 TR 或不同网格的自动重采样 |
| `group`   | 每人一张效应图的单样本 t；正向和负向 T 图；共同覆盖掩膜                                          | 两组、配对、协变量、多因素/重复测量、置换、FWE/FDR/簇推断          |

这些限制是接口实现范围，不是因为只有一名被试。pmod 主要依赖逐事件调节变量，FIR 依赖时间采样与设计可估性，[GLMsingle 的部分功能](https://glmsingle.readthedocs.io/en/latest/wiki.html)依赖跨 run 的刺激重复；增加被试数不会自动补齐这些输入。

## 2. 跨 run：为什么每个 run 独立建模

对同一被试第 $r$ 个 run，建立

$$
y_r=X_{task,r}\beta_r+X_{nuisance,r}\gamma_r+1_r\alpha_r+\epsilon_r.
$$

多个 run 放入 SPM 的不同 session 分区。这里的 SPM session 表示连续采集段，不必等同于清单中的访视 `session`。各 run 的 onset 都相对自己的第一帧，保持秒单位；不把 run 2 的 onset 加上 run 1 的长度。任务列、混杂列、截距及高通分区均保留 run 边界，避免把中间暂停当成连续采样。

若条件顺序为 `A,B`，两个 run 的条件差异分别为 `A₁−B₁` 和 `A₂−B₂`，被试效应为

$$
\hat\theta_s=\frac{1}{R_s}\sum_{r=1}^{R_s}(\hat\beta_{A,r}-\hat\beta_{B,r}).
$$

只有 canonical HRF 时，任务部分权重是 `[1/2,-1/2,1/2,-1/2]`；包含时间、弥散导数时，每个条件的 `bf(2),bf(3)` 权重均为 0。代码按 SPM 列名定位所有权重，混杂列与截距权重为 0，不依靠固定列号猜测。

这是在同一个一级模型内对 session 特异效应作算术平均，SPM 估计其标准误；不是对若干 `con` 图做逆方差固定效应汇总，也不等价于按 run 长度加权。不同 run 允许帧数与混杂列数量不同，但每个 run 都必须包含配置中的全部条件，并分别通过高通后的自由度和对比可估性检查。

SPM fMRI 一级模型即使 `global='None'`，仍有 session grand mean scaling，实际缩放记录在 `SPM.xGX.gSF`。这里输出的是相应缩放单位的效应，不能直接称为逐体素百分信号变化。不同任务、强度标度或预处理流程的效应也不能仅因网格相同就直接合并。[SPM 模型说明](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/)；安装版实现可查 `spm_fmri_spm_ui.m` 的 gSF 计算与 `spm_run_fmri_spec.m`。

## 3. 配置及启动

路径均可使用 Windows 绝对路径；清单中的相对路径相对清单所在目录解释。输出根目录必须是全新的目录。输入仍为未做时间滤波、未预先回归混杂的 BOLD，`temporal_state=unfiltered_unregressed`。

在 `config/glm_config.m` 中修改以下字段，然后运行 `run_glm`：

```matlab
cfg.manifestFile='E:\my_study\runs.tsv'; % [必改] run清单；每行一个真实采集段
cfg.outputRoot='E:\my_study\derivatives\subject_glm_v1'; % [必改] 新目录
cfg.level='subject'; % [可调] 被试内多个run联合估计
cfg.subject.combineSessions=false; % [可调] false按subject/session分开；true同被试跨访视合并
cfg.model.unit='condition'; % [约束] 目前跨run仅条件均值
cfg.fit.strategy='joint'; % [约束] 目前跨run采用联合模型
cfg.conditions={'A','B'}; % [必改] 每个run的完整条件集合，固定顺序
cfg.contrastNames={'A_minus_B'}; % [必改] 对比名，唯一且非空
cfg.contrastWeights=[1 -1]; % [必改] 每个run内部的条件权重，框架自动除以run数
cfg.execute=false; % [可调] 先准备作业；改true实际指定、估计和生成对比
```

`combineSessions=false` 时，同一个人的 baseline 和 followup 分别产生一个模型，不能未经处理把两张图都送入独立被试单样本检验。`true` 只表示用户明确要估计跨访视平均；如果目标是访视变化，应设计被试内差值或重复测量分析，当前组模块不自动代替这一设计。

`highpassSeconds`、`serialCorrelation`、微时间设置、`design.*`、`maskThreshold` 和 `minResidualDF` 仍在同一个配置文件中。`minResidualDF` 在一级模型逐 run 检查，组模型改由 `group.minSubjects` 控制。各 run 的显式掩膜（清单可选 `mask` 列）均作用于共同模型覆盖；须检查实际 `mask.nii`。SPM 中的空 `explicitMask` 不表示解剖覆盖已获认可。

准备模式生成 `model/specification.mat`，不生成 `SPM.mat`、beta、con 或完成标记。估计成功后，输出例如：

```text
subject_glm_v1/
  batch_status.tsv
  subject_contrasts.tsv
  sub-participant01/ses-baseline/combined/
    run_mapping.tsv
    run_001_event_mapping.tsv
    subject_plan.mat
    subject_contrasts.tsv
    GLM_SUBJECT_COMPLETE.mat
    model/
      SPM.mat
      design_audit.mat
      model_diagnostics.json
      model_diagnostics.png
      mask.nii
      con_0001.nii
      spmT_0001.nii
```

无访视标签时省略 `ses-*`。`run_mapping.tsv` 记录清单顺序、原始输入路径、TR、帧数与等权系数。事件映射保留原始 onset/duration 与建模时长。残差 ACF 按各 run 分别计算，禁止把一个 run 的尾帧与下一个 run 的首帧拼成 lag 配对；诊断仍是掩膜内确定性体素采样。

只有整个被试批次全部成功，才生成根目录的 `subject_contrasts.tsv`；有失败时保留成功输出和状态记录，但不自动发布缩小样本的组分析清单。

## 4. 从被试效应到组统计

单样本二级模型为

$$
\hat\theta_s=\mu+e_s,\quad t=\frac{\bar\theta}{s_\theta/\sqrt N},\quad df=N-1.
$$

这里每个观测是一个独立被试，run 不是样本量。同一被试的多个访视也不是独立样本。一级模型输出的未阈值化 `con_*.nii` 可以作为输入；不要使用 `spmT_*.nii`、阈值化显著图或任意未匹配的 beta 图。[SPM 二级教学示例](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/beginners/fmri/second_level_example/)采用一级效应图进入二级模型。

可直接使用上一步成功输出的 `subject_contrasts.tsv`，或依照 `config/glm_group_template.tsv` 编写清单：

| 列                | 含义与约束                            |
| ---------------- | -------------------------------- |
| `subject`        | 独立被试 ID；同一对比中只允许出现一次             |
| `session`        | 可为空，作为来源记录；不会让重复被试变成独立样本         |
| `contrast`       | 效应名称；每个名称建立一个组模型，同一批次使用一致的显式被试集合 |
| `contrast_image` | 未阈值化、同定义同尺度的效应图；必须是一张 3D 图       |
| `mask`           | 对应一级模型的实际分析掩膜；不能为空               |

图像与掩膜必须同网格；不同被试指向同一个效应文件会报错。显式声明同一批次各对比的共同被试集合，可以防止缺失对比造成无提示的样本变化；不自动剔除失败/缺失被试。输入路径独立并不能证明受试者生物学上独立，HCP 亲属关系等仍须由研究设计审查。

在总配置中改为：

```matlab
cfg.level='group'; % [必改] 读取效应图清单，不再读取BOLD/run清单
cfg.manifestFile='E:\my_study\derivatives\subject_glm_v1\subject_contrasts.tsv'; % [必改] 组清单
cfg.outputRoot='E:\my_study\derivatives\group_glm_v1'; % [必改] 新目录
cfg.group.design='one_sample'; % [约束] 单样本t，无协变量
cfg.group.minSubjects=3; % [可调] 最小独立被试数；不能据此判断统计功效足够
cfg.execute=false; % [可调] 准备后检查；实际估计需true
```

`conditions`、事件表达、HRF、一级混杂和高通等字段在 group 层级不参与建模；二级以清单的 `contrast` 标签为准。`explicitMask` 可进一步限制组覆盖。`qc.plot` 控制一级诊断图，二级输出数值 QC、SPM 设计和清单，不计算时间残差 ACF。

组掩膜是所有被试分析掩膜与可选全局掩膜的交集，保存为 `coverage_intersection.nii`。不对有符号效应图施加正值/相对强度阈值；掩膜内的合法零效应继续参与统计。最终 SPM `mask.nii` 还可能排除无法估计残差方差等无效体素，应检查最终覆盖。

每项对比输出 `contrast_001/` 等编号目录，`subjects_used.tsv`、`summary.json` 和根目录 `batch_status.tsv` 记录实际含义。`con_0001/spmT_0001` 是正向均值，`con_0002/spmT_0002` 是反向均值。两张单向图不自动构成经过多重比较校正的双侧推断。本模块不自动出显著脑区列表，也不把 T 图称为已经成立的科学发现。

##
