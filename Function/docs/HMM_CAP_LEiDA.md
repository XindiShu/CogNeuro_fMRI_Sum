# HMM、CAP 与 LEiDA：状态是什么、怎样统计变化



## 一、方法在分析什么

### 1. 三种“状态”的定义不同

| method | 每一帧用什么特征                   | 如何分状态                     |
| ------ | -------------------------- | ------------------------- |
| cap    | ROI幅度的空间模式，去空间均值并归一化       | 相关距离kmeans，可选种子激活帧        |
| leida  | 连续段Hilbert相位形成cos相位差矩阵的主向量 | 主向量统一符号后余弦kmeans          |
| hmm    | 有限ROI观测的高斯均值/协方差           | 原生GLHMM变分训练，保留Markov转移与后验 |

CAP不必是“连接状态”；LEiDA的主向量不是神经传播方向；HMM平滑/转移结构也不能自动验证真实状态数。

### 2. HMM的概率结构

隐状态s_t依赖s_(t−1)，观测y_t依赖当前状态的高斯分布。Gamma是每帧各状态的后验概率；Viterbi是整条最可能状态路径，两者不能用逐帧最大后验完全替代。

full协方差允许ROI之间共同变化；diag只保留各列方差。hmmMean='state'给各状态不同均值，'no'把状态差异主要交给协方差。nStates改变模型容量；多初始化/更多循环只是改善数值探索，不等于K选择或稳定性验证。

### 3. 预处理与边界

standardizeWithinRun把每run每ROI标准化，使幅度尺度接近；这属于共享描述模型，不是预测训练/测试隔离。LEiDA在各连续段独立Hilbert并裁端；trim并不能证明所有滤波边界效应已消失。

种子CAP只对超过阈值的帧分配状态，其余为0。0不是第0种脑状态。统计转移只连接相邻有效帧，不跨0、缺帧或run边界；停留区段接触边界时保留左右删失信息。

### 4. 占有率、停留和转移

占有率是某状态有效分配帧数的比例；平均停留是连续访问时长，不是散布时间点间距。若只看完整访问，短记录可能没有有效均值。输出还区分全观测帧占有率/已分配帧占有率和后验占有，不能混用分母。

##

## 二、运行前准备

TSV为subject/session/run/data_file。MAT/data需y、trSeconds、roiNames，建议frameIndices。所有run列顺序一致。ROI准备器直接适用；HMM还需隔离Python环境，CAP/LEiDA无需Python。

| 字段                      | 形状/类型      | 具体含义              |
| ----------------------- | ---------- | ----------------- |
| y / trSeconds           | T×R / 秒    | 至少4点，实际算法另有覆盖约束   |
| roiNames / frameIndices | R个名称 / T帧号 | run/缺口形成连续段，列顺序一致 |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_states.m](../examples/start_states.m)。MATLAB可用 `run('E:/my_study/start_states.m')` 运行自己另存的脚本。

```matlab
% states启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=state_config;
cfg.manifestFile='E:/my_study/prepared_roi/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/states_run01';
cfg.options.method='cap'; % 改leida或hmm时看对应参数
cfg.options.nStates=3;
cfg.pythonExecutable='D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_states(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### state_config.m

| 运行时字段                            | 实际修改/默认来源位置                | 当前默认                                                        | 候选、约束及理论/运行作用                                                                                                    |
| -------------------------------- | -------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`               | config/state_config.m 第4行  | `fullfile(root,'config','state_runs.tsv')`                  | subject/session/run/data_file；data.y/trSeconds/roiNames，可有frameIndices；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`                 | config/state_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_states')` | 新绝对输出目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                              |
| `cfg.execute`                    | config/state_config.m 第6行  | `false`                                                     | false输入预检，true共享模型和逐run统计；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                             |
| `cfg.pythonExecutable`           | config/state_config.m 第7行  | `''`                                                        | 独立GLHMM环境python.exe；本机D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe。                                  |
| `cfg.pythonTimeoutSeconds`       | config/state_config.m 第8行  | `600`                                                       | HMM子进程超时秒>0，超时保留失败材料并终止该子进程。                                                                                     |
| `cfg.standardizeWithinRun`       | config/state_config.m 第9行  | `true`                                                      | 每run每ROI去均值/除样本SD，统一幅度尺度；不是预测训练测试隔离。                                                                             |
| `cfg.maxMatrixGiB`               | config/state_config.m 第10行 | `1`                                                         | 合并原始时序double容量GiB上限；不是总峰值承诺，HMM还需MAT-v7传输空间；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                                 |
| `cfg.options.method`             | config/state_config.m 第11行 | `'cap'`                                                     | cap幅度帧模式；leida瞬时相位主特征向量；hmm原生GLHMM高斯状态。                                                                          |
| `cfg.options.nStates`            | config/state_config.m 第12行 | `3`                                                         | 固定状态数整数>=2；本轮不做自动K选择/稳定性证明；状态数K>=2，增加会提高模型容量；本接口不自动选K或证明稳定性。                                                     |
| `cfg.options.nReplicates`        | config/state_config.m 第13行 | `5`                                                         | CAP/LEiDA kmeans初始化次数，整数>=1。                                                                                     |
| `cfg.options.maxIterations`      | config/state_config.m 第14行 | `200`                                                       | CAP/LEiDA kmeans最大迭代次数。                                                                                          |
| `cfg.options.seed`               | config/state_config.m 第15行 | `53`                                                        | 固定随机种子并恢复调用者RNG。                                                                                                 |
| `cfg.options.capSeedColumn`      | config/state_config.m 第16行 | `[]`                                                        | 空=全部帧；指定ROI列时仅其标准化值高于capSeedThreshold的帧参与。                                                                       |
| `cfg.options.capSeedThreshold`   | config/state_config.m 第17行 | `1`                                                         | seed值阈值；standardizeWithinRun=true时单位为每run z。                                                                     |
| `cfg.options.leidaTrimFrames`    | config/state_config.m 第18行 | `3`                                                         | Hilbert变换在各连续段独立运行，丢弃每端指定帧数>=0；不能自动消除滤波/Hilbert全部边界效应。                                                           |
| `cfg.options.hmmCovariance`      | config/state_config.m 第19行 | `'full'`                                                    | full或diag高斯协方差；full允许ROI间协方差随状态变化；diag只拟合各ROI方差。数据需求和模型容量不同。                                                     |
| `cfg.options.hmmMean`            | config/state_config.m 第20行 | `'state'`                                                   | state拟合每状态均值，no为仅协方差状态；state允许各状态均值不同；no不拟合状态均值差，让状态主要由协方差描述。                                                    |
| `cfg.options.hmmMaxCycles`       | config/state_config.m 第21行 | `50`                                                        | 原生变分训练循环上限正整数。                                                                                                   |
| `cfg.options.hmmInitializations` | config/state_config.m 第22行 | `3`                                                         | 原生初始化尝试次数正整数。                                                                                                    |



## 六、结果

| 文件/结构                  | 应检查什么                          |
| ---------------------- | ------------------------------ |
| state_model.mat        | 共享特征/中心或原生HMM、Gamma/Xi/路径、训练设置 |
| 每run/state_path.tsv    | 真实frameIndices与label；0表示未分配    |
| 每run/state_metrics.mat | 占有/转移/停留及边界删失                  |
| STATES_COMPLETE.mat    | 数值/文件链完成，不证明K或收敛充分             |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

三种方法使用不同观测和模型，不能互相替代：HMM 在区域时序上拟合带 Markov 转移的高斯分布；CAP 聚类帧级幅度空间模式；LEiDA 聚类瞬时相位同步的主特征向量。入口统一为 `run_states`，实际模型和输出中明确 method。

### 环境、输入与配置

- 新配置 `config/state_config.m`，清单模板 `config/state_runs_template.tsv`：subject/session/run/data_file。

- MAT 内 `data.y` 为时间×区域，`trSeconds` 为秒，`roiNames` 为共同且顺序一致的区域身份；

- 可选 frameIndices 保存真实采集帧号，缺帧后必须保留间断。

- 所有输入有限、实数，每 run 至少8帧，区域不能恒定。

- 每 run 单独保留连续片段。

- `standardizeWithinRun=true` 用该 run 的区域均值／样本 SD 标准化，保存尺度；

- 这是共享描述性模型，不是训练测试隔离。

- 关闭时调用者自行确保去均值、滤波及跨 run 尺度符合所选方法。

- 代码不重滤波、不插值、不自动删帧。

- `maxMatrixGiB` 在 (0,2)，限制合并时序 double 体积，不代表总峰值；

- HMM 当前通过 MAT-v7 传输，不是大规模流式训练。

`options.method` 选 hmm/cap/leida，`nStates` 固定 K>=2。没有自动 K 优化、状态跨初始化一致性／稳定性证明、组间状态推断或状态名称自动解释。共享模型会用所有传入 run 的帧，不同被试的 run/时长影响拟合权重；不代表每被试同权或独立预测。

- CAP/LEiDA 依赖 MATLAB Statistics/Signal 功能。
- HMM 依赖官方 GLHMM 1.1.2；
- 本机隔离 Python3.12 环境位于 `D:/matlab/atoolbox/function_glhmm_env`，pythonExecutable 指其 Scripts/python.exe。
- 原应用 Python 未安装新包。
- 官方 wheel 的 GPL-3.0 LICENSE 保留在其 dist-info/licenses，完整版本锁和来源分别在环境根 FUNCTION_REQUIREMENTS_LOCK.txt／FUNCTION_PROVENANCE.json；
- 后端和环境不随 Function 分发。
- `scripts/requirements_glhmm.txt` 列出本轮核心验证版本，供独立环境安装。

### 三条计算路线

- HMM 使用 GLHMM Gaussian 模型，model_beta=no，hmmCovariance 为 full/diag，hmmMean 为 state/no。
- 不同 run 必须同 TR，所有有效连续片段按0起点／右端不含的 indices 传入，短于8帧的片段不拟合且返回 label0；
- 总有效观测至少 K×10，是工程下限。
- hmmMaxCycles／hmmInitializations 控制变分训练循环和初始化次数，原生可停用状态，实际 activeStates 保留。
- 当前是非随机批量 CPU 训练，不是 HMM-MAR/TDE/HSMM。

后验 Gamma、相邻联合后验 Xi、原生转移矩阵、均值／协方差、活跃状态和自由能轨迹保存。Gamma 行和、Viterbi one-hot、Xi 长度必须符合“时间点数减连续片段数”，模型参数须有限、协方差正定。自由能符号和尺度按原生实现保留，不套用 SPM 自由能的比较方向。当前没有检查充分收敛或后验稳定性；示例达到迭代上限也不会标成已收敛。

- GLHMM1.1.2 的串行 Viterbi 公开路径会漏传一个内部 serial 参数，导致维度错误。
- 本包训练用 serial=True，解码改用公开 parallel 路径，保留不同长度片段边界；
- 没有修改安装源码。
- MATLAB 通过 Java 参数数组启动 Python，不拼接 shell；
- pythonTimeoutSeconds 超时只终止自己的子进程，日志及准备文件保留。
- 原生 pickle 模型仅为本次运行的冻结材料，当前包装器不读取外部 pickle。

CAP 对每帧在空间维去均值／单位范数，以 correlation kmeans 聚类。capSeedColumn 为空时用所有非恒定空间帧；指定列则仅使用该列超过 capSeedThreshold 的帧，run 标准化开启时阈值为每 run z 单位。未选帧或无变化空间帧为 label0。centers 是归一化空间观测的聚类中心，不能当成原始 BOLD 百分比幅度图。

- LEiDA 在每个连续片段分别做 Hilbert 变换，取相位，构造 cos(phase_i−phase_j) 并取最大特征值对应单位特征向量。
- 符号约定多数分量为负，数目相等时使总和非正；
- 再以 cosine kmeans 聚类。
- leidaTrimFrames 从每片段两端去除指定帧，太短片段不使用。
- 截去3帧只是工程设置，不能保证 Hilbert／既有滤波边缘影响完全消失。
- nReplicates／maxIterations 控制 CAP/LEiDA kmeans，seed 固定并恢复外部 RNG；
- 重复初始化选目标值较好者不等于稳定性分析。

### 每 run 的统计与输出

共享 state_model.mat 保存模型、实际选帧、序列边界和尺度；HMM另保存原生请求、日志、后验及冻结模型。每 subject/session/run 有 state_path.tsv（原始帧号和1…K标签）与 state_metrics.mat。

硬路径占有率分别以全部观测帧、仅分配帧为分母；前者对 CAP 未选帧／LEiDA 裁剪帧计入分母，状态占有率总和可能小于1。HMM 额外给 Gamma 后验占有率，不能与硬 Viterbi 占有率混淆。每段或 label0 都会切断停留与转移，不跨缺帧/run 接续。

保存逐次 episode、秒单位时长、起止行号和左右边界截断标记；停留时间同时给包含截断 episode 的均值与只含完整 episode 的均值。没有完整 episode 时为 NaN。转移计数包含自保持，行归一化后没有出边的状态为 NaN；切换率以实际可观察正标签相邻对×TR 为分母，没有可用对时为 NaN。没有把未知间隔的状态当作保持，也没有把帧当群体独立被试做显著性。

###
