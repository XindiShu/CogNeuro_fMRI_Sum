# 功能连接：Pearson、秩相关、偏相关、种子与任务背景



## 一、方法在分析什么

### 1. 两条曲线“同步变化”是什么意思

一个ROI就是把一组已定义体素的信号汇成一条时间曲线。Pearson相关比较两条曲线偏离各自均值时是否一起升降：

例如 x=[1,2,3,4]、y=[2,4,6,8]，r=1；y变成[8,6,4,2]，r=-1。整体幅度乘常数不改变r。正相关不能直接推出一个区域驱动另一个区域。

### 2. 三种估计器回答的不是同一个问题

| cfg.fc.estimator | 先做什么         | 适合回答什么        | 限制                   |
| ---------------- | ------------ | ------------- | -------------------- |
| pearson          | 直接比较残差曲线     | 线性共同波动        | 异常值、共同任务/运动均可能改变r    |
| spearman         | 把每列数值转平均秩再相关 | 单调关系是否一致      | 忽略幅度距离，不等于去掉所有异常影响   |
| partial          | 求样本协方差逆矩阵    | 控制其余所有列后的线性关系 | 需要可逆且不过分病态；p大于n通常不适用 |

偏相关由 precision P=C⁻¹ 给出 -Pij/sqrt(PiiPjj)。本分支遇奇异矩阵会报错，不偷偷改估计器；想用收缩应读[OAS](FUNCTION_REGULARIZED_FC_MVPA_RSA.md)。

### 3. 为什么先说明回归和滤波

时序里同时有慢漂移、运动、任务反应等成分。程序把截距、可选线性趋势、显式混杂列和带外DCT基放入同一个Z：Yclean=Y−QQ'Y，Q为Z的独立列空间。这样避免顺序回归把已去掉的成分重新引回。

`clean.bandHz=[]`只是不新增本次带通，不代表上游数据从没滤过。`minResidualDimensions`约束代数剩余维度，不是因为时间点有自相关就能直接得到统计自由度。

### 4. 种子、权重、网络摘要与背景连接

| 功能     | 输入变化                   | 通用计算位置                                      |
| ------ | ---------------------- | ------------------------------------------- |
| 种子→体素  | 选ROI列，与同一固定mask内所有体素比较 | cog.seed_fc；seedColumns是列号，不是标签值            |
| 加权FC   | 每时间点给非负权重，零权重点不贡献拟合    | cog.weighted_fc；权重同时用于WLS混杂与相关              |
| 网络摘要   | 每个ROI再指定网络标签           | cog.network_summary；排除自身，分别平均r和Fisher-z     |
| 任务背景FC | 共同任务列与混杂一并去除后相关        | run_background_fc；读取原SPM任务设计，不使用已经回归过的残差再回归 |

Fisher-z=atanh(r)便于后续建模，却没有消除时间自相关。程序不自动给错误的“把所有帧当独立样本”的相关p值。

##

## 二、运行前准备

静态FC使用 `analysis_runs_template.tsv` 的11列，见[从零教程](FUNCTION_START_HERE.md)。每行对应一个预处理后的4D .nii；mask和整数ROI图须同网格。confounds为空或纯数值TSV，行数必须与完整BOLD相同。

背景FC不需要run TSV：直接给已估计的SPM.mat、sessionIndex、maskFile、roiFile；必须确认SPM引用的BOLD未先做时间回归/滤波。背景输入不等于GLM残差。

矩阵接口可直接写：

```matlab
w=ones(size(Y,1),1); % Y为时间xROI；请按实际设计改变权重
r=cog.weighted_fc(Y,w,[]);
network=cog.network_summary(r.correlation,networkLabels);
```

这里 `networkLabels` 必须与ROI列顺序对应；低层函数不替你读影像或保存文件。



## 三、步骤

1. 在研究目录保存输入、清单和自己的启动脚本；结果放新目录。
2. 按本章输入表核对每行/列的含义、单位、顺序和依赖组。
3. 打开下面的启动模板，先另存到研究目录，修改路径及理论参数。
4. 保持 `cfg.execute=false` 运行，检查报告；这只覆盖入口当前定义的预检，并不等于完整分析。
5. 没有输入错误后，将启动脚本中的false改true，重新运行同一脚本。
6. 到outputRoot读取下节结果，查看实际模型/覆盖/失败与跳过记录；不能只看目录存在。
7. 修改分析方案时换一个新outputRoot，保留成功结果和原输入。

主启动模板：[examples/start_fc.m](../examples/start_fc.m)。MATLAB可用 `run('E:/my_study/start_fc.m')` 运行自己另存的脚本。

```matlab
% fc启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=function_config;
cfg.manifestFile='E:/my_study/analysis_runs.tsv'; % [必改] 11列清单
cfg.outputRoot='E:/my_study/results/fc_run01';    % [必改] 尚不存在
cfg.methods={'static_fc'};
cfg.fc.estimator='pearson';
cfg.fc.seedColumns=[]; % 如[1 2]：第1/2个ROI列额外输出种子图
cfg.clean.bandHz=[];   % 明确是否新增带通
cfg.continueOnError=false;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_function(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
```

### 另一个入口：run_background_fc

模板：[examples/start_background.m](../examples/start_background.m)。

```matlab
% background启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=background_config;
cfg.spmMat='E:/my_study/glm/p01/r1/SPM.mat';
cfg.maskFile='E:/my_study/mask.nii';
cfg.roiFile='E:/my_study/roi_labels.nii';
cfg.outputRoot='E:/my_study/results/background_p01_r1';
cfg.temporalState='unfiltered_unregressed';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_background_fc(cfg);
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

### background_config.m

| 运行时字段               | 实际修改/默认来源位置                     | 当前默认                                                            | 候选、约束及理论/运行作用                                                          |
| ------------------- | ------------------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `cfg.spmMat`        | config/background_config.m 第4行  | `''`                                                            | 读取原始任务设计/扫描路径，不修改其SPM模型。                                               |
| `cfg.sessionIndex`  | config/background_config.m 第5行  | `1`                                                             | SPM内session索引，整数>=1。                                                   |
| `cfg.maskFile`      | config/background_config.m 第6行  | `''`                                                            | 固定有效体素mask，须与所选扫描同网格。                                                  |
| `cfg.roiFile`       | config/background_config.m 第7行  | `''`                                                            | 同网格整数ROI标签图。                                                           |
| `cfg.temporalState` | config/background_config.m 第8行  | `'unfiltered_unregressed'`                                      | 必须确认SPM引用的BOLD未事先时间回归/滤波。                                              |
| `cfg.outputRoot`    | config/background_config.m 第9行  | `fullfile(fileparts(root),'derivatives','function_background')` | 新的输出目录；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                     |
| `cfg.execute`       | config/background_config.m 第10行 | `false`                                                         | false仅预检；true读取ROI时序并计算背景连接；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。 |
| `cfg.maxMatrixGiB`  | config/background_config.m 第11行 | `2`                                                             | double矩阵上限GiB，>0；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                  |
| `cfg.roiMinVoxels`  | config/background_config.m 第12行 | `3`                                                             | 每ROI最少体素正整数；有效mask内每ROI最低体素数；太少拒绝，不会自动扩大ROI或补零。                        |
| `cfg.clean`         | config/background_config.m 第13行 | `shared.clean`                                                  | 额外趋势/频带选项；原SPM高通基会共同投影。                                                |
| `cfg.estimator`     | config/background_config.m 第14行 | `'pearson'`                                                     | pearson/spearman/partial。                                              |

### prepare_inputs_config.m

| 运行时字段                       | 实际修改/默认来源位置                         | 当前默认                                                          | 候选、约束及理论/运行作用                                                                          |
| --------------------------- | ----------------------------------- | ------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| `cfg.manifestFile`          | config/prepare_inputs_config.m 第4行  | `fullfile(root,'config','analysis_runs.tsv')`                 | 复用analysis_runs_template.tsv的11列，路径与处理状态必须真实；输入清单路径；先复制本方法对应模板，改成自己的行。路径只选择数据，不改变理论模型。 |
| `cfg.outputRoot`            | config/prepare_inputs_config.m 第5行  | `fullfile(fileparts(root),'derivatives','function_prepared')` | 新绝对目录，保留原始影像；保存新结果的目录；必须尚不存在，避免改坏已有成功结果。                                               |
| `cfg.execute`               | config/prepare_inputs_config.m 第6行  | `false`                                                       | false检查清单/文件/处理声明，true读影像并写MAT；false预检/有限输入计算；true才运行并保存。预检不是完整分析或科学质量验收。              |
| `cfg.mode`                  | config/prepare_inputs_config.m 第7行  | `'roi'`                                                       | roi=标签区域均值，供HMM/滑窗/熵等；voxels=掩膜内逐体素，供ICA等。                                             |
| `cfg.maxMatrixGiB`          | config/prepare_inputs_config.m 第8行  | `2`                                                           | 时间×体素double矩阵上限GiB，非总峰值保证；主double输入矩阵上限GiB；限制资源，不是总峰值内存或科学样本量。                         |
| `cfg.roiMinVoxels`          | config/prepare_inputs_config.m 第9行  | `3`                                                           | roi模式每区最少体素，正整数；有效mask内每ROI最低体素数；太少拒绝，不会自动扩大ROI或补零。                                    |
| `cfg.requireCommonFeatures` | config/prepare_inputs_config.m 第10行 | `true`                                                        | true要求所有输出列身份相同；voxels同时要求同网格，不自动取交集/重采样。                                              |
| `cfg.clean`                 | config/prepare_inputs_config.m 第11行 | `base.clean`                                                  | detrend/bandHz/minResidualDimensions继承function_config；只执行本次明确设置的联合投影。                  |



## 六、结果

| 文件/结构                             | 应检查什么                             |
| --------------------------------- | --------------------------------- |
| roi_timeseries.mat                | ROI曲线、覆盖与清理信息                     |
| static_fc.mat / fc_r.tsv          | FC矩阵及ROI顺序                        |
| seed_*_r.nii                      | 仅当选择seedColumns时输出，mask外NaN       |
| COMPLETE.mat / BATCH_COMPLETE.mat | run成功／所有run均成功；仍检查summary中的failed |

运行返回、数值/文件检查、样例覆盖和科研质量是四层不同检查。完成标记仅说明该入口完成了已选计算；请结合下面状态行和实际输出作判断。

##

## 七、输入、数值约定与实现细节补充

### 启动和连续时序输入

- 在MATLAB切换到本包，执行 setup_function；

- SPM不在路径时可传入本机安装目录。

- config/function_config.m 是连续时序配置入口。

- 复制 analysis_runs_template.tsv 为自己的清单并填入路径，修改 manifestFile、outputRoot、methods，先保持 execute=false 预检，再设true计算。

- 直接调用 run_function(cfg)。

- 默认配置不包含HCP绝对路径。

- 清单每行subject/session/run唯一；

- session可空。

- bold为未压缩4D NIfTI，mask为固定3D有效掩膜，roi_file为同网格非负整数标签图，tr_seconds为秒并须与NIfTI一致。

- confounds可以空；

- 若填TSV，其全部列必须是显式选择的有限数值回归量，行数与完整BOLD一致。

- 不能把含字符串、首行NaN或未选择的整个confounds总表直接交给此接口。

- temporal_state可用 unfiltered_unregressed、nuisance_regressed_unfiltered、nuisance_regressed_highpassed、denoised_bandpassed。

- 已经做过混杂回归的输入不允许再次传confounds。

- purpose为rest/task/engineering，是来源声明，不能改变方法假设。

- smoothing_fwhm_mm是输入已有平滑的声明；

- 本接口不重新平滑。

- 多被试/session/run会输出到各自目录，默认不跨run平均。

当前methods开放static_fc、alff、reho、graph。配置字段均有中文单位/约束注释；clean段控制截距、趋势、混杂和DCT带外频率基的联合投影。不删帧、不插值，residualDimensions仅是代数剩余维度。maxMatrixGiB限制主double矩阵大小，不保证进程峰值内存；输入按帧读取，固定mask内非有限值报错，不自动用标签/结果删体素。

### FC与任务连接

- static_fc输出ROI相关矩阵、Fisher-z矩阵和覆盖表。
- fc.estimator可选pearson、spearman、partial；
- partial在样本协方差奇异/病态时拒绝，不暗中换成正则化估计。
- fc.seedColumns指定ROI列号后额外写种子到体素相关图。
- 常数ROI报错；
- Fisher-z对角为NaN，非对角精确±1可为Inf，不暗自截断。
- 时间点相关没有自动附上错误的独立样本p值。

cog.network_summary(r,networkLabels)汇总网络内/间边，分别返回meanR和meanFisherZ，排除对角。cog.weighted_fc(y,weights,confounds)进行非负权重的WLS残差相关，权重需使用者按实验明确给出，零权重不构成插值。

- Background connectivity使用config/background_config.m和run_background_fc(cfg)：显式确认原SPM引用的BOLD为unfiltered_unregressed，指定spmMat、sessionIndex、maskFile和roiFile；
- 读取选中session未滤波任务设计列、原混杂和高通基，全部联合投影后计算ROI背景连接。
- 支持SPM引用3D/4D扫描；
- 不把原SPM残差重新回归任务。
- execute=false只预检，true写新结果。
- 原模型滤波采用特殊拼接session布局时会明确报错，需单独适配。
- 
