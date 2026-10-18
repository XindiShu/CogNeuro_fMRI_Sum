# glm_config.m 逐行说明、可选值与方法配置

本页解释的是 **`D:\GLM\config\glm_config.m` 当前154行版本**，核对日期2026-10-16，SHA256为 `2D3135480204CCB680BF40A5B646AF4E525DADAB299EE71F055085D64149C1D1`。工作区副本排版不同，本页行号以D盘为准；以后插入空行，行号会移动，可按参数名称定位。本次不修改配置原文件。

把 `cfg` 想成一张分析订单：**读哪些数据、每个参数代表哪个实验单位、怎样描述事件响应、怎样拟合、在哪个层级比较**。运行 `glm_config` 只生成这张订单，真正执行由 `run_glm.m` / `psy.glm_batch(cfg)` 完成。并非所有参数在所有方法下都参与计算；不过配置检查可能仍要求未使用分支的格式合法，保留完整配置比删字段稳妥。

阅读顺序：先看第1节认识语法，再按第2至第8节查每行。各方法的选择、必改/可调/固定项及完整设置步骤已移至 [GLM方法选择与参数操作指南](Methods_Summary.md)。具体文件用途另见 [逐文件说明](GLM_PACKAGE_FILE_EXPLAINED.md)。

## 1. 先看懂结构行、注释和空行

| 行号  | 原代码/内容                                              | 通俗解释                                             |
| --- | --------------------------------------------------- | ------------------------------------------------ |
| 1   | `function cfg=glm_config`                           | 定义一个叫glm_config的函数。输入没有参数，输出是名为cfg的配置结构。通常不改函数名。 |
| 2   | `%GLM_CONFIG ...`                                   | 注释，给人阅读，不执行。百分号后面的文字不会改变结果。                      |
| 5   | `root=fileparts(fileparts(mfilename('fullpath')));` | 找到当前配置文件，向上退两层得到包根目录；本机即D:\GLM。这样移动整包后不必改每条内部路径。 |
| 154 | `end`                                               | 结束这个配置函数。不是分析结束标志，不要删除。                          |

第4、25、48、66、92、127行是分节注释，只用于组织阅读，不选择实际算法；第2行同样是注释。除上表结构行、这些注释和下文62条参数赋值之外，其余82行为空行，只用于分隔参数。第48行的分节标题虽然写着LSA/LSS，第50—58行实际仍是pmod字段，是否生效由字段和合法组合决定。分号 `;` 抑制命令窗口回显；`'文字'` 是文本；`true/false` 是逻辑开关；`[]` 是空数值数组；`{}` 是空单元数组；`{'A','B'}` 是文本列表。`[]` 的意义由参数决定，有时表示自动选择，有时表示全部，并不一律表示关闭。

## 2. 第8—21行：读什么、写哪里、比较什么

### 第8行：cfg.manifestFile

`cfg.manifestFile=fullfile(root,'config','glm_runs.tsv');`

这是“输入清单的地址”，不是BOLD影像本身。默认指向D:\GLM\config\glm_runs.tsv，包里提供的是模板，实际清单需由你填写。可选值是存在的TSV路径：run/subject用run清单，group用被试效应图清单。清单内相对影像路径以清单所在目录为基准；配置里这个清单地址建议直接用绝对路径。换方法时也要换成该方法需要的表结构，不能只改文件名。

### 第10行：cfg.outputRoot

`cfg.outputRoot=fullfile(root,'derivatives','my_study_glm');`

分析结果写到哪里。可设任意合适的**新目录**，不覆盖旧模型。建议改为项目数据区或临时目录，例如 `E:\study\glm_condition_01`，让D:\GLM保持代码包用途。只准备和真正估计也要使用不同新目录，不能把execute改成true后继续向原准备目录写。

### 第12行：cfg.spmPath

`cfg.spmPath=fileparts(which('spm'));`

从MATLAB当前路径查找SPM的安装目录。已经加过SPM路径时可自动找到；找不到会得到空路径，不能因此认为SPM已经安装或加载。可手动设为本机实际路径，例如 `D:\matlab\atoolbox\spm12`。建议先 `addpath('D:\matlab\atoolbox\spm12')`，再调用glm_config。它不是原始数据目录，也不是D:\GLM。

### 第14行：cfg.execute

`cfg.execute=false;`

`false` 只检查输入、记录计划并准备相应作业；`true` 才估计模型。准备可能已经创建输出、配对差值等文件，不是完全无写入。建议先false查看设计，再换新输出目录设true。GLMsingle若预检不通过，会记录阻断原因，不能将这些记录当作已经生成beta。

### 第17行：cfg.conditions

`cfg.conditions={'conditionA','conditionB'};`

事件表里所有 `trial_type` 条件名称及固定顺序，例如HCP语言任务用 `{'story','math'}`。名称须字母开头，后续用字母、数字或下划线；区分大小写，与事件表一致。SPM逐run框架要求声明条件与该run实际条件完全对应。顺序决定下面权重的列顺序，不能交换条件顺序却保留旧权重。

### 第19行：cfg.contrastNames

`cfg.contrastNames={'A_minus_B'};`

给要检验的效应取名字。可用多个不重复、非空名字，例如 `{'story_minus_math','math_minus_story'}`，与权重每一行对应。条件模型使用它；pmod还会自动增加斜率对比，FIR会增加bin/窗口/整体对比。逐单元LSA/LSS的目标对比自动生成，二级模块也自动生成相应方向；GLMsingle不用此处生成SPM T图。

### 第21行：cfg.contrastWeights

`cfg.contrastWeights=[1 -1];`

告诉程序“怎么把条件相加减”。条件顺序为story、math时，`[1 -1]` 是story减math；`[-1 1]` 相反；`[1 0]` 选story；`[.5 .5]` 是两条件等权平均。多项比较写成 `[1 -1;-1 1]`，同时给两个contrastNames。必须是有限、非全零的数值行，每列一个条件，不手动补混杂、截距、run或HRF导数的零。run联合模型由程序把匹配效应等权分配到各run。

## 3. 第27—44行：一个beta代表什么、响应怎样表达

### 第27行：cfg.model.unit

`cfg.model.unit='condition';`

这行决定“哪些事件共享一个幅度参数”。

| 可选值           | 白话含义               | 事件表要求                       |
| ------------- | ------------------ | --------------------------- |
| `condition`   | 同条件共享一个幅度，得到条件共同响应 | onset/duration/trial_type   |
| `event`       | 每一行事件独立估计          | 基础三列，不声称每行必然是真正trial        |
| `trial`       | 每个真实trial单独估计      | 另有trial_id，run内每个ID恰好一行     |
| `item`        | 同一刺激多次出现共享一个幅度     | stimulus_id，可重复；同ID不能属于矛盾条件 |
| `block`       | 每行代表一个区块           | block_id在run内唯一，不把同ID多行自动合并 |
| `phase`       | 同条件的同阶段共享一个幅度      | phase，例如编码、保持、反应            |
| `trial_phase` | 每个trial的每个阶段独立估计   | trial_id+phase组合在run内唯一     |

先学条件GLM用condition，只有逐事件行需要不同beta时用event。HCP故事区块不因选择trial就变成句子试次。SPM subject层级当前只支持condition；GLMsingle只支持event/trial。分组实现并不表示每种组合都有真实HCP估计验证。

### 第29行：cfg.model.targetConditions

`cfg.model.targetConditions={};`

空表示输出所有单元的目标效应。逐事件模型可改为 `{'math'}`，只把math当目标；story等其他事件仍参与设计，不会被删掉。condition模型必须空；GLMsingle当前也必须空。建议学习LSA/LSS时先选少量明确目标，减少LSS模型数，但完整保留其他任务事件。

### 第31行：cfg.events.expression

`cfg.events.expression='duration';`

`duration` 使用表里每行实际秒数；`impulse` 把建模时长设为0，只表达开始时刻；`fixed` 全部用第33行的统一秒数。它改变的是分析副本的事件表达，不改原事件表。通常先保留有任务含义的duration；只关注瞬时触发时再明确用impulse，不能为方便运行随意抹掉长故事的时间结构。GLMsingle不接受impulse。

### 第33行：cfg.events.fixedDurationSeconds

`cfg.events.fixedDurationSeconds=1;`

只有fixed模式使用，单位秒。SPM允许有限数值且≥0；GLMsingle还要求所有run使用一个共同的正时长，且为0.1秒的整数倍。例如2秒可用2，20秒可用20。即使不使用fixed，也保留合法值。统一时长是明确的模型假设，不是程序自动测出的真实呈现时长。

### 第35行：cfg.hrf.type

`cfg.hrf.type='canonical';`

HRF可以理解为“事件发生后，BOLD怎样缓慢升起再落下”的模板。

| 引擎        | 可选值                         | 含义                    |
| --------- | --------------------------- | --------------------- |
| SPM       | `canonical`                 | 一个标准响应形状，最容易理解的起点     |
| SPM       | `canonical_time`            | 标准形状加时间导数，容纳一定的早晚偏差   |
| SPM       | `canonical_time_dispersion` | 再加宽度导数，容纳一定的宽窄偏差      |
| SPM       | `fir`                       | 按事件后时间分箱估计，不预设一条固定形状  |
| GLMsingle | `canonical` / `library`     | 官方假定HRF / 体素级20候选HRF库 |

导数增加设计列，不能直接把三个系数相加解释为更大的激活；统一逐单元读取取canonical列。GLMsingle的canonical与SPM微时间canonical不是同一套实现。FIR、pmod在本包都要求condition+joint，不能互相叠加。[SPM基函数说明](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/)

### 第38行：cfg.hrf.fir.windowSeconds

`cfg.hrf.fir.windowSeconds=20;`

FIR要观察事件开始后多少秒，有限正数。窗口从事件0秒开始，不自动加负时间基线。20是默认，不代表任何任务都合适；长持续事件需要另考虑观察窗。每bin宽度为windowSeconds/nBins，并须是TR/microtimeResolution的整数倍。

### 第40行：cfg.hrf.fir.nBins

`cfg.hrf.fir.nBins=10;`

把上述窗口分成多少个等宽箱，正整数。20秒分10箱就是每箱2秒。箱越多时间刻画越细，但设计列也越多，参数更难稳定估计。HCP TR=0.72、微时间16时，可用已跑通的21.6秒/10箱；默认20秒/10箱不满足该格点约束，启用FIR时需要一起调整。

### 第42行：cfg.hrf.fir.summaryBins

`cfg.hrf.fir.summaryBins=[];`

空表示所有bin等权平均；也可指定不重复的整数编号，如 `[3 4 5]`，均须在1到nBins之间。它只决定额外的窗口均值T对比，不删掉其他bin。最好在看结果前按响应问题确定，而不是根据峰的位置再挑箱。若窗21.6、10箱，第3—5箱覆盖事件后4.32到10.8秒。

### 第44行：cfg.hrf.fir.includeOmnibus

`cfg.hrf.fir.includeOmnibus=true;`

true额外做“这组bin整体是否有该效应”的F检验；false不做这一项。F没有正负方向，不能拿F图当有符号效应送入单样本组统计。刚学习FIR时建议true，结合逐bin和窗口T图理解；关闭也不等于停止估计各bin。

## 4. 第50—62行：参数调制、LSA与LSS

### 第50行：cfg.pmod.enabled

`cfg.pmod.enabled=false;`

是否检验“事件数值变化是否伴随BOLD幅度变化”，例如数学难度越高响应是否越强。true启用，false关闭；仅支持condition+joint的canonical及其导数。关闭时modulators必须为空；开启时必须填写，不能仅打开开关。

### 第52行：cfg.pmod.modulators

`cfg.pmod.modulators=struct('condition',{},'column',{},'name',{},'poly',{});`

默认是空调节量列表。每一项填写四个字段：condition=在哪个条件内使用，column=事件表中的数值列，name=这项效应的名字，poly=最高多项式阶数1到6。建议先用poly=1看线性关系。设2会同时建一阶和二阶，不能理解为只建平方项。列值在目标条件内须有限、有变异；不自动插补缺失。

例如 `struct('condition','math','column','difficulty','name','difficulty','poly',1)`。标签与列名须字母开头，后续字母/数字/下划线；同条件name不重复。多项调节量用结构数组，顺序会影响开启串行正交化时的解释。

### 第54行：cfg.pmod.center

`cfg.pmod.center='within_condition';`

`within_condition` 对每run每条件的调节值减去其均值，让条件主效应更接近“典型调节值时的响应”；`none` 保留原数值零点。例如难度2、4、6变成−2、0、2。建议先保留within_condition；选择none应知道难度0时的截距是否有实际意义。

### 第56行：cfg.pmod.scale

`cfg.pmod.scale='none';`

none保留调节变量单位；zscore再除以每run每条件的样本标准差，使用相对难度单位。zscore必须同时within_condition中心化。若各run的“一分难度”本身有共同含义，none更容易解释；若选择zscore，斜率含义变成每增加该run该条件一个标准差，不能再按原分数解释。

### 第58行：cfg.pmod.orthogonalize

`cfg.pmod.orthogonalize=false;`

false让配置列共同进入模型；true使用SPM按顺序的串行正交化，后面的列解释前面列剩下的部分，因此换顺序可能换解释。建议初学多调节量时先false并检查共线性；false不会让相关变量自动变得互相独立，也不保证高阶项满秩。

### 第60行：cfg.fit.strategy

`cfg.fit.strategy='joint';`

joint把全部估计单元放入一个模型：condition时是条件GLM，event/trial时是常说的LSA。lss每次拿一个目标单元单独拟合，其余事件合并作为干扰，最后收集每个目标的beta。condition和phase只支持joint；item/block/trial_phase也可做逐目标lss。LSS模型多，先用少量事件跑通更省时间。

### 第62行：cfg.fit.lssGrouping

`cfg.fit.lssGrouping='condition';`

只在lss时决定“其余事件怎么合并”：pooled全部合一，condition按原条件分别合并。例如目标是某一math时，其余math和story可分成两个干扰组。不同条件有不同响应时，可从condition起步；pooled列更少但合并假设更强。这不是“把整个条件作为目标的LSS”，当前不支持condition-target LSS。

## 5. 第68—88行：run、被试与组统计

### 第68行：cfg.level

`cfg.level='run';`

run每个run单独分析；subject把同一人的多个run送入一个被试层级模型；group读取每人的效应图做二级统计。SPM subject当前只支持condition+joint，各run保留独立任务/混杂/截距，匹配效应等权平均；GLMsingle用subject按人处理多run。group需要另一种清单，不能把多个run当成多名独立被试。

### 第70行：cfg.subject.combineSessions

`cfg.subject.combineSessions=false;`

false每个subject/session分开组织run；true同一人的不同session也合并。通常保留false，特别是训练前后或不同访视要保留差异时。它处理的是研究清单中的session，不是SPM内部每run的session分区；设true也不会把不同人的数据合并成一个人。

### 第72行：cfg.group.design

`cfg.group.design='one_sample';`

one_sample看被试平均效应；paired比较同一人的两个水平；two_sample比较两个独立组，当前为等方差；regression看被试效应与连续变量的关系，含截距。单样本与两组也可加协变量。配对当前不能加协变量，未开放Welch/非等方差、一般混合效应或多水平重复测量。一级的contrastWeights不负责决定这些二级权重。

### 第74行：cfg.group.minSubjects

`cfg.group.minSubjects=3;`

每项效应至少多少名独立被试，整数≥2。默认3是允许示例运行的工程下限，不是“3个人足够做群体研究”。配对的同一人两张图仍只算一人；多run也不增加人数。人数不够就报错，不自动放宽限制。

### 第76行：cfg.group.pairedLevels

`cfg.group.pairedLevels={'pre','post'};`

配对清单pair_level列的两个标签，两个不重复非空文本。方向始终第一个减第二个：默认pre−post；要post−pre应写 `{'post','pre'}`。按subject和标签配对，不按相邻行，也不凭session自动猜。每人须各一张图；缺失或重复会拒绝。

### 第78行：cfg.group.groupLabels

`cfg.group.groupLabels={'groupA','groupB'};`

两独立组清单group列的标签，方向第1组减第2组。可改为自己的两个不同标签，如 `{'patient','control'}`，标签必须和表一致，不按字母排序决定方向。同一人不能进入两组；HCP教学数据不会自动获得真实研究分组。

### 第80行：cfg.group.minPerGroup

`cfg.group.minPerGroup=2;`

two_sample每组最少人数，整数≥2，还要满足总minSubjects和残差维度要求。例如两组各2人通过这个下限并不说明推断可靠。它只参与两组分支的人数检查，其他分支保留默认即可。

### 第82行：cfg.group.covariateColumns

`cfg.group.covariateColumns={};`

二级清单中要进入模型的数值列，如 `{'age','score'}`。regression至少一列，paired必须空，one_sample/two_sample可空或多列。列名须安全、不重复、不与subject/group等保留字段冲突；值有限、有变化且不导致设计秩亏。文本类别不自动变哑变量，缺值不自动补。

### 第84行：cfg.group.covariateCenter

`cfg.group.covariateCenter='overall';`

overall对每列减去全部被试的均值；none保留原点。建议通常先overall，让截距或组均值对应平均年龄/分数位置。不会自动zscore，也不是分别在两组内中心化。两组加协变量使用共同斜率，不包含组×协变量交互。

### 第86行：cfg.group.minResidualDF

`cfg.group.minResidualDF=1;`

二级模型要求 `被试数−设计矩阵秩` 至少多少，正整数。协变量越多，可用残差维度越少；默认1仅服务于跑通示例。它不等于下面一级cfg.minResidualDF，也不是给所有图强制指定统计自由度。

### 第88行：cfg.engine

`cfg.engine='spm_classical';`

选择实际计算后端：spm_classical调用SPM经典GLM，glmsingle调用随包固定版本GLMsingle。换后端还要同时满足unit、level、HRF等限制，不能只改这一行。SPM生成SPM.mat及T/F对比；GLMsingle生成官方模型与逐事件beta，不伪造SPM T图。

## 6. 第94—124行：GLMsingle专属参数

这些字段主要在engine=glmsingle时使用；做SPM时保持默认完整结构即可。GLMsingle以每次事件为单位输出beta，用重复身份评估去噪与ridge参数。官方解释见 [GLMsingle FAQ](https://glmsingle.readthedocs.io/en/latest/wiki.html)，本包限制见 [完整实践](GLMsingle_ABCD.md)。

### 第94行：cfg.glmsingle.path

`cfg.glmsingle.path=fullfile(root,'external','glmsingle');`

官方依赖根目录，随包默认在D:\GLM\external\glmsingle。通常不改。换目录要包含固定来源记录、依赖清单及其匹配文件；不应直接替换成任意新版本后称为已验证。无需自行把utilities永久加到MATLAB全局路径。

### 第96行：cfg.glmsingle.identityColumn

`cfg.glmsingle.identityColumn='stimulus_id';`

事件表中哪一列定义“重复身份”。可设合法列名，例如stimulus_id；对应同一图片/音频的反复出现。开启去噪或ridge时，每个留一run折都要有训练与测试共享身份；增加被试不能替代每个人的跨run重复。trial_id通常每次不同，不能自然充当重复标签。类别也可作为显式教学假设，但story类别相同不等于同一故事音频重复。

### 第98行：cfg.glmsingle.wantDenoise

`cfg.glmsingle.wantDenoise=true;`

true执行GLMdenoise，利用共同噪声的主成分（PC）作回归量，并交叉验证选PC数量；false不执行此步骤。实际选0个PC是合法结果，不是失败。本功能在模型内联合处理，不要求先回归BOLD。学习完整C/D流程时保留true并满足重复条件。

### 第100行：cfg.glmsingle.wantRidge

`cfg.glmsingle.wantRidge=true;`

true做fractional ridge，通过收缩逐事件系数降低不稳定性，生成D；false不做。它不保证每个事件更大、更显著，也不直接生成T检验。true要求可用于交叉验证的重复身份。无重复时若明确都关闭78、80可走A/B，但这就是不同流程，不是完整C/D自动降级。

### 第102行：cfg.glmsingle.fracs

`cfg.glmsingle.fracs=fliplr(.05:.05:1);`

先生成0.05、0.10直到1，再倒序成1、0.95直到0.05。每个数是相对OLS系数长度的候选比例，1是不收缩，更小通常收缩更强；不是直接的lambda。必须是(0,1]内有限数值向量，至少两个不同候选，即使关闭ridge也保留合法格式。教学可用 `[1 .75 .5]` 减少候选，正式设计不把这个简化集当最优网格。

### 第104行：cfg.glmsingle.maxPCs

`cfg.glmsingle.maxPCs=10;`

最多尝试多少个噪声PC，正整数；实际选择范围可含0。增加上限会增加计算和设计负担，仍须有足够残差维度。教学从2起步可缩短运行；要关闭去噪用wantDenoise=false，不能把maxPCs设0。

### 第106行：cfg.glmsingle.noiseR2Threshold

`cfg.glmsingle.noiseR2Threshold=[];`

决定哪些低ONOFF拟合度体素可进入候选噪声池。空让官方自动估计，或给一个有限数值，单位是百分数R²，不是0—1概率；代码允许范围不限于0—100，因为R²可能为负。自动步骤需要fitgmdist等依赖。通常保留自动；本HCP教学例100是为了扩大候选池的显式近似，不能照搬为通用推荐。

### 第108行：cfg.glmsingle.pcR2Threshold

`cfg.glmsingle.pcR2Threshold=[];`

决定哪些体素参与评价PC数量，和“从哪些体素取噪声”是两件事。空为自动，或有限百分数R²。通常保持自动或依据任务预先设阈值；教学例−1e6表示几乎所有有限R²体素都参与评价，不表示显著性阈值，也不推荐作为一般研究设置。

### 第110行：cfg.glmsingle.maxPolyDegree

`cfg.glmsingle.maxPolyDegree=[];`

每run用多高阶的多项式描述慢漂移。空时每run按 `round(run秒数/60/2)` 自动决定；也可指定非负整数，0只有常数，1还包括线性。指定值对全部run共用，不能大到耗尽时序维度。GLMsingle不用SPM的128秒高通；教学合成例可用1，普通输入先保留自动。

### 第112行：cfg.glmsingle.onsetMode

`cfg.glmsingle.onsetMode='strict';`

strict要求onset在TR格点，数值容差1e−6秒；nearest明确允许舍入到最近TR，并记录原时间与误差。建议先strict暴露数据是否满足接口要求；需要演示近似时再nearest。舍入可能把两个事件挤到同一TR，碰撞仍会阻断，不自动合并。

### 第114行：cfg.glmsingle.maxOnsetErrorSeconds

`cfg.glmsingle.maxOnsetErrorSeconds=0.05;`

nearest模式允许的最大绝对舍入误差，有限数值≥0，单位秒；strict不使用这个放宽上限。TR=0.72时最近格点误差可接近0.36秒，0.05并不保证通过。HCP教学例用0.37是明确放宽，不是校正了时间采集精度，也不重采样BOLD。

### 第116行：cfg.glmsingle.minEndBufferSeconds

`cfg.glmsingle.minEndBufferSeconds=8;`

最后一个事件的格点onset到最后一帧采样时刻至少留多少秒，有限数值≥0。检查量是 `(帧数−1−最后零基帧号)*TR`；不是从事件结束时刻算，也不证明整个HRF已完整采到。默认8、HCP教学16都是接口设置；通用入口不自动删事件或补帧，教学启动器另在副本中显式排除并审计尾部事件。

### 第118行：cfg.glmsingle.chunkVoxels

`cfg.glmsingle.chunkVoxels=5000;`

一次处理多少个体素，正整数。类似分批搬运，主要影响内存和速度，不改变事件定义。内存紧张可减小；它不限制最终只分析5000体素，也不意味着输入数据不再一次加载。

### 第120行：cfg.glmsingle.maxInputGiB

`cfg.glmsingle.maxInputGiB=4;`

全部run掩膜内single输入矩阵的体积上限，有限正数，单位GiB（2³⁰字节）。估算约为体素数×总帧数×4字节。它是预检门槛，不是MATLAB峰值内存保证，拟合还会产生其他数组。超限时先检查范围/内存；只提高数字并不会增加电脑内存。

### 第122行：cfg.glmsingle.wantPercentBold

`cfg.glmsingle.wantPercentBold=true;`

true由官方按绝对meanvol换算百分BOLD单位；false保留输入强度单位。建议在保留正基线的输入上按目标统一选择，并在输出单位字段核对。它不恢复已去均值/回归的残差输入，也不让SPM beta自动具有相同尺度。

### 第124行：cfg.glmsingle.randomSeed

`cfg.glmsingle.randomSeed=0;`

固定随机数种子，使含随机步骤更容易复现。可用0到2³²−1的整数。教学保持固定值即可，换种子不是提升模型的办法；函数退出会恢复调用前随机状态，结果仍取决于输入、依赖版本及其他配置。

## 7. 第129—141行：掩膜、诊断与SPM时间参数

### 第129行：cfg.explicitMask

`cfg.explicitMask='';`

空字符串表示不提供额外全局显式掩膜，SPM仍按自己的隐式规则选择有效体素。也可填同网格3D、有限非负、有正值的掩膜绝对路径；清单mask列可逐run覆盖。不是ROI结果表，也不会自动配准。GLMsingle要求有明确有效覆盖掩膜，可由清单提供；不能把全视野1掩膜用于零填充或部分覆盖区域。

### 第131行：cfg.qc.plot

`cfg.qc.plot=true;`

是否保存模型诊断图，true开、false关。SPM估计后的数值设计/采样残差诊断不因关闭绘图而跳过；GLMsingle使用自己的导出诊断图流程，不是同一套SPM残差ACF。它不是“QC是否合格”的判定，也不是后处理统计叠加图开关；后者在glm_outputs_config中配置。

### 第133行：cfg.qc.maxResidualVoxels

`cfg.qc.maxResidualVoxels=32;`

SPM残差诊断最多确定性抽取多少个掩膜内体素，正整数。它限制采样诊断，不限制GLM分析体素。可增大以查看更多点，但32点通过不意味着全脑每点的时间残差都已审查。GLMsingle不使用此字段做同样的SPM残差诊断。

### 第135行：cfg.highpassSeconds

`cfg.highpassSeconds=128;`

SPM模型内高通截止周期，有限正数，单位秒；大致针对比该周期更慢的变化。128秒对应约0.0078Hz，不是128Hz，也不是在原图上先滤一遍。值越小去除的慢变化越多，也可能去掉长任务效应。教学SPM模型可从128起步，结合设计保留能量检查；GLMsingle使用多项式漂移，不使用本行。

### 第137行：cfg.serialCorrelation

`cfg.serialCorrelation='FAST';`

SPM怎样处理相邻时间点误差的相关性，可选FAST或AR(1)。FAST为本包默认；AR(1)是另一种误差模型，多个合成验证用它以便明确检查。HCP短TR示例可沿用FAST工程起点，再看残差诊断；不能把任一个选项当所有数据都正确的保证。GLMsingle不使用本行。

### 第139行：cfg.microtimeResolution

`cfg.microtimeResolution=16;`

SPM把一个TR在构造响应时再细分多少格，正整数。TR=0.72、16格时每格0.045秒；不会凭空生成16倍实测BOLD帧。默认16可作为起点，FIR的bin宽度要与这格点兼容。不是切片数量的同义词，不需盲目改成NIfTI切片数。

### 第141行：cfg.microtimeOnset

`cfg.microtimeOnset=8;`

SPM在上述微时间格中用哪一格作参考，整数1到microtimeResolution。8/16表示该网格的参考位置，不是“删前8帧”或“onset整体加8秒”。应与实际切片时间校正参考和事件定义相配，代码不自动读取STC记录猜这个值。HCP示例STC关闭，保留8是工程设置，不是已完成切片时间校正的证明。[SPM微时间与滤波说明](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/)

## 8. 第144—152行：继承混杂参数、掩膜阈值和失败处理

### 第144行：cfg.design

`cfg.design=design_config;`

把design_config返回的混杂设置装进这张订单。它包含下面这些字段；因此glm_config看起来只有这一行，实际仍要了解这些默认选择。建议在个人分析脚本中用 `cfg.design.字段=...` 覆盖，不必修改共享design_config。

| 继承字段                       | 当前默认                 | 通俗含义与选择                                                |
| -------------------------- | -------------------- | ------------------------------------------------------ |
| `motionModel`              | `'24'`               | none不选头动，6选六个平移/旋转，24选原值、差分及两者平方；表里须已有对应列，不在此从影像重新估计头动 |
| `includeTissueMeans`       | true                 | 是否加入white_matter与csf均值列；当前HCP示例通常明确设false，因为组织掩膜来源须先核对 |
| `linearTrend`              | true→第146行覆盖为false   | 是否再加入显式线性漂移                                            |
| `addSpikes`                | false                | true为每个FD超阈值帧加一列指示量，保留帧，不删除/扩展邻近帧                      |
| `fdThresholdMm`            | 0.5                  | 开启addSpikes时FD严格大于该毫米数才标记，可设有限非负数；0.5为默认，不是所有任务的统一质量界线 |
| `minResidualDF`            | 20                   | 仅混杂设计检查要求帧数−混杂秩至少多少；正整数，与一级任务联合设计、二级门槛分开               |
| `inputRoot` / `outputRoot` | design_config自己的衍生目录 | 独立混杂设计工具使用的路径，当前GLM按manifestFile读表，不使用这两个路径寻找GLM输入     |

连续混杂会去均值、按列范数缩放，常量列记录后剔除；它们和任务列在模型中联合使用。GLM不先生成一个回归残差BOLD再当原图拟合。GLMsingle同样可接收选定混杂，但通常把慢漂移交给自己的多项式。

### 第146行：cfg.design.linearTrend

`cfg.design.linearTrend=false;`

覆盖上一行继承来的true。false不额外加一列线性趋势，SPM仍有高通、GLMsingle仍有多项式；true再加该显式列。一般先false避免重复添加漂移项；是否需要额外趋势应结合设计判断，不是关闭所有基线项。

### 第148行：cfg.maskThreshold

`cfg.maskThreshold=0.8;`

SPM隐式相对强度阈值，代码允许0到1。它筛的是与影像强度有关的有效范围，不是“保留80%体素”或“p=0.8”。与显式掩膜共同约束最终mask.nii；设0也不保证全视野都有效。教学可先保持0.8并检查mask覆盖，不通过更改阈值来制造显著结果。GLMsingle使用其明确覆盖掩膜，不用本行的SPM阈值。

### 第150行：cfg.minResidualDF

`cfg.minResidualDF=20;`

一级任务模型至少留多少代数残差维度，正整数。SPM联合检查还考虑任务列、混杂和高通的代数维度；GLMsingle预检也据此检查任务/混杂/多项式与最大PC负担。它不等于SPM最终自相关修正后的统计自由度。建议先20，设计列太多报错时应先减少不合理复杂度，不为跑通无限降低门槛。

### 第152行：cfg.continueOnError

`cfg.continueOnError=true;`

true一项run/被试/组效应失败时记录状态并继续后面的独立项；false记录后停止。配置或整批预检错误仍可能直接中止。第一次学习建议false，容易看到问题；大批次可true，但最后逐项查看batch_status.tsv。继续执行不是把失败当成功，group也不自动删掉出错被试凑人数。

方法对照、易混淆参数、各方法的具体改法和原第9节以后内容，见 [独立的详细配置指南](Methods_Summary.md)。本页保留逐行释义，不再混入整套方法操作步骤。
