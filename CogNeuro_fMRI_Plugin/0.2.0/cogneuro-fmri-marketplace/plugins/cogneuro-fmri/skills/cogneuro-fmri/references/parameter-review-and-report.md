# 参数准备、循环确认与完整报告（0.5.0）

这些命令由Codex执行；用户不必手工写JSON。所有数据事实、参数理由和确认来源必须真实。原工具包正式配置保留，只生成项目配置与内存覆盖。

## 必答的准备状态

在项目答案顶层加入：

```json
"parameter_setup": {
  "value": "not_started",
  "source": "用户在当前对话明确回复：尚未修改参数",
  "confirmed": true
}
```

value仅可为ready（已改）、not_started（未改）、partial（部分已改）。提问时使用易懂的中文选项，同时问涉及文件；未知时不填写示例值。用户一开始已说明则直接记录，避免重复问。

ready：读取实际配置/继承配置及相关.md后给出复核建议。not_started：Codex根据目标和资料填写全部适用参数。partial：识别已决定与未决定部分。三者都须经过完整参数表和最终确认。

本机值不证明是出厂默认；文档与代码不一致时如实说明。来源可为原包.md、当前源码、官方文档、研究论文、用户事实或明确标注的判断，不能虚构引用。网上协议不能证明某个本地run的采集参数。没有依据的数据事实继续追问。

## 生成与审阅

正常plan之后：

```text
python -X utf8 <skill>/scripts/fmri_project.py prepare --project-dir <项目> --matlab-executable <程序> [--spm-root <目录>]
```

使用返回的attempt_dir及review_digest，不猜目录名称。prepare不会调用通用原生分析入口。返回phase仍为awaiting_confirmation，但parameter_review_status为needs_assessment；此时execute不能运行。

读取attempt内的review.json及parameter_assessment.template.json。调用桥保存baseline_config（覆盖前本机值）、resolved_config（交给入口的有效值），包含继承配置；不能只检查显式override。复杂MAT参数以原生类型交给入口，原MAT及其来源仍需审查；JSON表格不是完整MATLAB类型镜像。

Codex将模板另存为项目评估JSON，填写summary及全部items。每项只能含：

```json
{
  "path": "clean.bandHz",
  "applicability": "active",
  "unit": "Hz",
  "reason": "根据本研究目标讨论后的选择；这里必须填写实际理由",
  "basis": [{"kind": "package_doc", "reference": "实际读过的文档路径及相关段落"}]
}
```

这只是结构示例，不是任何研究的参数建议。applicability为active（参与本次分析）、inactive（未选方法分支，说明不使用的原因）或operational（路径/执行开关等）。无物理单位时填写无量纲或路径等准确描述。basis.kind允许package_doc/source_code/official_web/paper/user/judgment；reference必须是实际来源或明确说明判断的适用前提。未修改值也要说明保留依据。不能在评估项中夹带新的参数值。

```text
python -X utf8 <skill>/scripts/fmri_project.py assess-parameters --project-dir <项目> --attempt-id <编号> --review-digest <prepare返回摘要> --assessment <评估JSON>
```

该命令核对每个配置叶字段，缺项/重复/无依据会被拒绝。成功后返回新的review_digest，parameter_review_status=assessed。展示review.md完整参数对照表；关键参数在聊天中解释，其余项可供展开/文件审阅。此命令仍不批准执行。

使用可用的问答工具询问“确认无误并执行 / 指出需修改项”，没有问答工具则聊天提问并等待回复。不要用系统权限框代替。用户要求修改值时更新answers，plan新revision，prepare新attempt，再填写评估与展示；旧确认不能用于新revision。保留之前的提案和失败记录。

## 记录真实确认并执行

只有用户明确确认展示的方案后：

```text
python -X utf8 <skill>/scripts/fmri_project.py approve --project-dir <项目> --attempt-id <编号> --review-digest <assess返回的新摘要> --source <真实用户回复来源> --reply <真实确认回复>
python -X utf8 <skill>/scripts/fmri_project.py execute --project-dir <项目> --attempt-id <编号> --review-digest <同一新摘要> --confirmation 确认执行
```

普通研究保持actor=human；来源和回复必须可追溯。完整工作流已有明确批准且本阶段科学参数逐项比对未变时，可以记录原授权回复及比对记录的来源；未覆盖的参数必须重新问。执行器验证记录与该review对应，不独立认证回复者身份或判断自然语言是否同意，Codex有责任如实记录。

只有用户明确要求自动代答演示时，approve可以使用`--actor delegated_demo --delegation-source <人类授权来源>`。它必须与人类亲自确认分开报告；一般的“帮我分析”不授权自行模拟确认。

## 登记完整工作流与生成报告

在各阶段只读项目建立后，为整个研究保存工作流JSON；覆盖三个包，未使用的写skip及原因，外部上游数据的复用写reuse并说明来源。不能把外部处理说成本次原生执行。结构：

```json
{
  "steps": [
    {"id":"pre","package":"preprocessing","action":"skip","reason":"本研究使用已处理输入","source":"实际输入与用户确认"},
    {"id":"glm","package":"glm","action":"skip","reason":"本目标不需要GLM","source":"用户确认的研究路线"},
    {"id":"analysis","package":"function","action":"execute","method_id":"实际所选method_id","project_dir":"实际阶段项目绝对路径","reason":"用户选择的终点","source":"方案确认消息"}
  ]
}
```

示例不是固定LEiDA路线。原始影像项目可以登记预处理、GLM及后续分析；同一包多个步骤各自登记。package允许preprocessing/glm/function/project，action为execute/reuse/skip；execute需实际阶段项目及method_id。开发验证入口不可作为研究步骤。

```text
python -X utf8 <skill>/scripts/fmri_project.py workflow --project-dir <总项目> --spec <工作流JSON>
python -X utf8 <skill>/scripts/fmri_project.py report --project-dir <总项目>
```

子项目执行成功或失败后自动生成自身报告，并更新已登记的父报告；最后再report汇总。报告各版本另存reports/0001等，latest_report.json指向最新版本。包含REPORT_ZH.md、report.json、steps.tsv、parameters.tsv。未登记完整工作流时仅报告已观察记录，不声称整项研究完成。

报告以review/state/receipt及原生返回为准，列出实际调用、复用、跳过、失败尝试、逐项有效值/差异/理由/来源/确认、软件信息、输入输出指纹、日志与检查局限。未捕获的软件版本或旧版参数确认标为未记录；不补造。预检失败可随时单独report。运行成功但报告生成失败时保留成功状态和产物，只修复报告。

通用报告负责过程和参数追溯。Codex还须读取真实方法输出，补充适用的结果摘要、图表、模型诊断和解释；不把工程complete等同全面科学质量通过，不因写报告重新分析。历史项目可report，不需要重新计算。
