# Beta-series、ROI 解码与 RSA：从估计单元到模式



## 一、方法在分析什么

### 1. 输入的一行究竟是什么

分析矩阵X是“估计单元×体素”，不是“时间点×体素”。一行可能是一个trial/event/item的beta；它来自条件GLM、LSA/LSS或GLMsingle中的明确一种来源。同一个试次的多种估计结果不能当成多个独立样本。

### 2. 同一批beta有三条不同路线

| 路线          | 在比较什么                  | 输出               |
| ----------- | ---------------------- | ---------------- |
| Beta-series | 同条件多个单元间，ROI均值幅度是否共同变化 | ROI×ROI相关矩阵      |
| 分类/回归解码     | 体素模式能否预测留出单元的标签/连续值    | 留组预测、混淆矩阵或MAE/R² |
| RSA         | 不同条件的模式差异是否符合理论几何      | 条件×条件RDM及模型分数    |

分类准确不等于已经知道表示几何；相似RDM也不等于可以预测未见被试。选择方法前先写清目标和留出对象。

### 3. 交叉验证怎样防止看答案

例如run1训练、run2测试，再交换。每折均值、SD、零方差列只能由训练行学习；测试行按冻结参数转换。ridge求解SSE+lambda×||w||²；lambda大更强压缩，lambda小更接近无惩罚。原生diagLDA使用各特征对角协方差和均匀类别先验。

本入口在每subject/session内留partition。要跨人用[冻结泛化](FUNCTION_TRANSFER_RELIABILITY.md)，更多二分类器用[线性SVM/logistic](FUNCTION_REGULARIZED_FC_MVPA_RSA.md)。上游beta若共享HRF选择，事后留run不自动恢复端到端独立性。

### 4. 三种RDM距离

| metric      | 理论量                           | 重要差别                 |
| ----------- | ----------------------------- | -------------------- |
| correlation | 1−空间模式Pearson相关               | 忽略整体幅度尺度，常数模式无定义     |
| euclidean   | sqrt(sum((pa−pb)²))           | 保留幅度/尺度差，大尺度特征影响大    |
| crossnobis  | 独立分区差模式经噪声白化后的交叉乘积平均，并按特征数归一化 | 期望在无真实差异时接近0；可为负，不截断 |

Crossnobis需要独立partition及正定噪声协方差。协方差应来自合适残差/独立噪声估计，不能看测试标签后选择。理论RDM的labels顺序必须完全一致；两个条件只有一个距离，不能计算有变化的距离相关。

##

## 二、运行前准备

需要一张beta目录TSV，不是普通run表。至少列：estimate_id、subject、session、run、condition、image_path、volume_index、mask_path；推荐source_id和estimate_unit。image_path可指4D beta，volume_index从1开始。

ROI标签图由cfg.roiFile指定，必须与beta同网格。多个mask取固定交集；不自动配准。多个source_id时先选一种。每个partition必须含每个RSA条件；分类训练折每类至少2例。

示例行：

```tsv
estimate_id	source_id	subject	session	run	condition	image_path	volume_index	mask_path	estimate_unit
p01_r1_t1	lsa	p01	s1	r1	A	E:/study/beta_0001.nii	1	E:/study/mask.nii	event
```

实际应有足够多行与至少两个run；上面一行只解释列，不足以运行CV。



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_beta.m](../examples/start_beta.m)。MATLAB可用 `run('E:/my_study/start_beta.m')` 运行自己另存的脚本。

```matlab
% beta启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=roi_patterns_config;
cfg.catalogFile='E:/my_study/beta_catalog.tsv';
cfg.roiFile='E:/my_study/roi_labels.nii';
cfg.sourceId='lsa'; % 与自己的目录一致
cfg.outputRoot='E:/my_study/results/roi_patterns_run01';
cfg.methods={'beta_series','decode','rsa'};
cfg.partitionColumns={'run'};
cfg.options.decode.task='classification';
cfg.options.rsa.metric='correlation';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_roi_patterns(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### roi_patterns_config.m

| 运行时字段                  | 实际修改/默认来源位置                       | 当前默认                                                          | 候选、约束及理论/运行作用                                                      |
| ---------------------- | --------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------ |
| `cfg.catalogFile`      | config/roi_patterns_config.m 第4行  | `fullfile(root,'config','beta_catalog.tsv')`                  | 每行独立估计单元；兼容GLM统一beta目录schema。                                      |
| `cfg.roiFile`          | config/roi_patterns_config.m 第5行  | `''`                                                          | 与beta同网格整数ROI标签NIfTI。                                              |
| `cfg.outputRoot`       | config/roi_patterns_config.m 第6行  | `fullfile(fileparts(root),'derivatives','function_patterns')` | 新输出目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                  |
| `cfg.execute`          | config/roi_patterns_config.m 第7行  | `false`                                                       | false只检查清单；true读取beta计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。 |
| `cfg.sourceId`         | config/roi_patterns_config.m 第8行  | `''`                                                          | 单个source_id，避免同一事件LSA/LSS重复进入样本。                                   |
| `cfg.methods`          | config/roi_patterns_config.m 第9行  | `{'beta_series','decode','rsa'}`                              | beta_series/decode/rsa。                                            |
| `cfg.targetColumn`     | config/roi_patterns_config.m 第10行 | `'condition'`                                                 | 解码目标列，分类字符串或回归数值。                                                  |
| `cfg.partitionColumns` | config/roi_patterns_config.m 第11行 | `{'run'}`                                                     | 每个subject/session内部的独立分区字段；默认留一run。                                |
| `cfg.maxMatrixGiB`     | config/roi_patterns_config.m 第12行 | `2`                                                           | double beta矩阵上限GiB，>0；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。         |
| `cfg.roiMinVoxels`     | config/roi_patterns_config.m 第13行 | `3`                                                           | 每ROI最少有效体素，正整数；有效mask内每ROI最低体素数；太少拒绝，不会自动扩大ROI或补零。                 |
| `cfg.options`          | config/roi_patterns_config.m 第14行 | `o`                                                           | 分类/ridge/RSA/最少trial选项在pattern_config中逐项说明。                        |

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



## 六、结果

| 文件/结构                                   | 应检查什么                          |
| --------------------------------------- | ------------------------------ |
| selected_catalog.tsv / roi_coverage.tsv | 实际进入的来源/单元和ROI覆盖               |
| beta_series.mat                         | 逐条件/逐run结果，单元不足有明确状态           |
| unit_*_decode.mat                       | 预测、训练折模型、accuracy/MAE等         |
| unit_*_rsa.mat                          | RDM、labels、partition和modelFits |
| summary.json / PATTERNS_COMPLETE.mat    | 看每个记录的decode/rsa状态；整体返回也可能含跳过项 |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断



##

### Beta目录、beta-series、ROI解码和RSA

- config/roi_patterns_config.m对应run_roi_patterns(cfg)，pattern_config.m给出矩阵方法选项。

- 读取GLM已有统一beta目录，也可手工按相同schema建立目录：estimate_id、subject、session、run、condition、image_path、volume_index、mask_path必须存在；

- 逐beta文件可共用4D图并指定卷号。

- sourceId明确选择一种估计来源，避免同一试次LSA/LSS或GLMsingle不同变体重复进入样本。

- 图像与mask须同网格；

- 不同输入mask取固定交集，不自动统一不同模型单位。

- beta-series按subject/session/run/condition分别计算ROI均值序列的相关；

- estimate_unit须为可比较trial/event/item等，且同组不可混合source/method/variant/units。

- 低于minTrials标记insufficient_trials，不伪造矩阵。

- 默认不合并run，不把故事区块与数学事件宣称为同质trial。

- 解码在每subject/session内留一显式partition，默认partitionColumns={'run'}。

- 分类使用MATLAB diagLinear LDA和均匀先验；

- 回归使用固定lambda ridge。

- 标准化和常数特征剔除只从训练折计算；

- 保存每折均值、尺度、模型和预测。

- 输出accuracy、balancedAccuracy、混淆矩阵，或MAE/R²/相关。

- 少于两个独立分区跳过；

- 每训练折需至少两例每类。

- 无默认调参、特征筛选或未经置换的显著性声明。

- 跨被试/任务的冻结泛化及SVM/logistic已提供独立入口，见本包对应指南。

- RSA按条件和独立partition组织模式，每分区需包含每条件；

- 不填补缺失单元。

- 支持相关距离、欧氏距离和crossnobis。

- crossnobis需>=2独立分区及明确正定噪声协方差；

- 负距离合法，不截断。

- 可比较与返回labels顺序完全一致的modelRDMs，返回Spearman拟合值，无将RDM三角元素误作独立观测的p值。

- 固定条件Pearson天花板/被试bootstrap及PCM已在独立入口提供。
