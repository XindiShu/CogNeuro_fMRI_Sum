# PCM：用第二矩描述表示结构



## 一、方法在分析什么

### 1. 为什么不是再做一个RDM相关

PCM将模式Y写作条件表示+run等效应+噪声，表示的第二矩G描述哪些条件的模式共同变化。它对模式数据建立概率模型，比较在明确噪声假设下的数据似然/外测评分，而不是只比较几个距离条目的相关。

| 模型        | 给定什么            | 拟合什么                  |
| --------- | --------------- | --------------------- |
| fixed     | 一个完整PSD Gc      | 按配置拟合scale/噪声等，表示形状固定 |
| component | 一组PSD Gc(:,:,k) | 原生参数化的非负成分贡献及噪声       |

例如三个条件的identity G与某两个条件共享成分，表达不同表示假设。矩阵必须半正定；不能随意把一个看起来像RDM的矩阵直接当G。

### 2. 噪声为什么必须声明

rowNoiseCovariance描述估计单元间噪声依赖，featureNoiseCovariance描述体素/特征噪声。程序可按给定特征协方差白化；也可接受already_whitened声明。工程unwhitened只能明确opt-in，不能把它默认为科学白化。

### 3. 四种mode改变留出的对象

| mode          | 训练对象           | 评分对象                 |
| ------------- | -------------- | -------------------- |
| individual    | 各人数据           | 同一人拟合似然              |
| group         | 多个人共享表示参数      | 各人拟合似然               |
| individual_cv | 同一人其余partition | 留出partition的条件高斯预测评分 |
| group_cv      | 其余被试的表示参数      | 留出被试，原生拟合其scale/噪声   |

个体CV至少3partition，使训练还剩2个；组CV至少3被试。外测评分不是自动Bayes后验概率。固定run效应会投影共同条件方向，两条件中心化只有一个对比维度，不能再识别多个独立成分。

##

## 二、运行前准备

TSV只有subject/data_file，一名独立被试一行。data需y（估计单元×特征）、condition、partition、rowNoiseCovariance、noiseNote、spatialNoiseState；可提供featureNoiseCovariance。多个session/run可以编码进partition，仍保留一人一行。

cfg.conditionLabels明确模型行列顺序。cfg.models为cell，每模型name/type/Gc。相同条件、partition和噪声约定下才比较模型。

| 字段                            | 形状/类型        | 具体含义                     |
| ----------------------------- | ------------ | ------------------------ |
| y / condition / partition     | 观测×特征 / 每行标签 | 每partition含所有声明条件        |
| rowNoiseCovariance            | 观测×观测正定      | 估计单元噪声依赖，不是条件Gc          |
| noiseNote / spatialNoiseState | 说明 / 状态字符串   | already_whitened或明确工程未白化 |
| featureNoiseCovariance        | 特征×特征正定，可选   | 提供则按它白化，来源需说明            |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_pcm.m](../examples/start_pcm.m)。MATLAB可用 `run('E:/my_study/start_pcm.m')` 运行自己另存的脚本。

```matlab
% pcm启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=pcm_config;
cfg.manifestFile='E:/my_study/pcm_subjects.tsv';
cfg.outputRoot='E:/my_study/results/pcm_run01';
cfg.pcmPath='D:/matlab/atoolbox/pcm_toolbox-master/pcm_toolbox-master';
cfg.conditionLabels={'A','B','C'}; % 必须与数据和模型顺序一致
cfg.models={struct('name','independent','type','fixed','Gc',eye(3))};
cfg.options.mode='individual';
cfg.options.allowEngineeringNoise=false;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_pcm(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### pcm_config.m

| 运行时字段                               | 实际修改/默认来源位置              | 当前默认                                                     | 候选、约束及理论/运行作用                                                                                                         |
| ----------------------------------- | ------------------------ | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`                  | config/pcm_config.m 第4行  | `fullfile(root,'config','pcm_subjects.tsv')`             | subject/data_file，一被试一行，可把多个session/run编码为partition；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。                         |
| `cfg.outputRoot`                    | config/pcm_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_pcm')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                     |
| `cfg.pcmPath`                       | config/pcm_config.m 第6行  | `''`                                                     | 含pcm_fitModelGroup.m等文件的官方PCM目录。                                                                                      |
| `cfg.execute`                       | config/pcm_config.m 第7行  | `false`                                                  | false完整数据/模型/噪声预检，true原生拟合；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                 |
| `cfg.conditionLabels`               | config/pcm_config.m 第8行  | `{}`                                                     | 明确有序条件标签，与所有Gc的行列顺序一致。                                                                                                |
| `cfg.models`                        | config/pcm_config.m 第9行  | `{}`                                                     | cell结构name/type/Gc；fixed=单个PSD矩阵，component=PSD矩阵的3D堆叠。                                                                |
| `cfg.options.mode`                  | config/pcm_config.m 第10行 | `'individual'`                                           | individual/group/individual_cv/group_cv。                                                                              |
| `cfg.options.runEffect`             | config/pcm_config.m 第11行 | `'fixed'`                                                | fixed或random；fixed时成分需在条件中心化空间可识别；fixed将run共同方向作为固定效应处理；random采用随机run效应，影响可识别的表示空间。                                   |
| `cfg.options.fitScale`              | config/pcm_config.m 第12行 | `'auto'`                                                 | auto：fixed和group拟合scale；individual component不另拟合scale。也可显式logical；auto按固定/成分及个体/组模式选择是否拟合额外幅度；可显式logical，避免重复scale参数。 |
| `cfg.options.maxIterations`         | config/pcm_config.m 第13行 | `100`                                                    | 正整数优化上限；有限似然不等于充分收敛。                                                                                                  |
| `cfg.options.allowEngineeringNoise` | config/pcm_config.m 第14行 | `false`                                                  | true允许显式声明unwhitened_engineering；false需要特征噪声协方差或声明already_whitened。                                                   |

## 六、结果

| 文件/结构                | 应检查什么                               |
| -------------------- | ----------------------------------- |
| PCM.mat              | 模型、噪声说明、原生结果、似然/评分、Gcrossval等诊断     |
| model_likelihood.tsv | 行被试、列模型，具体含义由mode决定                 |
| PCM_COMPLETE.mat     | 有限评分和输出通过；convergenceAssessed=false |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

入口 `run_pcm`，配置 `config/pcm_config.m`；调用本机官方 MATLAB PCM 优化器，支持 fixed／component G 模型、个体与群体拟合、被试内分区 CV 和留一被试 group CV。feature／nonlinear／freechol／模型族后验、噪声上限和参数群体推断未包装，不能将本基础接口称为整个 PCM 工具箱的完整覆盖。

- 官方目录在 `D:/matlab/atoolbox/pcm_toolbox-master/pcm_toolbox-master`，pcmPath 指向该目录。
- 现有 ZIP 无可靠 commit/version 元数据，因此记录为本机快照，关键源码 SHA256 和来源保存在其新增 FUNCTION_PROVENANCE.json，原 MIT LICENSE 和源码未改；
- 依赖不随 Function 分发。
- 依据：[官方 MATLAB 源码](https://github.com/jdiedrichsen/pcm_toolbox)、[官方模型与拟合说明](https://pcm-toolbox-python.readthedocs.io/en/latest/fitting.html)。
- Python 文档用于方法边界，实际调用的是本机 MATLAB 版本。

### 输入与噪声

清单模板 `config/pcm_subjects_template.tsv`，每行 subject/data_file，一名独立被试一行；多个 session/run 编入该人的 partition，不把它们伪增为独立被试。不同人的空间特征数可以不同，但条件语义和 G 的行列顺序必须相同。`conditionLabels` 必须预先明确有序标签。

MAT 含 data：y 为观测×空间特征，condition／partition 每观测一个标签；每个 partition 必须包含全部条件，不静默补缺失单元。可复用 `cog.load_betas` 逐被试读现有 beta 目录，再通过预定独立 ROI／掩膜选列；不要在同一数据上按任务效果筛选后再声称独立模型比较。

- rowNoiseCovariance 是观测×观测的已知正定协方差形状 S，native 另估计噪声幅度。
- 它可以来自一级估计器／设计相关的噪声结构；
- 并非体素空间协方差。
- noiseNote 必须描述来源。
- featureNoiseCovariance 若提供则按 Cholesky 空间白化 y；
- 否则 spatialNoiseState 必须显式声明 already_whitened，或在 allowEngineeringNoise=true 时声明 unwhitened_engineering。
- 后者只是工程旁路，不建立独立同分布误差假设。
- 不能无记录地从待检验模式本身估计噪声并把测试信息泄漏到 CV；
- 复杂噪声估计应使用合适残差或独立数据。

### 模型、拟合与分数

- models 为 cell，每模型有唯一 name、type 和 Gc。
- fixed 为一份条件×条件 PSD 矩阵，component 为 PSD 成分的3D堆叠，用正权重线性组合。
- runEffect=fixed 时在条件中心化空间检查成分线性独立性；
- 被固定均值移除的重复成分明确拒绝。
- 零矩阵 fixed 可作为无条件信号的基线。
- 所有模型参数初值固定为0，避免旧 group-CV 例程用全被试 Ghat 初始化共享参数。

mode 为 individual／group／individual_cv／group_cv。所有输入至少两个分区；individual_cv 至少三个分区，以保证每训练折仍有两个；group 至少两名独立被试，group_cv 至少三人。这些是当前工程边界，不是科研样本量建议。

- fitScale=auto 时 fixed 及 group 模式估计个体尺度；
- individual component 不再另估计一个与成分权重重复的尺度。
- 也可明确给 logical。
- group 成分权重／个体尺度按原生规则及其尺度约束拟合，不应将绝对权重解释为已唯一识别。
- runEffect 可选 fixed 或 random，maxIterations 只限制优化，不证明充分收敛。

普通个体／group 拟合用原生边际似然；group_cv 用原生留一被试拟合共享表示参数，在被留出者上再估计其尺度和噪声。因此 group_cv 不是冻结全部参数后预测一个从未见过的行为目标。旧版 fixed-group-CV 没有给 theta_hat 赋值，本包只请求 T，固定 G 无自由参数部分明确返回空 theta 和原 G，不修改依赖源码。

- 旧版 individual-CV 没有正确切分提供的 S，且预测部分未完整使用该噪声结构。

- 本包改为每训练折调用原生个体拟合，S 按训练行切分；

- 再按拟合的 G、噪声、尺度和可选随机 run 效应构造完整观测协方差，计算高斯条件预测。

- 训练固定效应不确定性和测试固定效应分别按平坦先验积分，保留跨分区的已知 S 块；

- 超参数用训练点估计，是 plug-in predictive score，不对其后验积分。

- 每个分区保留训练／测试行号、原生拟合和条件预测均值／协方差。

- 各折受限预测对数密度求和，不包装为原生旧例程输出。

- likelihood 与 deltaLogLikelihoodVsFirst 按同一被试、同一数据/特征/噪声结构下比较；

- CV 分数和普通似然的定义不同，不跨 mode 混比，也不直接 softmax 成 Bayesian 模型概率。

- 不同自由度模型比较应结合合适 CV／推断设计。

- Gcrossval／SigmaCrossval 是原生无设计加权的诊断，不能当成对任意行协方差都完成偏差校正的估计。

- convergenceAssessed=false 保留，有限数值不是识别性或优化成功的充分证据。

###
