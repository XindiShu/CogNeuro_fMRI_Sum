# 同源配对连接、三种熵与 ACF 时间尺度



## 一、方法在分析什么

### 1. 熵不是一个通用的“脑复杂度数字”

| 量      | 问什么                    | 单位与重要约定                 |
| ------ | ---------------------- | ----------------------- |
| SampEn | 已经相似的m维时间模板在增加下一点后还相似吗 | -ln(A/B)，nats；无自身配对     |
| 排列熵    | 连续延迟窗口中的升降排列有多丰富       | bits及除log2(order!)的归一化值 |
| 直方图熵   | 幅度分布落入各箱的多样性           | bits；打乱时间不改变它           |

样本熵r=toleranceFraction×该列样本SD；delayFrames决定模板取样间隔。共同m/m+1起点使分母模板数一致。B=0返回NaN；B>0/A=0为Inf，不加伪计数。

排列熵的tiePolicy='omit'排除精确并列窗口，stable按原时间索引打破并列。常数序列在omit下无有效窗口，返回NaN；不能把无信息样本硬写成复杂度0的可靠估计。样本熵配对数量平方增长，maxComparisons为资源上限。

### 2. ACF面积、IAT与指数tau并不相同

有偏ACF用同一lag0平方和作所有lag分母。positiveAreaSeconds把首正瓣积分到线性插值零点；若maxLag时仍正，标记右截断。positiveIatSeconds=TR×(1+2sum正离散lag ACF)。指数tau只对首正瓣中指定范围的log(ACF)拟合，至少3点且负斜率才返回−1/slope。

这些量是输入BOLD及预处理的描述。maxLagSeconds改变截断范围，expFitMaxLagSeconds改变拟合段；滤波/运动/血流动力学均影响它们，不能直接称神经内在时间常数。

### 3. VMHC要先解决同源对应

本核心计算显式配对列的Pearson r/z；verified_symmetric是调用者提供映射证据的声明。普通MNI文件名或x坐标取反不能证明解剖同源。

engineering_mirror必须显式allowEngineeringMapping=true，只测试几何配对和数值，scientificMappingVerified保持false。当前HCP工程例属于这一类，不是科学空间VMHC验证通过。缺的是相应对称配准证据/输入，不是相关计算函数。

##

## 二、运行前准备

TSV为subject/session/run/data_file。MAT/data含y/trSeconds/featureIds/frameIndices；熵/ACF要求连续帧，缺口拆成不同run行。homotopic另需pairs（特征列索引的P×2非重用配对），可选space输出NIfTI。ROI准备器可用于熵/ACF；体素同源需自己给正确空间配对。

| 字段                         | 形状/类型         | 具体含义                    |
| -------------------------- | ------------- | ----------------------- |
| y / trSeconds / featureIds | T×F / 秒 / 列身份 | 同一连续片段                  |
| frameIndices               | 真实连续帧号        | 熵/ACF发现缺口拒绝，拆为多个run     |
| pairs / space              | P×2列索引 / 可选空间 | homotopic专用，列不重复，映射来源必需 |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_extended.m](../examples/start_extended.m)。MATLAB可用 `run('E:/my_study/start_extended.m')` 运行自己另存的脚本。

```matlab
% extended启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=rest_extended_config;
cfg.manifestFile='E:/my_study/prepared_roi/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/entropy_acf_run01';
cfg.methods={'entropy','timescales'};
cfg.entropy.sampleM=2;
cfg.entropy.toleranceFraction=.2;
cfg.timescales.maxLagSeconds=10;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_rest_extended(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 四、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### rest_extended_config.m

| 运行时字段                                   | 实际修改/默认来源位置                        | 当前默认                                                               | 候选、约束及理论/运行作用                                                                                                                  |
| --------------------------------------- | ---------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `cfg.manifestFile`                      | config/rest_extended_config.m 第4行  | `fullfile(root,'config','rest_extended_runs.tsv')`                 | subject/session/run/data_file；data.y/trSeconds/featureIds/frameIndices，可有pairs/space；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`                        | config/rest_extended_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_rest_extended')` | 新绝对目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                                                              |
| `cfg.execute`                           | config/rest_extended_config.m 第6行  | `false`                                                            | false输入预检，true计算；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                                                                    |
| `cfg.methods`                           | config/rest_extended_config.m 第7行  | `{'entropy','timescales'}`                                         | entropy/timescales/homotopic；同源配对需data.pairs和明确空间声明。                                                                           |
| `cfg.maxMatrixGiB`                      | config/rest_extended_config.m 第8行  | `1`                                                                | 读入double矩阵容量上限GiB，不是进程峰值保证；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                                                                |
| `cfg.entropy.sampleM`                   | config/rest_extended_config.m 第9行  | `2`                                                                | SampEn匹配模板长度整数>=1，m与m+1用相同起点集合。                                                                                                |
| `cfg.entropy.delayFrames`               | config/rest_extended_config.m 第10行 | `1`                                                                | 样本/排列熵嵌入延迟帧，整数>=1；不跨缺帧。                                                                                                        |
| `cfg.entropy.toleranceFraction`         | config/rest_extended_config.m 第11行 | `.2`                                                               | SampEn Chebyshev容差=此值×该列样本SD；严格正值。                                                                                             |
| `cfg.entropy.permutationOrder`          | config/rest_extended_config.m 第12行 | `3`                                                                | 排列阶数2..7。                                                                                                                      |
| `cfg.entropy.tiePolicy`                 | config/rest_extended_config.m 第13行 | `'omit'`                                                           | omit排除有精确并列的排列窗口，stable按原时间索引打破并列，均记录。                                                                                         |
| `cfg.entropy.histogramBins`             | config/rest_extended_config.m 第14行 | `16`                                                               | 幅度Shannon直方图箱数整数>=2；每列本身的min/max等宽，不能冒充时序复杂度。                                                                                  |
| `cfg.entropy.maxComparisons`            | config/rest_extended_config.m 第15行 | `5e6`                                                              | 每列两组pdist所用模板对数量上限，避免无界平方内存。                                                                                                   |
| `cfg.timescales.maxLagSeconds`          | config/rest_extended_config.m 第16行 | `10`                                                               | ACF最大滞后秒，实际还受连续记录长度限制。                                                                                                         |
| `cfg.timescales.expFitMaxLagSeconds`    | config/rest_extended_config.m 第17行 | `5`                                                                | 首正ACF瓣内的log-linear拟合范围秒，至少3个正滞后点才给tau。                                                                                         |
| `cfg.homotopic.mappingStatus`           | config/rest_extended_config.m 第18行 | `'not_declared'`                                                   | verified_symmetric或engineering_mirror；MNI标签本身不等于已验证对称配准。                                                                       |
| `cfg.homotopic.mappingNote`             | config/rest_extended_config.m 第19行 | `''`                                                               | 显式同源对应/对称模板/变换来源，不自动猜。                                                                                                         |
| `cfg.homotopic.allowEngineeringMapping` | config/rest_extended_config.m 第20行 | `false`                                                            | true显式允许几何镜像工程测试，scientificMappingVerified仍为false。                                                                             |

## 六、结果

| 文件/结构                      | 应检查什么                           |
| -------------------------- | ------------------------------- |
| rest_extended.mat          | 三种熵的匹配/并列/箱边界，ACF曲线/面积/tau/质量标记 |
| homotopic_r.nii            | 仅有homotopic+space时；两侧写相同配对r     |
| REST_EXTENDED_COMPLETE.mat | 该run所选计算完成，检查NaN/Inf和映射声明       |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

入口 `run_rest_extended`，配置 `config/rest_extended_config.m`，清单模板 `config/rest_extended_runs_template.tsv`。每个 subject/session/run 单独计算；本模块不自动预处理、补帧、生成对称模板或推断左右同源对应。

### 输入与运行

清单列为 `subject/session/run/data_file`，session 可为空，三个身份列组成唯一键。路径相对清单文件解析。每个 MAT 包含结构 `data`：

| 字段           | 契约                                     |
| ------------ | -------------------------------------- |
| y            | 有限实数，时间×特征；不能含 NaN/Inf                 |
| trSeconds    | 严格正值，单位秒                               |
| featureIds   | 唯一非空身份，与 y 的列完全对应                      |
| frameIndices | 原始递增整数帧号；省略时声明为 1:N，不能用重新编号掩盖缺帧        |
| pairs        | homotopic 必需，P×2 特征列索引；每列最多出现于一个配对     |
| space        | 可选，由 `cog.load_bold` 返回；提供时写配对相关 NIfTI |

```matlab
addpath('D:/Function'); setup_function('你的SPM目录');
cfg=rest_extended_config;
cfg.manifestFile='你的清单绝对路径';
cfg.outputRoot='一个尚不存在的结果目录';
cfg.methods={'entropy','timescales'};
run_rest_extended(cfg);       % 默认 execute=false，只预检
cfg.execute=true;
run_rest_extended(cfg);
```

熵和 ACF 要求一个清单行代表连续片段，发现 frameIndices 跳号即拒绝；多个片段应拆为不同 run 键分别计算。输入滤波、平滑、混杂、删帧方式都应由调用者记录在 MAT。该入口不做跨 run 合并或群体统计。

### 三种熵明确分开

- 样本熵参照 [Richman 与 Moorman 的方法](https://pubmed.ncbi.nlm.nih.gov/10843903/)，本实现的有限样本约定如下：长度 m、延迟 d 的模板，与长度 m+1 模板使用共同的 N−md 个起点；

- 仅统计无序、非自身的模板对，Chebyshev 距离 ≤ r 算匹配。

- B 为 m 维匹配数，A 为下一维匹配数，SampEn=−ln(A/B)，单位 nats。

- r=`toleranceFraction`×该列样本标准差。

- B=0 返回 NaN，B>0/A=0 返回 Inf，不加伪计数；

- 完全常数列的样本熵为0。

- 保存 A/B/r 和模板数，便于核对不同软件的边界约定。

- 排列熵参照 [Bandt 与 Pompe](https://pubmed.ncbi.nlm.nih.gov/12005759/)，将延迟窗口转为幅度排列，按排列概率计算 Shannon entropy，保存 bits 及除以 log2(order!) 的归一化值。

- `tiePolicy='omit'` 排除有精确并列的窗口，`stable` 则按原时间索引破并列；

- 均保存有并列和有效窗口数。

- 常数序列在 omit 下没有有效排列，返回 NaN，不能误写成零复杂度的可靠估计。

幅度直方图熵按每列 min/max 等宽分箱，保存箱边界和 bits，常数列为0。它描述幅度分布多样性，打乱时间不会改变此值，不能替代时间复杂度。

- 所有参数位于 `cfg.entropy`：`sampleM=2`、`delayFrames=1`、`toleranceFraction=.2`、`permutationOrder=3`、`tiePolicy='omit'`、`histogramBins=16`、`maxComparisons=5e6`。
- 最后一项限制每列模板对数量；
- SampEn 的时间/内存仍为平方级，当前不是全脑高速实现。
- 未实现多尺度/模糊熵、Lempel-Ziv 或偏倚校正。

### ACF 的三个不同量

对每列减均值，ACF(lag)=sum(x(t)x(t+lag))/sum(x²)，所有 lag 使用相同 lag0 分母，ACF(0)=1。当前选择有偏估计；不能与逐 lag 改变分母的实现直接混用。

- `positiveAreaSeconds`：包含 lag0，积分至首次非正 ACF 的线性插值零点。若最大 lag 仍为正，保存截断面积并标记 `positiveAreaRightCensored=true`，不能当完整面积。
- `positiveIatSeconds`：TR×(1+2×首正瓣内离散正 lag ACF 之和)，与上述梯形面积是不同定义。
- `exponentialApproxTauSeconds`：首正瓣中，在指定最大秒数内用截距+时间拟合 log(ACF)。至少3个正 lag 点且斜率负才给 tau=−1/slope，并保存 log 拟合 R²/点数。未满足条件返回 NaN。

配置在 `cfg.timescales.maxLagSeconds=10`、`expFitMaxLagSeconds=5`；实际 lag 也受记录长度限制。常数列无效。这些是输入 BOLD 时序的描述量，不能直接称为神经内在时间常数；滤波、血流动力学、运动和长度都会影响结果。未实现去卷积、多指数拟合或科研置信区间。

### 同源配对相关与 VMHC 空间前提

`cog.homotopic_fc` 对显式左右配对列计算 Pearson r/Fisher z，常数配对返回 NaN，完美 ±1 的 z 保留 Inf。NIfTI 中将 r 写入配对两侧，掩膜外为 NaN。

`cfg.homotopic.mappingStatus` 默认未声明，必须选择：

- `verified_symmetric`：调用者已经验证同源/对称空间对应，并在 `mappingNote` 写来源。结果中的 true 仅是调用者声明，代码不自动验证配准质量。

- `engineering_mirror`：显式几何镜像测试，必须同时 `allowEngineeringMapping=true`，仍标记 `scientificMappingVerified=false`。

- 仅有 MNI 文件名不能证明对应。

- DPARSF 官方课程也将 [进一步配准到对称模板](https://www.rfmri.org/Course/V3.0EN/4_R-fMRI_Data_Processing_DPARSFA.pdf) 列为 VMHC 的准备步骤。

- 当前包提供已准备配对输入后的计算接口；

- 不包装对称模板创建/非线性配准，亦不自动把普通 ROI 对解释为 voxel-mirrored homotopy。

###
