# 被试层面的 CPM / Ridge：内折选择、外折检验



## 一、方法在分析什么

### 1. 哪个维度是预测样本这里每一行是一名独立被试，X的列是FC边/脑特征，target是一人一个行为值。不是把一个人的1200帧变成1200个人。groupIds可以把同一家系/依赖单位放进同一个外组。

### 2. 为什么需要两层交叉验证

外折保留一组人，只用于最后评分；训练集内部再留组，比较候选超参数的MSE。选好参数后，用整个外训练集重新拟合，再预测外测人。目标值、协变量处理、缩放和特征筛选都不能提前看到外测结果。

| 方法    | 每个训练折做什么               | 内折选择什么         |
| ----- | ---------------------- | -------------- |
| CPM   | 逐边与训练行为相关，正/负边分别汇总，再回归 | cpmPGrid里的筛选阈值 |
| ridge | 所有有效边一起作L2回归           | lambdaGrid里的惩罚 |

CPM的边筛选p阈值是预测器构造规则，不是最后这些边经过多重校正后的显著性。ridge的目标为SSE+lambda||w||²，不能将同一个lambda数字直接当其他软件平均损失下的等价惩罚。

### 3. 混杂基线与置换

X/Y混杂残差和尺度只能在每训练折学习；另外保留nuisance-only基线，便于看脑特征是否带来额外预测。当前无协变量、独立行等受支持条件下才做完整重拟合的目标置换；有协变量/重复family组时不会用简单乱标签替代正确交换模型。

##

## 二、运行前准备

不需要TSV。MAT含data.x、target、subjectIds、groupIds、featureIds，可选covariates/exchangeBlocks。x为独立被试×边；subjectIds唯一。当前嵌套约束至少6个独立组，保证内层仍有足够训练组。

```matlab
data.x=X; data.target=behavior(:);
data.subjectIds=subjectIds(:); data.groupIds=familyOrSubjectIds(:);
data.featureIds=edgeNames(:);
save('E:/study/prediction_data.mat','data');
```

这些变量必须来自自己的已对齐表；不能分别排序脑和行为后靠行号碰运气。

| 字段                      | 形状/类型        | 具体含义               |
| ----------------------- | ------------ | ------------------ |
| x / target              | N人×P特征 / N×1 | 注意小写x，行是独立人        |
| subjectIds / groupIds   | N个身份/组       | subject唯一，依赖家系同组   |
| featureIds / covariates | P个身份 / N×C可选 | 所有人脑/行为/混杂需同一行对齐   |
| exchangeBlocks          | N个交换块，可选     | 支持条件受限，不能据块名证明可交换性 |



## 三、 步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_prediction.m](../examples/start_prediction.m)。MATLAB可用 `run('E:/my_study/start_prediction.m')` 运行自己另存的脚本。

```matlab
% prediction启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=prediction_config;
cfg.dataFile='E:/my_study/prediction_data.mat';
cfg.outputRoot='E:/my_study/results/prediction_run01';
cfg.options.method='ridge'; % 或cpm
cfg.options.lambdaGrid=[.1 1 10 100];
cfg.options.nPermutations=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_prediction(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### prediction_config.m

| 运行时字段                                      | 实际修改/默认来源位置                     | 当前默认                                                            | 候选、约束及理论/运行作用                                                                                                     |
| ------------------------------------------ | ------------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `cfg.dataFile`                             | config/prediction_config.m 第4行  | `fullfile(root,'config','prediction_data.mat')`                 | data.x/target/subjectIds/groupIds/featureIds，可加covariates/exchangeBlocks；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`                           | config/prediction_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_prediction')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                 |
| `cfg.execute`                              | config/prediction_config.m 第6行  | `false`                                                         | false完整CV输入预检，true运行嵌套CV与可选置换；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                          |
| `cfg.options.method`                       | config/prediction_config.m 第7行  | `'ridge'`                                                       | ridge或cpm；每外折内部留一组选择超参数。                                                                                          |
| `cfg.options.lambdaGrid`                   | config/prediction_config.m 第8行  | `[.1 1 10 100]`                                                 | ridge惩罚系数，>0；目标为SSE+lambda*\|\|w\|\|²，不是平均损失尺度。                                                                   |
| `cfg.options.cpmPGrid`                     | config/prediction_config.m 第9行  | `[.01 .05 .1]`                                                  | CPM训练折双侧边相关p阈值，在(0,1)；内折按MSE选择。                                                                                   |
| `cfg.options.nPermutations`                | config/prediction_config.m 第10行 | `0`                                                             | Monte Carlo次数>=0；有协变量或重复family组时当前不支持目标置换；0不置换；>0增加Monte Carlo分辨率/成本，最小plus-one p=1/(B+1)，仍需交换假设。                 |
| `cfg.options.exchangeabilityJustification` | config/prediction_config.m 第11行 | `''`                                                            | 写明独立被试和交换块的依据；代码不自动验证实验假设。                                                                                        |
| `cfg.options.seed`                         | config/prediction_config.m 第12行 | `43`                                                            | 固定随机种子，退出恢复调用者RNG。                                                                                                |



## 六、结果

| 文件/结构                        | 应检查什么                   |
| ---------------------------- | ----------------------- |
| prediction.mat               | 外测预测、各折训练参数、选中的超参数和可选置换 |
| out_of_group_predictions.tsv | 每人目标、脑模型预测、混杂基线预测       |
| PREDICTION_COMPLETE.mat      | 完整外折成功，不等于N或模型已足够科研     |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

- 入口 `run_prediction`；
- 配置 `config/prediction_config.m`。
- 这是有训练折内预处理和嵌套参数选择的独立实现，参考 [YaleMRRC 的 CPM 协议与源码](https://github.com/YaleMRRC/CPM) 和 [MATLAB ridge 定义](https://www.mathworks.com/help/stats/ridge.html)，没有复制或再分发其源码。
- 本包 CPM 是标准化残差边、正负网络联合回归的显式变体，不宣称逐字节复现某个原始脚本。

### 输入和独立性

`dataFile` 是含 `data` 的 MAT：x 为被试×特征，target 为有限数值目标，subjectIds 为唯一被试身份，featureIds 为唯一特征身份，groupIds 为 CV 组。可选 covariates 为被试×数值协变量，exchangeBlocks 为目标置换允许块；省略分别为空协变量／全部同一交换块。

一行一被试。多 session/run 可以构成该被试不同特征或在预先规定的策略下汇总，不能重复同一被试的 target 并伪增独立 N。家系／相关被试使用共同 groupIds，整个组同时留出。代码不自动识别 HCP 家系关系或推断特征对应边；方阵 FC 通常只取一次上三角、不含对角线，是否使用 r 或 Fisher z 应在准备输入时记录。

本嵌套流程至少6个独立 CV 组；所有双重留组后的协变量设计须满列秩，训练人数大于设计列数加2。这是当前实现的运行边界，不是科学样本量推荐。`execute=false` 检查这些条件，true 才训练；新 `outputRoot` 拒绝覆盖。

### 训练、选择和输出

外层留一 group，内层在剩余 group 中再留一组，按合并内折预测的 MSE 选择参数；并列选择配置网格最先出现者。所有内折和外折重新拟合：训练协变量加截距分别回归 x 和 y；仅用训练残差计算边均值、标准差、常量特征掩膜；再拟合预测模型。外测应用这些已学参数，原始目标从未用于该折模型或超参数选择。

`method='ridge'` 在标准化残差特征上求最小化 SSE + lambda × 权重平方和；lambdaGrid 所有值为正，截距／协变量不惩罚。这个 lambda 尺度不是每样本平均损失尺度。高维特征使用对偶解，但目标相同。

`method='cpm'` 在训练残差中按边—目标 Pearson 相关的双侧 p 筛选，考虑训练协变量所耗自由度，再分别求正／负入选标准化边之和，用联合线性模型预测目标残差。cpmPGrid 在 (0,1)，也只通过内折 MSE 选择。常量或线性依赖的网络强度列不加入设计；没有边入选时保留协变量/训练均值基线，不伪造非零网络。

外测预测包含训练协变量模型加回的部分，因此总目标相关可能主要来自协变量。结果同时给 nuisanceOnlyPrediction 和基于外层训练协变量残差的 residualCorrelation，不能把总预测性能全归因于连接特征。`correlation/rSquared/mae` 对合并外测预测计算；负 R² 保留。常量预测可使相关未定义，不把 NaN 解释为0或高性能。

每外折保存训练／测试行号、内折 MSE、选中参数及完整训练模型。`cog.prediction_fit` 和 `prediction_apply` 是单独可复用的冻结模型接口；外部新队列的 featureIds／协变量语义须由调用者与保存清单核对，不能只凭相同列数推定身份。

### 置换

- `nPermutations>0` 每次重新运行完整嵌套选择和预处理，目标仅在 exchangeBlocks 内打乱，按较高预测相关方向计算 `(1+超过或等于次数)/(B+1)`。
- 必须写 exchangeabilityJustification。
- 当前直接目标置换只支持每人唯一 CV 组且没有协变量的情形；
- 相关家系和有协变量的残差置换尚未实现，明确拒绝，不能借设置一个 site 块自动消除家系依赖。
- 观测或任何零分布相关未定义时拒绝产生 p。
- 没有解析相关 p、重复 CV 挑最好结果或自动多目标校正。
