# 自发活动：ALFF、fALFF 与 ReHo



## 一、方法在分析什么

### 1. 振幅与一致性是两种问题

ALFF看某个体素在所选低频段“波动多大”；fALFF看该频段占实际正频谱振幅的比例；ReHo看一个体素和周围邻居的时间排序有多一致。它们不是同一个指标的三种写法。

### 2. ALFF/fALFF怎样算

对N点时序做不补零FFT。单边振幅为abs(FFT)/N，除直流和Nyquist外加倍。

$$ALFF=\operatorname{mean}_{f\in band}A(f),\qquad fALFF=\frac{\sum_{f\in band}A(f)}{\sum_{f>0}A(f)}.$$

这套约定用振幅，不能换成平方后的功率比。例如正频谱中带内振幅和=6，全部正频谱和=10，则fALFF=.6。修改bandHz会改变分子包含的频点；它不是先截掉带外成分再计算“全谱分母”。

频率间距为1/(N×TR)，短记录未必含你指定的频点；没有频点时明确拒绝。补零只改变频率插值，本包未将其当作新增信息。

### 3. ReHo为什么使用秩

每个体素按时间点给出排序，Kendall W检验同一小邻域的排序是否一致。相同值使用平均秩，并校正ties。W接近1表示局部排序更一致，不等于神经活动强。

| neighborhood | 含中心的几何邻域   | 改变后的含义        |
| ------------ | ---------- | ------------- |
| 7            | 中心+6个面相邻体素 | 更小的局部范围       |
| 19           | 再含棱相邻      | 中等范围          |
| 27           | 整个3×3×3方块  | 更大范围，可能跨组织/边界 |

`minNeighbors`约束实际mask内邻居数，边界不足输出NaN并另存覆盖图，不补零邻居。邻域是体素格点定义，不是固定毫米半径。

### 4. 参数与预处理顺序

ALFF采用不新增带通的清理分支；ReHo采用clean.bandHz对应分支。已带通输入不能再计算有意义的“全正频率”分母；已经平滑会人为提高局部相似性。因此fALFF拒绝声明为denoised_bandpassed的输入，ReHo要求输入已有平滑声明=0。

##

## 二、运行前准备

使用11列 `analysis_runs_template.tsv`。本次组合输入应是未平滑且未事先带通的数据；上游高通必须如实声明。ROI图仍是共享入口必需字段，即使主要关心体素图。



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_spectrum.m](../examples/start_spectrum.m)。MATLAB可用 `run('E:/my_study/start_spectrum.m')` 运行自己另存的脚本。

```matlab
% spectrum启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=function_config;
cfg.manifestFile='E:/my_study/analysis_runs.tsv';
cfg.outputRoot='E:/my_study/results/alff_reho_run01';
cfg.methods={'alff','reho'};
cfg.spectrum.bandHz=[.01 .08]; % ALFF分子频段，Hz
cfg.clean.bandHz=[.01 .08];    % ReHo所用时序的本次带通
cfg.reho.neighborhood=27;
cfg.reho.minNeighbors=7;
cfg.continueOnError=false;
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

| 文件/结构                         | 应检查什么                |
| ----------------------------- | -------------------- |
| alff.nii / falff.nii          | 振幅/比例，不是自动z图         |
| reho.nii / reho_neighbors.nii | W值及实际邻居数；NaN位置结合覆盖解释 |
| spectrum.mat / reho.mat       | 数值定义、选中频点和清理信息       |
| COMPLETE.mat                  | run计算完成，不能据此认定生理指标可靠 |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

### ALFF/fALFF和ReHo

- ALFF/fALFF在联合去趋势/混杂但尚未本次带通的分支计算。
- 使用未补零FFT，振幅为abs(FFT)/N，除DC和Nyquist外单边加倍；
- ALFF是带内频点振幅均值，fALFF是带内振幅和除以全部正频率振幅和，不是功率比。
- 零信号ALFF=0、fALFF=NaN；
- 频带无可用Fourier点时报错。
- 此明确归一化不承诺与零填充FFT工具的绝对ALFF逐数相同。
- 已经带通的输入拒绝计算fALFF；
- 上游highpass等处理保留在来源声明中，分母只表示实际保留下来的完整正频谱。

ReHo要求声明未平滑输入，支持7/19/27邻域。每体素先按时间平均秩，计算带ties校正的Kendall W；边界只使用mask内实际邻居，最小邻居数由reho.minNeighbors指定，不足/全常数时输出NaN，并另存邻居数图。不暗中把缺失邻居当零信号。输出不自动进行z变换或空间平滑。
