# LSS

LSS（least squares separate）的核心是**每个目标单元各拟合一个模型，只收集该模型中的目标系数**。本章将pooled与condition干扰分组分别说明；它们都不是整个条件当目标的“condition级LSS”。



## 一、为什么为每个目标另建模型

LSA让所有单元各有一列；事件接近时，这些列可能相似，幅度区分不稳定。LSS保留当前目标的独立列，给其余事件施加更强的共享系数约束，从而减少这一次拟合的自由任务参数。

这是一个约束选择，不是免费增加信息：其他事件真实幅度可能不同，合并假设不完全符合数据时会影响目标估计。是否合适取决于时序、条件差异、trial变化及噪声，不能保证任意数据LSS优于LSA。[Mumford等，2012](https://doi.org/10.1016/j.neuroimage.2011.08.076)

## 二、pooled与condition差别

假设四个事件A1、A2、B1、B2，经相同事件表达/HRF后为a1、a2、b1、b2。估计A1时：

```text
LSA：          [a1, a2, b1, b2, Z]
LSS-pooled：   [a1, a2+b1+b2, Z]
LSS-condition：[a1, a2, b1+b2, Z]
```

pooled把所有非目标事件共享一份干扰幅度；condition为其余A和其余B分别估计干扰幅度。下一个目标A2时重建设计，不是沿用A1模型中其余A的系数作为A2的最终beta。

**参数对应：**第60行lss，第62行pooled/condition。原始trial_type决定干扰类别，不根据当前目标估计值自动分组；某类无剩余事件时不添加那类空条件。任务列数量还会随导数数目变化，不能把LSS想成永远两列。

文献中存在LSS-1/LSS-N等命名。这里优先写出目标与干扰的实际设计，避免把字母N当作目标单位或被试数。[Abdulrahman与Henson，2016](https://www.mrc-cbu.cam.ac.uk/wp-content/uploads/www/sites/3/2016/01/AbdulrahmanHenson_NI_trial_variability.pdf)



## 三、目标beta是怎样得到的

对目标 $q$ 的canonical简化模型：

$$
y=x_q\beta_q+A_q\alpha_q+\epsilon,
$$

$A_q$ 包含合并的非目标任务、混杂与截距。应用同一意义的高通/白化后，去掉 $A_q$ 所解释部分，记投影为 $M_A$，则

$$
\hat\beta_q=\frac{(x_q^*)^{\mathsf T}M_Ay^*}{(x_q^*)^{\mathsf T}M_Ax_q^*}.
$$

这是一目标列的解释公式；加导数时目标本身也是一组基函数，需按完整设计估计，实际由SPM完成。目标列被其他列几乎解释完时，分母很小仍会不稳定；LSS不会消除所有共线性。

每个 $q$ 的 $A_q$ 不同，所以各目标beta来自不同模型。它们共享同一BOLD和重叠响应，并不因此成为统计上独立的观测。不能把每个LSS模型当额外被试来增加组样本量。



## 四、事件单位和目标筛选

| 参数                           | 配置行号 | 选择与限制                                                |
| ---------------------------- | ---- | ---------------------------------------------------- |
| `cfg.engine`                 | 88   | spm_classical                                        |
| `cfg.level`                  | 68   | run，不支持SPM LSS subject联合                             |
| `cfg.model.unit`             | 27   | event/trial/item/block/trial_phase；不能condition或phase |
| `cfg.fit.strategy`           | 60   | lss                                                  |
| `cfg.fit.lssGrouping`        | 62   | pooled或condition，都是非目标分组                             |
| `cfg.model.targetConditions` | 29   | 空=所有目标；如math只为math建目标模型                              |
| `cfg.events.expression`      | 31   | duration/impulse/fixed明确选择，非目标事件也按同一表达处理             |
| `cfg.hrf.type`               | 35   | canonical或两类导数；不支持本接口逐目标FIR                          |

选择math为目标不会删除story：story仍在每个math目标模型里作为合并干扰。unit=trial要求真实唯一ID；item则当前目标可由同一stimulus_id多行组成。不是切换到item就自动得到每次呈现的beta，详见[估计单元篇](Estimation_Units_GLM_.md)。

当前第50行必须false、52为空；pmod/FIR与LSS没有接通。手工第19/21行条件对比不是本路线逐目标权重入口。当前没有condition-target LSS，也不把GLMsingle官方内部可能存在的LSS选项自动暴露出来。



##

## 五、配置与运行示例

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必改若不同] 安装位置
cfg=glm_config;
cfg.manifestFile='E:\study\runs.tsv'; % 配置第8行；[必改] 自己的完整run来源
cfg.outputRoot='E:\study\lss_condition_prepare'; % 配置第10行；[必改] 新目录
cfg.conditions={'story','math'}; % 配置第17行；[必改] 不删除非目标story
cfg.model.unit='event'; % 配置第27行；[可调] 每输入行一个目标单元
cfg.model.targetConditions={'math'}; % 配置第29行；[可调] 只输出数学目标
cfg.fit.strategy='lss'; % 配置第60行；[方法固定] 每目标一个模型
cfg.fit.lssGrouping='condition'; % 配置第62行；[选择] 若对照pooled需另开新目录
cfg.design.includeTissueMeans=false; % [HCP教学] 组织均值需另核对
cfg.continueOnError=false; % 配置第152行；[建议起点] 首次出错即停
cfg.execute=false; % 配置第14行；[步骤] 先准备，不在原目录覆盖估计
% 填好输入后：report=psy.glm_batch(cfg);
```

先看unit_mapping、event_mapping、模型计划是否符合目标/干扰定义；实际估计换新输出目录设true。LSS每目标一个模型，数量通常等于选择的目标单元数，比LSA更费计算和磁盘。不是每个模型都必须输出全部事件的最终beta；收集目标而不是重复收集“other”。

##
