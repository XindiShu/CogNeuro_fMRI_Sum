"""预检、冻结审阅与确认执行；支持预处理、条件GLM、ROI FC及预处理到GLM。"""
from __future__ import annotations

from contextlib import contextmanager
import csv
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import time
import uuid

import fmri_project as project_api

SKILL_ROOT = Path(__file__).resolve().parents[1]
SUPPORTED_ROUTES = {"fc", "glm", "preprocess", "preprocess_glm", "toolkit_method"}
CONFIRMATION_PHRASE = "确认执行"
ATTEMPT_PATTERN = re.compile(r"^[0-9]{4,6}$")
# 分块读取/复制为 1 MiB；单位为字节，不会一次装入整份影像。
CHUNK_BYTES = 1024 * 1024


def sha256(path):
    value = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(CHUNK_BYTES), b""):
            value.update(chunk)
    return value.hexdigest()


def _json(path, data):
    project_api.write_json(path, data)


def _read(path):
    return project_api.read_json(path)


def _inside(path, root):
    return project_api.within(Path(path).resolve(), Path(root).resolve())


def _safe_child(root, relative):
    path = root / relative
    if not _inside(path, root):
        raise ValueError("执行目录存在越界链接，停止写入")
    return path


def _state(attempt, phase, **updates):
    target = attempt / "state.json"
    previous = _read(target) if target.exists() else {}
    state = {**previous, **updates, "attempt_id": attempt.name, "attempt_dir": str(attempt),
             "phase": phase, "updated_utc": project_api.now(), "execution_ready": False}
    temporary = attempt / f".state.{uuid.uuid4().hex}.json"
    _json(temporary, state)
    temporary.replace(target)
    events = attempt / "events"
    events.mkdir(exist_ok=True)
    _json(events / f"{time.time_ns()}_{uuid.uuid4().hex[:8]}.json", state)
    return state


@contextmanager
def _lock(attempt):
    target = attempt / "operation.lock"
    try:
        with target.open("x", encoding="utf-8") as handle:
            handle.write(str(os.getpid()))
    except FileExistsError as exc:
        raise ValueError("此尝试已有运行锁；请先检查进程与状态，不自动重试或删除锁") from exc
    try:
        yield
    finally:
        target.unlink(missing_ok=True)


def _current(project_dir):
    project, state, inventory = project_api.ensure_project(project_dir)
    revision = _safe_child(project, state["current_revision"])
    if not _inside(revision, project / "revisions"):
        raise ValueError("项目修订指针不在 revisions 内")
    answers = _read(revision / "answers.json")
    plan = project_api.make_plan(inventory, answers)
    if plan["route"] not in SUPPORTED_ROUTES:
        raise ValueError("请使用toolkit_method选择现成接口；旧PPI/DCM规划ID请迁移到实际方法ID")
    if plan["phase"] != "draft_prepared":
        raise ValueError("计划仍有未回答问题或阻塞项，请先完成 plan")
    return project, revision, inventory, answers, plan


def _number(value, label, *, minimum=0, integer=False, positive=False):
    if (not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value)
            or (value <= minimum if positive else value < minimum)
            or (integer and int(value) != value)):
        raise ValueError(f"{label} 数值/单位/范围无效")
    return value


def _exact(value, fields, label):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise ValueError(f"{label} 必须明确包含且仅包含 {sorted(fields)}")
    return value


def _boolean(value, label):
    if not isinstance(value, bool):
        raise ValueError(f"{label} 必须为 true/false")


def normalized_options(plan):
    if plan["route"] in {"preprocess", "preprocess_glm"}:
        import preprocessing
        return preprocessing.normalized_options(plan)
    choices = plan["parameter_choices"]

    def confirmed(name):
        value, valid = project_api.fact_value(choices, name)
        if not valid:
            raise ValueError(f"需要明确确认 parameter_choices.{name} 及来源")
        return value

    budget = confirmed("execution_options")
    if plan["route"] == "fc":
        _exact(budget, {"max_matrix_gib", "roi_min_voxels"}, "execution_options")
        _number(budget["max_matrix_gib"], "max_matrix_gib", positive=True)
        _number(budget["roi_min_voxels"], "roi_min_voxels", minimum=1, integer=True)
        cleaning = confirmed("cleaning")
        _exact(cleaning, {"detrend", "bandHz", "minResidualDimensions"}, "cleaning")
        _boolean(cleaning["detrend"], "cleaning.detrend")
        _number(cleaning["minResidualDimensions"], "minResidualDimensions", minimum=1, integer=True)
        band = cleaning["bandHz"]
        if not isinstance(band, list) or len(band) not in (0, 2):
            raise ValueError("cleaning.bandHz 需要 [] 或 [低频, 高频]，单位 Hz")
        if band:
            _number(band[0], "低频 Hz")
            _number(band[1], "高频 Hz", minimum=band[0], positive=True)
            for row in plan["runs"]:
                if band[1] > 1 / (2 * row["values"]["tr_seconds"]):
                    raise ValueError("带通上界超过所选 run 的 Nyquist 频率")
        measure = confirmed("fc_measure")
        if measure not in ("pearson", "spearman", "partial"):
            raise ValueError("FC 估计器不支持")
        # 当前工具包总会调用联合投影；已有清理数据需另行适配，不能隐式重滤波/去趋势。
        if any(row["values"]["temporal_state"] != "unfiltered_unregressed" for row in plan["runs"]):
            raise ValueError("v0.2 FC 执行要求未滤波且未回归时序；已清理数据仍可规划")
        return {"cleaning": cleaning, "fc_measure": measure, **budget}
    _exact(budget, {"max_matrix_gib"}, "execution_options")
    _number(budget["max_matrix_gib"], "max_matrix_gib", positive=True)
    conditions = confirmed("conditions")
    if (not isinstance(conditions, list) or not conditions or any(
            not isinstance(x, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", x) for x in conditions)
            or len(set(x.lower() for x in conditions)) != len(conditions)):
        raise ValueError("conditions 需要互异的字母开头条件名称数组")
    contrasts = confirmed("contrasts")
    if not isinstance(contrasts, list) or not contrasts:
        raise ValueError("contrasts 需要 {name, weights} 对象数组")
    names = []
    for contrast in contrasts:
        _exact(contrast, {"name", "weights"}, "contrast")
        if not isinstance(contrast["name"], str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", contrast["name"]):
            raise ValueError("对比名称需要安全的字母开头标识")
        weights = contrast["weights"]
        if not isinstance(weights, list) or len(weights) != len(conditions):
            raise ValueError("对比权重列数与 conditions 不符")
        for weight in weights:
            if not isinstance(weight, (int, float)) or isinstance(weight, bool) or not math.isfinite(weight):
                raise ValueError("对比权重需要有限数值")
        if not any(weights):
            raise ValueError("对比权重不能全为 0")
        names.append(contrast["name"].lower())
    if len(set(names)) != len(names):
        raise ValueError("对比名称重复")
    glm = confirmed("glm_options")
    _exact(glm, {"highpass_seconds", "microtime_resolution", "microtime_onset", "serial_correlation",
                 "hrf", "min_residual_df", "mask_threshold", "confounds"}, "glm_options")
    _number(glm["highpass_seconds"], "高通秒", positive=True)
    for name in ("microtime_resolution", "microtime_onset", "min_residual_df"):
        _number(glm[name], name, minimum=1, integer=True)
    if glm["microtime_onset"] > glm["microtime_resolution"]:
        raise ValueError("microtime_onset 超过 microtime_resolution")
    _number(glm["mask_threshold"], "mask_threshold")
    if glm["mask_threshold"] > 1 or glm["serial_correlation"] not in ("AR(1)", "FAST") or glm["hrf"] != "canonical":
        raise ValueError("GLM pilot 限 canonical、AR(1)/FAST、0<=mask_threshold<=1")
    conf = _exact(glm["confounds"], {"motion_model", "include_tissue_means", "linear_trend", "add_spikes",
                                   "fd_threshold_mm", "min_residual_df"}, "glm_options.confounds")
    if conf["motion_model"] not in ("none", "6", "24"):
        raise ValueError("motion_model 应为 none/6/24")
    for name in ("include_tissue_means", "linear_trend", "add_spikes"):
        _boolean(conf[name], name)
    _number(conf["fd_threshold_mm"], "FD mm")
    _number(conf["min_residual_df"], "混杂最少残差维度", minimum=1, integer=True)
    return {"conditions": conditions, "contrasts": contrasts, "glm": glm, **budget}


def _record(path, role):
    path = Path(path).resolve(strict=True)
    if not path.is_file():
        raise ValueError(f"不是文件: {path}")
    return {"path": str(path), "role": role, "bytes": path.stat().st_size, "sha256": sha256(path)}


def _verify(records):
    for record in records:
        path = Path(record["path"])
        if (not path.is_file() or path.stat().st_size != record["bytes"] or sha256(path) != record["sha256"]):
            raise ValueError(f"冻结方案所依赖文件已变更/缺失: {path}")


def _code_files(root):
    root = Path(root).resolve(strict=True)
    result = []
    for path in sorted(root.rglob("*")):
        if path.is_file() and (path.suffix.lower() in {".m", ".p"} or path.suffix.lower().startswith(".mex")):
            if path.is_symlink() or not _inside(path, root):
                raise ValueError(f"代码目录含越界链接: {path}")
            result.append(path)
    return result


def _code_snapshot(root, role):
    return {"root": str(Path(root).resolve()), "files": [_record(p, role) for p in _code_files(root)]}


def _verify_code(groups):
    for group in groups:
        if [str(p) for p in _code_files(group["root"])] != [x["path"] for x in group["files"]]:
            raise ValueError(f"代码文件清单已变化: {group['root']}")
        _verify(group["files"])


def _copy_source(source, destination):
    source = Path(source).resolve(strict=True)
    before = _record(source, "source")
    with source.open("rb") as inp, destination.open("xb") as out:
        shutil.copyfileobj(inp, out, CHUNK_BYTES)
    if sha256(destination) != before["sha256"] or sha256(source) != before["sha256"]:
        raise ValueError(f"复制期间源文件发生变化: {source}")
    if source.name.lower().endswith(".nii.gz"):
        expanded = destination.with_suffix("")
        with gzip.open(destination, "rb") as inp, expanded.open("xb") as out:
            shutil.copyfileobj(inp, out, CHUNK_BYTES)
        return expanded, [before, _record(destination, "compressed_private_copy"), _record(expanded, "private_copy")]
    return destination, [before, _record(destination, "private_copy")]


def matlab_runner(job_file, matlab_executable):
    """固定入口 + 参数列表；不经 shell 拼接用户命令。"""
    job = _read(job_file)
    adapter_dir = Path(job_file).parent / "adapter"
    literal = lambda p: str(p).replace("'", "''")
    expression = f"addpath('{literal(adapter_dir)}');cogneuro_job('{literal(job_file)}');"
    command = [str(matlab_executable)]
    if os.name == "nt":
        command.append("-wait")
    command.extend(["-batch", expression])
    log_file = Path(job_file).with_suffix(".matlab.log")
    with log_file.open("xb") as log:
        completed = subprocess.run(command, cwd=Path(job_file).parent, stdout=log, stderr=subprocess.STDOUT,
                                   shell=False, check=False)
    result_file = Path(job["result_file"])
    if completed.returncode != 0:
        detail = _read(result_file) if result_file.is_file() else {}
        raise ValueError(f"MATLAB 退出码 {completed.returncode}: {detail.get('message', '')}; 日志 {log_file}")
    if not result_file.is_file():
        raise ValueError(f"MATLAB 未返回结构化结果；查看 {log_file}")
    return _read(result_file)


def _invoke(job_file, executable, runner):
    job = _read(job_file)
    result = (runner or matlab_runner)(Path(job_file), Path(executable))
    if not isinstance(result, dict):
        raise ValueError("MATLAB 适配器返回结果必须是对象")
    result_file = Path(job["result_file"])
    if result_file.exists():
        if _read(result_file) != result:
            raise ValueError("MATLAB 结果文件与返回值不一致")
    else:
        _json(result_file, result)
    expected = "preflight_passed" if job["mode"] == "preflight" else "complete"
    if result.get("status") != expected:
        raise ValueError(f"适配器未达到 {expected}: {result.get('message', result)}")
    return result


def _review_markdown(review):
    import review_policy
    lines = ["# fMRI 执行前审阅", "", f"路线：{review['route']}；目标：{review['goal']}",
             f"纳入运行：{len(review['runs'])}；独立单位：{review['independent_unit']}",
             f"结果目录：{review['output_root']}", "", "## 将执行的配置", "", "```json",
             json.dumps(review["options"], ensure_ascii=False, indent=2), "```", "", "## 运行与来源", ""]
    for run in review["runs"]:
        lines.append(f"- {run['run_id']} → {run['subject']}/{run['session']}/{run['run']}；TR={run['tr_seconds']} 秒")
    spatial = review["route"] in {"preprocess", "preprocess_glm"}
    native = review["route"] == "toolkit_method"
    input_scope = ("原始输入仅复制；预处理按所审阅的配置在本次私有副本上执行dummy删除、空间变换及相应插值。"
                   if spatial else "原始输入仅复制；分析使用本次私有副本。没有自动重采样、删帧或插值。")
    if native:input_scope="按现成工具包的原始接口读取声明输入；原包配置仅在内存中覆盖，所选分析自身的数据处理步骤以原配置为准。"
    lines.extend(["", "## 实际预检结果", "", "```json", json.dumps(review["preflight"], ensure_ascii=False, indent=2),
                  "```", "", "## 边界", "", input_scope,
                  ("研究层级与方法按所选原生配置执行；工程返回不等于科学质量通过。" if native else
                   "执行后仍需研究相关的解剖、信号、残差和推断检查。各run分别处理，当前不执行群体推断。"),
                  "科研参数、来源确认及完整文件指纹保存在 review.json。预检通过不表示科学假设或配准质量通过。",
                  "Python/MATLAB 安装及系统动态库不做完整环境镜像；代码指纹覆盖所选工具包与 SPM 的 .m/.p/MEX。",
                  "", "只有用户审阅并确认此具体方案后才可调用 execute。"])
    return "\n".join(lines) + "\n" + review.get('additional_review_notes','') + review_policy.markdown(review)


def prepare(project_dir, matlab_executable, spm_root, runner=None):
    project, revision, inventory, answers, plan = _current(project_dir)
    if plan['route']=='toolkit_method':
        import native_jobs
        return native_jobs.prepare(project_dir,matlab_executable,spm_root,runner=runner)
    if not spm_root:raise ValueError('所选旧专用路线需要--spm-root；通用接口按原方法依赖选择')
    if plan["route"] in {"preprocess", "preprocess_glm"}:
        import preprocessing
        return preprocessing.prepare(project_dir, matlab_executable, spm_root, runner=runner)
    options = normalized_options(plan)
    executable = Path(matlab_executable).expanduser()
    spm = Path(spm_root).expanduser()
    if not executable.is_absolute() or not executable.is_file():
        raise ValueError("matlab_executable 必须是实际 MATLAB 程序的绝对路径")
    if not spm.is_absolute() or not (spm / "spm.m").is_file():
        raise ValueError("spm_root 必须是包含 spm.m 的绝对目录")
    executable, spm = executable.resolve(), spm.resolve()
    toolkit = Path(plan["toolkit_roots"]["function" if plan["route"] == "fc" else "glm"])
    for code_root in (spm, toolkit, SKILL_ROOT):
        if _inside(project, code_root) or _inside(code_root, project):
            raise ValueError("项目目录不能与工具包、SPM 或 skill 目录互相包含")
    run_values = []
    for run in plan["runs"]:
        values = dict(run["values"])
        if plan["route"] == "glm":
            facts = answers["runs"][run["run_id"]]["facts"]
            mask, confirmed = project_api.fact_value(facts, "mask")
            if not confirmed or not isinstance(mask, str) or not Path(mask).is_absolute() or not Path(mask).is_file():
                raise ValueError("v0.2 GLM 执行需要确认的显式 mask 路径，便于有限性/网格检查")
            values["mask"] = str(Path(mask).resolve())
            if values["event_reference"] != "retained_first_volume" and values["discard_volumes"]:
                raise ValueError("事件尚需 dummy 时间平移；本版不自动转换，先提供已确认对齐的事件副本")
        run_values.append((run["run_id"], values))
    executions = _safe_child(project, "execution")
    executions.mkdir(exist_ok=True)
    for number in range(1, 1000000):
        attempt = executions / f"{number:04d}"
        try:
            attempt.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise ValueError("执行尝试数量超限")
    with _lock(attempt):
        _state(attempt, "preflighting", route=plan["route"], revision=str(revision), owner_pid=os.getpid())
        try:
            frozen = [_record(revision / "answers.json", "answers"), _record(revision / "plan.json", "plan"),
                      _record(project / "inventory.json", "inventory"), _record(executable, "matlab_launcher")]
            code_groups = [_code_snapshot(toolkit, "toolkit_code"), _code_snapshot(spm, "spm_code"),
                           _code_snapshot(SKILL_ROOT / "matlab", "adapter_source")]
            frozen.extend(_record(p, "planner_source") for p in sorted((SKILL_ROOT / "scripts").glob("*.py")))
            inputs = attempt / "inputs"
            inputs.mkdir()
            staged_rows, expected_runs, sources_for_review = [], [], []
            fields = ("bold", "mask", "roi_file", "confounds") if plan["route"] == "fc" else ("bold", "mask", "events", "confounds")
            for index, (run_id, values) in enumerate(run_values, 1):
                directory = inputs / f"run_{index:04d}"
                directory.mkdir()
                row = dict(values)
                for field in fields:
                    source = values.get(field, "")
                    if not source:
                        continue
                    suffix = ".nii.gz" if str(source).lower().endswith(".nii.gz") else Path(source).suffix
                    destination = directory / (field + suffix)
                    staged, records = _copy_source(source, destination)
                    row[field] = str(staged)
                    frozen.extend(records)
                staged_rows.append(row)
                expected = {k: values[k] for k in ("subject", "session", "run", "tr_seconds")}
                expected_runs.append(expected)
                sources_for_review.append({"run_id": run_id, **values})
            manifest = attempt / "runs.tsv"
            columns = project_api.FC_COLUMNS if plan["route"] == "fc" else project_api.GLM_COLUMNS + ["mask"]
            project_api.tsv(manifest, columns, staged_rows)
            frozen.append(_record(manifest, "execution_manifest"))
            adapter_dir = attempt / "adapter"
            adapter_dir.mkdir()
            for source in sorted((SKILL_ROOT / "matlab").glob("*.m")):
                destination = adapter_dir / source.name
                shutil.copyfile(source, destination)
                frozen.append(_record(destination, "adapter_copy"))
            # 同时冻结私有目录的完整代码清单，拒绝预检后新增的 .p/.m/MEX 覆盖入口。
            code_groups.append(_code_snapshot(adapter_dir, "adapter_private_code"))
            if not (adapter_dir / "cogneuro_job.m").is_file():
                raise ValueError("缺少本版固定 MATLAB job 入口")
            base = {"schema_version": 1, "route": plan["route"], "toolkit_root": str(toolkit),
                    "spm_root": str(spm), "manifest_file": str(manifest), "output_root": str(attempt / "results"),
                    "options": options, "expected_runs": expected_runs}
            preflight_job = {**base, "mode": "preflight", "work_root": str(attempt / "preflight_work"),
                             "result_file": str(attempt / "preflight_result.json")}
            execution_job = {**base, "mode": "execute", "work_root": str(attempt / "execution_work"),
                             "result_file": str(attempt / "execution_result.json")}
            _json(attempt / "preflight_job.json", preflight_job)
            _json(attempt / "execution_job.json", execution_job)
            frozen.extend([_record(attempt / "preflight_job.json", "preflight_job"),
                           _record(attempt / "execution_job.json", "execution_job")])
            preflight = _invoke(attempt / "preflight_job.json", executable, runner)
            _verify(frozen)
            _verify_code(code_groups)
            frozen.append(_record(attempt / "preflight_result.json", "preflight_result"))
            review = {"schema_version": 1, "skill_version": project_api.VERSION, "attempt_id": attempt.name,
                      "project_dir": str(project), "revision": str(revision), "route": plan["route"],
                      "goal": answers["goal"], "paradigm": answers["paradigm"],
                      "independent_unit": answers["independent_unit"], "runs": sources_for_review,
                      "options": options, "parameter_choices": plan["parameter_choices"],
                      "verified_facts": plan["verified_facts"], "toolkit_root": str(toolkit), "spm_root": str(spm),
                      "matlab_executable": str(executable), "output_root": base["output_root"],
                      "preflight": preflight, "frozen_files": frozen, "code_groups": code_groups,
                      "execution_ready": False, "scientific_qc_passed": False}
            import review_policy
            review_policy.initialize(review, answers)
            _json(attempt / "parameter_assessment.template.json", review_policy.template(review))
            _json(attempt / "review.json", review)
            (attempt / "review.md").write_text(_review_markdown(review), encoding="utf-8")
            digest = sha256(attempt / "review.json")
            return _state(attempt, "awaiting_confirmation", review_digest=digest,
                          review_path=str(attempt / "review.md"), review_markdown_sha256=sha256(attempt / "review.md"),
                          job_file=str(attempt / "execution_job.json"), parameter_review_status='needs_assessment',
                          assessment_template=str(attempt/'parameter_assessment.template.json'))
        except Exception as exc:
            return _state(attempt, "preflight_failed", error=str(exc), retry_policy="new_attempt_only")


def _get_attempt(project_dir, attempt_id=None, *, require_data_root=True):
    project, state, inventory = project_api.ensure_project(project_dir, require_data_root=require_data_root)
    root = _safe_child(project, "execution")
    if attempt_id is None:
        candidates = sorted(p.name for p in root.iterdir() if ATTEMPT_PATTERN.fullmatch(p.name) and p.is_dir()) if root.is_dir() else []
        if not candidates:
            raise ValueError("此项目尚无执行预检尝试")
        attempt_id = max(candidates, key=int)
    if not isinstance(attempt_id, str) or not ATTEMPT_PATTERN.fullmatch(attempt_id):
        raise ValueError("attempt_id 必须为已有尝试编号")
    attempt = _safe_child(project, "execution/" + attempt_id)
    return project, state, attempt, _read(attempt / "state.json")


def _check_outputs(job, result):
    root = Path(job["output_root"])
    if job['route']=='toolkit_method' and (result.get('method_id')!=job['method_id'] or result.get('native_analysis_called') is not True or not result.get('output_files')):
        raise ValueError('原生调用结果的方法身份或实际调用/产物证据不符')
    expected = []
    if job["route"] == "fc":
        expected.append(root / "BATCH_COMPLETE.mat")
    for row in job["expected_runs"]:
        # GLM 的 psy.run_output_dir 使用 sub-/ses-；Function 包直接使用身份值。
        subject = "sub-" + row["subject"] if job["route"] in {"glm", "preprocess"} else row["subject"]
        directory = root / subject
        if row["session"]:
            directory /= "ses-" + row["session"] if job["route"] in {"glm", "preprocess"} else row["session"]
        directory /= row["run"]
        if job["route"] == "fc":
            expected.extend(directory / name for name in ("COMPLETE.mat", "fc_r.tsv", "static_fc.mat", "roi_timeseries.mat", "roi_coverage.tsv"))
        elif job["route"] == "glm":
            expected.extend(directory / name for name in ("GLM_FRAMEWORK_COMPLETE.mat", "model_outputs.tsv"))
            markers = list((directory / "models").glob("*/COMPLETE.mat"))
            if not markers:
                raise ValueError(f"缺少 GLM 模型完成标记: {directory}")
            for marker in markers:
                expected.extend([marker, marker.parent / "SPM.mat"])
        elif job["route"] == "preprocess":
            expected.extend(directory / name for name in ("COMPLETE.mat", "input_info.mat", "preprocessing_plan.json"))
    for value in result.get("output_files", []):
        expected.append(Path(value))
    for file in expected:
        if not _inside(file, root) or not file.is_file():
            raise ValueError(f"缺少或越界的分析产物: {file}")
    return [_record(p, "output") for p in sorted(set(expected))]


def execute(project_dir, attempt_id, review_digest, confirmation, runner=None):
    project, project_state, attempt, state = _get_attempt(project_dir, attempt_id)
    if confirmation != CONFIRMATION_PHRASE:
        raise ValueError("用户审阅具体方案并明确同意后，确认字段须为“确认执行”")
    with _lock(attempt):
        # 加锁前的状态可能已过期，重复调用不得把成功状态改为 invalidated。
        state = _read(attempt / "state.json")
        if state["phase"] != "awaiting_confirmation":
            raise ValueError("此尝试不在等待确认状态；已完成/失败/中断的尝试均不自动重跑")
        if not isinstance(review_digest, str) or review_digest != state["review_digest"]:
            raise ValueError("审阅摘要不符，需重新展示并确认当前具体方案")
        import review_policy
        review_policy.require_approval(attempt, state, _read(attempt/'review.json'))
        _, project_state, _ = project_api.ensure_project(project)
        try:
            if sha256(attempt / "review.json") != review_digest or sha256(attempt / "review.md") != state["review_markdown_sha256"]:
                raise ValueError("审阅方案文件已变更，不能沿用旧确认")
            review = _read(attempt / "review.json")
            if str(_safe_child(project, project_state["current_revision"])) != review["revision"]:
                raise ValueError("项目已有新的问答/计划修订，请重新预检和确认")
            if review["attempt_id"] != attempt.name or review["project_dir"] != str(project):
                raise ValueError("审阅方案身份不符")
            _verify(review["frozen_files"])
            _verify_code(review["code_groups"])
            if review['route']=='toolkit_method':
                import native_jobs
                native_jobs.check_directory_inputs(review)
            job_file = attempt / "execution_job.json"
            job = _read(job_file)
            output = Path(job["output_root"])
            expected_output = attempt / "results" / "preprocessing" if job["route"] == "preprocess" else attempt / "results"
            if output != expected_output or output.exists() or (job["route"] == "preprocess" and (attempt / "results").exists()) or not _inside(job["work_root"], attempt):
                raise ValueError("结果位置异常或已存在，禁止覆盖")
        except Exception as exc:
            _state(attempt, "invalidated", error=str(exc), retry_policy="new_attempt_only")
            raise
        _json(attempt / "approval.json", {"review_digest": review_digest, "confirmation": confirmation,
                                         "recorded_utc": project_api.now(), "scope": "this_exact_attempt_only"})
        _state(attempt, "running", approval_digest=sha256(attempt / "approval.json"), owner_pid=os.getpid())
        try:
            result = _invoke(job_file, review["matlab_executable"], runner)
            _verify(review["frozen_files"])
            _verify_code(review["code_groups"])
            outputs = _check_outputs(job, result)
            extra_state = {}
            if review["route"] == "preprocess_glm":
                import preprocessing
                result, outputs = preprocessing.finish_pipeline(attempt, review, result, outputs, runner=runner)
                extra_state = {"preprocessing_output_root": str(output), "glm_output_root": str(attempt / "results" / "glm")}
                output = attempt / "results"
            _json(attempt / "receipt.json", {"status": "complete", "review_digest": review_digest,
                                            "outputs": outputs, "result": result, "stages": result.get("stages", []),
                                            "scientific_qc_passed": False})
            finished = _state(attempt, "complete", receipt_sha256=sha256(attempt / "receipt.json"),
                              output_root=str(output), stage="complete", scientific_qc_passed=False, **extra_state)
            import workflow_report
            return workflow_report.after_execution(project, finished)
        except Exception as exc:
            failed = _state(attempt, "execution_failed", error=str(exc), retry_policy="new_attempt_only",
                            partial_outputs_preserved=True)
            import workflow_report
            return workflow_report.after_execution(project, failed)


def status(project_dir, attempt_id=None):
    project, project_state, attempt, state = _get_attempt(project_dir, attempt_id, require_data_root=False)
    result = dict(state)
    result["source_available"] = Path(project_state["data_root"]).is_dir()
    if state["phase"] in {"running", "preflighting"}:
        result["phase"] = "running_or_interrupted"
        result["note"] = "未确认后台进程是否仍在运行；检查日志和结构化结果，不自动重试"
        result["operation_lock_present"] = (attempt / "operation.lock").exists()
    if state["phase"] == "awaiting_confirmation":
        try:
            if sha256(attempt / "review.json") != state["review_digest"] or sha256(attempt / "review.md") != state["review_markdown_sha256"]:
                raise ValueError("审阅文件变更")
            review = _read(attempt / "review.json")
            if str(_safe_child(project, project_state["current_revision"])) != review["revision"]:
                raise ValueError("计划修订已变化")
            _verify(review["frozen_files"])
            _verify_code(review["code_groups"])
            result["note"] = "预检已通过，仍需用户审阅此具体版本并明确确认执行"
        except (OSError, ValueError) as exc:
            result["phase"] = "needs_new_preflight"
            result["note"] = str(exc)
    if state["phase"] == "complete":
        receipt_file = attempt / "receipt.json"
        if not receipt_file.is_file() or sha256(receipt_file) != state["receipt_sha256"]:
            result["phase"] = "outputs_changed"
        else:
            receipt = _read(receipt_file)
            missing = [x["path"] for x in receipt["outputs"] if not Path(x["path"]).is_file()
                       or Path(x["path"]).stat().st_size != x["bytes"]]
            if missing:
                result["phase"], result["missing_or_resized_outputs"] = "outputs_changed", missing
            result["output_check_scope"] = "existence_and_size; full SHA256 values retained in receipt.json"
    return result
