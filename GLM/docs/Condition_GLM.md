# 条件GLM

本章对应同一条件共享响应幅度的GLM，常被称作条件平均GLM、categorical GLM或条件联合模型。具体改法见[方法操作指南](Methods_Summary.md)。

## 一、它估计的是什么

假设一个run里有4次story和8次数学事件。条件模型不为12行各估一个幅度，而是把story事件合成一个条件输入、math合成另一个条件输入，再分别估计两个共同幅度。

“平均”不是把story期间所有BOLD时间点直接相加除以次数。响应会延迟、持续、重叠，两个条件和头动等变量也会共享变化；GLM通过整个设计矩阵同时解释时间序列。共同幅度是在该设计、基线、混杂与误差模型下的系数。

- 若问题是“story相对math的共同响应是否不同”，条件模型直接对应它；

- 若问题是“每一道题的响应模式是什么”，需要逐事件LSA/LSS或适用的GLMsingle



## 二、从事件到设计矩阵

### 1. 先定义输入，再卷积响应

令第 $i$ 次事件的 onset 为 $o_i$，时长为 $d_i$。持续输入可写成

$$
u_c(t)=\sum_{i\in c}I[o_i\le t<o_i+d_i],\qquad x_c(t)=(u_c*h)(t).
$$

$h$ 为HRF。impulse表达则用onset处的脉冲替换方窗，fixed用共同建模时长。三个表达对应不同假设，不是同一列换个写法。

**参数对应：**第17行声明条件，第31行选duration/impulse/fixed，第33行仅fixed使用，第35行选HRF。事件秒数仍相对当前run第一帧；不因读取SPM模型而重减HCP Sync。[SPM模型指定](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/)

### 2. 一个体素上的模型

$$
y=X_{task}\beta+Z\gamma+\epsilon.
$$

对于A1、A2、B1、B2四次事件，令a1等表示已经卷积和采样的单事件列，则

```text
条件模型 Xtask = [a1+a2, b1+b2]
LSA模型  Xtask = [a1, a2, b1, b2]
```

条件模型相当于对同条件事件施加共享幅度约束。例如真实每次响应有差别，它估计的共同幅度也受事件重叠、设计相关和误差权重影响，不保证等于LSA beta的简单算术平均。

$Z$ 包括实际选择的混杂和SPM run截距。第144行继承design_config，第146行默认不额外加入显式线性趋势；默认头动24项、组织均值true需结合表中列及来源核对，当前HCP教学常覆盖组织均值为false。

### 3. 怎样估计与检验

为理解估计，可将高通和估计的白化变换记为 $T$，得到 $y^*=Ty,\ X^*=TX,\ Z^*=TZ$。在简化的已白化工作模型中，令 $M_Z$ 为去掉 $Z^*$ 可解释成分的投影：

$$
\hat\beta=((X^*)^{\mathsf T}M_ZX^*)^+(X^*)^{\mathsf T}M_Zy^*.
$$

上标 $+$ 表示广义逆。这里用于理解联合估计，不是替代SPM的实际ReML、滤波和有效自由度计算。第135行高通以秒为单位，第137行选择FAST/AR(1)，第139/141行是建模微时间格及参考。

**代码对应：**glm_framework_plan建立条件，glm_run指定并估计SPM，glm_contrasts按实际SPM列名放置权重，verify_glm核对结果。无需自行编写矩阵求逆或手动在混杂前先回归BOLD。

## 三、对比、效应和T值怎样区分

条件顺序A、B时，`[1 -1]` 定义 $\theta=\beta_A-\beta_B$；`[.5 .5]` 是两个条件系数等权平均；`[1 0]` 选择A系数。每行一项对比，与第19行名字对应，第21行列数与第17行一致。

T检验可概念化为 `t=估计效应/该效应的标准误`。因此con是效应，spmT是带不确定性标度的检验量；两者不是同一种图。 `[1 0]` 的基线解释取决于模型中截距、其他任务及混杂，不能不看设计就称为“全部脑活动”。

SPM一级即使不做全局归一化选择，也有session grand mean scaling的实际处理，检查SPM.xGX.gSF；不要直接把每个con叫作逐体素百分信号变化。GLMsingle百分BOLD也不自动与它同尺度。

## 四、哪些设置定义这条路线

| 参数                           | 配置行号 | 条件run模型的设置              |
| ---------------------------- | ---- | ----------------------- |
| `cfg.engine`                 | 88   | spm_classical           |
| `cfg.level`                  | 68   | run；同一人多run另设subject    |
| `cfg.model.unit`             | 27   | condition               |
| `cfg.model.targetConditions` | 29   | 必须空，用对比表达需要的条件差异        |
| `cfg.fit.strategy`           | 60   | joint                   |
| `cfg.conditions`             | 17   | 全部真实条件，固定顺序             |
| `cfg.contrastNames`          | 19   | 对比名字，逐行对应权重             |
| `cfg.contrastWeights`        | 21   | 每条件一列，不补混杂/截距/导数权重      |
| `cfg.events.expression`      | 31   | duration起步；另外两项须明确解释    |
| `cfg.hrf.type`               | 35   | canonical起步；导数、FIR另有理论篇 |

条件targetConditions不用于删条件。若不想输出某一效应，可不定义对应对比，但所有真实任务事件仍在模型中。pmod把条件模型扩展为事件属性调制；FIR把固定HRF扩展为时间bin；它们不是由某个隐藏预处理开关选择。

## 五、代码实践：先填写数据，再选择模型

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必改若不同] 安装位置
cfg=glm_config;
cfg.manifestFile='E:\study\runs.tsv'; % 配置第8行；[必改] 自己的run清单
cfg.outputRoot='E:\study\condition_prepare'; % 配置第10行；[必改] 新目录
cfg.conditions={'story','math'}; % 配置第17行；[必改] 事件条件及顺序
cfg.contrastNames={'story_minus_math','math_minus_story'}; % 配置第19行；[可调] 方向明确
cfg.contrastWeights=[1 -1;-1 1]; % 配置第21行；[必查] 对应上述顺序
cfg.model.unit='condition'; % 配置第27行；[方法固定] 条件共同幅度
cfg.model.targetConditions={}; % 配置第29行；[约束] 条件不筛目标列表
cfg.fit.strategy='joint'; % 配置第60行；[约束] 同一模型
cfg.design.includeTissueMeans=false; % [HCP教学] 不引入未经核对的组织均值；自己的研究另定
cfg.execute=false; % 配置第14行；[步骤] 先准备，实际运行另检查输入
% 填好路径后执行 report=psy.glm_batch(cfg);
```

run表每行一个subject/session/run，BOLD为4D、TR正确，confounds帧数和来源一致，events至少onset/duration/trial_type。表内相对路径以表目录为基准。原输入须未提前作时间滤波/混杂回归；空间处理与平滑取决于目标和有效覆盖。

准备阶段保存计划及作业但不承诺最终设计可估。核对后，换新输出目录设置execute=true调用psy.glm_batch。若直接使用run_glm，则它会重新读取文件中的cfg，不能保留本片段内存覆盖。

## 六、输出怎样检查

统一框架run根目录先看event_mapping.tsv、unit_mapping.tsv、model_status.tsv、model_outputs.tsv和summary.json；实际模型位于models/joint。SPM.mat里有真实设计与列名，beta还包含混杂和截距，不能按前几个文件凭感觉猜含义。

| 结果                                                      | 用途                                                 |
| ------------------------------------------------------- | -------------------------------------------------- |
| con_*.nii                                               | 已定义的线性效应；可用于恰当的被试间二级模型                             |
| spmT_*.nii                                              | 该效应的T检验量，不是beta幅度                                  |
| mask.nii、ResMS.nii                                      | 实际分析范围与残差方差，先核对几何和覆盖                               |
| design_audit.mat、model_diagnostics.mat/json、glm_qc.json | 秩、可估性、采样残差与输出完整性；glm_diagnostics.m是计算诊断的函数，不是输出文件名 |
| GLM_FRAMEWORK_COMPLETE.mat                              | 框架实际估计完成；PREPARED不能替代它                             |

多重校正、簇表、叠加图与ROI另走run_glm_outputs。当前FWE/BH对单对比定义检验族；不能只看未阈值T图宣称显著。条件共同beta不冒充逐事件目录来源。

##
