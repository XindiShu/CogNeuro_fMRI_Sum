---
name: cogneuro-fmri
description: "用户明确调用并给出数据路径时，交互式扫描数据、确认目标/范式/参数、填写真实清单，并调用用户已安装的预处理、GLM和分析方法三个工具包的现成入口。分析计算与方法约束由原工具包承担。"
---

# 三个现成 fMRI 工具包的交互式调用向导

本版 0.4.0 的职责是接入用户已有工具包。原包的分析代码、正式配置和用户文档保持原样；本 skill 管理数据盘点、问题、项目配置、清单、依赖顺序、调用和结果交接。不要因 skill 尚未连接某入口就称该分析方法未实现，也不要为连接方法重写其算法或把每种分析重跑一遍作为前提。

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

按 [workflow-spec.md](references/workflow-spec.md) 分轮确认研究问题、实验范式、当前数据阶段、最终终点、独立实验单位以及被试/session/run/样本对应。已有明确答案沿用。根据实际输入提供适用的现成路线，用户选择后只问该路线缺项和关键参数。推荐参数时说明依据及适用条件；采集事实、事件时间、CV分区、ROI、DCM网络等不能用示例值补造。

默认使用 `route: toolkit_method` 和目录中的 `method_id`，例如 `glm.model`、`function.ppi_batch`、`function.dcm`、`function.searchlight`、`function.prediction`。读取所选原包说明，使用 [native-answers.example.json](assets/native-answers.example.json) 约定保存项目专属答案；由Codex填写，不要求用户手工维护JSON。所有确认记录保留真实 `source`。

```text
python -X utf8 <skill>/scripts/fmri_project.py plan --project-dir <项目> --answers <项目答案JSON>
python -X utf8 <skill>/scripts/fmri_project.py status --project-dir <项目>
```

`inputs` 可以引用现成文件，也可以按当前安装模板提供带来源的行，由skill生成项目内TSV。缺失引用文件和未确认单元格会形成问题。不要复制模板示例行作为实验数据。真实事件/行为日志可在明确列、单位、时间零点和条件映射后转换为项目副本；缺少真实时间则追问，不生成虚构试次。MAT内变量/字段按原包契约检查，可用本机MATLAB读取必要元信息；不要把仅文件存在的检查说成模型或内部数据已经有效。

## 配置、准备与确认调用

读取目录指向的当前配置及继承配置，向用户解释本研究相关参数。`native_config` 包含 `config_hashes`、`native_execute` 和 `overrides`，一起保存来源与确认。哈希取目录实际读取结果，不从示例填入。`overrides` 为 `{path,value}` 数组，只在内存覆盖原生已有字段；不改正式配置，不运行会重新加载默认cfg的包装脚本。

`native_execute` 保留原包execute开关语义：true执行原包所选计算，false调用原包的准备/检查分支。没有该开关的入口不可伪装成安全的原生预检；skill的prepare仍只检查配置，不调用它。

```text
python -X utf8 <skill>/scripts/fmri_project.py prepare --project-dir <项目> --matlab-executable <MATLAB程序> [--spm-root <所需SPM目录>]
```

通用入口的prepare只在隔离进程读取原配置、绑定项目表格/路径并生成 `review.md/review.json`，不运行任何原生分析入口，也不自动用execute=false重验方法。检查所选方法的真实依赖（如SPM、FSL/WSL、GIFT、BrainSpace、GLHMM、PCM、PyDDM）；缺什么说明什么，不默默换算法或自动安装。

展示实际方法/函数签名、纳入数据、范式/目标、科学参数/来源、原生execute语义、缺项/已检查范围、软件来源、输出目录及后续阶段。用户对此具体工作流明确确认后调用：

```text
python -X utf8 <skill>/scripts/fmri_project.py execute --project-dir <项目> --attempt-id <编号> --review-digest <已审阅摘要> --confirmation 确认执行
```

固定短语记录已获同意，不是自行批准。完整工作流的已有明确授权覆盖后续未变的参数、依赖顺序和产物选取规则时沿用；不为同一方案逐阶段重复确认。更改研究选择、意外缺项或来源冲突时暂停依赖阶段并询问。

## 按真实产物交接，报告原包结果

每阶段使用该包的明确路径及独立MATLAB进程，避免两包共享 `+psy` 名称互相覆盖。研究输出放在项目新目录，保留原始输入和成功结果。检查原包真实返回/完成记录，再填下游清单；不能用猜测的前缀或尚不存在的文件装作产物。

常见链路：预处理→原生混杂/设计→GLM；GLM→原生结果/beta目录→ROI模式/Searchlight；已估计SPM→PPI，或原生私有VOI准备→任务DCM；静息ROI准备→谱DCM、动态连接或状态模型。谱DCM不强制经过任务GLM；矩阵预测/行为等直接从其原生数据入口起步。具体参数和文件结构读取原包文档，不在skill复刻计算。

用 `execution-status` 恢复状态；失败/中断不自动重跑成功分析。`complete` 表示调用和产物记录完成，不能代替模型诊断或科研结论。报告应区分原包能力、skill映射/调用检查、实际执行结果和科学质量。历史合成分析测试记录留在VALIDATION.json中，不作为每次接入的必跑步骤。

旧版 `preprocess/preprocess_glm/glm/fc` 专用适配器保留兼容，其范围限制仅适用于旧路径；新研究优先使用现成入口目录，不能把旧四路白名单当作三个工具包的能力边界。
