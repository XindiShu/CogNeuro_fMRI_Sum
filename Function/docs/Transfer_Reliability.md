# 冻结泛化、六种 ICC 与匹配项目分半



## 一、方法在分析什么

### 1. 泛化在换什么

disjoint_units训练/目标没有共同独立人，用于新被试；matched_units_distinct_domains允许同人新任务/时段，但样本id仍不重复，域名不同。两种策略回答不同问题，不能只改标签就称跨人泛化。

源域只学习一次特征掩膜、均值/SD、目标均值与模型；目标域不重学这些量，目标标签只用于最后评分。目标缺少某源类别时balancedAccuracy为NaN并标记不完整，不默认丢掉缺失类别后报告更好数字。

### 2. 六种ICC的选择先看设计

| 类别      | 单次    | k次平均  | 关键区别           |
| ------- | ----- | ----- | -------------- |
| 单因素     | ICC11 | ICC1k | 不单独拆测量者效应      |
| 双因素绝对一致 | ICC21 | ICC2k | 系统测量偏移也计入不一致   |
| 双因素一致性  | ICC31 | ICC3k | 允许固定偏移，不等于绝对相同 |

例如每人的第二次测量都加5，排序仍完美，ICC3可为1，ICC2会下降。负ICC是合法结果，意味着当前误差结构下可靠性低，不应裁成0。random/fixed测量者的推广范围仍由设计决定，代码不能代替采样论证。

### 3. 为什么不能随便拼出分半

输入是人×相同item×特征。每次同一item划分用于所有人，计算两半平均分的跨人Pearson r；在平行半测假设下给Spearman-Brown=2r/(1+r)。odd_even按固定顺序，random_balanced随机平衡。

随机分半分布共享人和item，不是独立重复或总体CI。不同人做了不同试题，不能只把“第1题”靠行号当共同item。N3 LR/RL摘要也不能被称长期重测设计。

### 4. Bootstrap按哪一维

ICC对独立人整行有放回抽样，所有occasion/特征一起保留；percentile区间在至少80%有效抽样等条件下返回。完整平衡数据、无自动缺失删除；复杂混合模型或不平衡设计未包装。



## 二、运行前准备

Transfer MAT含train/test，各有X/featureIds/sampleIds/independentUnitIds/domainId；train.Y必需，test.Y可无。Reliability另一个MAT/data含y（人×occasion/item×特征）、unitIds/featureIds，ICC另有occasionIds，分半另有itemIds。不需要TSV。

| 字段                            | 形状/类型             | 具体含义                                               |
| ----------------------------- | ----------------- | -------------------------------------------------- |
| train / test                  | 两个结构，不能只保存data    | X/featureIds/sampleIds/independentUnitIds/domainId |
| train.Y / test.Y              | 源标签必需，目标标签可选      | 目标标签只参与评分                                          |
| data.y / unitIds / featureIds | Reliability另一个MAT | 人×occasion/item×特征                                 |
| occasionIds或itemIds           | 测量场合名/共同项目名       | 根据icc/split_half选择，不是任意行号                          |

## 四、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_transfer.m](../examples/start_transfer.m)。MATLAB可用 `run('E:/my_study/start_transfer.m')` 运行自己另存的脚本。

```matlab
% transfer启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=transfer_config;
cfg.dataFile='E:/my_study/transfer_data.mat';
cfg.outputRoot='E:/my_study/results/transfer_run01';
cfg.options.unitPolicy='disjoint_units';
cfg.options.dependencyNote='请写训练/目标域及单位依赖来源';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_transfer(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

### 另一个入口：run_reliability

模板：[examples/start_reliability.m](../examples/start_reliability.m)。

```matlab
% reliability启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=reliability_config;
cfg.dataFile='E:/my_study/reliability_data.mat';
cfg.outputRoot='E:/my_study/results/icc_run01';
cfg.method='icc';
cfg.options.designNote='请改为实际的人/测量场合/项目及依赖设计';
cfg.options.nBootstrap=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_reliability(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### transfer_config.m

| 运行时字段                        | 实际修改/默认来源位置                   | 当前默认                                                          | 候选、约束及理论/运行作用                                                                                                                      |
| ---------------------------- | ----------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `cfg.dataFile`               | config/transfer_config.m 第4行  | `fullfile(root,'config','transfer_data.mat')`                 | MAT含train/test结构，各含X/featureIds/sampleIds/independentUnitIds/domainId；train.Y必需，test.Y可省略；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`             | config/transfer_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_transfer')` | 新输出目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                                  |
| `cfg.execute`                | config/transfer_config.m 第6行  | `false`                                                       | false身份/边界预检；true拟合和冻结预测；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                                |
| `cfg.options.estimator`      | config/transfer_config.m 第7行  | `'diaglda'`                                                   | diaglda分类或ridge回归；固定模型设置，不在目标域调参。                                                                                                  |
| `cfg.options.lambda`         | config/transfer_config.m 第8行  | `1`                                                           | ridge的严格正L2惩罚，目标均值仅来自源域。                                                                                                           |
| `cfg.options.unitPolicy`     | config/transfer_config.m 第9行  | `'disjoint_units'`                                            | 跨人用disjoint_units；同人跨任务/时段用matched_units_distinct_domains；disjoint_units要求新独立人；matched_units_distinct_domains允许同人新域，但不能重复样本。       |
| `cfg.options.dependencyNote` | config/transfer_config.m 第10行 | `''`                                                          | 任务/时段/被试及上游估计独立性和限制；domainId必须显式不同。                                                                                                |

### reliability_config.m

| 运行时字段                     | 实际修改/默认来源位置                      | 当前默认                                                             | 候选、约束及理论/运行作用                                                                                                      |
| ------------------------- | -------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `cfg.dataFile`            | config/reliability_config.m 第4行  | `fullfile(root,'config','reliability_data.mat')`                 | MAT含data.y(独立单位xoccasion/item x特征)/unitIds/featureIds及occasionIds或itemIds；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`          | config/reliability_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_reliability')` | 新目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                    |
| `cfg.execute`             | config/reliability_config.m 第6行  | `false`                                                          | false预检，true计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                          |
| `cfg.method`              | config/reliability_config.m 第7行  | `'icc'`                                                          | icc或split_half。                                                                                                    |
| `cfg.options.nBootstrap`  | config/reliability_config.m 第8行  | `0`                                                              | ICC独立单位整行percentile bootstrap次数整数>=0；小N优先仅点估计；0不给自助区间；>0重抽独立单位，不能把重抽次数当新增被试。                                       |
| `cfg.options.alpha`       | config/reliability_config.m 第9行  | `.05`                                                            | ICC边际区间尾部概率，总alpha在(0,1)；按所属方法区分：DM为密度归一化指数；重采样模块为置信区间总尾概率。见该字段原注释。                                                |
| `cfg.options.nSplits`     | config/reliability_config.m 第10行 | `100`                                                            | 随机平衡分半次数整数>=1。                                                                                                     |
| `cfg.options.splitPolicy` | config/reliability_config.m 第11行 | `'odd_even'`                                                     | odd_even固定项目顺序，或random_balanced；不跨单位改变项目分组；odd_even固定项目奇偶；random_balanced每次随机平衡，共同分组用于全部人。                         |
| `cfg.options.seed`        | config/reliability_config.m 第12行 | `149`                                                            | 重采样种子，退出恢复RNG。                                                                                                     |
| `cfg.options.designNote`  | config/reliability_config.m 第13行 | `''`                                                             | 单位/测量者/时段/项目和可比性；分半Spearman-Brown依赖平行半测假设。                                                                         |

## 六、结果判定

| 文件/结构           | 应检查什么                        |
| --------------- | ---------------------------- |
| transfer.mat    | 冻结模型、目标预测/身份、可选accuracy/MSE等 |
| reliability.mat | ICC六指标及均方/可选区间，或分半r/SB/项目索引  |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##



## 九、输入、数值约定与实现细节补充

本指南对应两个独立入口：`run_transfer / config/transfer_config.m` 和 `run_reliability / config/reliability_config.m`。通用核心不定位 HCP、不重新估计 beta，不合并重复 run 充独立样本。

### 冻结源模型的跨任务／时段／被试应用

- `cfg.dataFile` 为 MAT，含 `train` 和 `test`。
- 两者字段为 X（样本×特征）、featureIds、sampleIds（各域内唯一）、independentUnitIds（每行独立单位身份，可重复）、domainId（单个明确域名）；
- train.Y 必需，test.Y 可省略。
- 两域 sampleIds 必须完全不重叠，特征身份和顺序完全相同，域名不同。

配置全部位于 `transfer_config.m`：

- `options.estimator='diaglda'` 是原生 MATLAB diagLinear LDA，均匀类别先验，每类源域至少2例；`ridge` 为固定 L2 回归，`lambda=1` 严格正数，不自动调参。
- `unitPolicy='disjoint_units'` 要求训练/目标 independentUnitIds 不相交，用于跨被试；`matched_units_distinct_domains` 允许相同被试的不同任务/时段，但仍不允许重复样本。该选项是明确声明研究对象，不能自动证明两域独立。
- `dependencyNote` 必填，记录域含义、上游估计共享/家系/时序等限制。矩阵的列对应必须由用户准备，不支持没有同源特征的直接跨空间应用。

```matlab
addpath('D:/Function'); setup_function;
c=transfer_config;
c.dataFile='含train和test的MAT绝对路径';
c.outputRoot='新结果目录';
c.options.dependencyNote='说明域、单位以及上游估计的共享情况';
run_transfer(c); % 默认仅预检
c.execute=true;
r=run_transfer(c);
```

- `cog.pattern_fit` 只看源域 X/Y：学习零方差列掩膜、均值/样本SD、目标均值与模型。

- `cog.pattern_apply` 不接收目标标签，严格按冻结参数转换目标 X；

- 不做目标域重新中心化、调参或特征筛选。

- diagLDA 采用 [MATLAB fitcdiscr/predict](https://www.mathworks.com/help/stats/fitcdiscr.html)。

- 保存完整模型和目标样本身份。

- test.Y 存在时才评分。

- 分类输出 accuracy、各源类别 recall 和 balancedAccuracy；

- 目标缺少某源类别时 balancedAccuracy 返回 NaN，并标记 complete=false；

- 出现源域未见类别则拒绝评分。

- 回归输出 MAE/MSE、目标内R²和源域训练均值基线MSE；

- 不把样本内相关当泛化。

- 当前没有迁移学习适应、超参数选择、显著性置换或自动域循环；

- 多个方向由调用者明确组织。

已有 `cog.decode` 的显式分组留一接口可用被试组实现 leave-subject-out。新入口则便于保存一个源模型并反复应用到新的任务/时段/被试，所回答的泛化问题由单位策略和域准备决定。

### 六种 ICC 与输入

- reliability MAT 含 `data.y`（独立单位×测量occasion×特征）、唯一 unitIds、occasionIds、featureIds。
- 完整平衡、有限，无自动删缺失；
- 至少3个独立单位、2次测量。
- 公式遵循 [Shrout–Fleiss 六种 ICC 定义](https://pubmed.ncbi.nlm.nih.gov/18839484/)，但随机/固定测量者的可推广范围仍必须由设计解释。

记 n 个单位、k 次测量；R=单位间均方、C=测量者/occasion间均方、E=双因素残差均方、W=单位内单因素均方：

| 名称    | 点估计                       | 解释              |
| ----- | ------------------------- | --------------- |
| ICC11 | (R−W)/(R+(k−1)W)          | 单因素单次           |
| ICC1k | (R−W)/R                   | 单因素k次平均         |
| ICC21 | (R−E)/(R+(k−1)E+k(C−E)/n) | 双因素随机测量、绝对一致、单次 |
| ICC2k | (R−E)/(R+(C−E)/n)         | 绝对一致、k次平均       |
| ICC31 | (R−E)/(R+(k−1)E)          | 双因素混合、一致性、单次    |
| ICC3k | (R−E)/R                   | 一致性、k次平均        |

输出 `values` 为6×特征，顺序见 metricNames，保存四种均方。负值保留，分母为0返回 NaN；不裁剪到[0,1]。恒定测量偏移会降低绝对一致，但可保留ICC3的一致性；测试有独立解析例子证明这一区别。

- `cfg.method='icc'`；
- `options.designNote` 必填，`nBootstrap=0` 默认仅点值，alpha=.05，seed=149。
- 启用 bootstrap 时对独立单位整行有放回抽样，所有测量/特征一起保留，给边际 percentile 区间；
- 每指标至少80%重抽样值有限且不少于2个才给区间，保存有效次数。
- 不把n很小的区间当可靠科研推断，不实现F检验、BCa、多特征校正或不平衡混合模型。

### 项目分半

`cfg.method='split_half'`，输入维度改为单位×匹配项目×特征，提供 itemIds。每个单位必须有相同明确对应的项目；至少4个项目，不能将不同试次混成同一item。`splitPolicy='odd_even'` 按固定项目顺序分半，仅一个分组；`random_balanced` 随机平衡分组，nSplits=100。所有单位共享该次项目分组。

计算每半的项目均值，再对独立单位计算两半 Pearson r，同时给平行半测假设下的 Spearman-Brown 2r/(1+r)。负值保留；方差为0或修正分母为0给 NaN。保存每次左右项目索引。随机分半分布共享单位/项目，不能视为独立重复、总体置信区间、长期重测信度或完整 generalizability theory。
