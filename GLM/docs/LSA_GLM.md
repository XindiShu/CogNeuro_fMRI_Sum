# LSA：逐事件联合GLM的理论与实践

LSA（least squares all）在同一模型中为每个估计单元单独建任务列。统一操作见[方法配置指南](Methods_Summary.md)。

## 一、“all”是所有单元一起估计

四个事件A1、A2、B1、B2的HRF列分别为a1、a2、b1、b2，则

```text
条件GLM：[a1+a2, b1+b2, Z]
LSA：    [a1, a2, b1, b2, Z]
```

Z是同一run的混杂和截距。LSA不是每次只截一小段影像计算均值：它用整个时序共同区分各事件。估计A1时，A2/B1/B2也在同一模型中有自己的系数。相邻事件的响应重叠并不自动使模型无解，但会影响信息分配。[Mumford等，2012](https://www.sciencedirect.com/science/article/pii/S1053811911010081)

本包的unit='event'指每行一个单元；unit='trial'还要求真实且唯一trial_id。其他grouped单元也可joint，但那是相应单元联合模型；保留estimate_unit信息，不把item共享beta叫作每次呈现的独立trial beta。



## 二、估计公式与列相关

在每体素上写成

$$
y=\sum_{i=1}^{N}x_i\beta_i+Z\gamma+\epsilon.
$$

先把SPM高通/白化后的变量记为星号。令 $M_Z$ 去掉 $Z^*$ 解释的部分，简化工作模型的估计为

$$
\hat\beta=((X^*)^{\mathsf T}M_ZX^*)^+(X^*)^{\mathsf T}M_Zy^*.
$$

这说明每个beta同时取决于其他任务列与混杂。不是把条件beta分成N份，也不是将未建模事件当作不存在。实际估计、协方差与有效自由度由SPM完成，公式不取代ReML。

在理想独立、同方差的残差模型下，beta协方差与 $(X^{\mathsf T}M_ZX)^{-1}$ 成比例。若两个残差化任务列单位范数、相关系数为 $\rho$，其单系数方差含 $1/(1-\rho^2)$ 因子：$\rho$ 接近 $\pm1$ 时，噪声容易被分配成很不同的单事件幅度。

**代码对应：**glm_contrasts检查高通后的可估性和残差维度；glm_diagnostics报告设计奇异值、列相关、任务保留能量与采样残差。秩通过只说明不完全不可识别，不说明beta精确。这个二维代数例子用于理解，不是本包额外的统计检验。



## 三、为什么LSA不总等于条件GLM的另一种输出

条件模型对同条件事件施加相同幅度约束；LSA允许它们不同。只有在额外的设计/加权条件下，按条件平均LSA beta才与条件模型给出同一个估计。事后平均改变了目标和误差相关处理，不能不看设计就认为必然相同。

如果真正关心共同条件效应，条件模型是直接表达；如果关心逐次反应差异，LSA提供逐单元表示。方法表现与事件时序、真实trial变化和扫描噪声有关，不从缩写判断永远优于LSS。[Abdulrahman与Henson，2016](https://doi.org/10.1016/j.neuroimage.2015.11.009)



## 四、在当前代码中怎样选择

| 参数                           | 配置行号 | LSA中的选择或限制                     |
| ---------------------------- | ---- | ------------------------------ |
| `cfg.engine`                 | 88   | spm_classical                  |
| `cfg.level`                  | 68   | run；不支持SPM逐事件subject联合         |
| `cfg.model.unit`             | 27   | event，或有唯一trial_id的trial       |
| `cfg.fit.strategy`           | 60   | joint，即所有单元共同估计                |
| `cfg.model.targetConditions` | 29   | 空=全部目标；可只输出math，但其他事件仍有列       |
| `cfg.events.expression`      | 31   | 默认duration，也可明确impulse/fixed   |
| `cfg.hrf.type`               | 35   | canonical或两类导数；当前不支持逐trial FIR |
| `cfg.pmod.enabled`           | 50   | false，第52行为空；当前无逐trial pmod    |
| `cfg.minResidualDF`          | 150  | 一级联合信息量门槛，不是最终统计df             |

第19/21行的手工条件对比不定义每个目标，框架自动生成目标选择权重。第62行只管LSS，在这里不参与。不要删除未使用group/glmsingle字段，否则可能不再是合法完整配置。

**代码链：**glm_framework_plan将行分配给单元，给每单元命名unit_000001等，生成一个joint模型；glm_framework_run调用glm_run，并按实际SPM `Sn(1) unit_*bf(1)` 定位canonical beta。位置由真实列名确定



## 五、一个可以改成自己数据的配置

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必查] 包与SPM
cfg=glm_config;
cfg.manifestFile='E:\study\runs.tsv'; % 配置第8行；[必改] 已预处理run清单
cfg.outputRoot='E:\study\lsa_prepare'; % 配置第10行；[必改] 新目录
cfg.conditions={'story','math'}; % 配置第17行；[必改] 不漏story等非目标任务
cfg.model.unit='event'; % 配置第27行；[方法选择] 每行一单元
cfg.model.targetConditions={'math'}; % 配置第29行；[可调] 只输出数学目标
cfg.fit.strategy='joint'; % 配置第60行；[方法固定] LSA
cfg.level='run'; % 配置第68行；[约束] 各run独立
cfg.design.includeTissueMeans=false; % [HCP教学] 保留完整头动来源，组织均值另核对
cfg.continueOnError=false; % 配置第152行；[建议起点] 首次及时停下
cfg.execute=false; % 配置第14行；[步骤] 先准备
% 填好输入后：report=psy.glm_batch(cfg);
```

若目标是全部事件，29行设空；若用trial，事件表新增真实trial_id，每run内不能重复。onset/duration为秒，对应当前BOLD首帧；代码不自动从故事内部切出句子。准备检查后另开新目录设true，成功才有实际beta。



## 六、输出和目标筛选

统一框架根目录下，unit_mapping.tsv是一单元一行，event_mapping.tsv是一事件一行；模型位于models/joint。model_outputs.tsv把目标单元连到实际canonical_beta、contrast和statistic路径，完整模型仍含非目标任务及混杂列。

以HCP100206数学目标例说明：输入共12行、8个math目标，LSA仍估计12个事件任务列，输出目标效应是8个，不是先删除4个story行。混杂、导数、截距也有beta文件，不能以“目录有多少beta”当作目标数。

读入统一beta接口用framework+auto指向run完成根目录；它读取目标并核对SPM实际列。得到 `[目标单元×共同体素]` 矩阵，每行含来源、单位和事件链接。导数模型读取bf(1)，不自动组合导数为幅度/延迟。



## 七、使用beta时最需要保留的信息

保留subject/session/run、trial或item身份、条件和原事件索引。相邻事件的beta估计可相关；同一run/刺激信息若在后续训练与测试交叉出现，会改变泛化问题。统一接口只保留这些信息，不替你实施RSA/MVPA或选择交叉验证。

不同duration、HRF表达和SPM强度缩放会改变系数含义。一个事件beta为0可能是合法估计，不能当作缺失自动丢弃；有效共同mask内NaN/Inf则应检查来源。后处理目录会明确拒绝不完整/矛盾目标，不将缺失目标补0。

##
