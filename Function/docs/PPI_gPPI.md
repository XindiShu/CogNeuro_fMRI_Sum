# PPI / gPPI：任务条件怎样调制种子关系



## 一、方法在分析什么

### 1. PPI在问什么

假设视觉区和额叶在任务A比任务B更同步。PPI检验的是种子与目标的统计关系是否随心理条件改变。它不是普通静息FC，也不是DCM的神经动力参数。

一个简化新模型为：目标BOLD=心理主效应+种子生理项+心理×生理交互+混杂+误差。主效应不能省掉，否则交互可能吸收共同任务反应。原理和反卷积步骤见[SPM PPI手册](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/ppi/ppi/)。

### 2. 为什么不直接把两条BOLD相乘

程序先用原生VOI取得经任务效应调整的第一特征变量，再由spm_peb_ppi做神经层反卷积；在神经层乘心理输入，再卷积回BOLD层。原GLM与原始影像只读，新交互模型另存。

| mode | 心理表达          | 需要改的参数                                      |
| ---- | ------------- | ------------------------------------------- |
| ppi  | 一个明确条件对比，如A−B | psychologicalWeights=[1 -1]，长度与所选条件相同       |
| gppi | 每个所选条件单独交互    | conditionIndices控制条件，psychologicalWeights忽略 |

条件编号指SPM.Sess.U顺序，不是beta文件编号，不直接包含pmod列。先在MATLAB查看所选session的任务结构，再填写。

### 3. 两个开关

| execute | estimate | 实际动作                             |
| ------- | -------- | -------------------------------- |
| false   | 任意       | 预检，不构造VOI/新模型                    |
| true    | false    | 仍会提VOI、生成PPI、指定新SPM设计，但不估计beta/T |
| true    | true     | 完成上面步骤并估计/对比/输出检查                |





## 二、运行前准备

单run不需要TSV：准备已估计SPM.mat、同网格种子mask、可选目标analysisMask。analysisMask必须为原模型mask子集。原SPM必须可读到它引用的扫描和估计文件。

多被试使用 `ppi_runs_template.tsv`：subject/session/run/spm_mat/seed_mask/spm_session_index；调用 `run_ppi_batch(cfg,'E:/study/ppi_runs.tsv')`。不是把所有人的SPM都填进一个spmMat字符串。



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_ppi.m](../examples/start_ppi.m)。MATLAB可用 `run('E:/my_study/start_ppi.m')` 运行自己另存的脚本。

```matlab
% ppi启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=ppi_config;
cfg.spmMat='E:/my_study/glm/p01/r1/SPM.mat';
cfg.seedMask='E:/my_study/seeds/p01_seed.nii';
cfg.outputRoot='E:/my_study/results/ppi_p01_r1';
cfg.sessionIndex=1;
cfg.mode='gppi';
cfg.conditionIndices=[]; % []选该session全部条件
cfg.estimate=true;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_ppi(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

### 另一个入口：run_ppi_batch(cfg,'E:/my_study/ppi_runs.tsv')

模板：[examples/start_ppi_batch.m](../examples/start_ppi_batch.m)。

```matlab
% ppi_batch启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=ppi_config;
cfg.outputRoot='E:/my_study/results/ppi_batch_run01';
cfg.mode='gppi';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_ppi_batch(cfg,'E:/my_study/ppi_runs.tsv');
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

## 五、参数逐项解释

推荐在自己的启动脚本中写 `cfg.xxx=...` 覆盖默认值，方便保存每次方案。下表行号对应当前发布包的分方法配置文件；不是旧预处理toolkit_config。候选/范围来自实际开放接口，未列的高级选项不要自行填入。

### ppi_config.m

| 运行时字段                      | 实际修改/默认来源位置              | 当前默认                                                     | 候选、约束及理论/运行作用                                                            |
| -------------------------- | ------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------ |
| `cfg.spmMat`               | config/ppi_config.m 第4行  | `''`                                                     | 已估计SPM.mat，只读。                                                           |
| `cfg.seedMask`             | config/ppi_config.m 第5行  | `''`                                                     | 与BOLD同网格3D非负种子掩膜。                                                        |
| `cfg.analysisMask`         | config/ppi_config.m 第6行  | `''`                                                     | 空复用原模型mask；非空为同网格目标mask，须为原mask子集。                                       |
| `cfg.outputRoot`           | config/ppi_config.m 第7行  | `fullfile(fileparts(root),'derivatives','function_ppi')` | 新结果目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                        |
| `cfg.execute`              | config/ppi_config.m 第8行  | `false`                                                  | false仅预检；true计算VOI、PPI及新模型；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。    |
| `cfg.sessionIndex`         | config/ppi_config.m 第9行  | `1`                                                      | SPM内session索引，整数>=1。                                                     |
| `cfg.mode`                 | config/ppi_config.m 第10行 | `'gppi'`                                                 | ppi=单心理对比；gppi=每条件一交互。                                                   |
| `cfg.conditionIndices`     | config/ppi_config.m 第11行 | `[]`                                                     | []全部Sess.U；或明确条件编号，不含pmod列。                                              |
| `cfg.psychologicalWeights` | config/ppi_config.m 第12行 | `[]`                                                     | 与条件等长非全零权重；gppi忽略。                                                       |
| `cfg.highpassSeconds`      | config/ppi_config.m 第13行 | `128`                                                    | 交互模型高通秒，有限>0。                                                            |
| `cfg.serialCorrelation`    | config/ppi_config.m 第14行 | `'FAST'`                                                 | FAST或AR(1)。                                                              |
| `cfg.estimate`             | config/ppi_config.m 第15行 | `true`                                                   | true估计及T对比；false仅指定新模型；false仅准备/指定模型，true才反演/估计；execute=false时两者都不实际写结果。 |

## 六、结果判定

| 文件/结构                   | 应检查什么                          |
| ----------------------- | ------------------------------ |
| private_source          | 任务效应F/VOI的私有准备，不修改原SPM         |
| ppi_job.mat / SPM.mat   | 交互、回归量名称、实际新模型                 |
| beta_*.nii / spmT_*.nii | 仅估计后存在；读实际对比名，不猜编号             |
| PPI_COMPLETE.mat        | 估计与输出检查成功；estimate=false不会有该标记 |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 九、输入、数值约定与实现细节补充

### PPI/gPPI

config/ppi_config.m对应run_ppi(cfg)；多被试清单用ppi_runs_template.tsv及run_ppi_batch(cfg,manifest)。输入已估计SPM.mat、seedMask、SPM sessionIndex。输出根目录必须为新绝对路径。analysisMask可指定原分析mask子集，用于工程小范围验证；空时复用原mask。

- 先在输出private_source中建立仅任务效应F对比，再由SPM原生VOI批处理抽取经效应调整的第一特征变量；
- 调用spm_peb_ppi进行神经层反卷积、心理交互与再卷积。
- 全部原输入beta/方差和影像保持只读。
- ppi用psychologicalWeights指定心理对比；
- gppi为选中条件各建一个交互。
- 新模型包括交互、心理项、seed及原session混杂，采用指定高通和FAST/AR(1)，不直接对原模型追加PPI。
- 复杂pmod/HRF变体和条件子集的充分主效应模型仍需项目特定检查，当前实测是两条件canonical任务。

estimate=false仍会抽取VOI、生成交互并指定新模型；仅execute=false完全预检不写输出。估计后核验beta、方差、T对比及统计图在输出mask内有限且同网格，再保存完成标记。PPI表示条件调制关系，不与静息相关或DCM连接参数混用。
