# OAS 收缩连接、线性分类器与 RSA 噪声天花板



## 一、方法在分析什么

### 1. OAS为何能在p>n时求逆

样本协方差S可能秩不足。OAS在S与球形目标mu×I之间折中：C=(1−rho)S+rho×mu×I，mu=trace(S)/p。rho由数据按明确公式估计，不是用户手填的显著性阈值。

本包采用sklearn OAS约定，MLE分母n，省略原始Chen公式23的2/p项；已与安装的原生sklearn核对。C正定后可求precision及正则partial。这是密集球形收缩，不是graphical lasso或稀疏网络发现。

standardize=true改变各列单位，使目标作用在标准化空间；false保留原幅度。未标准化时常数列也可能因目标而获得正方差，这不代表观察到生理变化。

### 2. 线性SVM与logistic的区别

| estimator | 训练损失/输出侧重点      | 当前固定设置                         |
| --------- | --------------- | ------------------------------ |
| svm       | 间隔分类，输出分数不是校准概率 | 原生fitclinear、ridge、dual solver |
| logistic  | 二项对数损失，输出模型概率   | 原生fitclinear、ridge、LBFGS       |

lambda是原生目标中的L2系数，不直接等于SVM C。训练折按类别例数反比加权，各类总权重相同；变异列、均值/SD都在训练组内学习。当前二分类，不自动ECOC/非线性核或调参。

### 3. RSA噪声天花板为什么需要多个人、多条件

把每个被试RDM上三角去均值/L2归一化。upper将该人与包括本人的组均值比较；lower将其与排除本人的组均值比较。两者都受有限样本影响，不是对所有未来模型的严格概率界限。

模型同样按Pearson距离向量比较。两个条件只有一个距离，零方差，相关没有定义。当前只有固定条件Pearson，不是Spearman/协方差加权比较。

### 4. Bootstrap不能把自己当作其他被试

整被试有放回抽样会重复抽到同一人。lower必须排除目标原始身份的全部副本，否则同一人的噪声会进入自己的预测。只有一种原始身份或其他退化抽样时保留NaN并统计有效数。没有把RDM每条距离当独立观测抽样。

##

## 二、运行前准备

OAS使用subject/session/run/data_file清单，data.y/featureIds。线性解码不需TSV，data.X/Y/featureIds/sampleIds/cvGroups。RSA也不需TSV，data.rdms/subjectIds/conditionIds，可有modelRDMs/modelNames；这三种MAT结构不能互相替用。

| 字段                                     | 形状/类型            | 具体含义              |
| -------------------------------------- | ---------------- | ----------------- |
| data.y / featureIds                    | OAS：时间×特征 / 列名   | 与旧严格partial分支不同   |
| data.X/Y/sampleIds/featureIds/cvGroups | 分类：样本×特征/二类标签等   | 无run TSV，按显式组外测   |
| data.rdms/subjectIds/conditionIds      | RSA：条件×条件×人 / 身份 | 至少3条件/3人          |
| modelRDMs / modelNames                 | 可选理论RDM及唯一名称     | 顺序与conditionIds一致 |

## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_regularized.m](../examples/start_regularized.m)。MATLAB可用 `run('E:/my_study/start_regularized.m')` 运行自己另存的脚本。

```matlab
% regularized启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=regularized_fc_config;
cfg.manifestFile='E:/my_study/prepared_roi/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/oas_run01';
cfg.options.standardize=false;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_regularized_fc(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

### 另一个入口：run_linear_decode

模板：[examples/start_linear_decode.m](../examples/start_linear_decode.m)。

```matlab
% linear_decode启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=linear_decode_config;
cfg.dataFile='E:/my_study/linear_decode_data.mat';
cfg.outputRoot='E:/my_study/results/svm_run01';
cfg.options.estimator='svm';
cfg.options.dependencyNote='请改为真实cvGroups定义及上游估计依赖';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_linear_decode(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

### 另一个入口：run_rsa_ceiling

模板：[examples/start_rsa_ceiling.m](../examples/start_rsa_ceiling.m)。

```matlab
% rsa_ceiling启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=rsa_ceiling_config;
cfg.dataFile='E:/my_study/rsa_ceiling_data.mat';
cfg.outputRoot='E:/my_study/results/rsa_ceiling_run01';
cfg.options.designNote='请改为真实独立被试/条件/RDM来源';
cfg.options.nBootstrap=999;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_rsa_ceiling(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### regularized_fc_config.m

| 运行时字段                     | 实际修改/默认来源位置                        | 当前默认                                                                | 候选、约束及理论/运行作用                                                                                 |
| ------------------------- | ---------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`        | config/regularized_fc_config.m 第4行 | `fullfile(root,'config','regularized_fc_runs.tsv')`                 | subject/session/run/data_file；MAT含data.y/featureIds；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`          | config/regularized_fc_config.m 第5行 | `fullfile(fileparts(root),'derivatives','function_regularized_fc')` | 新目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                               |
| `cfg.execute`             | config/regularized_fc_config.m 第6行 | `false`                                                             | false预检，true计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                     |
| `cfg.options.standardize` | config/regularized_fc_config.m 第7行 | `false`                                                             | true先按该run样本SD标准化；常数特征拒绝；false对原幅度协方差收缩。                                                      |
| `cfg.options.maxFeatures` | config/regularized_fc_config.m 第8行 | `2000`                                                              | 正整数特征上限，O(p^2)内存/O(p^3)求逆，不是全脑体素默认。                                                           |

### linear_decode_config.m

| 运行时字段                        | 实际修改/默认来源位置                        | 当前默认                                                               | 候选、约束及理论/运行作用                                                                       |
| ---------------------------- | ---------------------------------- | ------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| `cfg.dataFile`               | config/linear_decode_config.m 第4行  | `fullfile(root,'config','linear_decode_data.mat')`                 | MAT含data.X/Y/featureIds/sampleIds/cvGroups；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`             | config/linear_decode_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_linear_decode')` | 新目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                     |
| `cfg.execute`                | config/linear_decode_config.m 第6行  | `false`                                                            | false预检，true留组预测；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                         |
| `cfg.options.estimator`      | config/linear_decode_config.m 第7行  | `'svm'`                                                            | svm或logistic；二分类，原生fitclinear。                                                      |
| `cfg.options.lambda`         | config/linear_decode_config.m 第8行  | `.01`                                                              | 固定严格正L2惩罚，不是SVM的C，不在测试组调参。                                                          |
| `cfg.options.seed`           | config/linear_decode_config.m 第9行  | `163`                                                              | native solver随机状态，退出恢复。                                                             |
| `cfg.options.dependencyNote` | config/linear_decode_config.m 第10行 | `''`                                                               | cvGroups代表被试/run/session/family等；上游beta共享和时间依赖由调用者审查。                               |

### rsa_ceiling_config.m

| 运行时字段                    | 实际修改/默认来源位置                      | 当前默认                                                             | 候选、约束及理论/运行作用                                                                                                   |
| ------------------------ | -------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `cfg.dataFile`           | config/rsa_ceiling_config.m 第4行  | `fullfile(root,'config','rsa_ceiling_data.mat')`                 | MAT含data.rdms(条件x条件x被试)/subjectIds/conditionIds，可选modelRDMs/modelNames；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`         | config/rsa_ceiling_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_rsa_ceiling')` | 新目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                 |
| `cfg.execute`            | config/rsa_ceiling_config.m 第6行  | `false`                                                          | false数值预检；true计算并写新目录；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                |
| `cfg.options.nBootstrap` | config/rsa_ceiling_config.m 第7行  | `999`                                                            | 整被试有放回抽样整数>=0；条件固定，不是距离条目的bootstrap；0不给自助区间；>0重抽独立单位，不能把重抽次数当新增被试。                                              |
| `cfg.options.alpha`      | config/rsa_ceiling_config.m 第8行  | `.05`                                                            | 边际percentile区间总alpha在(0,1)；按所属方法区分：DM为密度归一化指数；重采样模块为置信区间总尾概率。见该字段原注释。                                           |
| `cfg.options.seed`       | config/rsa_ceiling_config.m 第9行  | `173`                                                            | 重采样种子，退出恢复。                                                                                                     |
| `cfg.options.designNote` | config/rsa_ceiling_config.m 第10行 | `''`                                                             | 独立被试/家系、RDM估计方法及条件对应来源，不自动证明假设。                                                                                 |

## 六、结果判定

| 文件/结构              | 应检查什么                                  |
| ------------------ | -------------------------------------- |
| regularized_fc.mat | C/precision/相关/partial、rho、MLE协方差和单位信息 |
| linear_decode.mat  | 原生模型、每组训练参数、预测、score类别顺序               |
| rsa_ceiling.mat    | 上下限、模型/逐人分数、单位bootstrap/有效数/边际区间       |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

三个入口分别是 `run_regularized_fc`、`run_linear_decode`、`run_rsa_ceiling`，配置在同名 `config/*_config.m`。算法与HCP定位分离；不会把试验矩阵、真实结果或依赖源码复制进干净发布包。

### OAS 收缩协方差与正则 partial FC

- `regularized_fc_config.m` 中指定 manifestFile、outputRoot、execute；
- 清单列 `subject/session/run/data_file`，模板 `regularized_fc_runs_template.tsv`。
- 每个 MAT 的 `data.y` 为有限时间×特征，`featureIds` 为唯一对应列身份。
- 逐run独立估计，不跨run拼接，不自动滤波/混杂回归。

`options.standardize=false` 默认对原幅度协方差收缩；true先按本run样本SD逐列标准化，拒绝常数列。`maxFeatures=2000` 限制矩阵规模，存在 O(p²) 内存/O(p³) 求逆成本，不是全脑体素默认设置。

- 令 X 为去均值后的 n×p，S=X'X/n（MLE分母n），mu=trace(S)/p，a=mean(S.^2)。

- rho=min(1,(a+mu²)/((n+1)(a−mu²/p)))，分母非正时rho=1，再按[0,1]保护。

- C=(1−rho)S+rho×mu×I。

- 本实现明确采用 [scikit-learn OAS 的约定](https://scikit-learn.org/stable/modules/generated/oas-function.html)，省略原始 Chen 公式中的2/p项；

- 不能声称逐值等于原始公式23的另一版本。

- 输出 covariance、empiricalCovarianceMle、rho、目标均值方差、Cholesky计算的 precision、收缩后的相关以及 partialCorrelation=-Pij/sqrt(PiiPjj)（对角置1），保存输入均值/尺度。

- 即使p>n也可正定；

- 完全零方差数据拒绝。

- 未标准化时个别常数列可被正的球形目标赋予方差，这属于正则模型，不代表该特征观察到生理变异。

这是球形目标的密集收缩，未实现 Ledoit-Wolf、graphical lasso、稀疏边选择或有效样本量校正。BOLD自相关会影响独立行近似，数值正定不证明无偏连接或统计显著；旧严格可逆 sample partial 接口仍保留，二者需区分。

### 线性 SVM 与逻辑回归

- `linear_decode_config.m` 的 dataFile 为 MAT，含 `data.X/Y/featureIds/sampleIds/cvGroups`。

- X为有限样本×特征；

- Y恰好两类，sampleIds唯一。

- cvGroups 为真实要留出的被试/run/session/family等依赖组；

- 全部可编辑参数有中文注释：estimator='svm'或'logistic'，lambda=.01，seed=163，dependencyNote必填。

- 调用 [MATLAB fitclinear](https://www.mathworks.com/help/stats/fitclinear.html)，固定 ridge penalty；

- SVM用dual solver，logistic用LBFGS。

- lambda是该原生目标的正则系数，不能直接当作SVM的C。

- 按源折类别例数给予反比权重，使两类总权重相同。

- 没有自动调参，若需选择lambda，必须在外层训练集内另设内折。

每折通过 `cog.pattern_fit/apply` 只从训练行学习变异列、均值和尺度，再冻结应用；每类训练例数>=2。保存原生模型、训练参数、预测、类别顺序、分数、混淆矩阵、accuracy和balancedAccuracy。SVM分数不是校准概率；logistic的概率是当前模型输出，不等于独立验证的校准保证。调用者仍负责上游beta估计、平滑和组选择引入的依赖。

共享 pattern_fit/apply 也支持旧diagLDA/ridge和新svm/logistic，跨域 `run_transfer` 可显式选用新二分类器；旧独立配置默认项和既有文档保持原内容。尚无多类别ECOC、非线性核、深度模型或额外线性分类置换推断。

### 固定条件空间的 Pearson RSA 天花板与 bootstrap

`rsa_ceiling_config.m` 指定 MAT 中 `data.rdms`（条件×条件×独立被试）、唯一 subjectIds/conditionIds；可选 modelRDMs/modelNames，与数据同一条件顺序。至少3个完整条件、3个独立被试，有限对称零对角；允许负crossnobis距离。每个距离向量须有非零方差。不会将不同估计来源或条件偷偷对齐。

- 只取上三角距离，每个被试向量单独去均值、L2归一化，因而点积等于Pearson相关。

- upper用包括该被试的均值向量归一化后逐人评分；

- lower用排除目标原始被试的均值向量评分。

- 保存逐人分数及其算术平均，未做Fisher变换。

- 模型同样归一化，给每人/平均模型Pearson分数。

- 天花板估计旨在描述测量噪声限制，有限样本上下估计不能当作对所有未来模型的严格概率界限；

- 参见 [RSA工具箱的噪声天花板接口](https://rsatoolbox.readthedocs.io/en/stable/rsatoolbox.inference.noise_ceiling.html)。

- 本模块独立实现，未安装或调用该工具箱。

- `nBootstrap=999` 可为0，alpha=.05，seed=173，designNote必填。

- 每次对整被试有放回抽样，所有条件距离和模型评分一起保留；

- **lower排除目标原始身份的全部抽样副本**，避免同一个人重复抽到后成为自己的预测来源。

- 只有一种原始被试的抽样，lower为NaN；

- 其他零均值池等退化也保留NaN。

- 至少80%重抽样值有限且不少于2个才给该指标边际percentile区间，并保存有效次数。

条件固定，不对距离条目当独立样本抽样，也未实现条件bootstrap、交叉验证模型选择、Spearman天花板或协方差加权RDM比较。不同模型的边际区间并非模型差异检验，未作多模型校正。

### 运行、输出与验证

所有配置默认 execute=false；填入绝对路径/新输出目录和必填说明，先预检，再true执行。OAS每run保存 `regularized_fc.mat`；线性分类保存 `linear_decode.mat`；RSA保存 `rsa_ceiling.mat`，均带实际配置。成功结果不覆盖。

- 4项自动测试包括：12×25高维矩阵与隔离环境原生 sklearn OAS1.9.1逐值对照、正定性与求逆恒等式；
- 两种原生二分类器恢复信号/留出特征变化不改变本折训练模型、标准化尺度不变；
- 完全相同RDM的lower/upper/model=1及bootstrap；
- 原始身份排除和手算leave-one-subject相关。
- 原生Python仅作测试oracle，OAS运行核心无需Python。


