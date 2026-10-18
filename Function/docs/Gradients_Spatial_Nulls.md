# 连接梯度、跨人对齐与空间零模型



## 一、方法在分析什么

### 1. 梯度把“连接指纹相似”画成连续轴

每个节点有一行连接特征。两个区域即使没有很强直接连接，也可能因连接到其他区域的模式相似而在梯度空间靠近。输入节点×特征先变成亲和矩阵，再低维嵌入；轴是相似性结构，不是激活强度或时间传播方向。

| approach | 主要思想         | 怎样解释参数                                   |
| -------- | ------------ | ---------------------------------------- |
| dm       | 沿亲和网络扩散的多步关系 | alpha作密度归一化，diffusionTime控制扩散尺度；0使用原生多尺度 |
| le       | 图拉普拉斯的平滑低维坐标 | 强调相邻节点低维位置接近                             |
| pca      | 线性方差分解       | 成分是线性方差轴，与扩散特征值含义不同                      |

### 2. kernel、稀疏度与对齐

kernel='na'为normalized angle，'cs'为cosine，pearson/spearman比较线性/秩关系，gaussian使用距离核。当前由BrainSpace处理负亲和度；不要把负FC如何处理与亲和核后处理混为一谈。

`sparsityPercent=90`表示每节点连接指纹阈值化掉较低的90%，不是保留90%图边。少节点工程例的高稀疏度可能使图断连，需结合节点数核对。

嵌入轴可整体翻符号/旋转。none不对齐；pa对已经分别嵌入的坐标做Procrustes；joint联合嵌入。PA参考可选外部固定参考，默认有首单位初始化和均值迭代，不能把对齐后更相似当作独立验证的生物学发现。

### 3. 空间相邻为何影响地图相关

皮层地图通常空间平滑，普通打乱节点会破坏这种结构，使相关零分布不合适。Moran用明确空间权重保留指定空间结构；spin旋转球面数据保留几何邻近近似。两者仍依赖正确的节点/顶点对应，并不自动产生被试群体推断。

##

## 二、运行前准备

TSV是subject/session/run/data_file；MAT/data必须含matrix（节点×特征）、nodeIds、featureIds。所有单位的身份和顺序一致。

空间检验可选另一个MAT，含spatial.nodeIds/marker/method/options。Moran的options需要weights、nPermutations、seed；spin需要spheres（surface格式）、hemisphereSizes、surfaceAlgorithm（FreeSurfer/CIVET原生选择）、nPermutations、seed。只给六ROI坐标不能自动当作皮层球面顶点。

| 字段                       | 形状/类型   | 具体含义           |
| ------------------------ | ------- | -------------- |
| matrix                   | 节点×连接特征 | 矩阵行是要嵌入的节点，不是人 |
| nodeIds / featureIds     | 对应行/列身份 | 所有单位顺序一致       |
| spatial.nodeIds / marker | 可选空间MAT | marker与梯度同节点顺序 |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_gradient.m](../examples/start_gradient.m)。MATLAB可用 `run('E:/my_study/start_gradient.m')` 运行自己另存的脚本。

```matlab
% gradient启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=gradient_config;
cfg.manifestFile='E:/my_study/gradient_inputs.tsv';
cfg.outputRoot='E:/my_study/results/gradients_run01';
cfg.brainSpacePath='D:/matlab/atoolbox/BrainSpace_function_20261017/matlab';
cfg.options.approach='dm';
cfg.options.alignment='pa';
cfg.options.nComponents=3;
cfg.spatialNullFile=''; % 有对应marker/空间模型再填写
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_gradients(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### gradient_config.m

| 运行时字段                             | 实际修改/默认来源位置                   | 当前默认                                                           | 候选、约束及理论/运行作用                                                                                              |
| --------------------------------- | ----------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`                | config/gradient_config.m 第4行  | `fullfile(root,'config','gradient_inputs.tsv')`                | subject/session/run/data_file；MAT含data.matrix/nodeIds/featureIds；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`                  | config/gradient_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_gradients')` | 新绝对输出目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                        |
| `cfg.brainSpacePath`              | config/gradient_config.m 第6行  | `''`                                                           | BrainSpace的matlab目录；本机D:/matlab/atoolbox/BrainSpace_function_20261017/matlab。                              |
| `cfg.execute`                     | config/gradient_config.m 第7行  | `false`                                                        | false预检输入/顺序，true原生嵌入/对齐；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                        |
| `cfg.options.kernel`              | config/gradient_config.m 第8行  | `'na'`                                                         | na/cs/pearson/spearman/gaussian；遵循BrainSpace负亲和度置零规则。                                                      |
| `cfg.options.approach`            | config/gradient_config.m 第9行  | `'dm'`                                                         | dm扩散、le拉普拉斯、pca；各自特征值含义不同。                                                                                 |
| `cfg.options.alignment`           | config/gradient_config.m 第10行 | `'pa'`                                                         | none/pa/joint；pa缺省首单位为首次目标，后续迭代均值。                                                                         |
| `cfg.options.nComponents`         | config/gradient_config.m 第11行 | `3`                                                            | 整数>=1且<节点数-1。                                                                                              |
| `cfg.options.sparsityPercent`     | config/gradient_config.m 第12行 | `90`                                                           | [0,100)每节点连接特征百分位阈值；不是图边密度；每节点特征的百分位稀疏阈值，90意为去掉较低90%，不等于保留90%网络边。                                          |
| `cfg.options.alpha`               | config/gradient_config.m 第13行 | `.5`                                                           | 扩散参数[0,1]；按所属方法区分：DM为密度归一化指数；重采样模块为置信区间总尾概率。见该字段原注释。                                                       |
| `cfg.options.diffusionTime`       | config/gradient_config.m 第14行 | `0`                                                            | 非负数；0用原生多尺度缩放；0用原生多尺度DM缩放；正数指定扩散时间，改变低维坐标的尺度。                                                              |
| `cfg.options.alignmentIterations` | config/gradient_config.m 第15行 | `10`                                                           | PA迭代正整数。                                                                                                   |
| `cfg.options.seed`                | config/gradient_config.m 第16行 | `37`                                                           | 固定RNG并在退出后恢复。                                                                                              |
| `cfg.options.reference`           | config/gradient_config.m 第17行 | `[]`                                                           | 外部节点×成分参考；调用者必须核对同一nodeIds/顺序。                                                                             |
| `cfg.spatialNullFile`             | config/gradient_config.m 第18行 | `''`                                                           | 空不做空间关联；MAT含spatial.nodeIds/marker/method/options，须与节点顺序相同。                                                |
| `cfg.spatialGradientColumn`       | config/gradient_config.m 第19行 | `1`                                                            | 单次检验所选已对齐梯度列；多单位/多列不自动做多重比较。                                                                               |

## 六、结果

| 文件/结构                  | 应检查什么                |
| ---------------------- | -------------------- |
| gradients.mat          | 所有单位嵌入/特征值/对齐/可选空间关联 |
| unit_*_gradients.tsv   | 节点×保留成分，按nodeIds解释   |
| GRADIENTS_COMPLETE.mat | 数值完成；空间对应有效性仍需人工核对   |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

- 使用 BrainSpace 原生 `GradientMaps` 与空间随机化函数。
- 官方仓库 `MICA-MNI/BrainSpace` 固定 commit `8730de88ae32c4f88eeaf16ef2a6e53c5c32dc34`，仅检出 MATLAB 子树到 `D:/matlab/atoolbox/BrainSpace_function_20261017`，保留 BSD-3-Clause LICENSE、Git 版本和 `FUNCTION_PROVENANCE.json`。
- 后端不随 Function 分发；
- 新包仅提供接口、校验、测试和工程示例。

### 梯度输入和参数

- 入口 `run_gradients`，配置 `config/gradient_config.m`，清单模板 `config/gradient_inputs_template.tsv`：subject/session/run/data_file。

- 每个 MAT 含 `data.matrix`（节点×特征）、`nodeIds`、`featureIds`，所有输入节点和特征身份、顺序严格一致。

- 矩阵须有限、实数、没有全零节点行；

- 连接特征不一定必须方阵。

- FC 对角线、负连接和清理方式由调用者明确处理，不自动把未记录的操作加到输入。

- `brainSpacePath` 指 BrainSpace 的 matlab 目录；

- `execute=false` 预检矩阵身份和顺序，true 才嵌入。

- `outputRoot` 为新绝对目录。

- `options.kernel` 支持 na（normalized angle）、cs、pearson、spearman、gaussian；

- `approach` 支持 dm、le、pca。

- `nComponents` 为正整数且小于节点数减1。

- `sparsityPercent` 是每个节点连接特征百分位截断 [0,100)，不是网络边密度；

- na 通常产生非负亲和度。

- 代码按当前原生实现对负亲和度置零，不把输入负连接自动取绝对值。

- 阈值过高导致退化时不应强行解释输出。

扩散参数 `alpha` 在 [0,1]，`diffusionTime=0` 用原生多尺度缩放；其他非负值按对应扩散时间处理。`lambda` 是原生各方法的谱值，不统一叫“解释方差比例”，也不把扩散多尺度特征值当作 PCA 方差贡献。

- `alignment='none'` 保留单独嵌入；
- pa 为原生 Procrustes，默认首次参考是第一个输入，以后迭代对齐到前次均值，`alignmentIterations` 控制次数。
- 外部 `reference` 仅供 pa，须与当前 nodeIds／成分完全对齐，由调用者核对；
- 不能用标签错序的参考。
- joint 为原生联合嵌入，会改变各单位的嵌入定义，原生 raw gradients 为空、分单位结果在 aligned。
- 它们是描述性共同空间，不是独立外测结果；
- 用于预测时必须把模板／对齐的训练测试隔离纳入整个验证设计。
- `seed` 固定初始化并恢复外部 RNG。

输出 `gradients.mat` 含原生 gradients／aligned／lambda、实际选用矩阵、清单与身份；每输入一个梯度 TSV，以及总完成标记。梯度符号、近简并成分旋转及不同参数敏感性不能凭一次有限输出消除。

### 空间关联零模型

矩阵接口 `cog.spatial_association(map,marker,method,options)` 比较两个身份严格相同的一维有限图，至少5节点、均有变化。不是普通节点标签随机打乱。

| method | 必须提供的 options                                               | 实际行为与边界                                                                                                                                         |
| ------ | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| moran  | weights、nPermutations、seed                                  | weights 为节点×节点对称、非负、连通、对角为0的空间权重；调用 compute_mem(all) 与 Moran singleton。保留均值/标准差和该权重定义下的空间自相关，不自动推导合理的解剖权重                                       |
| spin   | spheres、hemisphereSizes、surfaceAlgorithm、nPermutations、seed | spheres 为一或两半球有序 cell，匹配完整顶点数据；FreeSurfer/CIVET 指定旋转规则。检查顶点数、以原点为中心的近恒定半径，然后调用原生最近邻旋转。不是唯一一一顶点置换，重复分配可能发生；没有 parcel 旋转、medial wall NaN 处理或皮层下旋转 |

球面方法需要真正对应的球面顶点坐标和按相同顺序的有限图，不能把体积 ROI 质心直接当球面顶点。不得无记录地删掉 NaN 顶点再旋转。Moran 的权重、图值、标记的行身份同样必须明确。两种方法保存实际 surrogate maps、相关零分布及元数据；Moran 额外给出观测／零图 Moran I 检查。

输出为 Pearson r、绝对相关双侧 Monte Carlo p，采用 `(1+超过或等于次数)/(B+1)`。它只覆盖这一次关联，没有自动多梯度／多标记／多单位校正或群体随机效应推断，空间模型是否适用仍需由输入几何和假设判断。

批量梯度中 `spatialNullFile` 可指 MAT，含 `spatial.nodeIds/marker/method/options`，nodeIds 须与梯度输入严格一致；`spatialGradientColumn` 选一个实际对齐梯度列，每输入独立计算关联。空文件路径则不做关联。
