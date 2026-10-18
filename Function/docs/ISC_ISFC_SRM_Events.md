# 自然刺激：ISC、ISFC、SRM 与有序事件分段



## 一、方法到底在分析什么

### 1. 同一行必须是同一刺激时刻

跨被试方法依赖同一刺激的时间对齐。两人都取前100帧并不表示看到同一内容；要核对实际刺激、开始时间、采样网格和已采用的血流动力学偏移。stimulusId/alignmentNote是必要记录，不能只写“已经对齐”。

### 2. ISC与ISFC

ISC把某人的一个ROI与其他人该ROI的平均曲线相关；ISFC则可以与其他人的另一个ROI比较。leave-one-subject-out参考排除本人，避免自己进入自己的平均。

| 输出     | 第i,j项是什么意思        | 怎样误读会错       |
| ------ | ----------------- | ------------ |
| ISC    | 同特征跨人的刺激锁定共同变化    | 当成同一个人内部的FC  |
| 有向ISFC | 目标人i特征与他人j特征参考的相关 | 当成神经方向因果     |
| 对称ISFC | 交换特征方向后的对称汇总      | 当成已消除所有非刺激混杂 |

循环偏移零模型对各人整段独立移位，保留各自时间结构；minShiftFrames排除接近零/整周期的偏移。max校正的feature/ISFC上三角族在实现细节中明确，不能当群体随机效应检验。

### 3. SRM寻找共同反应坐标

确定性正交SRM最小化各人Y_s≈S×W_s'的平方误差，W_s列正交。它允许每个人的空间特征数不同，但训练刺激时间对应必须相同。共享维度越大容量越高，不代表越“通用”。

训练时学习各人均值/尺度和映射；留出刺激只使用冻结映射。当前只支持训练里已经有的被试，对全新被试需另外学习其映射，不能凭空应用W。

### 4. 事件分段的“顺序”约束

事件模型用一个稳定空间模式描述一段连续时刻，状态只能保持或进入下一个事件，起点事件1、终点事件K。Gaussian EM估计模式/共同方差，Viterbi给最可能边界。

nEvents是预先给定的K，minVariance防止观测方差塌缩；未自动判断故事的真实事件数。这里没有BrainIAK退火、分裂合并或完整概率SRM。

##

## 二、运行前准备

不需要TSV。data.series为cell，每人时间×特征；subjectIds、featureIds（每人对应向量）、timeSeconds、stimulusId、alignmentNote必需。ISC/ISFC和原空间group事件需共同特征身份；SRM可以不同特征数。

可选留出数据需testSeries/testTimeSeconds/testStimulusId/testSubjectIds/testFeatureIds/testAlignmentNote，人数和身份顺序一致。不能只增加testSeries而省掉刺激时钟。

| 字段                         | 形状/类型            | 具体含义               |
| -------------------------- | ---------------- | ------------------ |
| series / subjectIds        | 每人T×特征的cell / 人名 | 共同刺激时刻逐行对应         |
| featureIds / timeSeconds   | 每人列名cell / 共同秒向量 | ISC/ISFC需共同特征空间    |
| stimulusId / alignmentNote | 共同刺激名 / 对齐依据     | 说明起点/偏移/重采样，不能只写同长 |
| testSeries及全部test*身份时钟     | 可选留出epoch        | 已知被试相同顺序，使用冻结训练映射  |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_naturalistic.m](../examples/start_naturalistic.m)。MATLAB可用 `run('E:/my_study/start_naturalistic.m')` 运行自己另存的脚本。

```matlab
% naturalistic启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=naturalistic_config;
cfg.dataFile='E:/my_study/naturalistic_data.mat';
cfg.outputRoot='E:/my_study/results/naturalistic_run01';
cfg.methods={'isc','isfc','srm','eventseg'};
cfg.isc.nSurrogates=0;
cfg.srm.nFeatures=3;
cfg.events.nEvents=3;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_naturalistic(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### naturalistic_config.m

| 运行时字段                         | 实际修改/默认来源位置                       | 当前默认                                                              | 候选、约束及理论/运行作用                                                                                                                                                          |
| ----------------------------- | --------------------------------- | ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cfg.dataFile`                | config/naturalistic_config.m 第4行  | `fullfile(root,'config','naturalistic_data.mat')`                 | data.series(cell时间×特征)/subjectIds/featureIds/timeSeconds/stimulusId/alignmentNote，可有testSeries/testTimeSeconds/testStimulusId；输入MAT路径；按本章字段准备。MAT变量名/大小写也是接口，不只是文件扩展名。 |
| `cfg.outputRoot`              | config/naturalistic_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_naturalistic')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                                                                      |
| `cfg.execute`                 | config/naturalistic_config.m 第6行  | `false`                                                           | false身份/时间/方法预检，true计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                                                                      |
| `cfg.maxArrayGiB`             | config/naturalistic_config.m 第7行  | `1`                                                               | 输入double及主要ISFC结果的容量上限GiB，不承诺总峰值；全脑ISC不要自动请求ISFC平方矩阵；主数组容量上限GiB；ISFC可能按特征平方增长。                                                                                         |
| `cfg.methods`                 | config/naturalistic_config.m 第8行  | `{'isc','isfc','srm','eventseg'}`                                 | 仅运行明确列出方法；ISC/ISFC/原空间group eventseg需要共同特征身份。                                                                                                                          |
| `cfg.isc.standardizeSubjects` | config/naturalistic_config.m 第9行  | `true`                                                            | 各被试每特征在该epoch标准化，再计算leave-one-subject-out均值参考。                                                                                                                         |
| `cfg.isc.nSurrogates`         | config/naturalistic_config.m 第10行 | `0`                                                               | 循环时间移位次数整数>=0；不是被试群体随机效应检验。                                                                                                                                            |
| `cfg.isc.minShiftFrames`      | config/naturalistic_config.m 第11行 | `3`                                                               | 排除接近0/完整周期的循环偏移，整数>=1且<=时间点数/2。                                                                                                                                        |
| `cfg.isc.seed`                | config/naturalistic_config.m 第12行 | `67`                                                              | 固定零模型RNG并恢复。                                                                                                                                                           |
| `cfg.srm.nFeatures`           | config/naturalistic_config.m 第13行 | `3`                                                               | 共享维度，正整数，不超过任一被试特征数或训练时间秩。                                                                                                                                             |
| `cfg.srm.maxIterations`       | config/naturalistic_config.m 第14行 | `100`                                                             | 确定性正交SRM交替最小二乘上限。                                                                                                                                                      |
| `cfg.srm.tolerance`           | config/naturalistic_config.m 第15行 | `1e-7`                                                            | 目标相对变化阈值>0。                                                                                                                                                            |
| `cfg.srm.scaleFeatures`       | config/naturalistic_config.m 第16行 | `true`                                                            | 每被试特征只按训练epoch均值/SD缩放，held-out复用，不重新拟合映射。                                                                                                                              |
| `cfg.events.nEvents`          | config/naturalistic_config.m 第17行 | `3`                                                               | 固定顺序事件数整数>=2；只允许保持/进入下一个事件。                                                                                                                                            |
| `cfg.events.maxIterations`    | config/naturalistic_config.m 第18行 | `100`                                                             | 同方差Gaussian EM上限，未做BrainIAK退火/多链/分裂合并。                                                                                                                                 |
| `cfg.events.tolerance`        | config/naturalistic_config.m 第19行 | `1e-7`                                                            | 相对似然变化阈值。                                                                                                                                                              |
| `cfg.events.minVariance`      | config/naturalistic_config.m 第20行 | `.001`                                                            | 共同观测方差下限>0，尺度依赖预处理。                                                                                                                                                    |



## 六、结果

| 文件/结构                     | 应检查什么                           |
| ------------------------- | ------------------------------- |
| naturalistic.mat          | ISC/ISFC、SRM映射/训练与留出、事件模式/后验/边界 |
| NATURALISTIC_COMPLETE.mat | 所选方法数值成功；时钟/刺激对应仍依据输入记录         |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

- 入口 `run_naturalistic`，配置 `config/naturalistic_config.m`。
- 这里的 MATLAB 数学层独立实现，方法／接口参考 [BrainIAK ISC](https://brainiak.org/docs/examples/isc/ISC.html)、[SRM](https://brainiak.org/notebooks/tutorials/html/11-srm.html) 和[事件分段](https://brainiak.org/examples/Event_Segmentation.html)，没有声称调用或完全复现 BrainIAK。

### 共同时间与身份

dataFile 含 data：series 为多个被试的时间×特征矩阵 cell，subjectIds 唯一，featureIds 为对应每人的唯一有序特征身份，timeSeconds 为共同且均匀递增的秒网格，stimulusId 与 alignmentNote 记录共同刺激和实际对齐依据。相同 TR／矩阵长度不等于看过同一刺激，也不能把静息起始帧号当共同叙事时间。

- ISC／ISFC／原空间平均后的 eventseg 要求各人的特征身份顺序一致；
- 仅 SRM 时允许被试不同空间特征／数量。
- 所有数据有限，当前入口不在缺失时点静默填值。
- 时间插值、刺激不同版本、删除段落、HRF 偏移和有效掩膜必须在准备层记录；
- 代码不自动推断。
- maxArrayGiB 约束输入和主要 ISFC 数组规模，不代表总峰值；
- 只请求 ISC 时不会建立特征平方 ISFC 矩阵。

可选 testSeries 必须同时提供 testSubjectIds／testFeatureIds／testTimeSeconds／testStimulusId／testAlignmentNote，身份与训练被试对应，时间长度可以不同。与训练数值完全相同的数据拒绝标为 held-out。是否存在上游处理、重复刺激或选择超参数的泄漏，仍由完整设计决定。

### ISC 与 ISFC

- 对每个被试，用其他人的均值作参考：同一特征相关为 leave-one-subject-out ISC；

- 每特征对其他特征为方向 ISFC，再以 (R+R')/2 得对称 ISFC。

- standardizeSubjects=true 时先在当前 epoch 按每人每特征标准化，使参考不被个体幅度支配。

- 原方向矩阵保留，ISC 对应对角线。

- 汇总为平均 Fisher z 再 tanh，极端±1只为变换作机器精度裁剪；

- 不是对原相关做任意阈值。

- LOO 被试估计相互依赖，不把它们直接作为独立检验。

- nSurrogates>0 对每个人独立循环移位，minShiftFrames 排除接近零／整周期的偏移；

- 假设周期边界和合适平稳性，不能自动消除任务、自相关或段落边界影响。

- 双侧绝对相关 Monte Carlo p=(1+超过或等于次数)/(B+1)。

- ISC 在全部特征作最大统计量校正，ISFC 在上三角含对角线作自己的最大校正，两个方法／不同 epoch 不是统一检验族。

- 这是时间对齐零模型，不是群体随机效应推断。

### 确定性正交 SRM

模型最小化 Σ_subject ||X_s−S W_s'||²，约束 W_s'W_s=I。每人时间均值及可选特征 SD 只从训练 epoch 学习，初始化采用首被试 PCA，然后用 SVD 正交 Procrustes 更新 W、平均投影更新 S；保存目标值轨迹。nFeatures 为预定共享维度，maxIterations／tolerance 控制交替优化，不进行自动维度选择。

cog.srm_apply 只应用已知被试的冻结映射与训练尺度；新被试还需要独立对齐训练段，当前不自动拟合它。若提供 testSeries，入口在该新时间段应用冻结 W，并单独报告共享特征 ISC。训练段投影相似不算独立验证。这里是确定性最小二乘模型，未包装 BrainIAK 的概率 SRM／FastSRM／半监督／新被试迁移全家族。

### 顺序 Gaussian 事件

- cog.ordered_events 对原空间跨人平均模式拟合同方差 Gaussian 顺序单链：只能保持当前事件或转到下一个，强制首帧事件1／末帧事件K。
- 对终点条件化后，对有序边界位置采用均匀先验；
- log-space 前后向得到后验，EM 更新事件模式与共同方差，Viterbi 给单调硬路径。
- 固定 nEvents，minVariance 限制尺度相关的方差下限，保留条件似然轨迹和 boundaryBeforeRows。

可传冻结 patterns／variance，只在新序列找同一顺序模式的边界，不重新学习；只有确实共享事件语义时才适用。不同故事不能因为都有K段就被当作同一事件模板。这个基础模型未实现 BrainIAK 的退火、分裂合并、多链或 K 选择，也没有主观边界匹配／重采样显著性。训练和冻结模式对齐已用已知合成边界验证，不能把有限 EM 输出解释为真实认知事件。

###
