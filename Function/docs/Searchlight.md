# 体积 Searchlight：把解码或 RSA 移动到每个局部球



## 一、方法在分析什么

### 1. 一个中心只代表一个局部邻域

选择中心后，程序用完整affine把体素坐标变成毫米坐标，取距离≤radiusMm的邻居，在球内运行同一解码/RSA。最后把分数放回中心位置，而不是把分数涂满整个球。

例如2×2×4 mm体素，6 mm半径不能用“每轴3格”代替，否则z方向范围会错。centerMaskFile只控制在哪里报告分数，不改变邻居仍从数据mask取的规则。

### 2. radius与覆盖的权衡

球小更局部、特征少；球大跨更多组织/功能区，训练参数更多。minFeatures不足时输出NaN并记录覆盖，不把NaN改0。所有中心的选择应预先定义，不根据结果挑有利位置再报告原p值。

### 3. 解码图与RSA图不同

decode按显式partition外测；RSA可输出平均条件距离（描述性）或与理论RDM的Spearman相关。平均距离大不代表更符合某理论。model_spearman至少3条件、有变化理论距离；crossnobis需合适全特征噪声协方差，代码按球截取子矩阵。

### 4. 为什么所有中心共享置换

每次合法标签置换用于所有中心，记录该次最大的统计量；某中心相对最大零分布得到FWE校正。若各中心任意独立打乱，不能得到同一张图的正确最大分布。

交换块只规定程序如何打乱，并不证明实验条件可交换。当前校正属于单被试/单单位、选定中心的上尾max，不是群体TFCE或双侧全族推断。

##



## 二、运行前准备

使用与ROI解码相同的beta目录；partitionColumns/exchangeabilityColumns对应目录中实际列。可选中心mask同网格。每subject/session使用自己的数据mask，不能误先求所有人的共同交集再当每人完整覆盖。

## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_searchlight.m](../examples/start_searchlight.m)。MATLAB可用 `run('E:/my_study/start_searchlight.m')` 运行自己另存的脚本。

```matlab
% searchlight启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=searchlight_config;
cfg.catalogFile='E:/my_study/beta_catalog.tsv';
cfg.sourceId='lsa';
cfg.outputRoot='E:/my_study/results/searchlight_run01';
cfg.options.mode='decode';
cfg.options.radiusMm=6;
cfg.options.nPermutations=0; % 先查输入和分数；置换需另填假设说明
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_searchlight(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

## 四、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### searchlight_config.m

| 运行时字段                                      | 实际修改/默认来源位置                      | 当前默认                                                             | 候选、约束及理论/运行作用                                                                                        |
| ------------------------------------------ | -------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `cfg.catalogFile`                          | config/searchlight_config.m 第4行  | `fullfile(root,'config','beta_catalog.tsv')`                     | 现有GLM统一beta目录，不重估GLM。                                                                                |
| `cfg.sourceId`                             | config/searchlight_config.m 第5行  | `''`                                                             | 只允许一个source_id，避免相同事件不同估计器重复。                                                                        |
| `cfg.outputRoot`                           | config/searchlight_config.m 第6行  | `fullfile(fileparts(root),'derivatives','function_searchlight')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                    |
| `cfg.execute`                              | config/searchlight_config.m 第7行  | `false`                                                          | false清单/列预检，true读取beta和计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                 |
| `cfg.centerMaskFile`                       | config/searchlight_config.m 第8行  | `''`                                                             | 空=全部共同掩膜体素；非空为同网格3D中心掩膜，邻居仍来自完整数据掩膜。                                                                 |
| `cfg.partitionColumns`                     | config/searchlight_config.m 第9行  | `{'run'}`                                                        | 每被试/session内CV/RSA分区，多个列组成联合分区键。                                                                     |
| `cfg.exchangeabilityColumns`               | config/searchlight_config.m 第10行 | `{'run'}`                                                        | 分类/回归目标仅在这些列的联合块内打乱；不能据此自动证明可交换性。                                                                    |
| `cfg.targetColumn`                         | config/searchlight_config.m 第11行 | `'condition'`                                                    | 解码目标；分类文本、回归数值；RSA使用condition列。                                                                      |
| `cfg.maxMatrixGiB`                         | config/searchlight_config.m 第12行 | `2`                                                              | beta矩阵double容量上限GiB，不是总峰值承诺；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                                     |
| `cfg.options.mode`                         | config/searchlight_config.m 第13行 | `'decode'`                                                       | decode或rsa。                                                                                          |
| `cfg.options.radiusMm`                     | config/searchlight_config.m 第14行 | `6`                                                              | 球半径毫米>0，用完整affine映射后的欧氏距离，支持非等方体素。                                                                   |
| `cfg.options.minFeatures`                  | config/searchlight_config.m 第15行 | `3`                                                              | 邻域最少特征，整数>=2；不足输出NaN和覆盖数。                                                                            |
| `cfg.options.decode`                       | config/searchlight_config.m 第16行 | `p.decode`                                                       | diagLinear分类或固定lambda ridge回归；缩放在训练折内。                                                               |
| `cfg.options.rsa`                          | config/searchlight_config.m 第17行 | `p.rsa`                                                          | correlation/euclidean/crossnobis，后者须提供全特征协方差再按邻域截取。                                                  |
| `cfg.options.rsaScore`                     | config/searchlight_config.m 第18行 | `'mean_distance'`                                                | mean_distance为描述性平均条件距离；model_spearman需>=3条件/单个有变化modelRDM。                                          |
| `cfg.options.nPermutations`                | config/searchlight_config.m 第19行 | `0`                                                              | Monte Carlo置换整数>=0；0不生成p图；mean_distance不支持置换；0不置换；>0增加Monte Carlo分辨率/成本，最小plus-one p=1/(B+1)，仍需交换假设。 |
| `cfg.options.permutationScope`             | config/searchlight_config.m 第20行 | `'engineering'`                                                  | engineering只检查计算链；assumed_exchangeable是调用者自行负责的可交换性假设。                                               |
| `cfg.options.exchangeabilityJustification` | config/searchlight_config.m 第21行 | `''`                                                             | 记录样本/条件为何能交换，或明确说明仅工程模拟。                                                                             |
| `cfg.options.seed`                         | config/searchlight_config.m 第22行 | `29`                                                             | 非负整数随机种子，退出后恢复RNG。                                                                                   |

### pattern_config.m

| 运行时字段                              | 实际修改/默认来源位置                  | 当前默认               | 候选、约束及理论/运行作用                                            |
| ---------------------------------- | ---------------------------- | ------------------ | -------------------------------------------------------- |
| `cfg.options.decode.task`          | config/pattern_config.m 第3行  | `'classification'` | classification=diagLinear LDA；regression=固定lambda ridge。 |
| `cfg.options.decode.lambda`        | config/pattern_config.m 第4行  | `1`                | ridge正则化>0；分类忽略，不根据测试集调参。                                |
| `cfg.options.rsa.metric`           | config/pattern_config.m 第5行  | `'correlation'`    | correlation/euclidean/crossnobis。                        |
| `cfg.options.rsa.noiseCovariance`  | config/pattern_config.m 第6行  | `[]`               | 特征×特征的独立残差噪声协方差，正定；不自动从测试标签估计。                           |
| `cfg.options.rsa.modelRDMs`        | config/pattern_config.m 第7行  | `[]`               | 条件×条件×模型数组，空仅生成脑RDM。                                     |
| `cfg.options.rsa.modelLabels`      | config/pattern_config.m 第8行  | `strings(0,1)`     | 与返回的条件标签顺序完全一致。                                          |
| `cfg.options.betaSeries.minTrials` | config/pattern_config.m 第9行  | `4`                | 每subject/session/run/condition最少估计单元，整数>=3。              |
| `cfg.options.betaSeries.estimator` | config/pattern_config.m 第10行 | `'pearson'`        | pearson/spearman/partial。                                |



## 五、结果判定

| 文件/结构               | 应检查什么                            |
| ------------------- | -------------------------------- |
| 每单位/searchlight.mat | 结果、meta、space、中心覆盖及最大零分布         |
| NIfTI分数/覆盖/p图       | 实际生成名称由mode/置换选择决定，mask外/覆盖不足NaN |
| summary.json        | 逐单位实际状态和选择，不把p图称群体结果             |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 输入、数值约定与实现细节补充

入口 `run_searchlight` 复用已估计 beta，不重新拟合 GLM。每个 subject/session 分开分析，该单位内部各 run 掩膜取交集；不同被试不互相缩减掩膜。输出空间和有效范围逐单位记录，没有隐含群体比较。

### 配置和输入

- 使用 `config/searchlight_config.m`，输入 beta 目录格式与 ROI 模式模块一致：`estimate_id/subject/session/run/condition/image_path/volume_index/mask_path`，可有 `source_id`。

- `sourceId` 选择单一估计器来源，不要将相同事件不同算法的 beta 重复当样本。

- `partitionColumns` 指定 CV／RSA 独立分区，默认 run；

- `targetColumn` 指分类目标或数值回归目标；

- RSA 始终使用 condition。

- 配置、源 beta 和源模型只读，结果写新 `outputRoot`。

- `centerMaskFile` 为空时每个共同有效体素作中心；

- 非空必须为同网格3D非负有限掩膜，仅限制中心，不限制邻居。

- `radiusMm` 以毫米为单位：使用 NIfTI 完整 affine 将体素中心转换到物理坐标后建立欧氏球，支持非等方体素和旋转。

- `minFeatures` 是最小邻居数，边界不足给 NaN，同时写邻域体素数，不能把它当作每球固定体素数。

- 当前通过 MATLAB `rangesearch` 建球，LDA/ridge/RSA 调用本包共享计算；

- 未调用 CoSMo 的体素单位半径函数。

- 此为体积球，不是表面测地线 searchlight。

- `options.mode='decode'` 使用 `options.decode` 的 diagLinear LDA 或固定 lambda ridge。

- 分类返回 balanced accuracy，回归返回预测与目标的 Pearson r；

- 缩放和常量特征剔除仅从每个训练折估计。

- 不在全样本筛选特征或调参。

- 跨 run 的上游 beta／HRF 估计、试次依赖、被试／家系分组仍由输入契约决定，留一 run 本身不能证明全流程无泄漏。

- `mode='rsa'` 使用 correlation／euclidean／crossnobis，条件×分区需完整。

- `rsaScore='mean_distance'` 返回下三角平均条件距离，只是描述性分离程度；

- 负 crossnobis 保留。

- crossnobis 必须提供当前单位完整特征顺序的噪声协方差，代码按每个球截取，不自动从同样本残差估计。

- 不同单位特征掩膜变化时，应逐单位提供匹配配置单独运行。

- `rsaScore='model_spearman'` 需要至少3条件、一个非恒定模型 RDM，`modelLabels` 与实际 condition 首次出现顺序严格一致。

- 两条件只有一个距离，不可能计算模型秩相关。

### 置换与推断范围

`nPermutations=0` 不输出 p 图。大于0时要求填写 `exchangeabilityJustification`：分类／回归只在 `exchangeabilityColumns` 的联合块内打乱目标，所有中心共享同一套行置换；RSA 模型拟合仅将模型条件身份整体重排，所有中心共享同一套条件置换。mean_distance 对条件重命名不变，因此拒绝这种置换。

- 调用者必须根据实验随机化和误差依赖判断可交换性。

- `permutationScope='engineering'` 明确标为 `inferenceEligible=false`，数值 p 图仅检验计算链；

- 选择 `assumed_exchangeable` 则记录调用者假设，代码并未证明它成立。

- 存在协变量时不能用这里的直接目标打乱代替适当残差置换；

- 当前不提供 Freedman–Lane、试次自相关模型或 family-aware 交换设计。

- 每球得到较高分数方向的单侧 Monte Carlo p=`(1+不小于观测值的次数)/(B+1)`，共享置换中所有有效中心的最大值构成零分布，生成 `pFweMax`。

- 检验族只包含本次该单位请求的有效中心，不包括未计算脑区、别的被试、别的模型或重复调参。

- 有限置换的最小 p 为 `1/(B+1)`。

- 这不是群体随机效应结果，也没有实现 TFCE／cluster 置换；

- 需要相应分析时不能据此替代。

###
