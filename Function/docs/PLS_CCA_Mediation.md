# PLS、CCA 与线性中介：关联、预测和路径要分开

## 一、方法在分析什么

### 1. 同样的X/Y，方法目标不同

| method         | 最大化/拟合什么           | 留出时评价什么              |
| -------------- | ------------------ | -------------------- |
| pls_covariance | X/Y得分的协方差，交叉协方差SVD | 冻结得分乘积；不是Y预测         |
| cca            | 经协方差白化后的X/Y相关方向    | 冻结配对得分乘积；不是总体典型相关证明  |
| pls_regression | 少量潜变量下预测Y          | 真正留组Y预测、MSE/R²       |
| mediation      | 给定X/M/Y线性路径        | a、b、直接/间接/总效应，假设另需论证 |

PLS-C受尺度影响较大；scaleFeatures决定训练残差是否按SD缩放。CCA的lambdaX/Y给协方差加ridge；二者都为0才是经典CCA，要求可观察秩/正定性。正则结果的奇异值不能直接当普通样本相关。

### 2. 样本内关联通常偏乐观

高维中可以找到很强训练关联。crossValidate使用显式cvGroups，所有混杂/尺度/方向只从训练组学习。nComponents和正则在当前入口中是固定的，不会因为外测表现好就自动合理；若要选择它们需再设嵌套训练。

### 3. 置换与bootstrap的对象

PLS-C/CCA在支持的独立无混杂行条件下整行置换Y，每次重拟合；bootstrap按independentUnitIds整单位抽样并对权重符号对齐。相关或近重根成分的旋转不自动解决，符号对齐不是完整成分匹配。

### 4. 线性中介的代数与因果不同

M=aX+协变量，Y=c'X+bM+协变量，间接效应ab，总效应c。在相同样本/共同协变量线性模型下检验c≈c'+ab是代数核对；ab不因显著就能证明X通过M导致Y。

整单位percentile bootstrap描述当前路径抽样不确定性。N=3结果模型df=0时只给点值，不伪造置信区间；二分类结局/交互/因果识别不在此接口。



## 二、运行前准备

不需要TSV。data.X/Y、sampleIds、independentUnitIds、XfeatureIds/YfeatureIds必需；可有covariates/cvGroups/exchangeBlocks。中介另有单列M，predictorColumn/outcomeColumn选择X/Y中的列。所有行须已按相同样本身份合并。

| 字段                                     | 形状/类型         | 具体含义                |
| -------------------------------------- | ------------- | ------------------- |
| X / Y                                  | N×X特征 / N×Y特征 | 同一行观测/独立单位          |
| sampleIds / independentUnitIds         | N个样本名/单位名     | sample唯一，重复测量单位一起保留 |
| XfeatureIds / YfeatureIds              | 各侧列身份         | 不得混排序               |
| covariates / cvGroups / exchangeBlocks | 可选            | 分别控制混杂、留出、交换        |
| M                                      | N×1，仅中介       | X/Y指定列外的单一中介向量      |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_multivariate.m](../examples/start_multivariate.m)。MATLAB可用 `run('E:/my_study/start_multivariate.m')` 运行自己另存的脚本。

```matlab
% multivariate启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=multivariate_config;
cfg.dataFile='E:/my_study/multivariate_data.mat';
cfg.outputRoot='E:/my_study/results/pls_run01';
cfg.method='pls_covariance';
cfg.options.nComponents=1;
cfg.options.crossValidate=false; % 有明确cvGroups再true
cfg.options.nPermutations=0;
cfg.options.nBootstrap=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_multivariate(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### multivariate_config.m

| 运行时字段                                      | 实际修改/默认来源位置                       | 当前默认                                                              | 候选、约束及理论/运行作用                                                                                                                                 |
| ------------------------------------------ | --------------------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `cfg.dataFile`                             | config/multivariate_config.m 第4行  | `fullfile(root,'config','multivariate_data.mat')`                 | data.X/Y/sampleIds/independentUnitIds/XfeatureIds/YfeatureIds，可加covariates/cvGroups/exchangeBlocks/M；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`                           | config/multivariate_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_multivariate')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                                             |
| `cfg.execute`                              | config/multivariate_config.m 第6行  | `false`                                                           | false输入与模型预检，true计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                                                |
| `cfg.method`                               | config/multivariate_config.m 第7行  | `'pls_covariance'`                                                | pls_covariance/cca/pls_regression/mediation。                                                                                                  |
| `cfg.options.nComponents`                  | config/multivariate_config.m 第8行  | `1`                                                               | 预先指定维数，不能超过训练折的可观察秩。                                                                                                                          |
| `cfg.options.scaleFeatures`                | config/multivariate_config.m 第9行  | `true`                                                            | 每训练折分别对X/Y残差按样本SD缩放。                                                                                                                          |
| `cfg.options.lambdaX`                      | config/multivariate_config.m 第10行 | `.1`                                                              | CCA X协方差ridge>=0；0要求训练特征协方差正定；CCA的X协方差ridge>=0；0需要正定性，>0改变最优化问题并缓解病态。                                                                         |
| `cfg.options.lambdaY`                      | config/multivariate_config.m 第11行 | `.1`                                                              | CCA Y协方差ridge>=0；均为0时经典CCA，非自动调参；CCA的Y协方差ridge>=0；与lambdaX共同为0才是经典CCA。                                                                        |
| `cfg.options.crossValidate`                | config/multivariate_config.m 第12行 | `false`                                                           | 用显式cvGroups留一组；固定维度/惩罚，不是嵌套模型选择。                                                                                                              |
| `cfg.options.nPermutations`                | config/multivariate_config.m 第13行 | `0`                                                               | PLS-C/CCA独立无协变量行的块内Y置换；PLS回归不支持该统计置换；0不置换；>0增加Monte Carlo分辨率/成本，最小plus-one p=1/(B+1)，仍需交换假设。                                                  |
| `cfg.options.nBootstrap`                   | config/multivariate_config.m 第14行 | `0`                                                               | 关联权重或中介ab的独立单位cluster bootstrap次数；PLS回归此处不提供载荷CI；0不给自助区间；>0重抽独立单位，不能把重抽次数当新增被试。                                                               |
| `cfg.options.alpha`                        | config/multivariate_config.m 第15行 | `.05`                                                             | percentile区间的双侧alpha，在(0,1)；按所属方法区分：DM为密度归一化指数；重采样模块为置信区间总尾概率。见该字段原注释。                                                                        |
| `cfg.options.inferenceScope`               | config/multivariate_config.m 第16行 | `'engineering'`                                                   | engineering或assumed_exchangeable；代码不证明独立性/可交换性/因果识别。                                                                                          |
| `cfg.options.exchangeabilityJustification` | config/multivariate_config.m 第17行 | `''`                                                              | 写明单位/依赖结构依据或明确工程目的。                                                                                                                           |
| `cfg.options.seed`                         | config/multivariate_config.m 第18行 | `79`                                                              | 固定重采样RNG并恢复。                                                                                                                                  |
| `cfg.mediation.predictorColumn`            | config/multivariate_config.m 第19行 | `1`                                                               | X中预先指定的单个预测列；M另为单个中介向量。                                                                                                                       |
| `cfg.mediation.outcomeColumn`              | config/multivariate_config.m 第20行 | `1`                                                               | Y中预先指定的单个结果列；线性无交互中介，不是二分类因果模型。                                                                                                               |



## 六、结果

| 文件/结构                     | 应检查什么                                |
| ------------------------- | ------------------------------------ |
| multivariate.mat          | 模型/方向/分数/训练参数、可选CV/重采样或中介路径          |
| MULTIVARIATE_COMPLETE.mat | 数值完成；仍读inferenceEligible和design note |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

入口 `run_multivariate`，配置 `config/multivariate_config.m`。明确区分 PLS-C 双块关联、PLS-R 直接预测、CCA 双块关联和线性路径分解；不能把训练相关、重采样关联、冻结外测或间接效应叫作同一种证据。

### 输入与训练处理

- dataFile 含 data.X/Y（样本×特征）、唯一 sampleIds、independentUnitIds、唯一有序 XfeatureIds/YfeatureIds，可加 covariates、exchangeBlocks、cvGroups。
- 一个独立单位可以有多行，bootstrap 时整单位一起抽样，CV 不能把同单位拆开。
- 实际家系／重复测量／site依赖由输入声明，代码不自动识别 HCP 家系。

所有数值有限实数。每次拟合只用该训练集把协变量加截距从 X/Y 回归掉，再按 scaleFeatures 设置学习残差均值／样本尺度，去除训练常量列。全数据拟合用于描述或重采样统计，独立 CV 折另行重新拟合，不复用全数据载荷。低维投影的维度 nComponents 和 CCA 惩罚参数由使用者预先规定，不自动用外测数据挑最好设置。

### 四种方法

PLS-C（pls_covariance）对预处理 X'Y/(N−1) 做 SVD，statistics 是交叉协方差奇异值，xWeights/yWeights 为成对方向；它们不是各变量的独有解释方差，也不直接产生行为预测。保存双块分数和训练分数相关，后者仅描述样本内关联。

- CCA 对 Cxx+lambdaX·I／Cyy+lambdaY·I 白化后的 Cxy 做 SVD，再回变换权重。

- 两个 lambda 均为0时为经典 CCA，要求相应训练协方差正定；

- 不悄悄用伪逆或全样本 PCA 修补高维问题。

- 正值为显式 regularized CCA，statistics 是正则协方差归一化的奇异值，与实际训练投影 Pearson r 分开保存。

- 经典结果已逐数值核对 MATLAB canoncorr；

- 正则化不消除小 N／调参／泛化问题。

- PLS-R（pls_regression）调用原生 plsregress，直接用冻结 BETA 预测 Y，再恢复训练尺度和协变量部分。

- 检查原生 XS=X0·stats.W 契约，不把 X loading 当回归系数。

- 原生预处理 Y 方差贡献只报告样本内量，不能替代外测 R²。

- 官方依据：[plsregress](https://www.mathworks.com/help/stats/plsregress.html)、[canoncorr](https://www.mathworks.com/help/stats/canoncorr.html)；

- 本轮 MATLAB R2025b。

- mediation 另需单中介向量 data.M，cfg.mediation 明确 X 预测列与 Y 结果列。

- 线性无交互模型为 M~C+X、Y~C+X+M，给 a、b、直接 c'、间接 ab、总 c；

- 相同协变量下 c=c'+ab。

- 这里不建立因果识别，没有未测混杂／时间先后／sequential ignorability 的证明，不是二分类中介或层级路径模型。

- 设计秩不足时拒绝，绝不靠不识别的伪逆给系数。

### 重采样与外测

- PLS-C/CCA 的 nPermutations>0 只支持无协变量、每行唯一独立单位时，在 exchangeBlocks 内打乱整行 Y并重拟合。

- 统计量越大越强，Monte Carlo p=(1+超过或等于次数)/(B+1)，同时给请求成分范围的最大统计量校正。

- 没有 family 成组置换／协变量残差置换。

- 必须写 exchangeabilityJustification，inferenceScope=engineering 标为非科研推断；

- assumed_exchangeable 仅记录调用者的假设，不由代码证明。

- 关联权重 bootstrap 将 X/Y 成对按 independentUnitIds 整单位重抽，重做预处理和拟合；

- 仅按 X 权重内积翻转成对符号，给 percentile 区间。

- 近简并成分可能旋转或换序，当前没有 Procrustes/成分匹配，不能把所有载荷区间自动当稳定脑图。

- 无秩／无变化抽样明确计数，最多尝试20B次，太多则拒绝；

- 区间条件于有效拟合，须查看被拒次数。

- PLS-R 此入口不做这些关联统计置换／载荷区间，而用预测 CV。

- crossValidate=true 需要 cvGroups，按组冻结拟合。

- PLS-R 返回合并外测 Y、每输出 r/R²，负 R²保留。

- PLS-C/CCA 返回各外测双块分数的、按训练分数 SD 标准化的乘积，及其均值／有效数；

- 它对成对符号翻转不变，适合保存双块外段关联贡献，不能称作 Y预测或总体 canonical r。

- 没有内层维度／惩罚选择，设置必须预定或在额外训练层选择。

中介仅提供独立单位 bootstrap 的 ab 等路径 percentile 区间，无 BCa／Sobel p／因果效应保证。需要原样本结果模型残差自由度>0；仅点估计时可保留自由度0的饱和解，但 inferenceEligible=false，无误差方差或区间。重采样与关联置换／CV不是通用可互换选项。
