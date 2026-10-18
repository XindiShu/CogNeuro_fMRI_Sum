# GLM方法选择与参数操作指南



## 一、每一种方法到哪里学习理论

“估计单元”“HRF”“拟合策略”“统计层级”可以组合，它们不是一排互斥算法。下表给出每项的理论和代码实践对应；共用一篇的条目明确指出阅读章节。

| 方法或维度                                    | 理论与本包实践文档                                                                                      |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------- |
| 条件共同响应GLM                                | [条件GLM](Condition_GLM.md)，一至六节                                                                 |
| LSA，逐事件/真实trial联合估计                      | [LSA](LSA_GLM.md)，一至七节                                                     |
| LSS-pooled、LSS-condition干扰分组             | [LSS](LSS_GLM.md)，二至五节                                                     |
| item、block、phase、trial_phase             | [估计单元](Estimation_Units_GLM_.md)，二至六节                                       |
| canonical、时间/宽度导数；duration/impulse/fixed | [HRF与事件表达](GLM_HRF.md)，一至六节                                          |
| pmod参数调制                                 | [pmod与FIR](Pmod_and_FIR_GLM.md)，第2节                                                            |
| FIR及bin/窗口T、整体F                          | [pmod与FIR](Pmod_and_FIR_GLM.md)，第3节                                                            |
| 被试内跨run条件模型                              | [跨run与单样本](Cross_run_group_GLM.md)，第2—3节                                                   |
| 二级单样本                                    | [跨run与单样本](Cross_run_group_GLM.md)，第4节；[二级设计](Group_and_Convariates.md)，第1、4—6节 |
| 二级两水平配对                                  | [二级设计](Group_and_Convariates.md)，第2、5—6节                                            |
| 二级两独立组、共同斜率协变量                           | 同上，第3—6节                                                                                       |
| 二级回归、单样本/两组调整模型                          | 同上，第4—6节                                                                                       |
| GLMsingle A/B/C/D                        | [GLMsingle](GLMsingle_ABCD.md)，第1—5节                                            |
| 已估计结果阈值、ROI和统一beta接口                     | [使用流程与结果导出](GLM_WORKFLOW_GUIDE.md)                                                 |

旧SINGLE_TRIAL_GLM讲早期入口，GLM_COMPOSABLE_FRAMEWORK讲第一阶段；其中尚未实现的表述有时间范围。新工作优先按上表的当前理论篇、本页和当前源码操作，避免混用旧字段名。



## 二、先分清“选择方法”和“填写数据”

### 1. 主要选择位置

| 参数                      | 配置行号 | 它决定的事                              |
| ----------------------- | ---- | ---------------------------------- |
| `cfg.engine`            | 88   | 用SPM经典GLM还是GLMsingle               |
| `cfg.level`             | 68   | 每run、同一被试多run、还是独立被试的组统计           |
| `cfg.model.unit`        | 27   | 一个系数代表条件、事件、trial、item、区块还是阶段      |
| `cfg.fit.strategy`      | 60   | 全部单元联合拟合，还是每目标分别拟合                 |
| `cfg.hrf.type`          | 35   | canonical、导数、FIR，或GLMsingle自己的HRF库 |
| `cfg.events.expression` | 31   | 保留时长、onset脉冲、还是统一固定时长              |
| `cfg.fit.lssGrouping`   | 62   | 选LSS时，其余事件合一还是按原条件分组               |
| `cfg.pmod.enabled`      | 50   | 条件模型是否增加事件参数调制；列表在第52行             |
| `cfg.group.design`      | 72   | 二级单样本、配对、两组还是回归                    |

pmod另由第50行启用，二级设计由第72行选择；LSS的干扰组织在第62行。只改一个开关，通常不足以完成方法切换。例如engine改为glmsingle，还须同时选择subject、event/trial、joint及其允许的HRF与事件表达。



### 2. 两种设置方式，选一种执行

**直接使用配置文件：**核对相应行，保存glm_config.m，然后运行run_glm。不要为了某一种方法删除其他字段；完整配置有统一格式检查。第48行的分节注释不是开关，其中第50—58行实际是pmod，LSA/LSS本身由27、60、62行决定。

**保留稳定配置，用个人分析脚本覆盖：**先 `cfg=glm_config`，再写需改变的字段，最后 `psy.glm_batch(cfg)`。这样不在固定行号的配置里不断插行。不要在覆盖cfg之后调用run_glm：该脚本会重新读取glm_config，覆盖你的临时选择。

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必改若不同] 包与SPM安装位置
cfg=glm_config;
cfg.manifestFile='E:\study\runs.tsv'; % 配置第8行；[必改] 填好的真实run清单
cfg.outputRoot='E:\study\condition_prepare'; % 配置第10行；[必改] 包外新目录
cfg.conditions={'story','math'}; % 配置第17行；[必改] 与自己的事件表完整一致
cfg.contrastNames={'story_minus_math'}; % 配置第19行；[必改] 与权重逐行对应
cfg.contrastWeights=[1 -1]; % 配置第21行；[必查] 列对应conditions
cfg.design.includeTissueMeans=false; % [教学例] 第144行继承后在内存覆盖；不是给第144行换一个布尔值
cfg.continueOnError=false; % 配置第152行；[建议起点] 初次运行及时停下查看原因
cfg.execute=false; % 配置第14行；[阶段选择] 先准备，不代表已估计
% 核对自己的路径与方法设置后再调用：report=psy.glm_batch(cfg);
```

这段只定义配置，E盘路径是待填占位值。准备通过后，换另一个新outputRoot，再把execute设为true并调用同一函数；当前实现不在原准备目录原地继续估计。



## 三、所有路线共同需要核对的项目

| 参数                    | 配置行号 | 应怎样处理                                          |
| --------------------- | ---- | ---------------------------------------------- |
| `cfg.manifestFile`    | 8    | run/subject用run清单；group用每人效应图清单；模板不是实际输入       |
| `cfg.outputRoot`      | 10   | 改成不存在的新目录；通常放包外，保留旧成功结果                        |
| `cfg.spmPath`         | 12   | 找不到SPM时填实际安装目录；不是BOLD目录                        |
| `cfg.execute`         | 14   | false准备、true估计；不要把准备标记当作beta来源                 |
| `cfg.conditions`      | 17   | 一级/GLMsingle条件集合与事件一致；不能靠删除不想看的条件来选择目标         |
| `cfg.contrastNames`   | 19   | 条件模型由你命名；单元/组统计自动生成；其余分支保留完整格式                 |
| `cfg.contrastWeights` | 21   | 条件模型中按17行顺序写每个条件的权重，不加run、混杂或导数的零              |
| `cfg.explicitMask`    | 129  | 必须同网格；run清单mask可覆盖全局设置；GLMsingle必须有有效显式覆盖      |
| `cfg.design`          | 144  | 继承design_config；头动/组织均值是否存在、帧序是否一致需另外核对        |
| `cfg.continueOnError` | 152  | 初次可false；true只让其他独立项继续，最后仍须逐项看batch_status.tsv |

run清单的bold/events/confounds必须同run同帧序。BOLD需实际符合unfiltered_unregressed，不能只修改声明字符串。二级观测是独立被试；不能将一个人的多个run/trial变成“多个人”。



## 四、每种方法具体怎样选择

### 1. 条件GLM：每个条件共享一个幅度

**方法固定：**第88行spm_classical、第68行run、第27行condition、第60行joint；第29行空。**必填：**第8—14行路径/执行状态、第17/19/21行条件/对比，以及实际混杂与覆盖。

第31行通常先duration，保留任务时长；第35行先canonical。可改canonical_time或canonical_time_dispersion容纳一定形状差异，但对比仍针对canonical列。需要pmod或FIR时，按下面对应步骤切换，而不是在条件模型中随意加未知字段。

```matlab
cfg=glm_config;
cfg.engine='spm_classical'; % 配置第88行；[方法固定] SPM
cfg.level='run'; % 配置第68行；[方法固定] 每run
cfg.model.unit='condition'; % 配置第27行；[方法固定] 条件共享系数
cfg.model.targetConditions={}; % 配置第29行；[约束] 条件模式为空
cfg.fit.strategy='joint'; % 配置第60行；[约束] 条件联合
cfg.events.expression='duration'; % 配置第31行；[建议起点] 保留任务时长
cfg.hrf.type='canonical'; % 配置第35行；[可调] 可选两类导数
```

第62行不参与joint，group与glmsingle分支保持合法默认。第50行false时第52行必须为空。第21行 `[1 -1]` 是条件差值效应，生成con与T，不是直接对两段原始BOLD均值相减。

### 2. LSA：所有事件单元一起分开估计

**方法固定：**88=spm_classical，68=run，60=joint。**选择单位：**27=event，或有真实唯一trial_id时trial。第29行可空或选择目标条件；未选事件仍保留在同一个设计中。

```matlab
cfg=glm_config;
cfg.model.unit='event'; % 配置第27行；[可调] trial需每行唯一真实ID
cfg.fit.strategy='joint'; % 配置第60行；[方法固定] LSA
cfg.level='run'; % 配置第68行；[约束] 当前SPM逐单元不跨run联合
cfg.hrf.type='canonical'; % 配置第35行；[建议起点] 可用导数，不能FIR
cfg.model.targetConditions={}; % 配置第29行；[可调] 如填math，须先把17行配置为含math的完整条件
```

第19/21行不是逐目标手工权重入口，框架自动产生目标单元对比和beta映射。第62行不生效。第35行不能fir，第50行须false且52为空；当前不支持逐trial pmod/FIR。第150行检查信息量不足时，应检查设计与列数，不要只把门槛改低。

### 3. LSS：每个目标单独拟合

与LSA相比，关键是**第60行改lss，第62行明确干扰分组**；88、68、27仍是SPM、run、event/trial或支持的其他单元。

```matlab
cfg=glm_config;
cfg.model.unit='event'; % 配置第27行；[可调] 目标单位
cfg.fit.strategy='lss'; % 配置第60行；[方法固定] 每目标一个模型
cfg.fit.lssGrouping='condition'; % 配置第62行；[选择] condition或pooled
cfg.level='run'; % 配置第68行；[约束] 不在SPM subject联合
cfg.model.targetConditions={}; % 配置第29行；[可调] 只筛输出目标，不删其他事件
```

condition保留“其余A”“其余B”等干扰类别；pooled将所有其他事件合成一组。二者都是逐目标LSS。**不能**把第27行改成condition来做“条件目标LSS”，也不能把phase与lss组合。FIR/pmod限制同LSA。目标多会生成大量模型，先用明确的一小批目标做工程演示，成功结果不覆盖。

### 4. item、block、phase、trial_phase：先改单位，再定joint/lss

| 27行选择       | 输入事件表必须有什么                | 60行可选     | 容易改错之处                   |
| ----------- | ------------------------- | --------- | ------------------------ |
| event       | 基础三列                      | joint/lss | 每行不一定是真实trial            |
| trial       | trial_id，每run每个ID恰好一行     | joint/lss | 多阶段同trial不能重复用trial模式    |
| item        | stimulus_id，同ID可多行且条件一致   | joint/lss | 同刺激呈现共用一个幅度，不是每次呈现一个beta |
| block       | block_id，每run唯一行          | joint/lss | 本接口不合并同block_id的多行       |
| phase       | phase；按trial_type×phase聚合 | joint     | 不是每个trial各阶段独立           |
| trial_phase | trial_id+phase组合唯一        | joint/lss | 每组合一行，不能重复或缺ID           |

这几条SPM路线保持第68行run，第88行spm_classical。第29行可按条件筛目标（condition本身除外）。第31/35行控制每个单元中的事件时长和HRF，不能通过换unit偷偷改变时间含义。选择item是将多次呈现约束为共享系数，得到的单行beta应通过event_links连回多行原事件。

### 5. canonical与导数、duration/impulse/fixed

**HRF在第35行：**canonical最少列；canonical_time增加时间导数；canonical_time_dispersion再加宽度导数。SPM单元模型可选这三者。导数不是额外事件，也不能直接把导数系数当秒或宽度。

**事件表达在第31行：**duration用原表；impulse仅用onset触发；fixed使用第33行。第33行SPM允许有限非负秒数，GLMsingle还要求正值、0.1秒倍数。建议保留真实时长，只有模型问题明确时再选择另外两项。FIR与GLMsingle的特殊组合见下文；SPM不能把35行填library。

### 6. pmod：事件属性调节幅度

**方法固定：**27=condition、60=joint、35=canonical或两类导数、29为空；68可run/subject。**必须一起改：**50=true和52非空modulators。**主要可调：**54中心化、56尺度、58串行正交化。

```matlab
cfg=glm_config;
cfg.conditions={'story','math'}; % 配置第17行；[必改] 对应事件条件
cfg.pmod.enabled=true; % 配置第50行；[方法选择] 必须同步填写下一项
cfg.pmod.modulators=struct('condition','math','column','difficulty','name','difficulty','poly',1); % 配置第52行；[必改] 列名与单位真实存在
cfg.pmod.center='within_condition'; % 配置第54行；[建议起点] 每run每条件去均值
cfg.pmod.scale='none'; % 配置第56行；[可调] zscore必须同时中心化
cfg.pmod.orthogonalize=false; % 配置第58行；[建议起点] 不按顺序分配共享变异
```

poly先1检验线性，2会同时增加一阶和二阶；最大支持6，不代表越高越好。调节量在对应条件必须有限且有变化，不能把缺失反应填0假装有效。关闭pmod时，50=false还必须将52恢复为空结构；不能只关一个开关后留下旧列表。当前不支持pmod+FIR、pmod+LSS、跨调节量交互或自动两条件斜率差。

### 7. FIR：响应时间分箱

**方法固定：**35=fir、27=condition、60=joint、50=false、52空、29空；68可run/subject。**必须成套选择：**38窗口、40箱数、42汇总箱、44整体F，以及31事件表达。没有 `cfg.TR` 字段，TR来自输入影像。

```matlab
cfg=glm_config;
cfg.hrf.type='fir'; % 配置第35行；[方法选择] 条件FIR
cfg.events.expression='impulse'; % 配置第31行；[模型假设] onset锁定响应
cfg.hrf.fir.windowSeconds=21.6; % 配置第38行；[HCP示例] 秒
cfg.hrf.fir.nBins=10; % 配置第40行；[HCP示例] 每箱2.16秒
cfg.hrf.fir.summaryBins=3:5; % 配置第42行；[可调] 预先确定汇总4.32—10.8秒
cfg.hrf.fir.includeOmnibus=true; % 配置第44行；[可调] 保留整体F
```

当TR=.72、139行=16时，每微时间格.045秒，2.16秒恰为48格。默认20秒/10箱并不匹配这一格点，启用FIR必须核对。duration与FIR也可组合，但解释变为持续输入的响应核，不能直接称onset后原始曲线。第42行不删除其他bin；第44行F不带有符号效应，不能当二级con输入。

### 8. 被试内跨run条件模型

**关键选择：**68=subject、70通常false。**固定组合：**88=spm_classical、27=condition、60=joint、29空。run清单每行独立run，事件零点各自从0开始，不把run2的onset加上run1长度。

可用canonical/导数，也可按合法组合用pmod或FIR；并非subject只支持最初canonical版本。各run保留独立任务、混杂、截距与高通，匹配效应等权平均，不能改一个权重伪装成逆方差合并。当前不支持SPM逐trial跨run联合、不同TR或网格自动对齐，也不自动补缺失条件。

70=true跨访视合并是额外假设，不能用来做pre/post差异而又抹掉访视。输出subject_contrasts.tsv可汇入二级清单；不能拿每run的T图代替每人的效应图。

### 9. 二级单样本

**关键：**68=group、72=one_sample、8行换为组清单。每名被试、每项效应一张同定义con和mask。74是独立人数门槛，86是二级N−rank(X)门槛；示例3人/1维不是正式充分样本量。

82可空，也可加入数值协变量；84通常overall。加入协变量后截距解释为指定原点的调整效应。17/19/21不负责二级权重，不要给一级contrastWeights加入“每人一个权重”。27/35等一级分支保留合法默认即可，不向二级图做HRF卷积或时间高通。

### 10. 二级配对

**必须：**72=paired、76设两个pair_level标签及顺序，82空。方向是76行第1个减第2个，例如post−pre。每人恰好两张图，按ID匹配，不按表中相邻行。74数独立被试而非两倍图数。

```matlab
cfg=glm_config;
cfg.level='group'; % 配置第68行；[约束] 组清单
cfg.group.design='paired'; % 配置第72行；[方法选择] 两水平配对
cfg.group.pairedLevels={'post','pre'}; % 配置第76行；[必查] 方向post减pre
cfg.group.covariateColumns={}; % 配置第82行；[约束] 当前paired不能加协变量
```

第78/80行不参与配对，84在无协变量时不改变模型。不能靠给session填pre/post替代pair_level；也不能自动删除不完整被试后声称同一队列。组模块先写差值图再做SPM单样本，详见二级理论篇。

### 11. 二级两独立组及调整模型

**必须：**68=group、72=two_sample、78两个group标签和方向、80每组最少人数；清单要有group列。同一人不进入两组，当前独立等方差，不能通过增加variance字段改成Welch。

82可空或列出age/score等协变量，84=overall/none须明确；两组加协变量采用共同斜率，无组×协变量交互。74、80、86三个门槛同时约束：总人数、每组人数、设计残差维度。GLM模块不自动标准化、插补或根据数据替你选择分组。

### 12. 二级回归

**必须：**68=group、72=regression、82至少一列变化且有限的数值变量；84决定中心。含截距，自动输出截距及各斜率正/负T；相同人的多项效应须保持同队列、同协变量。

```matlab
cfg=glm_config;
cfg.level='group'; % 配置第68行；[约束] 观测为独立被试
cfg.group.design='regression'; % 配置第72行；[方法选择] 含截距
cfg.group.covariateColumns={'age','score'}; % 配置第82行；[必改] 组表中的数值列
cfg.group.covariateCenter='overall'; % 配置第84行；[建议起点] 全体被试均值原点
```

76/78/80不在此分支决定模型。变量常量、彼此线性相关或N−rank不足会报错；不要只把86改1掩盖模型不可识别。一级pmod是事件内变量，本节是被试间变量，不能互换清单。

### 13. GLMsingle

**固定组合：**88=glmsingle、68=subject、27=event/trial、60=joint、29空、50=false/52空、35=canonical/library；31只duration/fixed，实际建模时长须共同正值且0.1秒倍数。必须有有效覆盖mask和保留正基线的原强度时序。

```matlab
cfg=glm_config;
cfg.engine='glmsingle'; % 配置第88行；[方法选择] 官方固定依赖
cfg.level='subject'; % 配置第68行；[约束] 每人多run，不把被试当run
cfg.model.unit='event'; % 配置第27行；[可调] trial须唯一真实trial_id
cfg.fit.strategy='joint'; % 配置第60行；[约束] 本接口的GLMsingle路线
cfg.hrf.type='library'; % 配置第35行；[可调] 或canonical
cfg.glmsingle.identityColumn='stimulus_id'; % 配置第96行；[必改] 真实重复身份列
cfg.glmsingle.onsetMode='strict'; % 配置第112行；[建议起点] 先检查，不先舍入
cfg.glmsingle.maxPCs=2; % 配置第104行；[教学简化] 不等于关闭去噪
cfg.glmsingle.fracs=[1 .75 .5]; % 配置第102行；[教学简化] 有限候选
```

片段保留98/100为true，实际输入须满足跨run共享身份。仍需填路径、完整条件与mask；不能把这段代码的字段检查通过当成输入预检通过。

| 参数                                   | 配置行号 | 本方法怎样处理                           |
| ------------------------------------ | ---- | --------------------------------- |
| `cfg.glmsingle.path`                 | 94   | 通常保留随包固定依赖，换路径不能任意换版本             |
| `cfg.glmsingle.identityColumn`       | 96   | 必核对重复标签的实验含义，不按事件行号假配重复           |
| `cfg.glmsingle.wantDenoise`          | 98   | true执行PC数量交叉验证；选0个PC也可成功          |
| `cfg.glmsingle.wantRidge`            | 100  | true执行ridge候选交叉验证并请求D             |
| `cfg.glmsingle.fracs`                | 102  | 至少两个不同(0,1]候选；完整默认或教学简化[1 .75 .5] |
| `cfg.glmsingle.maxPCs`               | 104  | 正整数上限，教学可2；关闭去噪用98=false，不用设0     |
| `cfg.glmsingle.noiseR2Threshold`     | 106  | 自动或有限百分数；噪声池门槛，不是p值               |
| `cfg.glmsingle.pcR2Threshold`        | 108  | 自动或有限百分数；评价PC的体素门槛，和噪声池不同         |
| `cfg.glmsingle.maxPolyDegree`        | 110  | 自动逐run多项式或共用非负整数；不用SPM高通          |
| `cfg.glmsingle.onsetMode`            | 112  | 先strict检查；nearest是明确舍入假设          |
| `cfg.glmsingle.maxOnsetErrorSeconds` | 114  | 只控制nearest允许误差，秒；碰撞仍阻断            |
| `cfg.glmsingle.minEndBufferSeconds`  | 116  | 最后格点onset到最后采样时刻的秒数；不自动删尾事件       |
| `cfg.glmsingle.chunkVoxels`          | 118  | 处理分块大小，不是最终体素抽样数                  |
| `cfg.glmsingle.maxInputGiB`          | 120  | single输入预算，不是峰值内存保证               |
| `cfg.glmsingle.wantPercentBold`      | 122  | 百分BOLD或源输入强度，跨方法仍不自动同尺度           |
| `cfg.glmsingle.randomSeed`           | 124  | 固定可复现种子，结束恢复状态                    |

98或100开启时，每一留一run折都须有训练/测试共享身份。若明确都关闭可估A/B，但不能称作完整C/D。第135/137/139/141/148行不是本后端的滤波/白化/格点设置；GLMsingle按TR采样，微时间不能帮它保留任意小数onset。第131行控制其导出图，133不是GLMsingle的SPM残差采样；150仍参与设计信息量预检。

HCP语言当前无同一音频跨run的严格重复，已有教学例改用trial_type类别、fixed20秒、nearest误差上限.37、尾部16秒，并由专用启动器在副本中排除尾部事件、抽样4096体素。**通用glm_config没有自动抽样/删事件开关**；单独设置118=4096不会复现那个例子。具体假设、原始身份和审计见GLMSINGLE_HCP_DEMO。

## 五、其余字段何时改、何时保持

| 参数                                | 配置行号 | SPM一级建议与边界                      | 二级/GLMsingle                 |
| --------------------------------- | ---- | ------------------------------- | ---------------------------- |
| `cfg.events.fixedDurationSeconds` | 33   | 只fixed使用，单位秒≥0                  | GLMsingle还要求共同正值和0.1秒倍数；二级不用 |
| `cfg.hrf.fir.windowSeconds`       | 38   | FIR才参与设计，正秒数；保留合法值              | GLMsingle/二级不以FIR拟合          |
| `cfg.hrf.fir.nBins`               | 40   | FIR正整数；越多越耗信息量                  | 非FIR保留合法默认                   |
| `cfg.hrf.fir.summaryBins`         | 42   | 空为全部，否则唯一有效箱编号                  | 不要用看结果后挑箱代替预选                |
| `cfg.hrf.fir.includeOmnibus`      | 44   | FIR整体F开关                        | F不是有符号二级效应                   |
| `cfg.pmod.enabled`                | 50   | pmod与52成套；当前条件joint             | GLMsingle须false              |
| `cfg.pmod.modulators`             | 52   | 关闭时必须为空，开启须真实数值列                | 不能把二级协变量放进这里                 |
| `cfg.pmod.center`                 | 54   | within_condition/none改变主效应原点    | 不是group总体中心化                 |
| `cfg.pmod.scale`                  | 56   | none/zscore，后者须中心化              | 不统一SPM与GLMsingle beta单位      |
| `cfg.pmod.orthogonalize`          | 58   | 串行true会依赖顺序；false仍需检查共线         | 不等于消除所有估计相关                  |
| `cfg.subject.combineSessions`     | 70   | subject才决定跨访视组织；通常false         | GLMsingle同样按被试组织session      |
| `cfg.group.minSubjects`           | 74   | run/subject不按它增加人数              | group独立人数门槛，默认3仅示例           |
| `cfg.group.pairedLevels`          | 76   | 一级保持默认                          | paired才决定两水平及方向              |
| `cfg.group.groupLabels`           | 78   | 一级保持默认                          | two_sample才决定组标签方向           |
| `cfg.group.minPerGroup`           | 80   | 一级保持默认                          | two_sample每组人数门槛≥2           |
| `cfg.group.covariateColumns`      | 82   | 不是事件pmod列表                      | regression必填，paired必须空       |
| `cfg.group.covariateCenter`       | 84   | 一级保持默认                          | overall/none，无自动标准化          |
| `cfg.group.minResidualDF`         | 86   | 不替代一级150行                       | group的N−rank门槛               |
| `cfg.qc.plot`                     | 131  | 关图不关SPM数值诊断                     | GLMsingle导出诊断；不是后处理叠加图开关     |
| `cfg.qc.maxResidualVoxels`        | 133  | 确定性残差体素采样，默认32，不是分析mask大小       | 不代表GLMsingle或二级逐体素残差ACF      |
| `cfg.highpassSeconds`             | 135  | 秒，默认128可作工程起点；核对任务频谱            | 二级不对被试序列高通，GLMsingle用多项式     |
| `cfg.serialCorrelation`           | 137  | FAST/AR(1)，看残差与TR，不是通用质量保证      | 不为二级或GLMsingle时序白化           |
| `cfg.microtimeResolution`         | 139  | 每TR微时间格，正整数，默认16                | 不能增加实测帧数                     |
| `cfg.microtimeOnset`              | 141  | 参考格1..resolution，默认8，核对采集/STC参考 | 不平移事件秒数，不是删帧数                |
| `cfg.design.linearTrend`          | 146  | 默认false避免额外趋势，与144继承配合          | GLMsingle通常交多项式，不因false关闭基线  |
| `cfg.maskThreshold`               | 148  | SPM隐式相对强度0..1，默认.8，核对mask       | 不控制GLMsingle显式覆盖             |
| `cfg.minResidualDF`               | 150  | 一级联合设计代数维度门槛，默认20               | GLMsingle也检查；不等于86或最终SPM统计df |

设计继承里的motionModel、includeTissueMeans、addSpikes、fdThresholdMm并没有各自的glm_config固定行；入口是144行。它们在design_config中定义，再于个人脚本的cfg.design覆盖。不同门槛不要混用：cfg.design.minResidualDF只检查混杂，150检查一级联合设计，86检查二级独立被试设计。

##

##
