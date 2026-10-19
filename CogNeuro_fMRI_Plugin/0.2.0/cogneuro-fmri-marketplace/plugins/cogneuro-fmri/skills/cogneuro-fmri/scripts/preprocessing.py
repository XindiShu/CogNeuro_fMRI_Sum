"""原始输入预处理与基于完成记录的GLM交接；科学选择在执行前冻结。"""
from __future__ import annotations

import json
from pathlib import Path
import re
import shutil

import fmri_project as project_api

PREP_ROUTES = {"preprocess", "preprocess_glm"}
# [约束] 只允许科学选项，不开放执行开关、输入/输出路径或任意配置代码。
ALLOWED_OVERRIDES = set("""
sliceTiming.enabled sliceTiming.mode sliceTiming.seconds sliceTiming.referenceSeconds
sliceTiming.acquisitionTimeSeconds sliceTiming.reference sliceTiming.microtimeResolution
realign.quality realign.separationMm realign.smoothingFwhmMm realign.registerToMean
realign.estimateInterpolation realign.writeInterpolation realign.wrap realign.mask
segment.backend segment.biasRegularisation segment.biasFwhmMm segment.gaussians
segment.affineRegistration segment.mrf segment.cleanup segment.warpRegularisation
segment.warpSamplingMm segment.deformationFields segment.saveBias segment.smoothnessMm
segment.nativeOutputs segment.warpedOutputs coreg.costFunction coreg.separationMm
coreg.smoothingFwhmMm coreg.tolerance voxelSizeMm boundingBoxMm normalise.method
normalise.interpolation smoothingFwhmMm smooth.dataType smooth.implicitMasking
smooth.prefix qc.enabled qc.maskFraction qc.maxResliceNonfiniteFraction fdRadiusMm
fdFlagMm sdc.method
""".split())


def normalized_options(plan):
    import execution as ctl
    choices = plan["parameter_choices"]
    def confirmed(name):
        value, valid = project_api.fact_value(choices, name)
        if not valid:
            raise ValueError(f"需要确认 parameter_choices.{name} 及真实来源")
        return value
    prep = confirmed("preprocessing_options")
    ctl._exact(prep, {"stop_after", "toolkit_config_sha256", "overrides"}, "preprocessing_options")
    if prep["stop_after"] not in ("realign", "segment", "smooth"):
        raise ValueError("stop_after 只支持 realign/segment/smooth")
    if not isinstance(prep["toolkit_config_sha256"], str) or not re.fullmatch(r"[0-9a-fA-F]{64}", prep["toolkit_config_sha256"]):
        raise ValueError("必须确认实际 toolkit_config.m 的 SHA256")
    overrides = prep["overrides"]
    if not isinstance(overrides, list):
        raise ValueError("overrides 必须为 {path,value} 数组，空数组表示明确沿用已审阅配置")
    paths = set()
    for option in overrides:
        ctl._exact(option, {"path", "value"}, "preprocessing override")
        name = option["path"]
        if not isinstance(name, str) or name not in ALLOWED_OVERRIDES or name.lower() in paths:
            raise ValueError("预处理 override 路径不允许或重复")
        paths.add(name.lower())
        if name in {"sdc.method", "segment.backend", "normalise.method"}:
            required = {"sdc.method": "none", "segment.backend": "spm", "normalise.method": "segmentation"}[name]
            if option["value"] != required:
                raise ValueError(f"本版执行仅支持 {name}={required}")
        # JSON严格有限；详细菜单数值约束由原生预检和MATLAB适配器校验。
        json.dumps(option["value"], allow_nan=False)
    budget = confirmed("execution_options")
    ctl._exact(budget, {"max_matrix_gib"}, "execution_options")
    ctl._number(budget["max_matrix_gib"], "max_matrix_gib", positive=True)
    for row in plan["runs"]:
        if row["values"].get("input_stage") != "raw" or row["values"].get("sdc_method") != "none":
            raise ValueError("本版预处理接入限定 raw 输入、明确的 sdc_method=none")
    result = {"preprocessing": prep, **budget}
    if plan["route"] == "preprocess_glm":
        handoff = confirmed("handoff_options")
        ctl._exact(handoff, {"bold_source", "include_tissue_means"}, "handoff_options")
        if handoff["bold_source"] not in ("realigned", "normalized_unsmoothed", "smoothed"):
            raise ValueError("必须明确选择交接的 realigned/normalized_unsmoothed/smoothed 产物")
        if handoff["bold_source"] != "realigned" and prep["stop_after"] != "smooth":
            raise ValueError("标准化或平滑产物需要 stop_after=smooth")
        if handoff["include_tissue_means"] is not False:
            raise ValueError("本版自动交接仅运动混杂，不生成或伪造 WM/CSF 均值")
        glm = ctl.normalized_options({**plan, "route": "glm"})
        if glm["glm"]["confounds"]["include_tissue_means"]:
            raise ValueError("自动交接未提取组织均值，GLM不可声明 include_tissue_means=true")
        result.update(handoff=handoff, glm_options=glm)
    return result


def prepare(project_dir, matlab_executable, spm_root, runner=None):
    import execution as ctl
    project, revision, inventory, answers, plan = ctl._current(project_dir)
    options = normalized_options(plan)
    executable, spm = Path(matlab_executable).expanduser(), Path(spm_root).expanduser()
    if not executable.is_absolute() or not executable.is_file() or not spm.is_absolute() or not (spm/"spm.m").is_file():
        raise ValueError("需要真实 MATLAB 程序和 SPM 根目录的绝对路径")
    executable, spm = executable.resolve(), spm.resolve()
    toolkit = Path(plan["toolkit_roots"]["preprocessing"]).resolve()
    config = toolkit/"config/toolkit_config.m"
    if not config.is_file() or ctl.sha256(config).lower() != options["preprocessing"]["toolkit_config_sha256"].lower():
        raise ValueError("预处理官方配置 SHA256 与确认值不符，先重新审阅当前文件")
    selected_roots = [toolkit, spm, ctl.SKILL_ROOT]
    if plan["route"] == "preprocess_glm":
        selected_roots.append(Path(plan["toolkit_roots"]["glm"]).resolve())
    for root in selected_roots:
        if ctl._inside(project, root) or ctl._inside(root, project):
            raise ValueError("项目目录不能与任一工具包、SPM或skill互相包含")
    executions = ctl._safe_child(project, "execution")
    executions.mkdir(exist_ok=True)
    for number in range(1, 1000000):
        attempt = executions/f"{number:04d}"
        try:
            attempt.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise ValueError("执行尝试数量超限")
    with ctl._lock(attempt):
        ctl._state(attempt, "preflighting", route=plan["route"], revision=str(revision))
        try:
            frozen = [ctl._record(revision/"answers.json", "answers"), ctl._record(revision/"plan.json", "plan"),
                      ctl._record(project/"inventory.json", "inventory"), ctl._record(executable, "matlab_launcher"),
                      ctl._record(config, "official_preprocessing_config")]
            groups = [ctl._code_snapshot(root, "selected_code") for root in selected_roots if root != ctl.SKILL_ROOT]
            groups.append(ctl._code_snapshot(ctl.SKILL_ROOT/"matlab", "adapter_source"))
            frozen.extend(ctl._record(p, "planner_source") for p in sorted((ctl.SKILL_ROOT/"scripts").glob("*.py")))
            if options["preprocessing"]["stop_after"] != "realign":
                frozen.append(ctl._record(spm/"tpm/TPM.nii", "SPM_tissue_prior"))
            inputs = attempt/"inputs"
            inputs.mkdir()
            staged, expected, originals = [], [], []
            for index, item in enumerate(plan["runs"], 1):
                values = dict(item["values"])
                row = dict(values)
                folder = inputs/f"run_{index:04d}"
                folder.mkdir()
                fields = ["bold", "t1", "metadata", "events"]
                if plan["route"] == "preprocess_glm": fields.append("mask")
                for field in fields:
                    value = values.get(field, "")
                    if not value: continue
                    suffix = ".nii.gz" if str(value).lower().endswith(".nii.gz") else Path(value).suffix
                    copied, records = ctl._copy_source(value, folder/(field+suffix))
                    row[field] = str(copied)
                    frozen.extend(records)
                staged.append(row)
                exp = {name: values[name] for name in ("subject", "session", "run", "tr_seconds")}
                if plan["route"] == "preprocess_glm": exp["mask"] = row["mask"]
                expected.append(exp)
                originals.append({"run_id": item["run_id"], **values})
            manifest = attempt/"runs.tsv"
            project_api.tsv(manifest, project_api.PRE_COLUMNS, staged)
            frozen.append(ctl._record(manifest, "execution_manifest"))
            adapter = attempt/"adapter"
            adapter.mkdir()
            for source in sorted((ctl.SKILL_ROOT/"matlab").glob("*.m")):
                destination = adapter/source.name
                shutil.copyfile(source, destination)
                frozen.append(ctl._record(destination, "adapter_copy"))
            groups.append(ctl._code_snapshot(adapter, "adapter_private_code"))
            base = {"schema_version": 1, "route": "preprocess", "toolkit_root": str(toolkit),
                    "spm_root": str(spm), "manifest_file": str(manifest),
                    "output_root": str(attempt/"results/preprocessing"),
                    "options": {"preprocessing": options["preprocessing"], "max_matrix_gib": options["max_matrix_gib"]},
                    "expected_runs": expected}
            pre = {**base, "mode": "preflight", "work_root": str(attempt/"preflight_work"),
                   "result_file": str(attempt/"preflight_result.json")}
            execute = {**base, "mode": "execute", "work_root": str(attempt/"execution_work"),
                       "result_file": str(attempt/"execution_result.json")}
            ctl._json(attempt/"preflight_job.json", pre)
            ctl._json(attempt/"execution_job.json", execute)
            frozen.extend(ctl._record(attempt/name, name) for name in ("preflight_job.json", "execution_job.json"))
            preflight = ctl._invoke(attempt/"preflight_job.json", executable, runner)
            ctl._verify(frozen)
            ctl._verify_code(groups)
            frozen.append(ctl._record(attempt/"preflight_result.json", "preflight_result"))
            review = {"schema_version": 1, "skill_version": project_api.VERSION, "attempt_id": attempt.name,
                      "project_dir": str(project), "revision": str(revision), "route": plan["route"],
                      "goal": answers["goal"], "paradigm": answers["paradigm"], "independent_unit": answers["independent_unit"],
                      "runs": originals, "staged_expected_runs": expected, "options": options,
                      "parameter_choices": plan["parameter_choices"], "verified_facts": plan["verified_facts"],
                      "toolkit_root": str(toolkit), "toolkit_roots": plan["toolkit_roots"], "spm_root": str(spm),
                      "matlab_executable": str(executable), "output_root": str(attempt/"results"),
                      "preflight": preflight, "frozen_files": frozen, "code_groups": groups,
                      "scientific_qc_passed": False, "execution_ready": False,
                      "deferred_checks": ["预处理后按确认policy选择真实完成产物", "交接帧数/事件零点/运动混杂/掩膜网格",
                                          "实际GLM设计可估计性；失败时不进行估计"] if plan["route"] == "preprocess_glm" else []}
            import review_policy
            review['additional_review_notes'] = '\n## 本次预处理范围\n\n按确认配置调用原生SPM步骤；私有副本停止点：'+options['preprocessing']['stop_after']+'。\n'
            if plan['route']=='preprocess_glm':
                review['additional_review_notes'] += '预处理→实际完成记录交接→GLM设计预检→条件GLM。输入尚未产生，设计尚未验证；交接或设计检查失败则停止，保留产物。\n'
            review['additional_review_notes'] += '旧专用路线不包含SDC/CAT/群体配准；不自动新增参数、重采样分析掩膜、补造组织信号或再次平移事件。科研QC仍待人工审查。\n'
            review_policy.initialize(review,answers)
            ctl._json(attempt/'parameter_assessment.template.json',review_policy.template(review))
            ctl._json(attempt/"review.json", review)
            text = ctl._review_markdown(review)
            (attempt/"review.md").write_text(text, encoding="utf-8")
            return ctl._state(attempt, "awaiting_confirmation", review_digest=ctl.sha256(attempt/"review.json"),
                              review_path=str(attempt/"review.md"), review_markdown_sha256=ctl.sha256(attempt/"review.md"),
                              job_file=str(attempt/"execution_job.json"))
        except Exception as exc:
            return ctl._state(attempt, "preflight_failed", error=str(exc), retry_policy="new_attempt_only")


def finish_pipeline(attempt, review, preprocessed, outputs, runner=None):
    import execution as ctl
    expected = review["staged_expected_runs"]
    runtime = list(outputs) + [ctl._record(attempt/"execution_result.json", "preprocessing_result")]
    evidence = []
    stages = [{"stage": "preprocessing", "route": "preprocess", "mode": "execute",
               "result_file": str(attempt/"execution_result.json")}]
    def invoke(stage, job, filename):
        ctl._verify(runtime)
        ctl._verify(evidence)
        ctl._verify(review["frozen_files"])
        ctl._verify_code(review["code_groups"])
        target = attempt/filename
        ctl._json(target, job)
        job_record = ctl._record(target, "pipeline_job")
        ctl._state(attempt, "running", stage=stage)
        result = ctl._invoke(target, review["matlab_executable"], runner)
        ctl._verify(runtime)
        ctl._verify(evidence)
        ctl._verify([job_record])
        ctl._verify(review["frozen_files"])
        ctl._verify_code(review["code_groups"])
        evidence.extend([job_record, ctl._record(Path(job["result_file"]), "pipeline_result")])
        stages.append({"stage": stage, "route": job["route"], "mode": job["mode"], "result_file": job["result_file"]})
        return result
    handoff_job = {"schema_version": 1, "route": "handoff", "mode": "execute",
                   "toolkit_root": review["toolkit_root"], "spm_root": review["spm_root"],
                   "output_root": str(attempt/"results/preprocessing/handoff"),
                   "preprocessing_result_file": str(attempt/"execution_result.json"),
                   "options": review["options"]["handoff"], "expected_runs": expected,
                   "result_file": str(attempt/"handoff_result.json")}
    handoff = invoke("handoff", handoff_job, "handoff_job.json")
    manifest = Path(handoff["manifest_file"])
    if not ctl._inside(manifest, Path(handoff_job["output_root"])) or not manifest.is_file():
        raise ValueError("交接清单不在本次新输出内")
    handoff_files = [Path(value) for value in handoff.get("output_files", [])]
    if manifest not in handoff_files: handoff_files.append(manifest)
    for path in handoff_files:
        if not ctl._inside(path, Path(handoff_job["output_root"])):
            raise ValueError("交接产物越界")
        runtime.append(ctl._record(path, "handoff_output"))
    # 原生handoff已检查身份；Python再次核对用于后续GLM的身份集合与TR。
    rows = handoff.get("runs", [])
    if isinstance(rows, dict): rows = [rows]
    def key(row): return tuple(str(row[name]).lower() for name in ("subject", "session", "run"))
    exp = {key(row): row for row in expected}
    if len(rows) != len(expected) or {key(row) for row in rows} != set(exp):
        raise ValueError("交接运行身份与已确认方案不符")
    for row in rows:
        if abs(row["tr_seconds"]-exp[key(row)]["tr_seconds"]) > 1e-5:
            raise ValueError("交接 TR 与确认值不符")
    glm_base = {"schema_version": 1, "route": "glm", "toolkit_root": review["toolkit_roots"]["glm"],
                "spm_root": review["spm_root"], "manifest_file": str(manifest),
                "output_root": str(attempt/"results/glm"), "options": review["options"]["glm_options"],
                "expected_runs": [{name: row[name] for name in ("subject", "session", "run", "tr_seconds")} for row in expected]}
    glm_pre = {**glm_base, "mode": "preflight", "work_root": str(attempt/"glm_preflight_work"),
               "result_file": str(attempt/"glm_preflight_result.json")}
    checked = invoke("glm_preflight", glm_pre, "glm_preflight_job.json")
    glm_job = {**glm_base, "mode": "execute", "work_root": str(attempt/"glm_execution_work"),
               "result_file": str(attempt/"glm_execution_result.json")}
    completed = invoke("glm_execute", glm_job, "glm_execution_job.json")
    glm_outputs = ctl._check_outputs(glm_job, completed)
    result = {"status": "complete", "route": "preprocess_glm", "stages": stages,
              "preprocessing": preprocessed, "handoff": handoff, "glm_preflight": checked,
              "glm": completed, "scientific_qc_passed": False}
    return result, runtime+glm_outputs+evidence
