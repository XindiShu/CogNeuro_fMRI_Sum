"""本地数据盘点、研究问答与三个现成工具包的接口调用。Python 3.10+。"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import sys

from inventory import scan_dataset

VERSION = "0.5.0"
ROUTES = {
    "toolkit_method": ("调用三个现成工具包中的方法", []),
    "preprocess": ("原始数据→所选预处理终点", ["preprocessing"]),
    "preprocess_glm": ("原始数据→预处理→条件 GLM", ["preprocessing", "glm"]),
    "glm": ("已有空间预处理数据→条件 GLM", ["glm"]),
    "fc": ("已有空间预处理数据→ROI FC", ["function"]),
    "ppi": ("已估计 SPM→PPI/gPPI", ["function"]),
    "task_dcm": ("已估计 SPM→VOI→任务 DCM", ["function"]),
    "spectral_dcm": ("静息数据→ROI 时序→谱 DCM", ["function"]),
}
TEMPORAL_STATES = {"unfiltered_unregressed", "nuisance_regressed_unfiltered",
                   "nuisance_regressed_highpassed", "denoised_bandpassed"}
ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]*$")
PRE_COLUMNS = "subject session run bold t1 input_stage sbref metadata events fieldmaps provenance sdc_method discard_volumes event_reference realign_weight fieldmap_epi".split()
GLM_COLUMNS = "subject session run bold events confounds temporal_state".split()
FC_COLUMNS = "subject session run bold mask roi_file tr_seconds temporal_state smoothing_fwhm_mm confounds purpose".split()
PPI_COLUMNS = "subject session run spm_mat seed_mask spm_session_index".split()
MODEL_FIELDS = {
    "toolkit_method": ["native_config"],
    "preprocess": ["preprocessing_options"],
    "preprocess_glm": ["preprocessing_options", "conditions", "contrasts", "glm_options"],
    "glm": ["conditions", "contrasts", "glm_options"],
    "fc": ["cleaning", "fc_measure", "roi_definition"],
    "ppi": ["ppi_method", "conditions", "psychological_contrast", "roi_definition"],
    "task_dcm": ["regions", "driving_inputs", "A", "B", "C", "voi_definition"],
    "spectral_dcm": ["regions", "A", "cleaning", "roi_definition"],
}


def now():
    return datetime.now(timezone.utc).isoformat()


def read_json(path):
    def reject_constant(value):
        raise ValueError(f"JSON 不允许非有限常量: {value}")
    value = json.loads(Path(path).read_text(encoding="utf-8-sig"), parse_constant=reject_constant)
    if not isinstance(value, dict):
        raise ValueError(f"JSON 顶层必须是对象: {path}")
    return value


def write_json(path, value):
    # 项目快照和草稿使用独占写入，不覆盖已有修订。
    with Path(path).open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, allow_nan=False)
        handle.write("\n")


def within(child, parent):
    return child == parent or parent in child.parents


def fact_value(facts, name):
    item = facts.get(name)
    if (isinstance(item, dict) and item.get("confirmed") is True
            and isinstance(item.get("source"), str) and item["source"].strip()
            and "value" in item):
        return item["value"], True
    return None, False


def input_changes(inventory, selected):
    """只比较已纳入源文件及其元数据的大小/mtime，不能证明内容完整性。"""
    records = {item["path"]: item for item in inventory["files"]}
    by_id = {row["run_id"]: row for row in inventory["runs"]}
    messages = []
    for run_id in selected:
        row = by_id.get(run_id)
        if row is None:
            continue
        source = row.get("bold") or str(Path(inventory["data_root"]) / run_id)
        for name in [source, *row.get("metadata", {}).get("sources", [])]:
            original = records.get(name)
            if original is None:
                continue
            try:
                path = Path(name)
                current = path.stat()
                changed = (not path.is_file() or current.st_size != original["size_bytes"]
                           or current.st_mtime_ns != original.get("mtime_ns", current.st_mtime_ns))
            except OSError:
                changed = True
            if changed:
                messages.append(f"扫描后输入已变更或移走，请新建扫描项目: {name}")
    return sorted(set(messages))


def ensure_project(path, *, require_data_root=True):
    project = Path(path).resolve(strict=True)
    state = read_json(project / "project.json")
    if state.get("schema_version") != 1 or state.get("skill_version") not in {"0.1.0", "0.2.0", "0.3.0", "0.3.1", "0.4.0", VERSION}:
        raise ValueError("项目版本不兼容，请保留原项目并使用对应版本或建立新项目")
    # 读取已有执行结果时允许原始数据盘离线；规划、预检和执行仍要求可访问。
    data_root = Path(state["data_root"]).resolve(strict=require_data_root)
    if within(project, data_root) or within(data_root, project):
        raise ValueError("项目目录与输入目录不能互相包含")
    inventory_file = project / "inventory.json"
    if hashlib.sha256(inventory_file.read_bytes()).hexdigest() != state["inventory_sha256"]:
        raise ValueError("inventory.json 已变更，请建立新扫描项目，避免错配旧答案")
    return project, state, read_json(inventory_file)


def tsv(path, columns, rows):
    with path.open("x", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def event_issues(path):
    """基本列/单位约束；不证明时序同步或条件含义正确。"""
    try:
        with Path(path).open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if not {"onset", "duration", "trial_type"}.issubset(reader.fieldnames or []):
                return ["任务工具包事件表需要 onset、duration、trial_type 三列"]
            count = 0
            for row in reader:
                count += 1
                onset, duration = float(row["onset"]), float(row["duration"])
                if not math.isfinite(onset) or not math.isfinite(duration) or duration < 0:
                    return [f"事件第 {count} 行 onset/duration 非有限或 duration<0"]
                if not (row["trial_type"] or "").strip():
                    return [f"事件第 {count} 行缺条件标签"]
            return [] if count else ["事件表没有事件行"]
    except (OSError, ValueError, csv.Error, UnicodeError) as exc:
        return [f"事件表不可读: {exc}"]


def make_plan(inventory, answers):
    import review_policy
    return review_policy.require_setup(_make_plan(inventory, answers), answers)


def _make_plan(inventory, answers):
    if not isinstance(answers, dict) or answers.get("schema_version", 1) != 1:
        raise ValueError("答案 schema_version 必须为 1")
    for key in ("runs", "parameter_choices", "toolkit_roots"):
        if key in answers and not isinstance(answers[key], dict):
            raise ValueError(f"answers.{key} 必须为对象")
    if answers.get('route')=='toolkit_method':
        import native_plan
        return native_plan.make_plan(inventory,answers)
    questions, blockers, deferred = [], [], []

    def ask(key, prompt, *, run_id=None, candidates=None, reason="需要用户提供或确认"):
        item = {"id": key, "prompt": prompt, "reason": reason}
        if run_id is not None:
            item["run_id"] = run_id
        if candidates:
            item["candidates"] = candidates
        questions.append(item)

    route = answers.get("route")
    if not isinstance(route, str) or route not in ROUTES:
        ask("route", "希望从哪里开始，最终达到什么分析目标？", candidates=list(ROUTES))
        route = None
    for key, prompt in (("goal", "希望检验什么研究问题、获得什么结果？"),
                        ("paradigm", "数据对应什么实验范式（静息/任务及任务设计）？"),
                        ("independent_unit", "独立实验单位是什么，是否有重复 session、配对或组别？")):
        if not isinstance(answers.get(key), str) or not answers[key].strip():
            ask(key, prompt)
    selected = answers.get("selected_run_ids", [])
    if not isinstance(selected, list) or any(not isinstance(x, str) for x in selected):
        raise ValueError("selected_run_ids 必须为 run_id 字符串数组")
    if len(selected) != len(set(selected)):
        raise ValueError("selected_run_ids 包含重复值")
    by_id = {row["run_id"]: row for row in inventory["runs"]}
    unknown = set(selected) - set(by_id)
    if unknown:
        raise ValueError(f"答案中存在扫描未记录的 run_id: {sorted(unknown)}")
    if not selected and route is not None:
        ask("selected_run_ids", "请确认纳入哪些候选数据，并核对被试/session/run 对应关系。",
            candidates=list(by_id))
    if not by_id and route is not None:
        blockers.append("未发现 BOLD 或 SPM.mat 候选；需补充路径或为其他格式开发适配器")
    blockers.extend(input_changes(inventory, selected))

    packages = {}
    markers = {"preprocessing": "matlab/+psy/preprocess_batch.m", "glm": "matlab/+psy/glm_batch.m",
               "function": "run_function.m"}
    for package in ROUTES[route][1] if route else []:
        raw = answers.get("toolkit_roots", {}).get(package)
        if not isinstance(raw, str) or not raw.strip():
            ask(f"toolkit_roots.{package}", f"{package} 工具包安装在哪里？")
            continue
        root = Path(raw).expanduser()
        if not root.is_absolute() or not root.is_dir() or not (root / markers[package]).is_file():
            blockers.append(f"{package} 路径须为包含 {markers[package]} 的有效绝对目录")
        else:
            packages[package] = str(root.resolve())

    rows, verified = [], []
    for run_id in selected:
        item, values = by_id[run_id], {}
        run_answer = answers.get("runs", {}).get(run_id, {})
        if not isinstance(run_answer, dict) or not isinstance(run_answer.get("facts", {}), dict):
            raise ValueError(f"run 答案必须包含 facts 对象: {run_id}")
        facts = run_answer.get("facts", {})

        def require(name, prompt, *, optional_empty=False, kind=None, choices=None):
            value, confirmed = fact_value(facts, name)
            candidate_name = "roi" if name == "roi_file" else name
            options = item.get("candidates", {}).get(candidate_name, [])
            if name == "metadata":
                options = item.get("metadata", {}).get("sources", [])
            if name == "tr_seconds":
                options = [{"value": item.get("header", {}).get("tr_seconds"), "source": "NIfTI header"},
                           {"value": item.get("metadata", {}).get("values", {}).get("RepetitionTime"),
                            "source": "direct JSON sidecar"}]
                options = [x for x in options if x["value"] is not None]
            if name in {"subject", "session", "run"}:
                guess = item.get("identity", {}).get(name)
                options = [guess] if guess else []
            if not confirmed or (value in (None, "") and not optional_empty):
                ask(f"{run_id}::{name}", prompt, run_id=run_id, candidates=options)
                return
            good = True
            if kind == "id":
                good = isinstance(value, str) and ((optional_empty and value == "") or bool(ID_PATTERN.fullmatch(value)))
            elif kind == "path":
                good = isinstance(value, str) and ((optional_empty and value == "") or
                    (Path(value).is_absolute() and Path(value).is_file()))
                if good and value:
                    value = str(Path(value).resolve())
            elif kind in {"positive", "nonnegative"}:
                good = isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)
                good = good and (value > 0 if kind == "positive" else value >= 0)
            elif kind == "integer":
                good = isinstance(value, int) and not isinstance(value, bool) and value >= 0
            if choices is not None:
                good = good and isinstance(value, str) and value in choices
            if not good:
                ask(f"{run_id}::{name}", prompt, run_id=run_id, reason="已填值类型、范围或路径无效")
                return
            values[name] = value
            verified.append({"run_id": run_id, "field": name, "value": value, "source": facts[name]["source"]})

        if route:
            for field in ("subject", "session", "run"):
                require(field, f"确认 {field} 标识（session 可明确为空）。", optional_empty=field == "session", kind="id")
            if route in {"preprocess", "preprocess_glm", "glm", "fc", "spectral_dcm"}:
                bold = item.get("bold", "")
                if not bold:
                    blockers.append(f"{run_id}: 当前路线需要 BOLD，SPM.mat 候选不能直接用于此路线")
                else:
                    values["bold"] = bold
                    header = item.get("header", {})
                    if header.get("status") != "ok":
                        blockers.append(f"{run_id}: NIfTI 头无效或当前扫描器不支持")
                    shape = header.get("shape", [])
                    if len(shape) < 4 or shape[3] <= 1 or any(x != 1 for x in shape[4:]):
                        blockers.append(f"{run_id}: 当前规划只接受单个 4D 时序（额外维度仅允许单例）")
                    if item.get("metadata", {}).get("conflicts"):
                        require("metadata_resolution", "请记录元数据冲突的解决依据。")
                    if not run_id.lower().endswith(("_bold.nii", "_bold.nii.gz")):
                        require("bold_modality", "此为普通 4D 候选，请确认实际模态为 BOLD。", choices={"bold"})
                require("input_stage", "确认输入为 raw 或 preprocessed。", choices={"raw", "preprocessed"})
                expected = "raw" if route in {"preprocess", "preprocess_glm"} else "preprocessed"
                if "input_stage" in values and values["input_stage"] != expected:
                    blockers.append(f"{run_id}: {route} 需要 {expected} 输入，请切换路线或提供对应阶段数据")
                require("tr_seconds", "确认 TR（秒）及其来源。", kind="positive")
            if route in {"glm", "fc", "spectral_dcm"}:
                require("temporal_state", "确认滤波/混杂回归历史。", choices=TEMPORAL_STATES)
                require("smoothing_fwhm_mm", "确认已施加的平滑 FWHM（mm，0 表示未平滑）。", kind="nonnegative")
                require("confounds", "确认混杂 TSV 路径；明确不用时填空并注明原因。", optional_empty=True, kind="path")
            if route in {"preprocess_glm", "glm"}:
                require("events", "提供并确认真实事件 TSV 及单位/时间来源。", kind="path")
                require("event_reference", "事件零点为最初采集帧还是当前保留帧？", choices={"original_first_volume", "retained_first_volume"})
                require("discard_volumes", "确认此前或本次删除的 dummy 帧数（不得重复删除）。", kind="integer")
                if "events" in values:
                    blockers.extend(f"{run_id}: {message}" for message in event_issues(values["events"]))
                if route == "glm" and values.get("temporal_state") not in (None, "unfiltered_unregressed"):
                    blockers.append(f"{run_id}: 当前 GLM 接口要求 unfiltered_unregressed，不能自动使用去噪残差")
                if route == "glm" and values.get("confounds") == "":
                    blockers.append(f"{run_id}: 当前 GLM 入口要求真实 confounds TSV；本版不伪造零矩阵")
            if route in {"preprocess", "preprocess_glm"}:
                require("t1", "确认对应结构像路径。", kind="path")
                require("metadata", "确认采集 JSON 路径（采集参数还需按预处理路线深查）。", kind="path")
                require("sdc_method", "确认畸变校正路线和采集依据。")
                if route == "preprocess":
                    require("events", "提供事件 TSV；无任务事件时明确留空。", optional_empty=True, kind="path")
                    require("discard_volumes", "确认本次需要删除的 dummy 帧数，0 表示不删。", kind="integer")
                    require("event_reference", "确认事件时间基准；无事件可填 unspecified。",
                            choices={"unspecified", "original_first_volume", "retained_first_volume"})
                if route == "preprocess_glm":
                    require("mask", "确认所选预处理产物空间的 GLM 分析掩膜。", kind="path")
                deferred.append({"run_id": run_id, "producer": "preprocessing/confound adapter",
                                 "outputs": ["GLM BOLD", "dummy-adjusted events", "confounds"],
                                 "status": "validated_after_preprocessing" if route == "preprocess_glm" else "not_requested"})
            if route in {"fc", "spectral_dcm"}:
                require("mask", "确认分析掩膜路径（网格/解剖对齐待深查）。", kind="path")
                require("roi_file", "确认 ROI 标签图路径及定义依据。", kind="path")
                require("purpose", "确认时序为 rest 或 task。", choices={"rest", "task"})
                if route == "spectral_dcm" and values.get("purpose") == "task":
                    blockers.append(f"{run_id}: 本版谱 DCM 规划路线限定静息数据")
                if values.get("temporal_state") not in (None, "unfiltered_unregressed") and values.get("confounds"):
                    blockers.append(f"{run_id}: 当前准备器不允许对已有回归数据隐式再加入混杂")
            if route in {"ppi", "task_dcm"}:
                require("spm_mat", "确认已估计的 SPM.mat；影像引用和估计状态待 MATLAB 深查。", kind="path")
                require("spm_session_index", "确认 SPM 内部 session 序号（从 1 开始）。", kind="positive")
                if "spm_session_index" in values and int(values["spm_session_index"]) != values["spm_session_index"]:
                    blockers.append(f"{run_id}: SPM session 序号必须为整数")
            if route == "ppi":
                require("seed_mask", "确认种子掩膜路径和独立定义依据。", kind="path")
            if route in {"task_dcm", "spectral_dcm"}:
                require("te_seconds", "确认真实 TE（秒，不能使用工程示例假设）。", kind="positive")
                if values.get("te_seconds", 0) > 0.1:
                    blockers.append(f"{run_id}: 当前 DCM 接口要求 0<TE<=0.1 秒，请核对单位")
                require("region_sampling_delays_seconds", "确认各区域采样时延（秒）及区域顺序。")
                deferred.append({"run_id": run_id, "producer": "DCM input adapter", "outputs": ["dcm_data.mat"],
                                 "status": "adapter_not_implemented"})
        rows.append({"run_id": run_id, "values": values})

    keys = [(x["values"].get("subject", ""), x["values"].get("session", ""), x["values"].get("run", "")) for x in rows]
    complete_keys = [tuple(v.lower() for v in key) for key in keys if key[0] and key[2]]
    if len(complete_keys) != len(set(complete_keys)):
        blockers.append("确认后的 subject/session/run 身份重复；需分清 acquisition/echo 或明确选择一个来源")
    choices = answers.get("parameter_choices", {})
    for name in MODEL_FIELDS.get(route, []):
        value, confirmed = fact_value(choices, name)
        if not confirmed or value is None or value == "":
            ask(f"parameter_choices.{name}", f"请讨论并确认 {name}，记录选择理由和来源。")
        elif name == "fc_measure" and value not in ("pearson", "spearman", "partial"):
            blockers.append("当前 FC 路线估计器只规划 pearson/spearman/partial")
        elif name == "ppi_method" and value not in ("classic", "gppi"):
            blockers.append("PPI 方法应明确为 classic 或 gppi")
    return {"schema_version": 1, "skill_version": VERSION,
            "phase": "needs_answers" if questions or blockers else "draft_prepared",
            "route": route, "route_label": ROUTES[route][0] if route else None,
            "goal": answers.get("goal"), "paradigm": answers.get("paradigm"),
            "selected_run_ids": selected, "toolkit_roots": packages,
            "questions": questions, "blockers": blockers, "runs": rows,
            "verified_facts": verified, "parameter_choices": choices,
            "deferred_outputs": deferred, "execution_ready": False,
            "limitations": ["fc/glm/preprocess/preprocess_glm 可另行 prepare 深预检与确认执行；PPI/DCM仍仅规划", "当前 plan 的头信息与基本表格检查不证明全体素有限性或解剖对齐",
                            "SPM.mat 估计状态/引用影像、设计可估计性、模型收敛与科学质量尚未验证",
                            "参数选择仅记录与基本检查，完整工具包配置约束待执行适配器验证"]}


def create_revision(project, inventory, answers):
    plan = make_plan(inventory, answers)
    for root in plan["toolkit_roots"].values():
        if within(project, Path(root)) or within(Path(root), project):
            raise ValueError("项目目录与工具包安装目录不能互相包含")
    revisions = project / "revisions"
    if not within(revisions.resolve(), project):
        raise ValueError("修订目录指向项目之外，停止写入")
    revisions.mkdir(exist_ok=True)
    for number in range(1, 100000):
        revision = revisions / f"{number:04d}"
        try:
            revision.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise ValueError("修订数量超出限制")
    drafts = revision / "draft_manifests"
    drafts.mkdir()
    rows = [x["values"] for x in plan["runs"]]
    route = plan["route"]
    if route=='toolkit_method':
        import native_plan
        native_plan.write_drafts(drafts,plan)
    if route in {"preprocess", "preprocess_glm"}:
        tsv(drafts / "preprocessing_runs.DRAFT.tsv", PRE_COLUMNS, rows)
        # 未来产物路径留空，不把原始 BOLD 冒充预处理结果。
        downstream = [{k: v for k, v in row.items() if k in {"subject", "session", "run"}} for row in rows]
        if route == "preprocess_glm":
            tsv(drafts / "glm_runs.DRAFT.tsv", GLM_COLUMNS, downstream)
    elif route == "glm":
        tsv(drafts / "glm_runs.DRAFT.tsv", GLM_COLUMNS, rows)
    elif route in {"fc", "spectral_dcm"}:
        tsv(drafts / "analysis_runs.DRAFT.tsv", FC_COLUMNS, rows)
    if route == "ppi":
        tsv(drafts / "ppi_runs.DRAFT.tsv", PPI_COLUMNS, rows)
    if route in {"task_dcm", "spectral_dcm"}:
        tsv(drafts / "dcm_runs.DRAFT.tsv", ["subject", "session", "run", "data_file"], rows)
    write_json(revision / "answers.json", answers)
    write_json(revision / "parameter_choices.json", plan["parameter_choices"])
    write_json(revision / "questions.json", {"questions": plan["questions"], "blockers": plan["blockers"]})
    write_json(revision / "plan.json", plan)
    return revision, plan


def update_pointer(project, state, revision, plan):
    state = {**state, "skill_version": VERSION, "phase": plan["phase"], "current_revision": revision.relative_to(project).as_posix(),
             "updated_utc": now(), "execution_ready": False}
    # 仅更新项目指针，所有旧答案、计划和草稿均保留。
    temporary = project / ".project.next.json"
    write_json(temporary, state)
    temporary.replace(project / "project.json")
    return state


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    scan = sub.add_parser("scan", help="只读扫描并建立新的规划项目")
    scan.add_argument("--data-root", required=True, help="[必填] 本地数据目录，输入始终只读")
    scan.add_argument("--project-dir", required=True, help="[必填] 新项目目录，不能与输入互相包含")
    plan_parser = sub.add_parser("plan", help="读取确认答案并保留新的计划修订")
    plan_parser.add_argument("--project-dir", required=True)
    plan_parser.add_argument("--answers", required=True, help="[必填] 项目专属答案 JSON；包含来源及确认标记")
    status = sub.add_parser("status", help="恢复最新问题与规划状态")
    status.add_argument("--project-dir", required=True)
    prepare_parser = sub.add_parser("prepare", help="生成现成入口配置审阅；旧专用路线保留其预检策略")
    prepare_parser.add_argument("--project-dir", required=True)
    prepare_parser.add_argument("--matlab-executable", required=True, help="[必填] MATLAB 程序绝对路径")
    prepare_parser.add_argument("--spm-root", help="[按所选原入口需要] SPM 安装根目录")
    execute_parser = sub.add_parser("execute", help="在用户审阅并明确确认后执行冻结方案")
    execute_parser.add_argument("--project-dir", required=True)
    execute_parser.add_argument("--attempt-id", required=True)
    execute_parser.add_argument("--review-digest", required=True, help="[必填] 已审阅方案的 SHA256")
    execute_parser.add_argument("--confirmation", required=True, help="[必填] 用户实际同意后填“确认执行”；不得自行批准真实分析")
    execution_status = sub.add_parser("execution-status", help="只读执行状态，不重跑任何计算")
    execution_status.add_argument("--project-dir", required=True)
    execution_status.add_argument("--attempt-id")
    assess_parser = sub.add_parser("assess-parameters", help="补齐参数评估表，不授予执行许可")
    assess_parser.add_argument("--project-dir", required=True)
    assess_parser.add_argument("--attempt-id", required=True)
    assess_parser.add_argument("--review-digest", required=True)
    assess_parser.add_argument("--assessment", required=True, help="Codex根据当前配置/文档填写的项目评估JSON")
    approve_parser = sub.add_parser("approve", help="用户审阅具体表格后记录真实确认；不可自行代答")
    approve_parser.add_argument("--project-dir", required=True)
    approve_parser.add_argument("--attempt-id", required=True)
    approve_parser.add_argument("--review-digest", required=True)
    approve_parser.add_argument("--source", required=True, help="真实用户回复的会话/消息来源")
    approve_parser.add_argument("--reply", required=True, help="真实确认回复，不伪造")
    approve_parser.add_argument("--actor", choices=['human','delegated_demo'], default='human')
    approve_parser.add_argument("--delegation-source", help="仅演示代答：人类明确授权的来源")
    workflow_parser = sub.add_parser("workflow", help="登记三包的执行/复用/跳过路线，不执行分析")
    workflow_parser.add_argument("--project-dir", required=True)
    workflow_parser.add_argument("--spec", required=True)
    report_parser = sub.add_parser("report", help="只读执行记录，生成完整步骤与参数报告，不重跑分析")
    report_parser.add_argument("--project-dir", required=True)
    args = parser.parse_args(argv)
    try:
        if args.command in {'assess-parameters','approve'}:
            import review_policy
            if args.command == 'assess-parameters':
                result = review_policy.assess(args.project_dir,args.attempt_id,args.review_digest,args.assessment)
            else:
                result = review_policy.approve(args.project_dir,args.attempt_id,args.review_digest,args.source,args.reply,args.actor,args.delegation_source)
            print(json.dumps(result,ensure_ascii=False));return 0
        if args.command in {'workflow','report'}:
            import workflow_report
            result = workflow_report.register(args.project_dir,args.spec) if args.command=='workflow' else workflow_report.generate(args.project_dir)
            print(json.dumps(result,ensure_ascii=False));return 0
        if args.command in {"prepare", "execute", "execution-status"}:
            import execution
            if args.command == "prepare":
                result = execution.prepare(args.project_dir, args.matlab_executable, args.spm_root)
            elif args.command == "execute":
                result = execution.execute(args.project_dir, args.attempt_id, args.review_digest, args.confirmation)
            else:
                result = execution.status(args.project_dir, args.attempt_id)
            print(json.dumps(result, ensure_ascii=False))
            return 2 if result["phase"] in {"preflight_failed", "execution_failed", "invalidated"} else 0
        if args.command == "scan":
            data = Path(args.data_root).expanduser().resolve(strict=True)
            project = Path(args.project_dir).expanduser().resolve()
            if not data.is_dir():
                raise ValueError("数据路径必须是目录")
            if within(project, data) or within(data, project):
                raise ValueError("项目目录与输入目录不能互相包含")
            if project.exists():
                raise ValueError("项目目录已存在；新扫描需新目录，已有项目使用 plan/status")
            inventory = scan_dataset(args.data_root)
            project.mkdir(parents=True)
            write_json(project / "inventory.json", inventory)
            state = {"schema_version": 1, "skill_version": VERSION, "created_utc": now(),
                     "data_root": str(data), "inventory_sha256": hashlib.sha256((project / "inventory.json").read_bytes()).hexdigest(),
                     "environment": {"python": sys.version.split()[0], "matlab_executable_candidate": shutil.which("matlab"),
                                     "matlab_license_checked": False, "dependencies_checked": False}}
            revision, plan = create_revision(project, inventory, {})
            update_pointer(project, state, revision, plan)
        else:
            project, state, inventory = ensure_project(args.project_dir)
            if args.command == "plan":
                answers = read_json(args.answers)
                revision, plan = create_revision(project, inventory, answers)
                update_pointer(project, state, revision, plan)
            else:
                revision = (project / state["current_revision"]).resolve(strict=True)
                if not within(revision, project / "revisions"):
                    raise ValueError("项目修订指针越界")
                plan = read_json(revision / "plan.json")
                changes = input_changes(inventory, plan.get("selected_run_ids", []))
                if plan['route']=='toolkit_method':
                    import native_plan
                    changes+=native_plan.input_changes(plan)
                if changes:
                    plan = {**plan, "phase": "stale_inputs", "blockers": [*plan["blockers"], *changes]}
        print(json.dumps({"project_dir": str(project), "revision": str(revision),
                          "plan": str(revision / "plan.json"), "questions": str(revision / "questions.json"),
                          "phase": plan["phase"], "question_count": len(plan["questions"]),
                          "blocker_count": len(plan["blockers"]), "blockers": plan["blockers"],
                          "execution_ready": False}, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps({"error": str(exc), "execution_ready": False}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
