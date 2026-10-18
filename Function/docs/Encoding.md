# Ridge / Banded Ridge 编码：从刺激特征预测脑反应

## 一、方法到底在分析什么

### 1. 编码与解码方向相反

编码给刺激/任务特征X，预测脑反应Y；解码给脑模式预测标签。这里Y可以同时有多个ROI/体素输出，每一列都有自己的外测预测和评分。

$$\hat W=\arg\min_W ||Y-XW||_F^2+\sum_b\lambda_b||W_b||_F^2.$$

ridge对所有特征用同一lambda；banded_ridge给不同特征空间不同惩罚。例如语义特征和声学特征列数/噪声不同，允许分别压缩。权重大小仍依赖缩放和相关性，不能直接把某组贡献等同“唯一解释方差”。

### 2. lambdaCandidates每行、每列代表什么

ridge为候选数×1；banded为候选数×特征空间数。一行表示事先固定配置，不进行调参；多行才在外训练集内作留组选择。当前按每输出内折MSE选择，因此不同脑输出可选择不同候选。

### 3. 滞后和purge

lagsFrames=[0 1 2]将当前与前1/2采集帧特征用于预测当前脑反应；不会跨run或真实帧号缺口取值。连续采样TR=.8秒时lag2对应1.6秒，不是2秒。

event_estimates的行不是采集帧，因而只允许lag0。continuous需共同TR和逐帧对齐刺激特征。阻塞CV额外剔除训练中靠近测试块的帧，并加上最大lag，避免同一特征时间点重叠；这不证明血流动力学及上游估计已完全独立。

##

## 二、运行前准备

不需要TSV。data含featureSpaces（cell，每个为样本×该空间特征）、对应featureIds（cell）、featureSpaceNames、y、targetIds、runIds、frameIndices、cvGroups；continuous另有trSeconds；可选covariates。

先按真实时钟对齐X与Y，不是把两份表裁成同样行数就算对齐。目标列/特征列身份要明确，估计单元行与采集帧行不混用。

| 字段                                   | 形状/类型                  | 具体含义                    |
| ------------------------------------ | ---------------------- | ----------------------- |
| featureSpaces / featureIds           | cell，每空间N×P_b / cell列名 | 所有空间与Y同一行               |
| featureSpaceNames / targetIds        | 各空间名 / Y列名             | 唯一非空                    |
| y / runIds / frameIndices / cvGroups | N×脑输出 / N个身份           | 实际run/帧和外折组             |
| trSeconds / covariates               | 连续采样必需秒 / N×C可选        | event_estimates不能假装连续采样 |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_encoding.m](../examples/start_encoding.m)。MATLAB可用 `run('E:/my_study/start_encoding.m')` 运行自己另存的脚本。

```matlab
% encoding启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=encoding_config;
cfg.dataFile='E:/my_study/encoding_data.mat';
cfg.outputRoot='E:/my_study/results/encoding_run01';
cfg.options.method='ridge';
cfg.options.lambdaCandidates=[.1;1;10;100];
cfg.options.sampleKind='event_estimates';
cfg.options.lagsFrames=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_encoding(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### encoding_config.m

| 运行时字段                          | 实际修改/默认来源位置                   | 当前默认                                                          | 候选、约束及理论/运行作用                                                                                                                             |
| ------------------------------ | ----------------------------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `cfg.dataFile`                 | config/encoding_config.m 第4行  | `fullfile(root,'config','encoding_data.mat')`                 | data.featureSpaces/featureIds/targetIds/y/runIds/frameIndices/cvGroups/featureSpaceNames，详见新编码指南；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`               | config/encoding_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_encoding')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                                         |
| `cfg.execute`                  | config/encoding_config.m 第6行  | `false`                                                       | false读取/索引/候选预检，true实际CV；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                                       |
| `cfg.options.method`           | config/encoding_config.m 第7行  | `'ridge'`                                                     | ridge或banded_ridge。                                                                                                                       |
| `cfg.options.lambdaCandidates` | config/encoding_config.m 第8行  | `[.1;1;10;100]`                                               | 每行候选；ridge单列，banded每列一个特征空间；单行表示预先固定、不调参。                                                                                                 |
| `cfg.options.lagsFrames`       | config/encoding_config.m 第9行  | `0`                                                           | 非负整数滞后，连续时序单位=采集帧；event_estimates只能0；非负整数采集帧滞后；秒数=帧数×TR，不跨run或缺口。                                                                         |
| `cfg.options.sampleKind`       | config/encoding_config.m 第10行 | `'event_estimates'`                                           | event_estimates或continuous，显式区分trial估计单元/采集帧；event_estimates只允许lag0；continuous按真实采集帧滞后并需要TR。                                              |
| `cfg.options.purgeFrames`      | config/encoding_config.m 第11行 | `0`                                                           | 同一run跨CV块时额外排除相邻训练帧；还会加最大特征滞后以免重叠；同run阻塞CV额外排除测试块附近训练帧；程序还加最大lag避免特征重叠。                                                                   |

## 六、结果

| 文件/结构                 | 应检查什么                        |
| --------------------- | ---------------------------- |
| encoding.mat          | 外测预测、有效帧、候选选择、训练参数与空间/目标身份   |
| ENCODING_COMPLETE.mat | 完整CV完成；查看各输出的基线/R²/MSE而非只看平均 |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

- 编码方向是刺激／任务特征→脑活动。
- 入口 `run_encoding`，配置 `config/encoding_config.m`；
- 支持单一惩罚 ridge、多特征空间分别惩罚的 banded ridge、每脑输出独立的内折参数选择，以及明确 run／缺帧边界的因果滞后特征。
- 数学层独立实现，参考 [Himalaya 官方正则模型定义](https://gallantlab.org/himalaya/models.html)；
- 没有安装或宣称调用其 GPU／随机搜索实现。

### 数据契约

- dataFile 含结构 data：featureSpaces 是多个样本×特征矩阵的 cell；

- featureSpaceNames 为唯一空间名称，featureIds 是对应每空间的唯一有序特征 ID cell；

- y 为样本×脑输出矩阵，targetIds 明确对应 ROI／体素身份；

- runIds、frameIndices 和 cvGroups 每样本一项。

- 可选 covariates 为数值样本×协变量，省略时仅截距。

- 所有值有限实数。

- 该入口一次分析一个明确的数据集，多个被试可各自调用新输出；

- 不隐含跨被试合并。

- sampleKind=event_estimates 时 frameIndices 是 run 内有序估计单元号，只允许 lagsFrames=0；

- 例如试次级 beta 的特征→活动模式预测。

- continuous 时 frameIndices 是实际采集帧号，data.trSeconds 须声明共同 TR 秒，特征必须已与脑采样点对齐。

- 代码不猜刺激时间、重采样、自动HRF卷积或把不同刺激语义补成同一变量。

lagsFrames 为非负唯一整数，y(t) 用每空间 X(t-lag) 预测；每 run 及缺帧段单独匹配实际索引，不跨 run／间断借历史。不足完整历史的行排除、预测保持 NaN，并保存 validRows／sourceRows，不能重编号假装连续。连续刺激的滞后长度应依据 TR 与设计预先设置；不是按脑响应挑滞后。

### 验证与估计

外层留一 cvGroup。默认使用独立 run 分组；相关被试／session或时间块如何成组由问题决定，标签不会自动证明独立性。同一 run 内按块验证时，purgeFrames 加最大特征滞后，从训练端排除靠近测试行的帧，减少共享历史；这不能自动消除全部时序／滤波依赖。

lambdaCandidates 每行一个候选。ridge 每候选一列，所有空间共享该惩罚；banded_ridge 每列一个特征空间，分别惩罚。均为正数。单行是预先固定参数，不调参，至少需两个外 CV 组；多候选需要至少三个组，在外训练部分内再留一组，以每个脑输出的内折 MSE 独立选候选，并列选配置中第一个。候选集完全由调用者预定，不进行无限参数搜索。

每个内／外训练折分别用协变量加截距回归 X 和 y，仅从训练残差估计特征均值／样本尺度、移除训练常量列，再最小化 SSE + Σ_group lambda_group×该组系数平方和；目标保留原活动单位。高维情况用代数等价对偶解。外测应用冻结的混杂系数、尺度和权重，不使用外测 y 选择参数。

- 总预测把训练协变量模型的部分加回，同时保留 nuisancePrediction。
- featureSpacePredictions 仅是线性可加分量；
- 分量相关并不等于特征空间的独有解释方差，当前没有嵌套重新拟合的 variance partitioning。
- 模型、候选损失和每目标选择结果逐折保存；
- encoding_fit／encoding_apply 可单独用于冻结模型，应用前需用保存身份核对特征／目标语义，而非只比较列数。

报告合并外测预测的每输出 Pearson r 和 R²，负 R² 保留；恒定目标／恒定预测相关为 NaN。没有解析显著性、时序置换、自动多体素校正或模板跨队列推断。上游 beta／HRF／特征学习也必须考虑训练测试隔离；本入口不能补救已发生的泄漏。

###
