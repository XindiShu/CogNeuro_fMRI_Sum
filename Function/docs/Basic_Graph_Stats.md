# 基础网络指标、网络摘要与被试一样本统计



## 一、方法在分析什么

### 1. 从连接矩阵到图

ROI是节点，保留下来的正连接是边。本基础入口先明确处理负边，再使用绝对阈值；r>=.2与“保留20%边”完全不同。密度控制、社区和零网络见[高级网络](FUNCTION_NETWORK_NBS.md)。

| 指标               | 直观含义         | 当前定义            |
| ---------------- | ------------ | --------------- |
| degree           | 连接到几个邻居      | 二值边数            |
| strength         | 连接权重总量       | 保留正边权重之和        |
| binaryClustering | 邻居彼此是否也连接    | 二值三角形比例         |
| shortest path    | 按指定代价最省的路线   | 每边长度=1/权重       |
| globalEfficiency | 所有成对节点是否容易到达 | 1/最短路的平均，不可达贡献0 |

断连图的有限路径均值只平均能到达的成对路径，不是无条件的全图特征路径长度。不能用它直接宣称“小世界”。

### 2. 一样本统计的单位是人

将每人一个预定边/指标放成Y的行，检验均值是否为0：t=mean(Y)/(SD(Y)/sqrt(N))，df=N−1。也可以先在每人内算配对差，随后用差值一样本检验；不能把同人的run充成额外独立人。

BH-FDR将一次传入的非NaN p值视为一个检验族。alpha=.05改变的是该检验族的控制阈值，不会修复样本依赖、选择偏差或N太少。Cohen dz=均值/差值SD，与独立两组d不是同一个量。



## 二、运行前准备

从NIfTI开始仍用11列analysis_runs清单，并在methods选graph。已有FC矩阵也可直接调用：

```matlab
S=load('E:/study/static_fc.mat','fc');
base=function_config;
g=cog.graph_metrics(S.fc.correlation,base.graph);
save('E:/study/new_graph.mat','g'); % 自己确认文件不存在
```

被试统计直接调用 `stats=cog.group_summary(Y,subjectIds,.05)`，Y为独立人×指标，subjectIds唯一。至少3人只是代码下限，不是科学样本量建议。



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_graph.m](../examples/start_graph.m)。MATLAB可用 `run('E:/my_study/start_graph.m')` 运行自己另存的脚本。

```matlab
% graph启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=function_config;
cfg.manifestFile='E:/my_study/analysis_runs.tsv';
cfg.outputRoot='E:/my_study/results/graph_run01';
cfg.methods={'graph'};
cfg.graph.negativePolicy='drop';
cfg.graph.threshold=.2;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_function(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### function_config.m

| 运行时字段                             | 实际修改/默认来源位置                   | 当前默认                                                          | 候选、约束及理论/运行作用                                                                                  |
| --------------------------------- | ----------------------------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`                | config/function_config.m 第4行  | `fullfile(root,'config','analysis_runs.tsv')`                 | 每行一个subject/session/run；模板analysis_runs_template.tsv；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`                  | config/function_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_analysis')` | 新的结果根目录；不得置于原始输入目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                 |
| `cfg.spmPath`                     | config/function_config.m 第6行  | `fileparts(which('spm'))`                                     | SPM安装目录；空时需先加入SPM路径。                                                                           |
| `cfg.execute`                     | config/function_config.m 第7行  | `false`                                                       | false只预检；true计算并写入新目录，已有run目录拒绝覆盖；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                   |
| `cfg.methods`                     | config/function_config.m 第8行  | `{'static_fc','alff'}`                                        | 已开放方法；METHOD_STATUS.tsv列出可用及待开发项。                                                              |
| `cfg.continueOnError`             | config/function_config.m 第9行  | `true`                                                        | true逐run记录错误继续；false立即停止；false立即停下检查；true逐run保留失败并继续，整体没有完成标记时不要视为成功。                          |
| `cfg.maxMatrixGiB`                | config/function_config.m 第10行 | `2`                                                           | 读入的double矩阵大小上限，GiB>0；不是进程峰值内存承诺；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                          |
| `cfg.roiMinVoxels`                | config/function_config.m 第11行 | `3`                                                           | 每ROI有效掩膜内最少体素，正整数；不足则报错；有效mask内每ROI最低体素数；太少拒绝，不会自动扩大ROI或补零。                                    |
| `cfg.clean.detrend`               | config/function_config.m 第12行 | `true`                                                        | 去除线性趋势；与截距/混杂/频率基联合投影；true加线性趋势列，false不加；截距仍在联合投影中。                                            |
| `cfg.clean.bandHz`                | config/function_config.m 第13行 | `[]`                                                          | []不带通；或[低频 高频]Hz，0<=低频<高频<=1/(2TR)；[]不新增带通；[低 高]Hz约束本次DCT频率选择；不得超过1/(2TR)。                     |
| `cfg.clean.minResidualDimensions` | config/function_config.m 第14行 | `10`                                                          | 投影后最少代数剩余维度；不等于统计有效自由度；联合投影后最低代数剩余维度；不是考虑时间自相关后的有效统计df。                                        |
| `cfg.fc.estimator`                | config/function_config.m 第15行 | `'pearson'`                                                   | pearson/spearman/partial；partial要求可逆样本协方差；pearson=线性相关；spearman=平均秩相关；partial=控制其余列后的严格逆协方差关系。 |
| `cfg.fc.seedColumns`              | config/function_config.m 第16行 | `[]`                                                          | []只做ROI矩阵；非空为ROI列号，额外输出seed-to-voxel。                                                          |
| `cfg.spectrum.bandHz`             | config/function_config.m 第17行 | `[0.01 0.08]`                                                 | ALFF/fALFF频带Hz，须落在Nyquist范围内。                                                                  |
| `cfg.reho.neighborhood`           | config/function_config.m 第18行 | `27`                                                          | 7/19/27含中心体素；在未平滑数据上计算。                                                                        |
| `cfg.reho.minNeighbors`           | config/function_config.m 第19行 | `7`                                                           | 边界最少有效邻居数；不足输出NaN及覆盖状态。                                                                        |
| `cfg.statistics.fdrAlpha`         | config/function_config.m 第20行 | `0.05`                                                        | BH-FDR显著性水平，0<值<1；每次明确给出的检验族单独校正。                                                              |
| `cfg.graph.threshold`             | config/function_config.m 第21行 | `0.2`                                                         | 正边绝对阈值>=0；不是网络密度阈值；绝对正权阈值，不是图密度比例；较高保留边更少、可能断连。                                                |
| `cfg.graph.negativePolicy`        | config/function_config.m 第22行 | `'drop'`                                                      | drop显式丢弃负边并记录数目；reject遇负边报错；drop丢负边并记数；reject报错。不暗中取绝对值。                                       |



## 六、结果

| 文件/结构                 | 应检查什么                           |
| --------------------- | ------------------------------- |
| graph_metrics.mat     | 邻接、degree/strength/聚类/路径/效率及断连数 |
| static_fc.mat         | 本次图指标使用的连接矩阵                    |
| cog.group_summary返回结构 | 低层矩阵接口，需要调用者明确保存位置              |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

### 图论和共同统计

- graph调用ROI矩阵的正边网络；
- graph.threshold为绝对阈值，negativePolicy=drop明确丢弃负边并计数，reject则报错。
- 输出degree、strength、二值聚类系数、权重倒数最短路、全局效率、有限路径均值、密度和断连数。
- 本基础graph函数不包含这些进阶功能；
- 社区/二值零网络/密度/NBS另用run_network，不能把两个入口的范围混淆。

cog.group_summary(y,subjectIds,alpha)仅支持独立被试行的一采样t、均值CI、Cohen dz和BH-FDR；可用每人配对差值，但不是通用重复测量接口。被试ID必须唯一；n>=3只是工程约束。cog.bh_fdr每次传入的全部非NaN值是一个检验族。复杂置换、回归及混合效应仍需后续实现。
