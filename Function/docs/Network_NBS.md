# 社区、密度敏感性、保度零网络与 NBS



## 一、方法分析什么

### 1. 社区是在同一图中寻找什么

Louvain寻找相对给定零连接期望而言，社区内连接更强的划分。gamma改变分辨率：较大倾向更小社区，较小倾向更大社区。多次随机重启取最高Q，仍不保证全局最优。

参与系数衡量一个节点的连接是否分散到多个社区。它依赖所选划分；不是一个完全独立于gamma的固有“枢纽标签”。保存共分配比例矩阵用于查看重复结果，但这不是自动consensus clustering。

### 2. 密度与零网络到底保留什么

densities=.2表示按全部可能无向边数保留最多20%最大正边；正边不足时报告实际密度。相同权重按线性索引决定，可能有确定性偏好。

二值randmio_und保留每节点degree，不保留加权strength、空间长度或连通性。成功重接为0不能称独立随机网络；无四个互异端点的边对直接退出，避免原生无限选边。只有观察/全部有效null均连通等条件满足时才给二值小世界sigma。

### 3. NBS检验的是成分，不是每条边

先在独立人行上计算每边t；超过预定阈值的同号边组成连通成分。extent是成分边数；excess_mass是sum(abs(t)−threshold)。整单位符号翻转对同一人的全部边共享，零分布取全部成分的最大统计量。

both正负分别连成分，再共享两侧最大值。成分p经过校正，不意味着其中每一边单独显著；改变阈值/多个对比后的全族选择不在该p的保证中。

### 4. 精确与Monte Carlo

S<=exactMaxUnits时枚举全部2^S模式，包括观察模式；否则nPermutations次随机符号并采用plus-one p。一样本误差/配对差在零假设下需要符号对称。三人只有8模式，不能把分辨率当成大样本科研推断。

##

## 二、运行前准备

图论TSV为subject/session/run/data_file，data.matrix/nodeIds。同一批节点顺序一致。NBS另一个MAT/data含matrices（节点×节点×独立人）/nodeIds/independentUnitIds；配对比较需先每人内相减。对角不用，Fisher-z对角Inf须在新准备副本中明确置0。

| 字段                            | 形状/类型                  | 具体含义              |
| ----------------------------- | ---------------------- | ----------------- |
| matrix / nodeIds              | 图MAT的N×N / 节点身份        | 有限、对称；拓扑忽略对角      |
| matrices / independentUnitIds | NBS另一个MAT的N×N×S / S个单位 | 一人一个矩阵，配对先做差，有限输入 |
| NBS nodeIds                   | N个名称                   | 与图清单节点顺序一致        |

## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_network.m](../examples/start_network.m)。MATLAB可用 `run('E:/my_study/start_network.m')` 运行自己另存的脚本。

```matlab
% network启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=network_config;
cfg.manifestFile='E:/my_study/network_runs.tsv';
cfg.outputRoot='E:/my_study/results/network_run01';
cfg.bctPath='D:/matlab/atoolbox/BCT_function_20261017/2019_03_03_BCT';
cfg.options.negativePolicy='drop';
cfg.options.densities=[.2 .3 .4];
cfg.nbsDataFile=''; % 需要NBS再提供独立单位矩阵
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_network(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### network_config.m

| 运行时字段                          | 实际修改/默认来源位置                  | 当前默认                                                         | 候选、约束及理论/运行作用                                                                                   |
| ------------------------------ | ---------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`             | config/network_config.m 第4行  | `fullfile(root,'config','network_runs.tsv')`                 | subject/session/run/data_file；MAT含data.matrix/nodeIds；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`               | config/network_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_network')` | 新目录，不能覆盖既有结果；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                        |
| `cfg.execute`                  | config/network_config.m 第6行  | `false`                                                      | false预检；true执行；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                       |
| `cfg.bctPath`                  | config/network_config.m 第7行  | `''`                                                         | BCT函数目录；本机D:/matlab/atoolbox/BCT_function_20261017/2019_03_03_BCT。                              |
| `cfg.options.negativePolicy`   | config/network_config.m 第8行  | `'reject'`                                                   | reject或drop；不取绝对值，不支持signed modularity。                                                         |
| `cfg.options.densities`        | config/network_config.m 第9行  | `[.2 .3 .4]`                                                 | (0,1]递增比例，分母为全部可能无向边，正边不足时记录实际密度。                                                               |
| `cfg.options.gamma`            | config/network_config.m 第10行 | `1`                                                          | Louvain分辨率，严格正数；Louvain分辨率>0；大值通常细分更多小社区，小值倾向合并，不是p阈值。                                          |
| `cfg.options.communityRepeats` | config/network_config.m 第11行 | `20`                                                         | 每密度随机重启次数整数>=1，取最大Q并保存共分配矩阵。                                                                    |
| `cfg.options.nNull`            | config/network_config.m 第12行 | `20`                                                         | 二值保度零网络数量，整数>=0；不是加权保strength null。                                                             |
| `cfg.options.rewireIterations` | config/network_config.m 第13行 | `10`                                                         | BCT每边重接次数整数>=1；无互异四节点边对时不调用可能死循环的原生函数。                                                          |
| `cfg.options.seed`             | config/network_config.m 第14行 | `113`                                                        | 固定随机种子，退出恢复调用者RNG。                                                                              |
| `cfg.nbsDataFile`              | config/network_config.m 第15行 | `''`                                                         | 空则不做NBS；MAT含data.matrices(NxNxS)/nodeIds/independentUnitIds。                                    |
| `cfg.nbs.threshold`            | config/network_config.m 第16行 | `3.1`                                                        | 预定单个t阈值，>0；不自动选择阈值；预定的边t阈值>0，决定哪些边进入连通成分；并非成分最终FWE alpha。                                       |
| `cfg.nbs.tail`                 | config/network_config.m 第17行 | `'both'`                                                     | positive/negative/both；both分别连正负成分，以同一最大零统计量校正两侧；positive/negative/both；both分别连同号成分并共享两侧最大零统计量。 |
| `cfg.nbs.componentStatistic`   | config/network_config.m 第18行 | `'extent'`                                                   | extent边数或excess_mass=sum(abs(t)-threshold)；extent看边数；excess_mass看超过t阈值的质量和；二者是不同检验量。            |
| `cfg.nbs.nPermutations`        | config/network_config.m 第19行 | `999`                                                        | Monte Carlo独立符号翻转数整数>=1；exact分支不用此数。                                                            |
| `cfg.nbs.exactMaxUnits`        | config/network_config.m 第20行 | `12`                                                         | S<=此值枚举2^S符号，0禁用；范围0..16。                                                                       |
| `cfg.nbs.seed`                 | config/network_config.m 第21行 | `127`                                                        | Monte Carlo种子。                                                                                  |
| `cfg.nbs.exchangeabilityNote`  | config/network_config.m 第22行 | `''`                                                         | 独立单位及零假设下差值/误差符号对称的依据；家系/重复run不可充独立N。                                                           |



## 六、结果

| 文件/结构                | 应检查什么                        |
| -------------------- | ---------------------------- |
| 每run/network.mat     | 密度、原生分区/Q、参与、共分配、null度数和成功次数 |
| nbs.mat              | 可选：t、成分/边、FWE p、最大零分布        |
| NETWORK_COMPLETE.mat | 所选批次完成，需看null混合和连通性          |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

- 入口 `run_network`，参数 `config/network_config.m`，清单模板 `config/network_runs_template.tsv`。
- 计算核心分别为 `cog.network_analysis` 和 `cog.nbs_onesample`。
- 旧基础 `cog.graph_metrics` 保持原接口；
- 空间 Moran/spin 在已有梯度模块中，未重复计算。

### 拓扑输入与参数

清单列 `subject/session/run/data_file`，session 可空，键唯一；每个 MAT 含 `data.matrix`（有限对称节点×节点）及唯一 `data.nodeIds`。清单中所有矩阵节点身份/顺序必须相同。对角线在拓扑中清零，原输入文件不改。

```matlab
addpath('D:/Function'); setup_function;
c=network_config;
c.manifestFile='你的清单绝对路径';
c.outputRoot='尚不存在的输出目录';
c.bctPath='你的BCT函数目录';
c.options.negativePolicy='drop'; % 必须明确决定负边如何处理
run_network(c);                % execute=false，只检查输入身份/矩阵
c.execute=true;
run_network(c);
```

`cfg.options` 中全部可编辑行均有中文注释：

| 字段               | 默认与含义                            |
| ---------------- | -------------------------------- |
| negativePolicy   | reject；或 drop，负边置零并记录数量，不取绝对值    |
| densities        | [.2 .3 .4]；递增 (0,1]，分母为 N(N−1)/2 |
| gamma            | 1；严格正的 Louvain 分辨率               |
| communityRepeats | 20；每个密度的随机重启次数                   |
| nNull            | 20；二值保度零网络数量，0不计算                |
| rewireIterations | 10；原生 BCT 每边重接次数参数               |
| seed             | 113；退出恢复调用者随机状态                  |

每个密度保留 floor(density×全部可能边数) 条最大正边；边数不足则保留全部正边，报告实际密度，不补零/负边。相同权重按线性索引排序，可能产生确定性的几何偏好，科研分析应评估该约定。密度曲线是描述性敏感性分析，没有密度选择后的显著性校正。

调用原生 BCT `community_louvain(...,'modularity')`，保存每次分区/Q、最高Q的分区，以及同一社区的出现比例矩阵。这是随机重启描述，不是 consensus clustering 或全局最优保证。`participation_coef` 对该最高Q分区计算加权参与系数；孤立节点为0。基础输出同时保留加权最短路/效率和二值聚类。

零网络用 `randmio_und` 对**二值**邻接重接，逐次检查度数、对称性和零对角，并记录实际成功次数；不保留 strength、连通性、空间布线。找不到四个互异端点的边对时直接返回原二值图/0次重接，避免原生函数的内部循环无法退出。0次重接的结果不能视为随机样本。稠密/小图可能混合不足，本模块不自动证明其混合。

只在观察图及所有零图均连通、所有零图至少有一次成功重接、平均零聚类>0时给二值 normalized C、normalized L、sigma=(C/Cnull)/(L/Lnull)。其他情况返回 NaN；不能用只对有限路径求均值来冒充断连网络的小世界指标。

### NBS 输入与推断范围

- `cfg.nbsDataFile` 默认空。

- 非空时 MAT 含 `data.matrices`（N×N×S）、相同顺序 `nodeIds`、唯一非空 `independentUnitIds`。

- 每个独立单位一个矩阵，S>=3。

- 输入全部有限、对称；

- Fisher-z 对角的 Inf 必须在准备副本时显式清零，NBS不使用对角线。

- 一样本均值检验的零假设为0；

- 配对比较须由调用者先在同一单位内相减，不能把两次测量当独立样本。

- `cfg.nbs` 参数：`threshold=3.1` 是预定的单个 t 阈值；

- `tail=positive/negative/both`；

- `componentStatistic=extent`（边数）或 `excess_mass`（sum(abs(t)−threshold)，是本包明确指定的超阈质量约定）；

- `nPermutations=999`、`exactMaxUnits=12`（允许0..16）、`seed=127`。

- 必须填写 `exchangeabilityNote`，说明独立单位及零假设下误差/差值符号对称的依据。

- 文字声明不能自动证明假设成立。

- 逐边一样本 t，恒定0边给0，非零恒定边拒绝以免产生未定义有限统计量。

- 超过阈值的边形成连通成分；

- both 将正负分别成分化，所有成分/两侧共享每次置换的最大统计量。

- NBS 的成分检验思想见 [Zalesky、Fornito 与 Bullmore (2010)](https://pubmed.ncbi.nlm.nih.gov/20600983/)。

- 本实现独立编写，并非运行官方 NBS GUI。

当 S<=exactMaxUnits，完整枚举2^S个整单位符号，包括观察模式，p=超越次数/模式数。否则独立 Monte Carlo 翻转整行，p=(1+超越次数)/(B+1)。同次翻转对该单位所有边共享，保留边之间依赖。结果保存 t/df、每成分节点/边/符号/统计量/成分FWE p、最大零分布与精确枚举标志。

校正范围仅为**一个预定阈值和统计量**下全图成分及已选两侧。成分p不能赋给其中每条边当作边显著性；多阈值/多对比/多数据选择不在当前校正范围。未实现一般混杂GLM、两样本标签置换、家系交换块、TFNBS或空间限制NBS。

###
