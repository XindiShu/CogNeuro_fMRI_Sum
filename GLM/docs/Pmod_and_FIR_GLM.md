# pmod 与 FIR：理论、总配置与代码实践



## 1. 实现范围与方法选择

| 目标                 | 配置路线                               | 当前输出                                       |
| ------------------ | ---------------------------------- | ------------------------------------------ |
| 事件属性是否调节响应幅度       | `pmod.enabled=true`，canonical 或其导数 | 原条件对比；每个调节量每一阶的 canonical T 对比             |
| 不预设 canonical 响应形状 | `hrf.type='fir'`                   | 每个 bin 的 T 对比；预选 bin 均值；可选整体 F 检验          |
| 同一人的多个 run         | `level='subject'`                  | run 特异系数的等权平均；保留独立事件、混杂、截距与高通              |
| 多人标量效应             | `level='group'`                    | 使用一致定义的 pmod 斜率、FIR bin 或时间窗均值效应图；沿用单样本组模型 |

pmod、FIR 当前均要求 `model.unit='condition'` 且 `fit.strategy='joint'`。尚未实现 pmod+FIR 同时使用、trial/item/LSS 的 pmod/FIR、跨调节量交互、自定义调节量差值、多项式整体 F、负时间 FIR bin 或 GLMsingle。配置不支持的组合会报错。原有逐 run LSA/LSS 与 canonical 模型继续支持。

多被试不是 pmod/FIR 的必要前提。pmod 需要真实逐事件数值；FIR 需要足够时间信息和可估设计。增加被试数不能替代这些条件。

## 2. pmod：事件属性与响应幅度

对条件 $c$，在其每个事件 $i$ 的输入上同时加入基本事件幅度与调节量：

$$
y(t)=\sum_c\beta_c[u_c*h](t)+\sum_{c,j,p}\beta_{cjp}[u_{cjp}*h](t)+X_N\gamma+\epsilon,
$$

$$
u_{cjp}(t)=\sum_{i\in c}z_{ij}^{p}\,b_i(t),\qquad
z_{ij}=(m_{ij}-a_{cj})/s_{cj}.
$$

$b_i$ 是事件 stick 或有持续时长的输入，$h$ 是 HRF。pmod 在事件幅度上起作用，随后与 HRF 卷积；它不是把事件向量当成每帧混杂列，也不是先从 BOLD 回归掉行为变量。[SPM 模型说明](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/)说明了逐事件参数调节与多项式展开；[官方参数建模示例](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/faces/parametric/)演示二阶调节。

默认 `center='within_condition'`，即各 run 各条件分别减去该调节量的事件算术均值；`scale='none'` 保留原单位。基本条件系数对应变换后的调节值为 0 时的响应。持续时长不同或事件重叠时，不应把它直接等同于未经建模的平均 BOLD。

`center='none'` 保留原点，此时主效应解释依赖原始数值的 0。`scale='zscore'` 要求中心化，再除以各 run 各条件的样本标准差。标准化后斜率表示一份该 run 标准差的效应；原单位斜率和标准化斜率不是同一个统计量。跨 run/人比较须采用一致且有依据的尺度。

多项式最高阶 `poly=2` 会同时加入 `z` 与 `z²`，而非只加入二次项。支持整数 1..6，检查有限性、变异和事件层展开的秩；高阶不代表更合理。默认同时拟合时，某一阶的系数是在控制其他阶与其他调节量之后的条件效应。

### 2.1 正交化必须显式决定

`orthogonalize=false` 是本包默认值，保留列之间的共享变异，由联合 GLM 估计条件效应。事件中心化不能保证卷积、采样后的设计列正交。

`true` 使用 SPM 的串行正交化：先基本事件输入，再按 `modulators` 数组顺序及多项式阶数处理；SPM 在输入和卷积后的设计阶段都涉及正交化。后列解释相对前列剩余的变异，交换调节量顺序会改变系数的解释。这不是自动解决共线性，也不保证所有列可估。

具体调用保留 stock SPM 的 `cond.pmod` 与 `cond.orth`，可复核本机 `spm_get_ons.m` 和 `spm_fMRI_design.m`。框架先执行明确的中心化/缩放，再把数值交给 SPM；没有隐式替用户选择行为学变量。

### 2.2 参数和事件模板

以下字段均在 `config/glm_config.m`：

```matlab
cfg.level='subject'; % [可调] run=单run；subject=同人多个run
cfg.model.unit='condition'; % [约束] 本阶段pmod按条件联合建模
cfg.fit.strategy='joint'; % [约束] 不用于LSS
cfg.hrf.type='canonical'; % [可调] 也可canonical_time/canonical_time_dispersion
cfg.pmod.enabled=true; % [可调] 开启pmod
cfg.pmod.modulators=struct('condition','conditionA','column','difficulty', ...
    'name','difficulty','poly',1); % [必改] 条件、事件列、安全名称、最高阶；顺序影响正交化
cfg.pmod.center='within_condition'; % [可调] 各run各条件中心化；或none
cfg.pmod.scale='none'; % [可调] 原单位；或zscore（要求中心化）
cfg.pmod.orthogonalize=false; % [可调] 是否SPM串行正交化
cfg.execute=false; % [可调] 准备后审查；实际估计需true
```

多个调节量使用结构数组，例如：

```matlab
cfg.pmod.modulators(1)=struct('condition','conditionA','column','difficulty','name','difficulty','poly',2); % [示例] 线性和二次
cfg.pmod.modulators(2)=struct('condition','conditionA','column','rt_seconds','name','rt','poly',1); % [示例] RT必须事先统一到秒
```

事件模板为 `config/glm_events_pmod_template.tsv`。每行仍是原本的事件，附加数值列即可；调节量的单位由研究者定义并在研究记录中说明。本模块不自动把 ms 转成 s、不插补、不把缺失响应填成 0，也不自动删除事件。仅非适用条件允许 `n/a`；对应条件的每行必须有有限实数且至少有变异。条件、SPM 名称及列名采用字母开头的字母/数字/下划线标签，同条件调节量名称不可重复。

`amplitude/modulation/pmod` 这类容易被误解为自动加权的列，必须显式声明为调节量，否则报错。关闭 pmod 时 `modulators` 必须是空结构数组，避免配置被无提示忽略。

### 2.3 对比和审计文件

基本条件对比仍由 `conditions/contrastNames/contrastWeights` 指定。额外自动输出例如 `pmod_conditionA_difficulty_power_1` 和 `..._power_2`；导数模型仍只检验每一阶的 canonical 系数，导数及其他混杂列权重为 0。并未自动建立“条件 A 的斜率减条件 B 的斜率”。

`pmod_values.tsv`（被试模型为 `run_001_pmod_values.tsv` 等）记录原事件行号、条件、原列名、调节量名、原值、实际送入 SPM 的值、中心、尺度及阶数；源事件表不改写。串行正交化后的实际列还须查看 `SPM.Sess.U` 和 `SPM.xX.X`，不能只看中心化表。

## 3. FIR：用多个时间 bin 估计响应

FIR 用一组有限支持的时间窗替代 canonical HRF：

$$
h_c(\tau)=\sum_{b=1}^{B}\beta_{cb}\,I[(b-1)\Delta\le\tau<b\Delta],\quad \Delta=W/B.
$$

它增加估计列数，允许更灵活的响应形状，同时需要更多信息、自由度与对设计的检查。事件重叠或时序规则会导致 bin 相关甚至不可估；框架不靠自动删 bin 或删事件来“修复”。[SPM 基函数说明](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/#other-basis-sets)要求指定窗口长度与基函数阶数。

事件表达仍是独立选择：

- `impulse`：把每个事件视为 onset 上的脉冲，FIR 系数可用于描述 onset 锁定的响应。这是明确改变建模表达，源持续时长仍保留。
- `duration`：保留事件时长并与 FIR 卷积；长区块下系数描述的是对持续输入的核，不能直接叫作 onset 后原始 BOLD 时间曲线。
- `fixed`：全部使用配置的固定时长，须有实验依据。

FIR 不会自动推断哪种表达最符合你的问题，也不会自动选择显著体素画“代表性 HRF”。

### 3.1 窗口、bin 与微时间

```matlab
cfg.pmod.enabled=false; % [约束] 当前FIR不与pmod合用
cfg.pmod.modulators=struct('condition',{},'column',{},'name',{},'poly',{}); % [约束] 清空pmod定义
cfg.hrf.type='fir'; % [可调] 使用SPM原生FIR
cfg.hrf.fir.windowSeconds=20; % [可调] 窗口0..20秒；不是高通周期
cfg.hrf.fir.nBins=10; % [可调] 10个bin，每个2秒
cfg.hrf.fir.summaryBins=[3 4 5]; % [可调] 预先指定bin均值；空=所有bin
cfg.hrf.fir.includeOmnibus=true; % [可调] 额外整体F检验
cfg.events.expression='impulse'; % [可调] onset锁定表达，按研究问题选择
```

`windowSeconds>0`，`nBins` 为正整数，`summaryBins` 为不重复的 1..B 编号。窗口从 0 秒开始；当前没有负时间窗参数，也不隐式平移 onset。

SPM 原生代码把每个 bin 离散成 `round(Δ/dt)` 个微时间格，`dt=TR/microtimeResolution`。本包要求该比值为整数，允许 NIfTI 时间头浮点表示误差，但拒绝实质性的自动取整；实际 `fir_time_bins.tsv` 从 SPM 已生成的基函数长度和 dt 计算边界。

例如 HCP `TR=0.72 s`、微时间分辨率 16 时，dt 约 0.045 s，窗口 21.6 s、10 个 bin 对应每 bin 48 个微时间格，即约 2.16 s；默认 20 s/10 bin 在该 TR 上不满足约束，需要显式调整。采样仍受微时间参考 `microtimeOnset` 及事件离散化影响，bin 边界不是精度无限的生理时标。

### 3.2 三种对比的含义

每个原条件对比（例如 A−B）扩展为：

| 输出名后缀          | 类型  | 检验/效应                   |
| -------------- | --- | ----------------------- |
| `_bin_001` 等   | T   | 指定 bin 的有符号条件差异         |
| `_window_mean` | T   | 预选 bin 系数的等权平均；不是积分/AUC |
| `_all_bins`    | F   | 所有 bin 的对应条件差异是否共同为 0   |

跨 run 时，先对匹配 bin 的 run 特异效应取等权平均，再构建上述对比；F 检验针对平均曲线，不能解读为“任何一个 run 有效即检出”。每个 run 仍独立检查高通后的代数自由度及全部请求对比的可估性。

整体 F 使用 bin 间协方差，不是各 bin t 值的平均或平方和。它没有方向，也不直接表明峰值在哪个 bin。预选时间窗应在看结果前确定；大量 bin/对比/脑区仍涉及多重比较，本模块不自动完成推断校正。

#
