---
name: cogneuro-fmri
description: "用户明确调用并给出数据路径时，交互式扫描数据、确认目标/范式/参数、填写真实清单，并调用用户已安装的预处理、GLM和分析方法三个工具包的现成入口。分析计算与方法约束由原工具包承担。"
---

# 三个现成 fMRI 工具包的交互式调用向导

本版 0.5.0 接入用户已有工具包，强制参数准备状态问询、逐项审阅、真实确认记录，并从实际执行记录生成完整步骤/参数报告。原包算法、正式配置和用户文档保持原样；本skill管理项目专属配置和调用。不要重写分析算法或为接入而重跑各种方法。

## 先读安装包，再确定工作流

用户明确调用 `$cogneuro-fmri` 后，提取数据路径、三包安装位置和已有目标。缺少安装位置时询问或利用本次会话已知路径；不将开发机器的 D 盘写成安装默认值。用本地 Python 3.10+ 只读建立当前入口目录：

```text
python -X utf8 <skill>/scripts/toolkit_catalog.py --preprocessing-root <预处理包> --glm-root <GLM包> --function-root <分析包> --output <新的目录JSON>
```

按需只给已知包路径。阅读目录的 `counts`、`unmapped_entrypoints` 和候选方法；用 `--method <method_id>` 只展开所选入口的配置源码行、输入、模板列、实际选择项和原包说明。登记覆盖见 [interface-map.md](references/interface-map.md)，调用约定见 [toolkit-adapters.md](references/toolkit-adapters.md)。40 是登记接口数量，包含示例/开发校验，不是40种独立算法，也不代表每个入口已重新完成数值验证。

发现新入口或原包变更时，先读其原函数/配置/文档，补齐调用关系或解释接口差异，不改原包算法。原包已有方法由配置组合选择，尤其GLM的估计单元、HRF、fit、层级和后端；不能套用旧skill仅canonical/run/FC或无SDC的限制。HCP及GLMsingle示例须用户明确要求才选择；开发验证脚本不作为分析入口。

## 从路径和目标开始问答

在输入和工具包之外创建项目。扫描只读文件/元数据，不运行分析：

```text
python -X utf8 <skill>/scripts/fmri_project.py scan --data-root <数据路径> --project-dir <新项目>
```

阅读 `inventory.json` 的全部文件，不只看 BOLD/run 候选。矩阵、beta目录、RDM、行为、预测、组统计任务可能没有任何4D BOLD；不要因此要求重新预处理或阻塞。文件名/前缀只给候选，不能证明处理历史或模型已估计。

按 [workflow-spec.md](references/workflow-spec.md) 分轮确认目标、范式、起止阶段、独立单位及身份对应。已有明确答案沿用，不把流程固定成三包全部顺序执行。

用户未说明参数是否改好时，必须主动询问“已经修改、尚未修改、部分修改”，并记录涉及文件及真实回复来源。优先使用当前客户端可用的交互问答工具；没有该工具时在聊天中询问并等待回复。未回答只能继续只读盘点，不能代选答案。系统运行权限框不能代替研究参数确认。

- 已经修改：仍须读取当前.m及继承配置、相关.md，核对目标和数据，提出保留/修改/补充信息的建议；不擅自覆盖用户选择。
- 尚未修改：依据包内说明、当前源码和适用的权威资料，自动填写本项目所选步骤的全部适用参数；保留值也进入表格。
- 部分修改：先明确已改和待定部分，再分别复核/配置。

“本机当前值”不等于已证明的出厂默认值。参数建议须给出处与适用条件；用户未提供的采集事实、事件时间、CV分区、ROI、DCM网络不能从网上示例补造。参数审阅和完整报告的具体命令见 [parameter-review-and-report.md](references/parameter-review-and-report.md)。

默认使用 `route: toolkit_method` 和目录中的 `method_id`，例如 `glm.model`、`function.ppi_batch`、`function.dcm`、`function.searchlight`、`function.prediction`。读取所选原包说明，使用 [native-answers.example.json](assets/native-answers.example.json) 约定保存项目专属答案；由Codex填写，不要求用户手工维护JSON。所有确认记录保留真实 `source`。

```text
python -X utf8 <skill>/scripts/fmri_project.py plan --project-dir <项目> --answers <项目答案JSON>
python -X utf8 <skill>/scripts/fmri_project.py status --project-dir <项目>
```

`inputs` 可以引用现成文件，也可以按当前安装模板提供带来源的行，由skill生成项目内TSV。缺失引用文件和未确认单元格会形成问题。不要复制模板示例行作为实验数据。真实事件/行为日志可在明确列、单位、时间零点和条件映射后转换为项目副本；缺少真实时间则追问，不生成虚构试次。MAT内变量/字段按原包契约检查，可用本机MATLAB读取必要元信息；不要把仅文件存在的检查说成模型或内部数据已经有效。

## 配置、准备与确认调用

读取当前配置、继承配置和所选方法.md，保存用户的`parameter_setup`状态。`native_config`含`config_hashes`、`native_execute`、`overrides`；其中confirmed只表示选择及来源已明确，不是最终执行许可。哈希取实际读取结果。覆盖仅在项目配置和内存生效，不改原包正式.m，不运行会重新加载默认cfg的包装脚本。

`native_execute` 保留原包execute开关语义：true执行原包所选计算，false调用原包的准备/检查分支。没有该开关的入口不可伪装成安全的原生预检；skill的prepare仍只检查配置，不调用它。

```text
python -X utf8 <skill>/scripts/fmri_project.py prepare --project-dir <项目> --matlab-executable <MATLAB程序> [--spm-root <所需SPM目录>]
```

prepare保存覆盖前配置和交给入口的有效配置，生成review及`parameter_assessment.template.json`；尚未获准分析。Codex按模板逐项填写适用性、单位、保留/修改理由和文档/源码/权威网络/用户/判断依据，再调用`assess-parameters`。它生成新的review摘要，不授予执行许可。缺失任一项评估会阻止进入最终确认。未选中的CAP/HMM等分支标记inactive并说明；路径和执行开关标记operational。缺依赖如实说明，不默换算法或安装。

展示实际入口、完整起止路线、输入、参数旧值/本次值/是否改动/单位/适用性/理由/依据、输出、缺项和检查范围。等待用户明确回复；用户提出修改则更新项目答案、plan新修订、prepare新尝试并重新评估，直至确认无误。不得把沉默或仅说明“已修改好参数”当作最终执行许可。

收到真实确认后先运行`approve`，记录原消息来源和原回复，再用它对应的最新摘要execute。普通研究actor为human；只有人类明确授权代答的模拟演示才允许delegated_demo，并记录授权来源，不能冒称人类逐项确认。该记录用于来源追踪，不是独立人类身份认证。

```text
python -X utf8 <skill>/scripts/fmri_project.py execute --project-dir <项目> --attempt-id <编号> --review-digest <已审阅摘要> --confirmation 确认执行
```

仅填写execute的确认短语不能绕过逐项评估和approve记录。明确批准的完整工作流只覆盖其中已决定且未变的参数、依赖顺序和产物规则；后续逐项比对一致后记录原授权来源，不重复询问同一选择。未被批准的参数、更改、缺项或冲突须重新询问。代码/配置/问答修订变化后旧摘要不能继续使用。

## 按真实产物交接，报告原包结果

每阶段使用该包的明确路径及独立MATLAB进程，避免两包共享 `+psy` 名称互相覆盖。研究输出放在项目新目录，保留原始输入和成功结果。检查原包真实返回/完成记录，再填下游清单；不能用猜测的前缀或尚不存在的文件装作产物。

常见链路：预处理→原生混杂/设计→GLM；GLM→原生结果/beta目录→ROI模式/Searchlight；已估计SPM→PPI，或原生私有VOI准备→任务DCM；静息ROI准备→谱DCM、动态连接或状态模型。谱DCM不强制经过任务GLM；矩阵预测/行为等直接从其原生数据入口起步。具体参数和文件结构读取原包文档，不在skill复刻计算。

先用`workflow`登记三包的execute/reuse/skip及原因和来源，把分阶段项目挂到同一工作流。各阶段成功或执行失败后自动生成版本化报告；登记的子阶段完成时自动更新父工作流报告。结束前运行`report`刷新汇总，并检查`latest_report.json`。若报告失败，只修复报告，不重跑成功分析。

向用户交付中文报告、steps.tsv、parameters.tsv及report.json，明确列出三包实际调用、原有结果复用、跳过原因、失败/重试、有效配置与差异、依据及确认来源、输入输出、软件信息、日志和检查局限。外部HCP既有处理不得算成本次执行。读取真实原生输出补充该方法的结果、图表与解释；不能编造未知结果。旧版项目可只读生成报告，缺少新版逐项审阅或确认的地方标为未记录，不补造。

用`execution-status`恢复，不重跑成功分析。complete不能替代模型诊断或科学质量；历史测试记录不作为每次分析必跑步骤。

旧版 `preprocess/preprocess_glm/glm/fc` 专用适配器保留兼容，其范围限制仅适用于旧路径；新研究优先使用现成入口目录，不能把旧四路白名单当作三个工具包的能力边界。
