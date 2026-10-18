# D:\GLM 包内文件说明

本页回答三个问题：**这个文件做什么、使用时能改哪里、要不要手动Run**。按2026-10-16当前实际目录逐项核对，共 **198个文件**；`FILE_MANIFEST.json`记录其中197个文件，不记录自身。以下各节标题给出文件所在目录，表中点击文件名可打开对应文件。当前仍存在的`glm_config.asv`、旧入口、示例和测试均照实列出。

## 先看：平常需要操作哪些文件

| 目的                                       | 需要填写或修改                                      | 手动启动                    |
| ---------------------------------------- | -------------------------------------------- | ----------------------- |
| 条件GLM、LSA/LSS、pmod/FIR、跨run、二级或GLMsingle | `config/glm_config.m`及所选输入表；先按方法配好一套参数       | `run_glm`               |
| 已完成模型的统计图、beta矩阵和ROI导出                   | `config/glm_outputs_config.m`及结果/beta来源/ROI表 | `run_glm_outputs`       |
| HCP语言任务的GLMsingle近似教学演示                  | `config/glmsingle_demo_config.m`，先读专用演示文档    | `run_glmsingle_demo`，可选 |
| 兼容旧逐事件LSA/LSS流程                          | `config/single_trial_config.m`及旧run清单        | `run_single_trial`，可选   |

四个入口按任务选择，**不需要依次全部运行**。估计配置中的`execute=false`只准备和检查；需要实际估计时设置为`true`。总配置是返回参数的MATLAB函数，单独运行它不会估计模型；TSV是数据表，也不能按Run。

从[GUIDE](GUIDE.md)了解流程，从[Methods_Summary](Methods_Summary.md)选择方法与必改参数，从[Line_by_Line_Explanation](Line_by_Line_Explanation.md)查单个字段。本页只解释文件职责。

“通常保持”表示普通分析不用改，不代表源码不能开发；修改算法、接口或发布逻辑后应重新验证。“复制填写”表示把模板复制到个人项目再填路径和数据，保留必需列名与单位。定稿共享配置、第三方固定依赖、许可证和自动生成哈希清单不作为个人参数编辑。文件改动会改变发布哈希，维护发布时应重新生成清单，不能手填哈希让检查通过。

## 1. 根目录：6个文件

`run_glm.m`和`run_single_trial.m`是脚本，每次重新读总配置；如果在命令窗口自定义了`cfg`，统一估计应直接调用`psy.glm_batch(cfg)`。另两个入口是函数，可无参数读取各自配置；GLMsingle演示也可同时传入`cfg,demo`。

| 文件                                              | 内容与用途                                                                                                           | 哪些可以改                      | 是否需要手动运行                             |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------- | ------------------------------------ |
| [FILE_MANIFEST.json](../FILE_MANIFEST.json)     | 发布清单，记录包内其他文件的相对路径、字节数和SHA256；用于核查文件是否变化。不是被试/run输入表，也不包含自己的哈希。                                                 | 自动生成，勿手改                   | 否；发布脚本生成                             |
| [README.md](../README.md)                       | 包首页，说明GLM包与预处理包的关系。部分内容保留早期阶段状态；当前操作顺序读GUIDE，方法与限制读Methods_Summary及对应方法文档。                                      | 说明文字，可按需修订                 | 否；阅读                                 |
| [run_glm.m](../run_glm.m)                       | 统一估计启动脚本：读取glm_config，再调用psy.glm_batch；条件、LSA/LSS、pmod/FIR、跨run、二级、GLMsingle均由配置选择。它会重新读配置，不使用你之前在命令窗口临时改过的cfg。 | 通常保持；参数在glm_config         | 是；准备好配置后运行run_glm                    |
| [run_glm_outputs.m](../run_glm_outputs.m)       | 已估计模型的后处理函数：读取SPM结果、阈值化/绘图、建立统一beta目录/矩阵、ROI提取；可传cfg，也可无参数读glm_outputs_config。不重新拟合源模型。                         | 通常保持；参数在glm_outputs_config | 是；运行run_glm_outputs，或传入cfg           |
| [run_glmsingle_demo.m](../run_glmsingle_demo.m) | 特定HCP语言任务教学启动器：在新事件副本中显式统一时长/时间格点、审计尾部排除、抽样掩膜后执行GLMsingle。近似假设不是通用GLMsingle自动默认。                                | 通常保持；改专用demo配置             | 可选；运行run_glmsingle_demo，或同时传cfg和demo |
| [run_single_trial.m](../run_single_trial.m)     | 早期逐事件LSA/LSS启动脚本，读取single_trial_config；用于兼容既有例子。新项目优先统一run_glm框架，两个入口的部分字段命名不同。                                 | 通常保持；改single_trial_config  | 旧入口可选；运行run_single_trial             |

## 2. config：20个文件

这里放配置函数与输入表模板，**不包含你的实际影像或已估计模型**。模板中的E盘路径、participant01、条件名、分数等都是示意，使用前必须替换。普通分析修改`glm_config.m`或`glm_outputs_config.m`及自己填写的表即可；共享的预处理配置不是额外必改步骤。

| 文件                                                                               | 内容与用途                                                                                                         | 哪些可以改                           |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| [design_config.m](../config/design_config.m)                                     | 混杂设计参数：头动none/6/24、WM/CSF均值、趋势、FD指示列及残差维度；glm_config继承后会把linearTrend覆盖成false。其独立输入/输出目录不是GLM数据入口。             | 普通分析优先在cfg.design覆盖；改本文件影响继承默认值 |
| [glm_beta_sources_template.tsv](../config/glm_beta_sources_template.tsv)         | 后处理beta来源清单：id/engine/source_dir/variant，展示framework、早期single_trial和GLMsingle来源根目录与版本选择。                      | 复制填写已完成来源与版本；勿填原始BOLD           |
| [glm_config.asv](../config/glm_config.asv)                                       | MATLAB编辑器自动保存的备份；正式入口不会读取它。核对历史修改时可参考，不能把它当作当前生效配置。                                                           | 备份，不作正式配置；不必跟着改                 |
| [glm_config.m](../config/glm_config.m)                                           | 统一估计总参数，返回cfg：输入输出、条件、估计单元、事件时长、HRF、拟合策略、统计层级、pmod、组设计、GLMsingle及混杂。当前文件154行，字段解释见Line_by_Line_Explanation。   | 必查路径/输入/条件；按方法调整合法参数            |
| [glm_events_glmsingle_template.tsv](../config/glm_events_glmsingle_template.tsv) | GLMsingle事件样例，含重复刺激身份stimulus_id与独立trial_id，帮助区分“每次事件”和“重复身份”。                                                | 复制填写；保留基础列，填相应ID/调节量            |
| [glm_events_pmod_template.tsv](../config/glm_events_pmod_template.tsv)           | pmod事件样例，除基础时间/条件外增加difficulty数值列，展示调节变量怎样逐事件对应。数值只是占位例。                                                      | 复制填写；保留基础列，填相应ID/调节量            |
| [glm_events_template.tsv](../config/glm_events_template.tsv)                     | 通用事件表样例：onset/duration/trial_type及trial_id/stimulus_id/phase。时间为秒、零点对应当前BOLD第一帧；选择block时需自己增加block_id。        | 复制填写；保留列名/秒制，按单元补ID             |
| [glm_group_paired_template.tsv](../config/glm_group_paired_template.tsv)         | 在组基本列上增加pair_level，展示同一人pre/post两张图，供按ID配对、求差后检验。                                                             | 复制填写效应图、被试及相应设计列                |
| [glm_group_regression_template.tsv](../config/glm_group_regression_template.tsv) | 在组基本列上增加synthetic_score，示范连续协变量清单；这是合成占位分数，不是HCP真实变量。                                                         | 复制填写效应图、被试及相应设计列                |
| [glm_group_template.tsv](../config/glm_group_template.tsv)                       | 二级单样本输入表：subject/session/contrast/contrast_image/mask。每人每个效应一张有符号效应图，通常是con，不是T/F图。                           | 复制填写效应图、被试及相应设计列                |
| [glm_group_two_sample_template.tsv](../config/glm_group_two_sample_template.tsv) | 在组基本列上增加group列，展示两个独立组；当前模型为等方差，不是Welch。                                                                      | 复制填写效应图、被试及相应设计列                |
| [glm_outputs_config.m](../config/glm_outputs_config.m)                           | 后处理总参数：results/betas/both、阈值方向/FWE/FDR、PNG、矩阵内存预算、ROI及新输出路径。不要把这些字段加到glm_config里。                             | 必查来源清单/新输出目录；按需调阈值/ROI          |
| [glm_results_template.tsv](../config/glm_results_template.tsv)                   | 后处理统计结果清单：id、spm_mat、contrast_index；指出读哪一个已估计SPM模型的哪项对比。                                                      | 复制填写已估计SPM.mat及对比编号             |
| [glm_roi_template.tsv](../config/glm_roi_template.tsv)                           | ROI清单：roi名字、mask_file、label；0选所有正值体素，正整数选择分区标签。只描述区域，不包含beta本身。                                               | 复制填写ROI路径/标签；核对网格与覆盖            |
| [glm_runs_template.tsv](../config/glm_runs_template.tsv)                         | 统一run/subject输入表：subject/session/run、4D BOLD、events、confounds、temporal_state；可按接口增加mask列。每行一个run，不是一行一个trial。 | 复制填写真实run来源；保留接口列名              |
| [glmsingle_demo_config.m](../config/glmsingle_demo_config.m)                     | 返回cfg和demo两部分；覆盖普通GLM配置中的HCP教学近似，并配置抽样体素上限等演示行为。只有该专用启动器消费demo。                                               | 仅跑HCP教学例时修改cfg和demo设置           |
| [preprocess_config.m](../config/preprocess_config.m)                             | HCP预处理示例预设，供历史HCP发现例子和测试等共享依赖使用；包含本机数据/SPM预设。通用GLM按run清单读已预处理数据，不靠它重新预处理。                                     | 仅适配旧HCP例时改路径；普通GLM不必改           |
| [single_trial_config.m](../config/single_trial_config.m)                         | 早期LSA/LSS参数：可同时选择两方法、目标条件及all_other/by_condition干扰分组；继承普通GLM参数。它的字段不能原样当成新框架字段。                               | 仅用旧入口时改；不混用新框架字段                |
| [single_trial_runs_template.tsv](../config/single_trial_runs_template.tsv)       | 早期LSA/LSS入口的逐run输入模板，基本列同run清单，用于旧入口兼容，不是统一beta后处理清单。                                                         | 复制填写真实run来源；保留接口列名              |
| [toolkit_config.m](../config/toolkit_config.m)                                   | 用户定稿的预处理总参数共享副本，供依赖它的旧示例/测试使用；通用GLM不把它当第二份必填配置。                                                               | 定稿共享配置，保持；普通GLM不改               |

事件表每行是输入事件；run清单每行是一个run；组清单每行是一个效应图输入。三者不能互换。事件时间以秒计，零点对应当前BOLD第一帧；run与事件等表内相对路径按对应接口规定的表所在目录解析。字段组合和限制以参数/方法文档及代码校验为准。

## 3. docs：14个文件

以下只列当前真实存在的名称，已改名或移出的旧文件不再作为包内入口。文档用于阅读，无需手动Run；手工改名后需同步检查引用。方法文档把理论与本包代码/参数相连，阅读顺序不要求逐篇全部看完。

| 文件                                                         | 内容与用途                                                                                         | 哪些可以改              |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------ |
| [Condition_GLM.md](Condition_GLM.md)                       | 条件平均GLM的理论与代码实践：事件卷积、设计矩阵、条件beta与对比，以及本包条件模型的参数和输出对应。                                         | 说明文字，可按需修订；改名须检查引用 |
| [Cross_run_group_GLM.md](Cross_run_group_GLM.md)           | 跨run被试条件模型与单样本二级：run/session划分、效应等权合成、subject_contrasts交接及模型限制。                               | 说明文字，可按需修订；改名须检查引用 |
| [Estimation_Units_GLM_.md](Estimation_Units_GLM_.md)       | 估计单元理论与代码实践：condition/event/trial/item/block/phase/trial_phase各代表什么，需要哪些事件ID，以及怎样配合joint或lss。 | 说明文字，可按需修订；改名须检查引用 |
| [GLM_HRF.md](GLM_HRF.md)                                   | 事件表达与HRF理论及代码对应：原时长、瞬时、固定时长，canonical及其时间/弥散导数、时间采样和beta含义。                                   | 说明文字，可按需修订；改名须检查引用 |
| [GLMsingle_ABCD.md](GLMsingle_ABCD.md)                     | GLMsingle A/B/C/D理论与本包适配：HRF库、去噪/ridge、重复身份、时长/时间格点、固定依赖、参数和输出。                               | 说明文字，可按需修订；改名须检查引用 |
| [GLMSINGLE_HCP_DEMO.md](GLMSINGLE_HCP_DEMO.md)             | HCP语言任务教学演示的显式假设：条件重复身份、时长统一、时间舍入、尾部排除和体素抽样，配合专用demo入口阅读。                                     | 说明文字，可按需修订；改名须检查引用 |
| [Group_and_Convariates.md](Group_and_Convariates.md)       | 二级配对、两独立组、回归与协变量：输入配对、对比方向、中心化、等方差假设、配置和输出。文件名按当前目录保留。                                        | 说明文字，可按需修订；改名须检查引用 |
| [GUIDE.md](GUIDE.md)                                       | 完整使用流程：准备输入→估计→确认完成→导出统计图、逐单元beta和ROI；第一次跑自己的数据先读它。                                           | 说明文字，可按需修订；改名须检查引用 |
| [Line_by_Line_Explanation.md](Line_by_Line_Explanation.md) | 按当前glm_config.m的行号解释配置语句、可选值、单位和约束；查单个参数时读。成套方法设置另读Methods_Summary。                           | 说明文字，可按需修订；改名须检查引用 |
| [LSA_GLM.md](LSA_GLM.md)                                   | LSA理论与代码实践：全部估计单元同时单列回归量、共线性和beta解释，对应joint策略及单元/目标设置。                                        | 说明文字，可按需修订；改名须检查引用 |
| [LSS_GLM.md](LSS_GLM.md)                                   | LSS理论与代码实践：每个目标分别拟合、其余事件怎样合并，解释两种干扰分组及与LSA的关系。                                                | 说明文字，可按需修订；改名须检查引用 |
| [Methods_Summary.md](Methods_Summary.md)                   | 方法选择与参数操作：在哪里选择条件GLM、LSA/LSS、估计单元、HRF、pmod/FIR、跨run、二级、GLMsingle，以及哪些字段必须或可以修改。               | 说明文字，可按需修订；改名须检查引用 |
| [Package_File_Explanation.md](Package_File_Explanation.md) | 本页：按实际目录解释每个文件的职责、修改范围和手动运行方式；用于查找文件，不代替方法理论或逐行参数说明。                                          | 说明文字，可按需修订；改名须检查引用 |
| [Pmod_and_FIR_GLM.md](Pmod_and_FIR_GLM.md)                 | pmod与FIR理论及代码实践：调节量、中心化/尺度/正交化、响应分箱、T/F对比与当前合法组合。                                             | 说明文字，可按需修订；改名须检查引用 |

## 4. examples：14个文件

示例为可选学习/验证材料，不是每次真实分析的前置步骤。四个合成验证函数会生成小数据并实际估计，默认结果放临时目录或指定的新目录；HCP历史示例依赖包外影像/混杂，原代码部分输出路径位于包内`derivatives`，发布包使用时应先复制并改成包外新目录。不能因为名称含`validate`就把它理解为只读预检查。

| 文件                                                                                   | 内容与用途                                                                | 哪些可以改              |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | ------------------ |
| [hcp_100206_confounds.tsv](../examples/hcp_100206_confounds.tsv)                     | 共享的100206混杂提取来源表：BOLD、WM/CSF图、运动参数、对齐声明；不包含已经提取的全部逐帧数值。              | 复制改自己的来源/事件；不改原数据  |
| [hcp_100206_sdc_confounds.tsv](../examples/hcp_100206_sdc_confounds.tsv)             | 同类混杂来源表，但指向畸变校正分支；不能与未校正分支混用。                                        | 复制改自己的来源/事件；不改原数据  |
| [hcp_100206_sdc_glm.tsv](../examples/hcp_100206_sdc_glm.tsv)                         | 100206畸变校正后条件GLM的run表，影像/混杂相对路径指向历史衍生结果。                             | 复制改自己的来源/事件；不改原数据  |
| [hcp_100206_sdc_single_trial.tsv](../examples/hcp_100206_sdc_single_trial.tsv)       | 对应早期逐事件例的run来源表，不是每事件一行的事件表。                                         | 复制改自己的来源/事件；不改原数据  |
| [hcp_glm_engineering.tsv](../examples/hcp_glm_engineering.tsv)                       | 历史HCP条件GLM的run来源表，记录影像、事件、混杂及时间处理声明。                                 | 复制改自己的来源/事件；不改原数据  |
| [hcp_language_lr_events.tsv](../examples/hcp_language_lr_events.tsv)                 | 100206 LR早期事件表：onset/duration/trial_type；含story区块与math事件段，不带逐音频身份细节。 | 复制改自己的来源/事件；不改原数据  |
| [run_hcp_sdc_glm_100206.m](../examples/run_hcp_sdc_glm_100206.m)                     | 100206经畸变校正分支的LANGUAGE LR条件GLM工程例，复用既有预处理和混杂，不是通用数据发现。               | 先复制改路径/新输出目录；不原样启动 |
| [run_hcp_sdc_math_trial_100206.m](../examples/run_hcp_sdc_math_trial_100206.m)       | 只将math事件行设为目标的LSA/LSS例，story仍参与设计，用于验证目标筛选。                          | 先复制改路径/新输出目录；不原样启动 |
| [run_hcp_sdc_single_trial_100206.m](../examples/run_hcp_sdc_single_trial_100206.m)   | 100206 LR逐输入事件行的早期LSA/LSS例；story区块与math事件段粒度不同，不代表词或句子。              | 先复制改路径/新输出目录；不原样启动 |
| [validate_glm_engineering.m](../examples/validate_glm_engineering.m)                 | 历史HCP LANGUAGE LR条件GLM脚本，不是自生成合成数据；读取本机HCP/衍生来源，空间与组织限制保留。           | 先复制改路径/新输出目录；不原样启动 |
| [validate_glm_group_engineering.m](../examples/validate_glm_group_engineering.m)     | 生成12个合成人、两组和数值变量，运行5种二级场景，并对每个有效体素的22个T对比独立OLS复核。                    | 可复制改实验设置；输出放包外新目录  |
| [validate_glm_outputs_engineering.m](../examples/validate_glm_outputs_engineering.m) | 合成贯通例：组模型、LSA/LSS、GLMsingle来源→阈值导出、统一beta和ROI；可用reuse复用成功来源。         | 可复制改实验设置；输出放包外新目录  |
| [validate_glm_release.m](../examples/validate_glm_release.m)                         | 便携全合成验收入口：调用贯通例、补条件run/subject模型、检查函数来源/包哈希、逐行回读80个beta；只向包外新目录写结果。  | 可复制改实验设置；输出放包外新目录  |
| [validate_glmsingle_engineering.m](../examples/validate_glmsingle_engineering.m)     | 生成2run、8个重复身份的合成BOLD和真值，真实调用官方A/B/C/D；mixed/slow噪声选项便于检查去噪。          | 可复制改实验设置；输出放包外新目录  |

四个合成函数的参数形式分别为`validate_glm_release(outputRoot,spmPath)`、`validate_glm_outputs_engineering(outputRoot,reuse)`、`validate_glm_group_engineering(outputRoot)`和`validate_glmsingle_engineering(outputRoot,noiseProfile)`。`reuse`用于复用相应成功来源，`noiseProfile`为`mixed`或`slow`；完整说明见各文件开头。使用前将`examples`加入MATLAB路径并准备可用SPM。三个`run_hcp_sdc_*`文件是函数；`validate_glm_engineering.m`是历史脚本。这些都是可选入口，正常分析优先走统一配置和`run_glm`。

## 5. matlab/+psy：44个文件

`+psy`是MATLAB命名空间，例如`glm_batch.m`通过`psy.glm_batch`调用。下列函数由启动入口自动调度，**不要逐个按Run**；高级使用者可以按函数签名传完整参数调用。普通方法选择在总配置中完成，开发改算法后才需要修改这里。

| 文件                                                                  | 内容与用途                                                                                   | 哪些可以改            |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------- |
| [confound_design.m](../matlab/+psy/confound_design.m)               | 从逐帧混杂表选择头动/组织/趋势/FD指示列、中心化缩放并算秩；只构建设计，不滤波或回归影像。                                         | 普通使用保持；开发改算法后须验证 |
| [discover_hcp.m](../matlab/+psy/discover_hcp.m)                     | HCP专用目录发现适配，只识别约定的原始unprocessed布局；不替代通用GLM清单或预处理计算。                                     | 普通使用保持；开发改算法后须验证 |
| [file_sha256.m](../matlab/+psy/file_sha256.m)                       | 流式读取文件计算SHA256，适合大影像，不把整幅文件一次装入内存。                                                      | 普通使用保持；开发改算法后须验证 |
| [glm_absolute_path.m](../matlab/+psy/glm_absolute_path.m)           | 将相对路径按MATLAB目录/指定基准展开成规范绝对路径，避免Java工作目录与MATLAB pwd不一致。                                  | 普通使用保持；开发改算法后须验证 |
| [glm_basis.m](../matlab/+psy/glm_basis.m)                           | 把canonical、两类导数和FIR选项转换为SPM原生基函数设置；不提供任意HRF透传。                                          | 普通使用保持；开发改算法后须验证 |
| [glm_batch.m](../matlab/+psy/glm_batch.m)                           | 总分发：有model分支走新框架，否则保留早期逐run条件流程。                                                        | 普通使用保持；开发改算法后须验证 |
| [glm_beta_catalog.m](../matlab/+psy/glm_beta_catalog.m)             | 将framework、旧single_trial、GLMsingle来源变成统一beta目录及事件链接，核对完成标记、目标、实际SPM列和第四轴映射。             | 普通使用保持；开发改算法后须验证 |
| [glm_beta_read.m](../matlab/+psy/glm_beta_read.m)                   | 按目录读 `[估计单元×共同掩膜体素]` single矩阵并保存空间坐标约定；不平均、重采样或统一方法尺度。                                  | 普通使用保持；开发改算法后须验证 |
| [glm_contrast_table.m](../matlab/+psy/glm_contrast_table.m)         | 把对比名称、T/F类型、编号和效应/统计图路径写成明确目录；准备与已估计分开。                                                 | 普通使用保持；开发改算法后须验证 |
| [glm_contrasts.m](../matlab/+psy/glm_contrasts.m)                   | 按SPM真实列名，把条件权重放到正确canonical/bin列上，并检查对比可估性；跨run匹配列自动平均。                                 | 普通使用保持；开发改算法后须验证 |
| [glm_diagnostics.m](../matlab/+psy/glm_diagnostics.m)               | 记录高通后设计、列相关和保留能量，并在确定性体素样本上检查残差自相关；可绘图，不作显著性判定。                                         | 普通使用保持；开发改算法后须验证 |
| [glm_events.m](../matlab/+psy/glm_events.m)                         | 早期条件模型的事件适配，确保条件完整，不静默丢未知条件或把幅度列当成单位事件。                                                 | 普通使用保持；开发改算法后须验证 |
| [glm_file_inventory.m](../matlab/+psy/glm_file_inventory.m)         | 对输入路径去重后记录绝对路径、实际字节和SHA256，用于前后只读核对。                                                    | 普通使用保持；开发改算法后须验证 |
| [glm_framework_batch.m](../matlab/+psy/glm_framework_batch.m)       | 读通用run清单、核对ID/重复/路径，按run或subject调度，记录批次状态；group转交组模块，GLMsingle转相应后端。                    | 普通使用保持；开发改算法后须验证 |
| [glm_framework_options.m](../matlab/+psy/glm_framework_options.m)   | 创建输出前核对完整字段、枚举值和合法组合，拒绝未实现的组合，不静默改方法。                                                   | 普通使用保持；开发改算法后须验证 |
| [glm_framework_plan.m](../matlab/+psy/glm_framework_plan.m)         | 读取事件并按condition/event/trial/item等生成单元、目标和模型计划；不估计影像、不改原表。                               | 普通使用保持；开发改算法后须验证 |
| [glm_framework_run.m](../matlab/+psy/glm_framework_run.m)           | 对一个run落实单元计划：保存事件/单元映射，逐模型调用SPM计算层，并记录目标canonical beta路径。                               | 普通使用保持；开发改算法后须验证 |
| [glm_group_batch.m](../matlab/+psy/glm_group_batch.m)               | 执行二级设计：保存交集覆盖、配对差值、SPM作业、正负T及输入哈希，并核对计划与实际设计一致。                                         | 普通使用保持；开发改算法后须验证 |
| [glm_group_plan.m](../matlab/+psy/glm_group_plan.m)                 | 读取组清单，按ID配对/分组、读取协变量，构建并审计独立设计；先检查人数、队列、秩，不执行SPM。                                       | 普通使用保持；开发改算法后须验证 |
| [glm_highpass_rank.m](../matlab/+psy/glm_highpass_rank.m)           | 计算各run高通基的总秩，供残差维度检查，避免将多个run拼成一条时间序列误算。                                                | 普通使用保持；开发改算法后须验证 |
| [glm_model_contrasts.m](../matlab/+psy/glm_model_contrasts.m)       | 生成完整对比目录：普通T、pmod斜率T、FIR逐bin/窗口T和整体F；检查名字冲突。                                            | 普通使用保持；开发改算法后须验证 |
| [glm_outputs_options.m](../matlab/+psy/glm_outputs_options.m)       | 检查独立后处理配置的模式、阈值、方向、ROI、矩阵预算等合法值。                                                        | 普通使用保持；开发改算法后须验证 |
| [glm_pmod.m](../matlab/+psy/glm_pmod.m)                             | 从事件数值列取调节量，按配置中心化/尺度处理并生成SPM pmod结构和审计表。                                                | 普通使用保持；开发改算法后须验证 |
| [glm_read_table.m](../matlab/+psy/glm_read_table.m)                 | 按文本读TSV，保留ID前导零与空字段，核对列集合；数值类型由调用层明确转换。                                                 | 普通使用保持；开发改算法后须验证 |
| [glm_results_export.m](../matlab/+psy/glm_results_export.m)         | 只读既有SPM T/F模型，转换完整搜索域的概率/阈值/簇，保存图、表及输入哈希；不调用会改写源模型的结果入口。                                | 普通使用保持；开发改算法后须验证 |
| [glm_results_plot.m](../matlab/+psy/glm_results_plot.m)             | 绘制I/J/K三切面PNG，按affine采样背景；空结果也说明，不做配准或自动世界轴重定向。                                         | 普通使用保持；开发改算法后须验证 |
| [glm_roi_extract.m](../matlab/+psy/glm_roi_extract.m)               | 对统一固定体素集合按二值ROI/标签求等权均值、空间标准差和体素数；不足覆盖按nan/error策略记录。                                   | 普通使用保持；开发改算法后须验证 |
| [glm_run.m](../matlab/+psy/glm_run.m)                               | SPM一级计算内核：检查BOLD/TR/几何/混杂/掩膜，指定、估计、建立T/F对比并做诊断。可接收一个run或同一人的多个run；多个run分别建SPM session。  | 普通使用保持；开发改算法后须验证 |
| [glm_subject_run.m](../matlab/+psy/glm_subject_run.m)               | 同一人跨run的组织层：核对身份/session，逐run生成计划，再把runs交给glm_run联合建模；保存run映射和等权效应交接表subject_contrasts。 | 普通使用保持；开发改算法后须验证 |
| [glm_threshold.m](../matlab/+psy/glm_threshold.m)                   | 计算T/F尾概率、单对比BH-FDR或SPM原生高度FWE阈值；处理T正负/双侧，不做簇水平推断。                                       | 普通使用保持；开发改算法后须验证 |
| [glm_write_json.m](../matlab/+psy/glm_write_json.m)                 | 在新结果目录写UTF-8 JSON记录；不是用户文档编辑器，也不改写源SPM模型。                                               | 普通使用保持；开发改算法后须验证 |
| [glmsingle_dependency.m](../matlab/+psy/glmsingle_dependency.m)     | 核对官方固定提交、来源记录及依赖文件哈希，临时准备所需MATLAB路径。                                                    | 普通使用保持；开发改算法后须验证 |
| [glmsingle_design_check.m](../matlab/+psy/glmsingle_design_check.m) | 对每run、每个候选HRF建立逐事件设计，联合混杂/多项式核对可估性及PC上限所需维度。                                            | 普通使用保持；开发改算法后须验证 |
| [glmsingle_export.m](../matlab/+psy/glmsingle_export.m)             | 保存官方模型及R²/HRF/PC/ridge等图，写逐事件4D beta、帧映射、单位与诊断；逐帧回读核对，不伪造SPM.mat/T。                     | 普通使用保持；开发改算法后须验证 |
| [glmsingle_options.m](../matlab/+psy/glmsingle_options.m)           | 验证本适配层开放的GLMsingle字段、候选比例、开关、整数/内存/时间限制；不允许任意原生参数透传。                                    | 普通使用保持；开发改算法后须验证 |
| [glmsingle_plan.m](../matlab/+psy/glmsingle_plan.m)                 | 事件转TR二值设计，检查重复身份、共同正时长、对齐/碰撞/尾部，建立按run与时间排序的beta索引，收集全部阻断原因。                            | 普通使用保持；开发改算法后须验证 |
| [glmsingle_run.m](../matlab/+psy/glmsingle_run.m)                   | 检查各run、读有效掩膜内正基线原时序、准备原生选项，调用官方估计，再核对实际步骤/顺序并导出完成记录。                                    | 普通使用保持；开发改算法后须验证 |
| [read_events_tsv.m](../matlab/+psy/read_events_tsv.m)               | 通用秒制事件读取，保留原onset/duration，核对字段/时间，报告尾部超出，不自动裁剪或平移。                                     | 普通使用保持；开发改算法后须验证 |
| [read_hcp_events.m](../matlab/+psy/read_hcp_events.m)               | 读取HCP EV的onset/duration/amplitude列并按显式条件组织，不静默删幅度、平移、裁尾或拼run。                           | 普通使用保持；开发改算法后须验证 |
| [run_output_dir.m](../matlab/+psy/run_output_dir.m)                 | 按subject/session/run构造输出目录，避免不同人或访视的同名run混在一起。                                          | 普通使用保持；开发改算法后须验证 |
| [single_trial_batch.m](../matlab/+psy/single_trial_batch.m)         | 早期LSA/LSS的清单读取和逐run调度、失败记录，服务旧启动器。                                                      | 普通使用保持；开发改算法后须验证 |
| [single_trial_run.m](../matlab/+psy/single_trial_run.m)             | 早期逐事件LSA一个联合模型、LSS每目标一个模型的实际组织，保留时长和非目标事件。                                              | 普通使用保持；开发改算法后须验证 |
| [spm_step.m](../matlab/+psy/spm_step.m)                             | 执行一个SPM batch前先保存精确matlabbatch，方便复核究竟传了什么作业。                                            | 普通使用保持；开发改算法后须验证 |
| [verify_glm.m](../matlab/+psy/verify_glm.m)                         | 读模型输出，检查mask、beta、残差方差、全部T/F效应/统计文件的存在、几何和掩膜内数值完整性。                                     | 普通使用保持；开发改算法后须验证 |

`glm_diagnostics.m`、`verify_glm.m`、`file_sha256.m`等是正常运行需要的质量检查/文件核查代码，不是可随意移走的调试记录。`glm_subject_run`负责同一人的跨run组织与交接，`glm_run`承担实际SPM一级计算，两者协作。

## 6. tests：10个文件

这些是测试源码，不是测试结果或运行日志。修改代码、迁移环境后可用MATLAB的`runtests`执行；正常处理自己的数据不必逐个运行。部分测试会真实调用SPM/GLMsingle并在临时目录生成结果。测试文件存在不等于当前环境已通过，也不表示所有参数组合都经过真实数据验证。

| 文件                                                              | 内容与用途                                                       | 哪些可以改            | 是否需要手动运行            |
| --------------------------------------------------------------- | ----------------------------------------------------------- | ---------------- | ------------------- |
| [test_glm.m](../tests/test_glm.m)                               | 传统条件对比列映射、未知事件条件拒绝、预回归残差输入保护等基础行为。                          | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glm_framework.m](../tests/test_glm_framework.m)           | 单元分组、真实ID/重复刺激、时长表达、目标保留、两种LSS、掩膜/批次隔离、SPM实际系数与HRF导数/诊断。    | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glm_group_extended.m](../tests/test_glm_group_extended.m) | ID配对/缺失/重复、方向、非平衡等方差两组、回归/调整模型、中心化、共线和相对路径等9项检查。            | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glm_multilevel.m](../tests/test_glm_multilevel.m)         | 多run条件设计、被试身份/几何/队列检查、等权对比及早期单样本组统计。                        | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glm_outputs.m](../tests/test_glm_outputs.m)               | T/F概率近零/远尾、FWE/BH、双侧符号簇、坐标/空结果、三种beta适配、矩阵/ROI及篡改/覆盖拒绝等16项。 | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glm_pmod_fir.m](../tests/test_glm_pmod_fir.m)             | pmod中心化/尺度/正交设置、FIR时间格点、T/F对比、可估性及不合法组合拒绝。                  | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glmsingle.m](../tests/test_glmsingle.m)                   | 时间/身份映射、阻断不降级、实际官方A/B/C/D、候选/掩膜/内存/非有限输入、固定依赖篡改拒绝及批次保护。     | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_glmsingle_demo.m](../tests/test_glmsingle_demo.m)         | 教学事件副本、舍入/尾部排除/原索引、掩膜抽样和专用启动器，避免近似行为改写原输入。                  | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_single_trial.m](../tests/test_single_trial.m)             | 旧LSA/LSS多被试/session隔离、两种干扰策略、目标筛选及非法配置。                     | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |
| [test_verify_glm.m](../tests/test_verify_glm.m)                 | 有效SPM输出通过，掩膜内非有限效应被拒绝；只检查输出完整性。                             | 开发维护时可改；不是个人分析参数 | 仅测试时用runtests；非日常步骤 |

## 7. scripts：2个文件

这两份属于包维护和发布，不参与数据估计。正式发布应从开发工作区运行脚本，包内副本不能当成面向使用者的分析入口。

| 文件                                                    | 内容与用途                                                                 | 哪些可以改           | 是否需要手动运行               |
| ----------------------------------------------------- | --------------------------------------------------------------------- | --------------- | ---------------------- |
| [release_layout.json](../scripts/release_layout.json) | 发布边界元数据：GLM专用、两包共享及已停用的路径；两个发布脚本据此确定复制范围，不参与模型估计。                     | 发布维护时可改；不作为分析参数 | 否；由发布脚本读取              |
| [sync_glm_copy.ps1](../scripts/sync_glm_copy.ps1)     | 从开发工作区定向发布到D:\GLM，保护未授权文档和定稿配置，备份替换项并重建实际文件哈希清单。仅供维护发布，不是分析启动器或自动更新器。 | 发布维护时可改；普通分析保持  | 仅维护者从开发工作区调用；不在包中直接Run |

## 8. external/glmsingle：88个固定依赖文件

这里是官方GLMsingle及fracridge的固定版本。适配层会检查来源提交与依赖哈希；普通使用保持完整，不单独改函数、裁剪看似不用的文件或重写哈希记录。若要升级依赖，需要整体重新适配和验证。下面逐个解释文件，但其中的滤波、绘图、相关计算等工具并不都作为本工具包的独立功能开放。

### 8.1 版本、许可和算法：8个文件

| 文件                                                                                           | 内容与用途                                                                        | 哪些可以改            | 是否需要手动运行           |
| -------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ---------------- | ------------------ |
| [DEPENDENCY_MANIFEST.json](../external/glmsingle/DEPENDENCY_MANIFEST.json)                   | 固定依赖文件的相对路径/哈希，本适配层启动前核对，发现被改动即拒绝。                                           | 固定版本/哈希记录，勿手改    | 否；适配层自动核对          |
| [LICENSE](../external/glmsingle/LICENSE)                                                     | GLMsingle BSD 3-Clause许可及版权条件，分发时保留。                                         | 保留版权和许可原文，勿改删    | 否；许可证              |
| [LICENSE](../external/glmsingle/matlab/fracridge/LICENSE)                                    | fractional ridge独立依赖的版权与再分发条件。                                               | 保留版权和许可原文，勿改删    | 否；许可证              |
| [fracridge.m](../external/glmsingle/matlab/fracridge/matlab/fracridge.m)                     | fractional ridge数值求解器，沿候选fraction计算回归系数与相关参数，不是整个fMRI管线。                     | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [interp1qr.m](../external/glmsingle/matlab/fracridge/matlab/interp1qr.m)                     | fracridge使用的快速一维线性插值，按已知点插算中间值，越界返回NaN。                                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [interp1qr_license.txt](../external/glmsingle/matlab/fracridge/matlab/interp1qr_license.txt) | 上述插值代码自身的许可证，和主包许可证一起保留。                                                     | 保留版权和许可原文，勿改删    | 否；许可证              |
| [GLMestimatesingletrial.m](../external/glmsingle/matlab/GLMestimatesingletrial.m)            | 官方逐事件估计主入口，组织HRF选择、GLMdenoise及ridge的A/B/C/D。我们的glmsingle_run负责输入/约束/安全调用/导出。 | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [SOURCE.json](../external/glmsingle/SOURCE.json)                                             | 官方仓库、固定提交、下载压缩包哈希及fracridge来源；用于确定版本出处，不记录个人分析输入。                            | 固定版本/哈希记录，勿手改    | 否；适配层自动核对          |

### 8.2 matlab/utilities：80个文件

| 文件                                                                                                | 内容与用途                                                              | 哪些可以改            | 是否需要手动运行           |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------- | ------------------ |
| [absolutepath.m](../external/glmsingle/matlab/utilities/absolutepath.m)                           | 把相对地址转换为绝对地址的官方辅助函数；与本包psy.glm_absolute_path不是同一文件。                | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [axissquarify.m](../external/glmsingle/matlab/utilities/axissquarify.m)                           | 调整图的坐标轴为等比例方形、围绕原点，可加y=x参考线。                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [calccod.m](../external/glmsingle/matlab/utilities/calccod.m)                                     | 按预测与数据计算解释方差/拟合优度，输出百分数；支持均值/增益等选项，不是显著性p值。                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [calccodcell.m](../external/glmsingle/matlab/utilities/calccodcell.m)                             | 对分成多个cell的数据块计算类似拟合优度，减少大数组拼接。                                     | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [calccorrelation.m](../external/glmsingle/matlab/utilities/calccorrelation.m)                     | 沿指定维度计算相关系数，可选择是否先减均值等；属于内部数值辅助，不是本包已实现的FC分析入口。                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [calccpfov1D.m](../external/glmsingle/matlab/utilities/calccpfov1D.m)                             | 生成一维FFT对应的频率坐标，可用每视野周期数或角频率表示。                                     | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [calczscore.m](../external/glmsingle/matlab/utilities/calczscore.m)                               | 沿维度或整体减均值除标准差，返回z分数及均值/标准差，含NaN处理。                                 | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [catcell.m](../external/glmsingle/matlab/utilities/catcell.m)                                     | 把cell中的数组按指定维度拼接，供分块计算组织数据。                                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [cell2str.m](../external/glmsingle/matlab/utilities/cell2str.m)                                   | 将含数值/文本的二维cell转为可表达它的字符串，供官方记录/辅助使用。                               | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [choose.m](../external/glmsingle/matlab/utilities/choose.m)                                       | 简单条件选择：条件真返回yes，假返回no。                                             | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [chunking.m](../external/glmsingle/matlab/utilities/chunking.m)                                   | 把索引或向量分成指定长度的批块，最后一块可较短。                                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [cmaplookup.m](../external/glmsingle/matlab/utilities/cmaplookup.m)                               | 按数值范围查颜色表，把数值阵列转为RGB颜色。                                            | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [cmapsign.m](../external/glmsingle/matlab/utilities/cmapsign.m)                                   | 生成蓝—黑—红发散色表，适于带正负的数值。                                              | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [cmapsign2.m](../external/glmsingle/matlab/utilities/cmapsign2.m)                                 | 生成蓝—白—红发散色表。                                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [cmapsign4.m](../external/glmsingle/matlab/utilities/cmapsign4.m)                                 | 生成青—蓝—黑—红—黄色表。                                                     | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [cmapturbo.m](../external/glmsingle/matlab/utilities/cmapturbo.m)                                 | 生成turbo连续色表，供官方绘图使用。                                               | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [constructbutterfilter1D.m](../external/glmsingle/matlab/utilities/constructbutterfilter1D.m)     | 构造一维Butterworth滤波器形状，是官方底层工具；不等于当前接口允许另加任意滤波步骤。                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [constructpolynomialmatrix.m](../external/glmsingle/matlab/utilities/constructpolynomialmatrix.m) | 生成逐阶正交、单位长度的多项式列，用于run内慢漂移建模。                                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [constructstimulusmatrices.m](../external/glmsingle/matlab/utilities/constructstimulusmatrices.m) | 将刺激序列展开成包含前后滞后的设计矩阵，供官方FIR等内部计算。                                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [copymatrix.m](../external/glmsingle/matlab/utilities/copymatrix.m)                               | 复制矩阵并在指定索引位置赋值，方便内部构建设计或掩膜。                                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [deconvolvevectors.m](../external/glmsingle/matlab/utilities/deconvolvevectors.m)                 | 对已卷积向量进行反卷积的数值辅助，不是独立的研究任务反卷积管线。                                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [errorbar2.m](../external/glmsingle/matlab/utilities/errorbar2.m)                                 | 画上下或左右误差条，可表达不对称误差。                                                | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [figureprep.m](../external/glmsingle/matlab/utilities/figureprep.m)                               | 创建/准备通常不可见的绘图窗口，设置位置和hold状态。                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [figurewrite.m](../external/glmsingle/matlab/utilities/figurewrite.m)                             | 按官方图形命名与格式保存图，调用底层导出工具。                                            | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [filterout.m](../external/glmsingle/matlab/utilities/filterout.m)                                 | 按指定值或大小比较筛除数组元素，返回保留值和索引。                                          | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [findtailthreshold.m](../external/glmsingle/matlab/utilities/findtailthreshold.m)                 | 对数值分布拟合双高斯混合并寻找尾部阈值；GLMsingle自动R²阈值涉及它，需要fitgmdist。                | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [flatten.m](../external/glmsingle/matlab/utilities/flatten.m)                                     | 把数组展开为一个行向量。                                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [fouriertospace1D.m](../external/glmsingle/matlab/utilities/fouriertospace1D.m)                   | 把频率域幅度滤波器转换成指定长度的时间/空间域一维滤波核。                                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [getcanonicalhrf.m](../external/glmsingle/matlab/utilities/getcanonicalhrf.m)                     | 给定刺激持续时间和TR，产生GLMsingle假定的标准HRF。                                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [getcanonicalhrflibrary.m](../external/glmsingle/matlab/utilities/getcanonicalhrflibrary.m)       | 按持续时间/TR生成候选HRF库，使用旁边TSV内的官方形状。                                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [getcanonicalhrflibrary.tsv](../external/glmsingle/matlab/utilities/getcanonicalhrflibrary.tsv)   | 官方候选HRF的数值采样表；不是任务事件表或真实被试时序，不需填写。                                 | 固定HRF库，勿改成个人数据   | 否；官方库函数读取          |
| [getfigurepos.m](../external/glmsingle/matlab/utilities/getfigurepos.m)                           | 读取绘图窗口位置/尺寸并转换指定单位。                                                | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [GLMestimatemodel.m](../external/glmsingle/matlab/utilities/GLMestimatemodel.m)                   | 官方通用GLM模型拟合内核，处理设计、HRF、重采样/估计等底层步骤，被主算法调用。                         | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [GLMpredictresponses.m](../external/glmsingle/matlab/utilities/GLMpredictresponses.m)             | 根据已估计模型和设计预测响应时间序列，用于拟合/交叉验证评估。                                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [imageactual.m](../external/glmsingle/matlab/utilities/imageactual.m)                             | 按图像原始像素大小显示，避免绘图时缩放。                                               | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [isint.m](../external/glmsingle/matlab/utilities/isint.m)                                         | 判断每个数是否有限且恰为整数，返回逻辑值。                                              | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [isrowvector.m](../external/glmsingle/matlab/utilities/isrowvector.m)                             | 判断输入是否为单行向量。                                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [linspacecircular.m](../external/glmsingle/matlab/utilities/linspacecircular.m)                   | 在循环区间生成等间距点，终点视为起点因此不重复包含终点。                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [linspacefixeddiff.m](../external/glmsingle/matlab/utilities/linspacefixeddiff.m)                 | 从起点按固定步长生成指定数量的点。                                                  | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [makeimagestack.m](../external/glmsingle/matlab/utilities/makeimagestack.m)                       | 把多张二维图整理为拼图，可指定归一化、边框与排布。                                          | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [matchfiles.m](../external/glmsingle/matlab/utilities/matchfiles.m)                               | 按路径模式匹配文件并排序的官方辅助函数；不是HCP数据发现规则。                                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [matrixindex.m](../external/glmsingle/matlab/utilities/matrixindex.m)                             | 对矩阵某一维按每个位置给定的索引取值，例如从候选结果中选最佳项。                                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [mkdirquiet.m](../external/glmsingle/matlab/utilities/mkdirquiet.m)                               | 创建目录并抑制“已存在”等提示，属于官方文件系统工具。                                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [mod2.m](../external/glmsingle/matlab/utilities/mod2.m)                                           | 取模但将余数0改为除数，便于从1开始的循环索引。                                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [mtimescell.m](../external/glmsingle/matlab/utilities/mtimescell.m)                               | 计算矩阵与多个纵向分块数组的乘积，减少直接拼接所需内存。                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [nanreplace.m](../external/glmsingle/matlab/utilities/nanreplace.m)                               | 官方数组NaN/非有限值替换工具；其存在不代表本包在有效beta矩阵里自动补零。                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [normalizemax.m](../external/glmsingle/matlab/utilities/normalizemax.m)                           | 按指定维度或全局最大值缩放数组。                                                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [normalizerange.m](../external/glmsingle/matlab/utilities/normalizerange.m)                       | 把源数值范围线性映射到目标范围，可选择截断等行为。                                          | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [olsmatrix.m](../external/glmsingle/matlab/utilities/olsmatrix.m)                                 | 生成普通最小二乘回归所需的矩阵算子，包含列范数等数值处理选项。                                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [olsmatrix2.m](../external/glmsingle/matlab/utilities/olsmatrix2.m)                               | 另一套普通/带lambda的ridge回归矩阵算子，不等于fraction参数化主求解器。                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [permutedim.m](../external/glmsingle/matlab/utilities/permutedim.m)                               | 按指定维度或全局打乱数组次序，可返回实际排列。                                            | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [picksubset.m](../external/glmsingle/matlab/utilities/picksubset.m)                               | 按数量/分组与随机种子选择子集，可同时返回其余部分。                                         | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [placematrix.m](../external/glmsingle/matlab/utilities/placematrix.m)                             | 把小矩阵按位置放进大矩阵，适合拼图等数组组织。                                            | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [printnice.m](../external/glmsingle/matlab/utilities/printnice.m)                                 | 按官方预设格式与分辨率导出绘图窗口。                                                 | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [processmulti1D.m](../external/glmsingle/matlab/utilities/processmulti1D.m)                       | 将一个处理单条行向量的函数依次应用于多条序列。                                            | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [projectionmatrix.m](../external/glmsingle/matlab/utilities/projectionmatrix.m)                   | 构造去掉给定设计可解释成分的投影矩阵，供内部回归运算。                                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [resamplingindices.m](../external/glmsingle/matlab/utilities/resamplingindices.m)                 | 生成在起止索引间按目标数量/倍率重新采样的索引坐标。                                         | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [reshape2D.m](../external/glmsingle/matlab/utilities/reshape2D.m)                                 | 将指定维度移到前面，再把数组变成二维，方便矩阵计算。                                         | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [reshape2D_undo.m](../external/glmsingle/matlab/utilities/reshape2D_undo.m)                       | 按原尺寸/维度信息撤销reshape2D，恢复数组布局。                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [rmdirquiet.m](../external/glmsingle/matlab/utilities/rmdirquiet.m)                               | 官方安静删除目录工具。当前适配调用关闭原生文件输出并使用NaN输出目录，避免主函数清空已有目录；此文件不是本包清理用户数据的启动器。 | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [robustrange.m](../external/glmsingle/matlab/utilities/robustrange.m)                             | 给图示数据估计避开极端离群值的合理显示范围。                                             | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [scattersparse.m](../external/glmsingle/matlab/utilities/scattersparse.m)                         | 抽取较少点画散点图，减少大量点的绘图负担。                                              | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [setfigurepos.m](../external/glmsingle/matlab/utilities/setfigurepos.m)                           | 设置窗口的位置/大小，支持归一化位置或缩放倍数。                                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [setrandstate.m](../external/glmsingle/matlab/utilities/setrandstate.m)                           | 官方随机状态设置工具，可固定或按时间选种子；本包另通过cfg记录并恢复自己的随机状态。                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [signedarraypower.m](../external/glmsingle/matlab/utilities/signedarraypower.m)                   | 计算sign(x)乘abs(x)的指定次幂，保留正负号。                                       | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [sizefull.m](../external/glmsingle/matlab/utilities/sizefull.m)                                   | 按指定维度数返回完整尺寸向量，补齐必要的末尾单例维。                                         | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [splitmatrix.m](../external/glmsingle/matlab/utilities/splitmatrix.m)                             | 按给定维度与分段长度拆分矩阵。                                                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [squish.m](../external/glmsingle/matlab/utilities/squish.m)                                       | 将数组前若干维压成一维，用于体素维与时间维转换。                                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [statusdots.m](../external/glmsingle/matlab/utilities/statusdots.m)                               | 按当前进度打印点号提示，不是结果文件或统计检验。                                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [straightline.m](../external/glmsingle/matlab/utilities/straightline.m)                           | 在图中加水平或垂直参考线。                                                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [stripfile.m](../external/glmsingle/matlab/utilities/stripfile.m)                                 | 拆分路径的目录/文件部分，可按选项交换输出。                                             | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [subscript.m](../external/glmsingle/matlab/utilities/subscript.m)                                 | 按给定下标范围读取数组或指定变量的数据，支持多种索引表达。                                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [swap.m](../external/glmsingle/matlab/utilities/swap.m)                                           | 交换两个输入的输出顺序，是一个小型变量操作助手。                                           | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [tsfilter.m](../external/glmsingle/matlab/utilities/tsfilter.m)                                   | 给多条时间序列应用指定频域/时间域滤波器的官方底层函数；不表示本包预先滤波BOLD作为任务输入。                   | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [unitlength.m](../external/glmsingle/matlab/utilities/unitlength.m)                               | 将整体或指定维度的向量缩放到单位长度，并返回长度/比例等信息。                                    | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [unitlengthfast.m](../external/glmsingle/matlab/utilities/unitlengthfast.m)                       | 面向向量/二维矩阵的较精简单位长度归一化。                                              | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [vectorlength.m](../external/glmsingle/matlab/utilities/vectorlength.m)                           | 计算整体或沿维度的欧氏长度。                                                     | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [vflatten.m](../external/glmsingle/matlab/utilities/vflatten.m)                                   | 把数组展开为一个列向量，与flatten的行向量不同。                                        | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [zerodiv.m](../external/glmsingle/matlab/utilities/zerodiv.m)                                     | 带除零/特殊数值策略的数组相除工具。                                                 | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |
| [zeromean.m](../external/glmsingle/matlab/utilities/zeromean.m)                                   | 对整体或指定维度减去均值。                                                      | 固定第三方依赖，勿单独修改/裁剪 | 否；由GLMsingle内部按需调用 |

## 9. 沿文件找到输入与输出

统一估计的调用关系是`run_glm → glm_config → psy.glm_batch`。SPM一级run走框架计划和`glm_run`，跨run先经过`glm_subject_run`；二级走`glm_group_plan/glm_group_batch`。GLMsingle走本包`glmsingle_*`适配函数，再调用上面的固定第三方依赖。入口自动调用所需函数，不需要手动逐层启动。

后处理由`run_glm_outputs`读取`glm_outputs_config`或传入的`cfg`，统计图交给`glm_results_export/glm_threshold/glm_results_plot`，逐单元beta交给`glm_beta_catalog/glm_beta_read`，ROI提取交给`glm_roi_extract`。它读取既有模型，不重新估计源模型。

原始影像、预处理衍生数据、SPM安装和正式模型结果都放在包外；HCP只用于示例，不是运行通用工具包必须附带的数据。完成标记、输出文件含义、估计准备与实际完成的区别见[GUIDE](GUIDE.md)。不要按文件名序号猜beta对应的事件，应查生成的单元/事件/对比映射。

本页是当前目录说明，**不是删除清单**。已有备份、旧入口和示例照实标注；是否精简发布内容需要另行按依赖和使用目的决定。
