# 滑窗动态连接与平稳相位零模型



## 一、方法在分析什么

### 1. 滑窗估计什么

在连续片段中，每次取一段时间的ROI时序计算连接，窗口向前移动，得到一条“连接随窗口位置”的序列。窗口间有大量重叠，不能把每个窗口当独立实验。

| 选择                | 变大/变小会怎样                 | 没有解决什么           |
| ----------------- | ------------------------ | ---------------- |
| windowSeconds     | 大窗相关较稳定但时间分辨率低；小窗更灵敏也更嘈杂 | 真实神经连接变化与采样噪声的区分 |
| stepSeconds       | 小步结果更密、更重叠               | 不会凭空增加独立信息       |
| taper=rectangular | 窗口内同权                    | 端点突变             |
| taper=gaussian    | 中心权重大、两端低                | 不自动保证更好的生理解释     |

程序将秒round到帧并保存实际值；frameIndices有缺帧或run边界就切段，窗口不跨段。GaussianSigmaFraction是sigma/窗口帧数，不是秒数。

### 2. 为什么静态过程也会出现动态曲线

有限样本相关本来就波动。程序可给每个连续段的所有ROI加相同的随机频域相位，保留各自功率谱和逐对互谱，破坏原先的特定时间定位。这是一个平稳多变量零模型，不是完全独立白噪声。

对每个边/窗长取跨窗r标准差，与surrogate比较；每次零样本用全部边和指定窗长的共同最大值作联合校正。只选择“最好看的窗口长度”再单独报告未校正值会改变问题。

##

## 二、运行前准备

TSV为subject/session/run/data_file；data.y（时间×ROI）、trSeconds、roiNames必需，frameIndices可显式保留真实帧号。通用ROI准备器可直接生成。

| 字段                      | 形状/类型         | 具体含义                   |
| ----------------------- | ------------- | ---------------------- |
| y / trSeconds           | T×R / 秒       | 共同ROI时序                |
| roiNames / frameIndices | R个名称 / T个真实帧号 | 不填帧号会视为连续1:T，删帧后必须明确提供 |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_dynamic.m](../examples/start_dynamic.m)。MATLAB可用 `run('E:/my_study/start_dynamic.m')` 运行自己另存的脚本。

```matlab
% dynamic启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=dynamic_fc_config;
cfg.manifestFile='E:/my_study/prepared_roi/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/dynamic_fc_run01';
cfg.options.windowSeconds=[30 60 90];
cfg.options.stepSeconds=3;
cfg.options.taper='gaussian';
cfg.options.nSurrogates=0; % 0只做描述，确认输入后另设次数与新输出
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_dynamic_fc(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### dynamic_fc_config.m

| 运行时字段                               | 实际修改/默认来源位置                     | 当前默认                                                            | 候选、约束及理论/运行作用                                                                                                        |
| ----------------------------------- | ------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`                  | config/dynamic_fc_config.m 第4行  | `fullfile(root,'config','dynamic_runs.tsv')`                    | subject/session/run/data_file；MAT中data.y/trSeconds/roiNames，可有frameIndices；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`                    | config/dynamic_fc_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_dynamic_fc')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                    |
| `cfg.execute`                       | config/dynamic_fc_config.m 第6行  | `false`                                                         | false读输入和窗口预检，true计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                      |
| `cfg.options.windowSeconds`         | config/dynamic_fc_config.m 第7行  | `[30 60 90]`                                                    | 多个正数秒，round到实际帧数并记录；共同最大统计量覆盖这些窗长和全部边。                                                                               |
| `cfg.options.stepSeconds`           | config/dynamic_fc_config.m 第8行  | `3`                                                             | 步长秒>0，round到帧数，至少1帧。                                                                                                 |
| `cfg.options.taper`                 | config/dynamic_fc_config.m 第9行  | `'gaussian'`                                                    | rectangular或gaussian；高斯权重仅在本窗口截断。                                                                                    |
| `cfg.options.gaussianSigmaFraction` | config/dynamic_fc_config.m 第10行 | `.2`                                                            | 高斯sigma/窗口帧数，正数。                                                                                                     |
| `cfg.options.minWindows`            | config/dynamic_fc_config.m 第11行 | `3`                                                             | 同窗长至少3个窗口才计算跨窗相关SD。                                                                                                  |
| `cfg.options.nSurrogates`           | config/dynamic_fc_config.m 第12行 | `0`                                                             | 整数>=0；0不计算零分布/p值；科研需另行选充分次数。                                                                                         |
| `cfg.options.seed`                  | config/dynamic_fc_config.m 第13行 | `47`                                                            | 固定随机种子，退出恢复调用者RNG。                                                                                                   |



## 六、结果

| 文件/结构                         | 应检查什么                       |
| ----------------------------- | --------------------------- |
| dynamic_fc.mat                | 各窗长相关矩阵、实际窗口/帧、r-SD、可选零分布/p |
| DYNAMIC_FC_COMPLETE.mat       | 单run完成                      |
| DYNAMIC_FC_BATCH_COMPLETE.mat | 全部run成功；仍检查窗口数和实际秒数         |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

- 入口 `run_dynamic_fc`，配置 `config/dynamic_fc_config.m`，清单模板 `config/dynamic_runs_template.tsv`。
- 一行 subject/session/run/data_file；
- 每个 MAT 含 `data.y`（时间×节点）、`trSeconds`、唯一有序 `roiNames`，可选 `frameIndices`。
- 所有数值有限；
- 原始输入只读，输出使用新绝对目录。

`frameIndices` 是真实采集帧号，正整数且严格递增；省略代表从1开始的完整连续采集。删帧后不能重新编号伪装连续：例如1…40、101…140会分成两段。每个 run 单独调用，每个连续片段单独开窗，不跨 run／session／缺帧间隔。代码不插值、自动删帧或重新滤波，时序清理及其来源由调用者记录。

- `windowSeconds` 为一组预定窗长，`stepSeconds` 为步长，均按 TR round 成帧数并记录实际秒数。

- 实际窗长至少8帧，多个窗长取整后不能重复；

- 步长至少1帧。

- 窗口保留起止原始帧号、行号和以首采集帧为0的中心秒数。

- 尾部不完整窗口丢弃；

- 每窗长至少 `minWindows`（>=3）个窗口才计算变异，其余明确为 insufficient_windows，不能把总完成标记当成每个设置都覆盖充足。

- `taper` 为 rectangular 或 gaussian，后者 sigma=gaussianSigmaFraction×实际窗帧数，仅在该球窗内截断。

- 每个窗口调用联合带截距 WLS 残差 Pearson 相关，保存 r 和 Fisher z。

- `effectiveWeightCount=1/sum(normalizedWeights²)` 仅描述权重，不是自相关调整后的自由度。

- 完美相关可产生无穷 Fisher z；

- 当前跨窗统计使用有界 r 的样本标准差，未把无穷 z 填成有限值。

- 常量加权时序明确拒绝。

所有无向非对角边按保存的 edgeNodes 顺序输出。跨窗相关 SD 是动态变化的描述量，窗口重叠导致强依赖；不对这些窗口使用独立样本 t 检验，也不自动把高 SD 当成神经状态切换。

### 共享相位零模型

`nSurrogates=0` 不做零模型，大于0时对每个连续片段生成多变量相位 surrogate。每个正频率所有节点乘同一随机相位，再作共轭对称反变换，DC／Nyquist 保留。因此单段离散自谱、互谱和静态相关得以保留；没有独立打乱各节点相位来破坏原静态 FC。测试对奇偶长度逐对核对互谱和相关，精度在数值误差内。

每个 surrogate 重算全部预定窗长的滑窗相关 SD。边的单侧 Monte Carlo p 为 `(1+不小于观测SD的次数)/(B+1)`；共同最大统计量同时覆盖本 run 中全部有效窗长和所有边，得到 pFweEdgesAndLengths。不同 run／被试／ROI选择／额外调参未纳入该检验族。`seed` 固定并恢复外部 RNG。

这个零模型对应周期边界条件下的线性平稳谱约束，不精确保留原振幅排序、尖峰或所有非线性结构；边界不连续、趋势、非高斯信号和先前滤波都可能影响结果。实际窗长需要结合低频范围、扫描时长和运动敏感性预先选择。不能只按显著窗长选结果，也不把一次 surrogate 检验当成数据平稳性的证明。

依据：[Prichard 与 Theiler 的多变量 surrogate 原始论文](https://journals.aps.org/prl/abstract/10.1103/PhysRevLett.73.951)。相位与滑窗代码在本包独立实现，无新增外部依赖；NIfTI到ROI的准备可使用首批共享接口。

###
