# DCM、spectral DCM 与 PEB：从网络假设到参数



## 一、方法在分析什么

### 1. DCM比相关多建了什么

DCM先写一个隐含神经活动的动态模型，再通过血流动力学前向模型生成BOLD，反演参数后比较模型能否解释观测。任务bilinear模型可写成：

$$\dot z=(A+\sum_j u_jB_j)z+Cu.$$

| 矩阵  | 理论问题             | 在cfg.models中填写什么   |
| --- | ---------------- | ------------------ |
| A   | 没有任务调制时哪些区域可相互影响 | a二值掩膜；行接收、列发送；包括对角 |
| B   | 哪些连接可被输入j改变      | b(:,:,j)二值掩膜       |
| C   | 实验输入从哪里直接进入网络    | c(:,j)二值掩膜         |

填1表示允许估计该参数，不是预先把连接强度设为1。实际后验位于DCM.Ep；对角自连接有SPM专门参数化，不能当成普通区域间Hz逐数

### 2. 任务与spectral输入不同

任务DCM需要明确神经输入u及输入步长；这些是刺激设计，不是把BOLD复制成输入。spectral DCM用随机波动的交叉谱解释静息数据，不需要人为制作任务B/C。不能用一套任意滤波/延迟声明覆盖两条路线。

### 3. 自由能、模型比较与群体层次

自由能F近似平衡拟合和复杂度；同一观测数据的候选模型可做稳定softmax得到均匀先验固定效应概率。不同ROI、不同清理数据或不同扫描长度的F不能混着比较。

PEB在独立被试参数上建立群体设计；BMR在该框架下缩减参数，BMA按模型证据平均。BMA不是把所有DCM参数不加权求均值。群体表一被试一行，重复run/候选网络不能充N。

### 4. 哪些参数更改了模型，哪些只是优化

a/b/c和fields改变允许估计的理论对象；covariateColumns改变群体解释；maxIterations主要控制反演机会，不会把差模型变成好模型。TE与采样延迟属于采集/预处理信息，不能为提高拟合任意调。





## 二、运行前准备

个体TSV：subject/session/run/data_file。data_file是MAT/data，至少含y(时间×ROI)、trSeconds、roiNames、TESeconds、delaysSeconds；可有X0混杂。task还需u/inputDtSeconds/inputNames。完整约束保留在下方实现细节。

已有任务SPM可先用 `cog.prepare_dcm_spm(spmMat,roiManifest,sessionIndex,TESeconds,newOutput)`；ROI表为name/mask_file，程序建立私有VOI。不能仅给一个原始BOLD文件就启动任务DCM。

静息ROI MAT可以由通用准备器生成，再根据实际协议补TESeconds/delaysSeconds；通常不要在该阶段无记录地重复带通。

| 字段                              | 形状/类型               | 具体含义                |
| ------------------------------- | ------------------- | ------------------- |
| y                               | T×R                 | 时间点×ROI，至少16点、有限非恒定 |
| trSeconds / roiNames            | 秒 / R个名称            | 共同顺序，不自动重新排列        |
| TESeconds / delaysSeconds       | 秒 / R个秒数            | 来自协议/采样参考，不凭拟合调     |
| X0                              | T×混杂列，可选            | 省略时常数项              |
| u / inputDtSeconds / inputNames | 高分辨率输入×通道 / 秒 / 通道名 | 仅task，TR/dt为整数且覆盖扫描 |



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_dcm.m](../examples/start_dcm.m)。MATLAB可用 `run('E:/my_study/start_dcm.m')` 运行自己另存的脚本。

```matlab
% dcm启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=dcm_config;
cfg.manifestFile='E:/my_study/dcm_runs.tsv';
cfg.outputRoot='E:/my_study/results/spectral_dcm_run01';
cfg.mode='spectral';
cfg.models=struct('id','full_two_node','a',ones(2),'b',[],'c',[]);
% 上例必须对应每个data.y恰好两列，且名称顺序完全相同
cfg.estimate=true;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_dcm(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

### 另一个入口：run_dcm_group

模板：[examples/start_dcm_group.m](../examples/start_dcm_group.m)。

```matlab
% dcm_group启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=dcm_group_config;
cfg.manifestFile='E:/my_study/dcm_group.tsv';
cfg.outputRoot='E:/my_study/results/peb_run01';
cfg.fields={'A'};
cfg.covariateColumns={};
cfg.reduceAndAverage=true;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_dcm_group(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```



## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### dcm_config.m

| 运行时字段                       | 实际修改/默认来源位置              | 当前默认                                                     | 候选、约束及理论/运行作用                                                                                     |
| --------------------------- | ------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `cfg.manifestFile`          | config/dcm_config.m 第4行  | `fullfile(root,'config','dcm_runs.tsv')`                 | subject/session/run/data_file；data_file内需data结构，见新DCM说明；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`            | config/dcm_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_dcm')` | 新绝对结果目录，禁止覆盖；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                                          |
| `cfg.execute`               | config/dcm_config.m 第6行  | `false`                                                  | false校验数据和网络；true写准备文件并按estimate估计；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。                     |
| `cfg.estimate`              | config/dcm_config.m 第7行  | `true`                                                   | false仅准备DCM；true实际原生反演并检查后验；false仅准备/指定模型，true才反演/估计；execute=false时两者都不实际写结果。                     |
| `cfg.mode`                  | config/dcm_config.m 第8行  | `'task'`                                                 | task=确定性单状态bilinear；spectral=静息交叉谱。                                                               |
| `cfg.models`                | config/dcm_config.m 第9行  | `struct('id',{},'a',{},'b',{},'c',{})`                   | 每个模型明确id/A/B/C二值掩膜；A行=接收节点、列=发送节点，必须包括自连接。                                                        |
| `cfg.options.maxIterations` | config/dcm_config.m 第10行 | `128`                                                    | 正整数；工程低迭代并不等同充分收敛。                                                                                |
| `cfg.options.arOrder`       | config/dcm_config.m 第11行 | `8`                                                      | spectral多变量AR阶数，正整数且至少4倍阶数的时间点。                                                                   |
| `cfg.options.centerInputs`  | config/dcm_config.m 第12行 | `true`                                                   | task输入是否中心化；实际值随模型保存。                                                                             |
| `cfg.continueOnError`       | config/dcm_config.m 第13行 | `false`                                                  | true逐run记录失败继续，false保留已完成模型后停止；false立即停下检查；true逐run保留失败并继续，整体没有完成标记时不要视为成功。                       |

### dcm_group_config.m

| 运行时字段                  | 实际修改/默认来源位置                    | 当前默认                                                           | 候选、约束及理论/运行作用                                                        |
| ---------------------- | ------------------------------ | -------------------------------------------------------------- | -------------------------------------------------------------------- |
| `cfg.manifestFile`     | config/dcm_group_config.m 第4行  | `fullfile(root,'config','dcm_group.tsv')`                      | subject/dcm_file清单，可附数值协变量；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`       | config/dcm_group_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_dcm_group')` | 新绝对目录，不在个体模型目录写结果；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                        |
| `cfg.execute`          | config/dcm_group_config.m 第6行  | `false`                                                        | false预检所有后验与设计；true估计PEB；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。  |
| `cfg.covariateColumns` | config/dcm_group_config.m 第7行  | `{}`                                                           | 清单数值列，自动总体中心化；截距始终保留。                                                |
| `cfg.fields`           | config/dcm_group_config.m 第8行  | `{'A'}`                                                        | 后验参数字段，如{'A','B'}；不能混同不同模型类型/区域顺序。                                   |
| `cfg.maxIterations`    | config/dcm_group_config.m 第9行  | `64`                                                           | PEB最大迭代，正整数。                                                         |
| `cfg.reduceAndAverage` | config/dcm_group_config.m 第10行 | `true`                                                         | true调用spm_dcm_peb_bmc做BMR/BMA；false仅PEB。                             |
| `cfg.modelMasks`       | config/dcm_group_config.m 第11行 | `[]`                                                           | 空用SPM自动缩减搜索；非空为候选模型×所选参数的0/1矩阵。                                      |



## 六、结果

| 文件/结构                 | 应检查什么                  |
| --------------------- | ---------------------- |
| 每run/模型的DCM.mat       | 原生参数Ep/Cp、自由能F、观测与模型定义 |
| dcm_catalog.tsv       | 个体结果路径，不是群体独立样本表的自动替代  |
| PEB.mat / BMA_BMR.mat | 另运行run_dcm_group才生成    |
| 数值检查和完成标记             | 维度/有限性/文件链，不表示模型充分收敛   |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。



## 七、输入、数值约定与实现细节补充

此模块调用本机 SPM 原生反演；通用代码不包含 HCP 路径。已实现确定性单状态 bilinear task DCM、静息 spectral DCM、多候选网络批量估计、同一数据的固定效应模型概率，以及独立被试的 PEB／BMR／BMA。随机 DCM、双状态、非线性 DCM、组随机效应 BMS 和 PEB 留一被试预测尚未实现，不能用本说明中的基础流程代替这些变体。

### 环境与配置

在 MATLAB 中运行 `setup_function('你的SPM目录')`。本轮验证使用 MATLAB R2025b、SPM12 revision 7771；SPM 不随包分发。修改新分析包自己的 `config/dcm_config.m` 与 `config/dcm_group_config.m`，不要改预处理包已定稿的 `toolkit_config.m`。

- 个体配置中的 `manifestFile` 指向 TSV，列为 `subject/session/run/data_file`，session 可以为空；
- ID 仅用字母、数字、下划线、连字符。
- 模板为 `config/dcm_runs_template.tsv`。
- 同一被试可有多个 session/run；
- 每个 run 与每个候选网络各有独立输出。
- `outputRoot` 使用新绝对目录。
- `execute=false` 会读取并校验全部数据和网络；
- `execute=true, estimate=false` 仅准备文件，不产生完成反演标记；
- 两个开关均为 true 才调用 SPM。
- `mode` 明确选 task 或 spectral，`models` 明确指定候选网络，代码不自动推断网络。

`options.maxIterations` 是正整数最大迭代数，`options.arOrder` 为 spectral 多变量 AR 阶数，`options.centerInputs` 控制 task 输入中心化。迭代少只是工程便捷选择。`continueOnError` 可使不同 run/model 的失败分别保留并继续；未全部成功时不写总完成标记。

### 个体输入与网络定义

每个 `data_file` 是 MAT 文件，含结构 `data`：

| 字段             | 内容与约束                             |
| -------------- | --------------------------------- |
| y              | 时间点×区域的有限、非恒定时序；至少16点             |
| trSeconds      | TR，秒，正数                           |
| roiNames       | 与 y 列一一对应的唯一非空区域名称，所有候选模型保留同样顺序   |
| TESeconds      | 实际回波时间，秒，范围 (0,0.1]；必须根据采集协议填写    |
| delaysSeconds  | 每区域采样时延，秒，在 [0,TR]；需与预处理和微时间参考一致  |
| X0             | 可选的时间点×混杂矩阵，有限且满列秩；省略时用常数项        |
| u              | task 必需，神经输入的高分辨率时间点×输入通道         |
| inputDtSeconds | task 必需，输入步长，秒；TR/步长须为整数且覆盖全部扫描时长 |
| inputNames     | task 必需，与 u 列对应的唯一输入名称            |

`models(k)` 含安全的 `id` 与二值掩膜 `a/b/c`。A 是区域×区域，行接收、列发送，所有对角线必须为1；B 是区域×区域×输入的调制掩膜；C 是区域×输入的驱动掩膜，task 至少有一个驱动连接。掩膜不是初始连接强度。spectral 不接任务 B/C，置空；至少需 `4*arOrder` 时间点，这只是输入下限。

- 已有 SPM 任务 GLM 可用 `cog.prepare_dcm_spm(spmMat,roiManifest,sessionIndex,TESeconds,newOutput)` 准备。
- ROI TSV 列 `name/mask_file`，掩膜必须在模型数据网格，名称顺序固定。
- 适配器在新私有目录建立任务效应 F 对比，调用 SPM VOI 提取经白化、滤波、效应调整的第一特征时序与共同混杂基，再取所选 session 的高分辨率神经输入。
- 源 SPM 估计和原始影像不写入。
- 它不进行解剖配准，也不证明 ROI 选择独立；
- 使用者需明确 ROI 和上游 GLM 设计。

静息输入可自行提取 ROI 时序并处理混杂；不要无记录地重复带通滤波。示例单独去常数/线性趋势，并保留 HCP 上游已做高通的事实。task、spectral 两条路线的输入准备不应混为同一种。

- 调用 `run_dcm(cfg)` 后，每个模型保存原生 `DCM.mat`、后验数值检查、状态和完成标记，根目录有 `dcm_catalog.tsv`。
- 现有输出根会拒绝覆盖。
- `cog.dcm_check` 检查后验维度、有限性和协方差半正定，报告自由能及可用的时域解释方差；
- `convergenceAssessed=false` 始终明确保留。
- 有限后验、一次成功返回、原生日志的停止信息都不足以证明识别性、参数恢复或科学意义。

`cog.dcm_model_probabilities({DCM1,DCM2,...})` 只接受同一 y、输入、TR、区域顺序的已估计模型，在均匀先验下对自由能做稳定 softmax，并给出相对首个模型的 log Bayes factor。这是单一数据集固定效应比较，不是跨被试随机效应 BMS。不要比较不同清理数据、不同区域或不同时间点的自由能。

### PEB、模型缩减与平均

群体 TSV 模板 `config/dcm_group_template.tsv`，每行 `subject/dcm_file`，可附数值协变量。一名独立被试一行，至少3人；不能把同一个人的 run 或不同候选网络当成独立被试增加 N。同文件不可重复，区域名称/顺序、网络掩膜和后验维度须一致。3人下限只为工程运行，不是科学样本量推荐。

- `dcm_group_config.m` 中 `covariateColumns` 指定总体中心化的数值列，截距自动加入；
- 设计须满秩且人数大于回归列数。
- `fields` 选择共同后验参数字段，如 `{'A'}`。
- 运行 `run_dcm_group(cfg)` 调用原生 `spm_dcm_peb`；
- `reduceAndAverage=true` 时再调用 `spm_dcm_peb_bmc`。
- `modelMasks=[]` 用原生自动缩减搜索；
- 非空为候选模型×`PEB.Pnames` 参数的二值矩阵，原生例程主要支持前两个群体效应的指定模型比较。
- 复杂多效应设计应直接核对 SPM 输出定义。
- 输出在新的群体目录，个体 DCM 不改写。
- 保存 `PEB.mat`、可选 `BMA_BMR.mat` 和完成标记。
