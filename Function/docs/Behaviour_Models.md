# RW 学习、Softmax、DDM 与潜变量事件导出



## 一、方法在分析什么

### 1. RW是怎样学习的

每试次先由当前Q计算选择概率，再看到reward，更新所选动作：delta=reward−Qchosen，Qchosen←Qchosen+alpha×delta。未选动作在该模型中不更新；新block重置到initialValue。

例如Q=.5、reward=1、alpha=.2，则预测误差=.5，更新后Q=.6。alpha控制新反馈影响，beta控制softmax选择更偏向高Q还是更随机；beta的单位与奖励尺度有关。lapse是固定的均匀随机选择比例，不能当成已拟合参数。

### 2. DDM怎样把选择和反应时连起来

噪声证据从0起点积累，在±B首次到达边界；v为漂移、B为边界半宽、t0为非决策时间。扩散噪声固定为1以确定尺度。观测RT≈决策首达时间+t0。

| 参数  | 理论作用        | 不应直接解释为            |
| --- | ----------- | ------------------ |
| v   | 平均证据积累方向/速率 | 不经设计核对的“能力”        |
| B   | 需要积累到多远才作答  | 边界总宽；本模型总宽为2B      |
| t0  | 非决策耗时       | 所有任务事件之前的时间或任意RT平移 |

本包原生PyDDM常数二选项、无偏起点、固定mixture；复杂漂移/边界、跨试次随机效应未开放。dtSeconds控制密度时间网格，dx在当前解析求解中主要记录模型网格设置，不可当作新的心理参数。

### 3. 拟合成功与行为解释分开

有界多起点/DE减少局部优化风险，但有限NLL或达到循环上限不等于参数恢复良好。真实LANGUAGE准确率只是工程reward代理，RT从第一音频选项算起，不能据此赋予学习或决策机制意义。

### 4. 潜变量进入GLM前还缺时钟

Q、预测误差或概率可作为pmod，但必须明确选择/反馈发生的真实秒数。cog.parametric_events只打包明确onset/duration和对应latent，不猜反馈时点、不估计GLM。默认导出一阶调制，中心化开关明确，orth=0防止隐式顺序正交化。

##

## 二、运行前准备

run清单为subject/session/run/trials_file。每run试次TSV按真实顺序，至少trial_id、block_id、choice；RW还要reward，DDM还要rt_seconds。choice=1..K与actionLabels对应；DDM限2类，1映射上边界。缺失/超限试次不会悄悄删除。

RT单位必须秒：毫秒先明确除1000，且记录起算事件。block_id改变时RW重置，不按试次id字母排序重排行为。

| 字段                  | 形状/类型         | 具体含义                 |
| ------------------- | ------------- | -------------------- |
| trial_id / block_id | 试次表身份列        | 按真实行为顺序，block改变则RW重置 |
| choice / reward     | 整数1..K / RW奖励 | 奖励须在rewardRange内     |
| rt_seconds          | DDM反应时秒       | 选择和RT必须对应同一个试次       |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_behavior.m](../examples/start_behavior.m)。MATLAB可用 `run('E:/my_study/start_behavior.m')` 运行自己另存的脚本。

```matlab
% behavior启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=behavior_config;
cfg.manifestFile='E:/my_study/behavior_runs.tsv';
cfg.outputRoot='E:/my_study/results/rw_run01';
cfg.method='rw_softmax'; % DDM改为ddm并填写Python路径
cfg.actionLabels={'left','right'};
cfg.pythonExecutable='D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_behavior(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 四、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### behavior_config.m

| 运行时字段                       | 实际修改/默认来源位置                   | 当前默认                                                          | 候选、约束及理论/运行作用                                                                                                                  |
| --------------------------- | ----------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `cfg.manifestFile`          | config/behavior_config.m 第4行  | `fullfile(root,'config','behavior_runs.tsv')`                 | subject/session/run/trials_file；试次表按真实顺序，含trial_id/block_id/choice/reward/rt_seconds；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`            | config/behavior_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_behavior')` | 新绝对输出目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                            |
| `cfg.execute`               | config/behavior_config.m 第6行  | `false`                                                       | false检查输入，true拟合并保存逐试次结果；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                            |
| `cfg.method`                | config/behavior_config.m 第7行  | `'rw_softmax'`                                                | rw_softmax或ddm。                                                                                                                |
| `cfg.actionLabels`          | config/behavior_config.m 第8行  | `{'left','right'}`                                            | choice整数1..K与真实行为含义一一对应；DDM限K=2，1为上边界。                                                                                         |
| `cfg.minimumTrials`         | config/behavior_config.m 第9行  | `8`                                                           | 每run最少完整试次数；只是工程下限。                                                                                                            |
| `cfg.pythonExecutable`      | config/behavior_config.m 第10行 | `''`                                                          | 独立PyDDM环境python.exe；本机D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe。                                                |
| `cfg.pythonTimeoutSeconds`  | config/behavior_config.m 第11行 | `600`                                                         | DDM子进程超时秒>0，仅停止自己的子进程。                                                                                                         |
| `cfg.rw.initialValue`       | config/behavior_config.m 第12行 | `.5`                                                          | 每block起始Q，单位与reward相同。                                                                                                         |
| `cfg.rw.rewardRange`        | config/behavior_config.m 第13行 | `[0 1]`                                                       | 允许奖励范围；正确率代理不等同实际反馈，需在输入记录。                                                                                                    |
| `cfg.rw.alphaBounds`        | config/behavior_config.m 第14行 | `[.001 .999]`                                                 | 学习率范围[0,1]内，拟合一份chosen-action RW率；学习率拟合边界，0几乎不更新、1由新反馈完全覆盖所选Q；不是显著性alpha。                                                      |
| `cfg.rw.betaBounds`         | config/behavior_config.m 第15行 | `[.01 20]`                                                    | softmax逆温度，单位=奖励单位的倒数，非负；逆温度范围；大值更偏好高Q，小值更接近随机，依赖奖励单位。                                                                         |
| `cfg.rw.lapse`              | config/behavior_config.m 第16行 | `.02`                                                         | 固定随机选择比例[0,1)，不参与本轮拟合。                                                                                                         |
| `cfg.rw.nStarts`            | config/behavior_config.m 第17行 | `5`                                                           | 有界fmincon多起点次数，整数>=1。                                                                                                          |
| `cfg.rw.maxIterations`      | config/behavior_config.m 第18行 | `200`                                                         | 每起点优化迭代上限；保留exitflag，不保证全局最优。                                                                                                  |
| `cfg.rw.seed`               | config/behavior_config.m 第19行 | `59`                                                          | 多起点随机种子，退出恢复RNG。                                                                                                               |
| `cfg.ddm.driftBounds`       | config/behavior_config.m 第20行 | `[-5 5]`                                                      | 常数漂移范围，固定扩散噪声=1。                                                                                                               |
| `cfg.ddm.boundBounds`       | config/behavior_config.m 第21行 | `[.3 3]`                                                      | 对称边界±B的正半宽范围；边界±B的正半宽范围；增加通常更谨慎、更慢，总边界宽为2B。                                                                                    |
| `cfg.ddm.nondecisionBounds` | config/behavior_config.m 第22行 | `[0 1]`                                                       | 非决策时间秒；上限进一步限制为最小观测RT的95%；非决策时间秒范围；会进一步受最小RT的95%限制，不能混用毫秒。                                                                     |
| `cfg.ddm.dtSeconds`         | config/behavior_config.m 第23行 | `.01`                                                         | 密度时间网格秒；当前恒定DDM用原生解析求解。                                                                                                        |
| `cfg.ddm.dx`                | config/behavior_config.m 第24行 | `.02`                                                         | 空间网格；记录为原生模型设置，非决策参数单位仍为秒。                                                                                                     |
| `cfg.ddm.maxRtSeconds`      | config/behavior_config.m 第25行 | `30`                                                          | 明确的RT秒上限；超限拒绝，不静默截尾或把毫秒当秒。                                                                                                     |
| `cfg.ddm.mixture`           | config/behavior_config.m 第26行 | `.02`                                                         | 固定均匀混合比例(0,1)，降低零密度风险；不是拟合lapse。                                                                                               |
| `cfg.ddm.maxIterations`     | config/behavior_config.m 第27行 | `40`                                                          | differential evolution循环上限；低次数只为工程验证。                                                                                          |
| `cfg.ddm.populationSize`    | config/behavior_config.m 第28行 | `8`                                                           | 原生DE种群倍数，整数>=1。                                                                                                                |
| `cfg.ddm.seed`              | config/behavior_config.m 第29行 | `61`                                                          | 固定原生优化随机种子。                                                                                                                    |



## 六、结果

| 文件/结构                                                | 应检查什么                        |
| ---------------------------------------------------- | ---------------------------- |
| behavior_model.mat                                   | 每run参数、目标函数、实际试次/动作定义        |
| trial_latents.tsv                                    | RW选择前Q、预测误差、概率等              |
| ddm_fit.mat / native_ddm.pkl / trial_ddm_density.tsv | DDM原生模型、逐试次密度与参数             |
| BEHAVIOR_COMPLETE.mat                                | 该run完成；仍检查边界参数/exitflag/试次语义 |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

- 入口 `run_behavior`，配置 `config/behavior_config.m`，清单模板 `config/behavior_runs_template.tsv`。
- 已包装 chosen-action Rescorla–Wagner＋softmax，以及官方 PyDDM 的恒定、无起点偏置二选项 DDM。
- 没有层级贝叶斯、双学习率、模型空间穷举、条件相关漂移／边界、DDM-RL 或神经参数因果解释。

### 行为输入与来源

- 每行 subject/session/run/trials_file，每 run 独立拟合。
- 试次 TSV 必须按真实顺序，有唯一 trial_id、block_id、choice；
- choice 为1…K整数，由 actionLabels 明确映射。
- RW 另需有限 reward；
- DDM 需正的 rt_seconds（秒），choice仅1/2，1为上边界。
- minimumTrials 为工程下限，不能作为参数估计充分的推荐。
- 通用入口不会丢试次、填缺失奖励或推断反应时单位；
- 不完整数据明确拒绝。
- HCP 特定提取和排除记录只在 examples／derivatives，原表不改。

### RW／softmax

- rw_softmax 首先用选择发生前的 Q 计算 softmax，再加入固定 lapse/K 的随机选择概率；

- 当前奖励只在之后更新已选行动 Q ← Q＋alpha×(reward−Q)。

- 每遇 block_id 边界重新置为 initialValue，不把不同 block 当同一学习历程，也不是有记忆的多上下文模型。

- rewardRange 与 initialValue 的单位由任务决定，beta 的单位为该奖励尺度的倒数。

- fit_rw 在 alphaBounds／betaBounds 内以 fmincon 多起点最小化条件负对数似然。

- alpha 在[0,1]，beta非负，lapse固定而非拟合，参数数目为2。

- nStarts／maxIterations／seed 控制优化，保留各起点目标、exitflag 和输出。

- AIC/BIC 由该似然及两参数给出，不替代合适的外测／模型恢复；

- convergenceAssessed=false，即使某起点正常退出也不宣称全局最优或参数可识别。

输出 trial_latents.tsv 保留原 trial_id／block_id、选择、奖励、选择概率、PE、每试次负对数概率和各行动的选择前 Q。若输入额外提供已验证的非负 scanner-relative onset_seconds，另导出带时序的潜变量表。没有反馈时刻的任务不能仅凭 PE 数值自动猜一个真实反馈事件。

### 二选项 DDM

- pythonExecutable 指独立 PyDDM 环境，本机复用 `D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe`，PyDDM0.9.0、MIT LICENSE 和额外版本锁／来源保存在该环境。

- 新增包未改变先前 GLHMM 依赖版本，后端不随 Function 分发；

- 安装核心版本见 scripts/requirements_ddm.txt。

- 使用对称边界±B、固定扩散噪声1、中点起点、恒定漂移 v，以及非决策时间 t0。

- 只拟合 v/B/t0 三参数；

- 固定 UniformMixture 比例提供污染密度。

- 参数边界、dtSeconds、dx、maxRtSeconds、mixture 和 DE maxIterations／populationSize／seed 均在 cfg.ddm。

- t0 上界进一步限制为最小观测 RT 的95%，有效边界随结果保存。

- rt_seconds 超过明确上限时拒绝，绝不静默把毫秒当秒。

- PyDDM 原生 differential evolution＋解析求解输出拟合参数、每试次负 log density、上下边界密度、选择概率、时间网格、原生 FitResult、AIC/BIC 和冻结模型。

- 密度单位为每秒，连续密度大于1时单试次负 log density 可以为负。

- 有限拟合不等于优化充分、RT处理正确、模型恢复成功或决策机制成立。

- 没有拟合未反应／删失反应，也没有自动分条件或解释 upper 为“正确”；

- 它由 actionLabels 的第一行动定义。

子进程通过参数数组启动，超时只终止本次进程，日志／准备材料保留；Python环境和 pickle 不放进发布目录。当前流程只写自己生成的冻结模型，不读取任意外部 pickle。

### 与 fMRI 时序连接

cog.parametric_events 接受显式秒单位 onset／duration、逐事件潜变量矩阵和名称，生成 SPM multiple-conditions MAT 结构：一阶 pmod，可选中心化，orth=0，保存所减均值。不进行 HRF 卷积或估计 GLM。该函数只能检查格式，真实事件语义／scanner参考点必须由调用者确认。

- HCP 后处理 examples/export_hcp_behavior_events.m 复用已拟合结果并严格按 trial_id 连接。
- 原始 FilteredTrialStats.RTTIME 是按键时刻，发布 response_* EV 则是响应窗口起点，二者不应强行相等。
- 后处理用 ResponsePeriod.OnsetTime 和 Sync 核对发布 EV 的时钟，再保留真实按键时刻；
- 未匹配则停止，不猜偏移。
- 新增 verified_event_exports 含参数事件 TSV、中心化的 multiple_conditions.mat 和 TIMING_POSTCHECK.json，旧拟合和原始准备报告不覆盖。

### 验证与真实例边界

四项测试验证可手算的 Q／PE 更新、未来奖励不改变当前概率、多起点似然改善、PyDDM 模拟→原生拟合→密度链，以及事件 MAT 契约／中心化。模拟 DDM 的一个固定种子例恢复接近生成参数，只是该工程情形，不能当一般参数恢复研究。

- 真实工程例在 derivatives/function_stage3_behavior_20261017：三人 LANGUAGE 两 run，共76完整二选项试次。

- 读取真实代码2/3与 RTFromFirstOption（毫秒转换秒），ACC仅作奖励代理；

- 按第一音频选项计时的 RT 含呈现过程，不是已验证的纯决策时间。

- RW每run重置，DDM混合题型用恒定模型。

- LANGUAGE并非强化学习任务；

- 这些拟合只检查真实输入、优化、潜变量和文件链，不给学习率／漂移的科研意义。

- 被排除的原始行号与原因保留；

- 不改 EPRIME／EV／已有 GLM。

- 事件导出是格式与时钟验证，没有估计新的神经参数 GLM。

- 官方实现依据：[PyDDM Quick Start](https://pyddm.readthedocs.io/en/latest/quickstart.html)、[拟合接口](https://pyddm.readthedocs.io/en/stable/apidoc/model.html)、[作者源码](https://github.com/mwshinn/PyDDM)。

- RW 数学层为本包独立实现。
