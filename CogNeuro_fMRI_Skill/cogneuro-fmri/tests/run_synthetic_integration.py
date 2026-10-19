"""真实隔离 MATLAB 进程的微型 FC/GLM 端到端测试，绝不使用真实被试数据。"""
from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import subprocess
import sys

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0,str(SCRIPTS))
from approval_fixture import reviewed


def nifti(shape, values, tr=2.0):
    header = bytearray(352)
    struct.pack_into("<i", header, 0, 348)
    dimensions = [len(shape), *shape]
    struct.pack_into("<8h", header, 40, *(dimensions + [1] * (8 - len(dimensions))))
    struct.pack_into("<2h", header, 70, 16, 32)
    struct.pack_into("<8f", header, 76, 1, 2, 2, 2, tr, 1, 1, 1)
    struct.pack_into("<f", header, 108, 352)
    header[123] = 10
    struct.pack_into("<h", header, 254, 1)
    for index in range(3):
        row = [0.0] * 4
        row[index] = 2.0
        struct.pack_into("<4f", header, 280 + index * 16, *row)
    header[344:348] = b"n+1\0"
    return bytes(header) + struct.pack("<" + "f" * len(values), *values)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")


def fact(value):
    return {"value": value, "source": "开发合成测试的明确生成设置；不代表真实研究参数或用户分析确认", "confirmed": True}


def cli(*args):
    completed = subprocess.run([sys.executable, "-B", "-X", "utf8", str(SCRIPTS / "fmri_project.py"), *map(str, args)],
                               capture_output=True, text=True, encoding="utf-8", check=False)
    if completed.returncode:
        raise RuntimeError(completed.stdout + completed.stderr)
    return json.loads(completed.stdout)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pearson(x, y):
    xbar, ybar = sum(x) / len(x), sum(y) / len(y)
    a, b = [v - xbar for v in x], [v - ybar for v in y]
    return sum(v * w for v, w in zip(a, b)) / math.sqrt(sum(v * v for v in a) * sum(w * w for w in b))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("matlab-executable", "spm-root", "function-root", "glm-root", "output-root"):
        parser.add_argument("--" + name, required=True, help="[必填] 本机实际绝对路径；输出必须是新目录")
    parser.add_argument("--routes", nargs="+", choices=("fc", "glm"), default=["fc", "glm"],
                        help="[可调] 默认两条路线；修复后可只复测受影响路线，使用新输出目录")
    args = parser.parse_args()
    output = Path(args.output_root).resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = output / "synthetic_source"
    source.mkdir()
    rng = random.Random(20261017)
    n, voxels = 96, 27
    # 合成已知任务效应；SPM canonical 双gamma仅用于生成测试信号，不改估计标准。
    dt, resolution = 0.125, 16
    kernel = []
    for index in range(int(32 / dt) + 1):
        value = index * dt
        kernel.append(math.exp(-value) * (value ** 5 / math.gamma(6) - value ** 15 / (6 * math.gamma(16))))
    total = sum(kernel)
    kernel = [v / total for v in kernel]
    stimulus = [0.0] * (n * resolution)
    for event in range(11):
        start = round((4 + event * 16) / dt)
        for tick in range(start, start + round(2 / dt)):
            stimulus[tick] = 40.0 if event % 2 == 0 else -20.0
    task = []
    for frame in range(n):
        sample = frame * resolution + 7
        task.append(sum(kernel[k] * stimulus[sample - k] for k in range(min(sample, len(kernel) - 1) + 1)))
    series = [[], [], []]
    data = []
    for frame in range(n):
        values = []
        for voxel in range(voxels):
            label = voxel // 9
            signal = math.sin(frame / 7) + (label + 1) * math.cos(frame / (9 + label * 3))
            value = 100 + task[frame] + signal + rng.gauss(0, 0.3)
            # 与写入的 float32 数据一致，供独立相关系数核对。
            values.append(struct.unpack("<f", struct.pack("<f", value))[0])
        data.extend(values)
        for label in range(3):
            series[label].append(sum(values[label * 9:(label + 1) * 9]) / 9)
    bold = source / "sub-pilot_ses-baseline_task-test_run-01_desc-preproc_bold.nii.gz"
    with gzip.open(bold, "wb") as handle:
        handle.write(nifti((3, 3, 3, n), data))
    metadata = source / (bold.name[:-7] + ".json")
    write_json(metadata, {"RepetitionTime": 2.0, "EchoTime": 0.03, "SyntheticTestOnly": True})
    mask, roi = source / "mask.nii", source / "roi.nii"
    mask.write_bytes(nifti((3, 3, 3), [1] * voxels))
    roi.write_bytes(nifti((3, 3, 3), [v // 9 + 1 for v in range(voxels)]))
    events, confounds = source / "events.tsv", source / "confounds.tsv"
    events.write_text("onset\tduration\ttrial_type\n" + "".join(f"{4 + i * 16}\t2\t{'A' if i % 2 == 0 else 'B'}\n" for i in range(11)), encoding="utf-8")
    confounds.write_text("unused\n" + "".join(f"{i}\n" for i in range(n)), encoding="utf-8")
    before = {str(p): digest(p) for p in source.iterdir()}
    write_json(output / "source_hashes_before.json", before)
    reports = {}
    for route in args.routes:
        project = output / (route + "_project")
        cli("scan", "--data-root", source, "--project-dir", project)
        inventory = json.loads((project / "inventory.json").read_text(encoding="utf-8"))
        run_id = next(r["run_id"] for r in inventory["runs"] if r["bold"])
        values = {"subject": "pilot", "session": "baseline", "run": "run1", "input_stage": "preprocessed",
                  "tr_seconds": 2.0, "temporal_state": "unfiltered_unregressed", "smoothing_fwhm_mm": 0,
                  "confounds": "", "mask": str(mask), "roi_file": str(roi), "purpose": "rest"}
        choices = {"cleaning": fact({"detrend": False, "bandHz": [], "minResidualDimensions": 10}),
                   "fc_measure": fact("pearson"), "roi_definition": fact("合成三分区标签，每区9体素"),
                   "execution_options": fact({"max_matrix_gib": 0.25, "roi_min_voxels": 1})}
        if route == "glm":
            values.update(events=str(events), event_reference="retained_first_volume", discard_volumes=0, confounds=str(confounds))
            choices = {"conditions": fact(["A", "B"]), "contrasts": fact([{"name": "A_minus_B", "weights": [1, -1]}]),
                       "execution_options": fact({"max_matrix_gib": 0.25}),
                       "glm_options": fact({"highpass_seconds": 128, "microtime_resolution": 16, "microtime_onset": 8,
                                            "serial_correlation": "AR(1)", "hrf": "canonical", "min_residual_df": 10,
                                            "mask_threshold": 0.5, "confounds": {"motion_model": "none", "include_tissue_means": False,
                                                "linear_trend": False, "add_spikes": False, "fd_threshold_mm": 0.5, "min_residual_df": 10}})}
        answers = {"schema_version": 1, "route": route, "goal": "开发用合成流程验收，无科研显著性主张", "paradigm": "合成测试",
                   "independent_unit": "单个合成运行，无群体推断", "selected_run_ids": [run_id],
                   "toolkit_roots": {"function" if route == "fc" else "glm": args.function_root if route == "fc" else args.glm_root},
                   "runs": {run_id: {"facts": {k: fact(v) for k, v in values.items()}}}, "parameter_choices": choices,
                   "parameter_setup":fact("ready")}
        answer_file = project / "answers.json"
        write_json(answer_file, answers)
        cli("plan", "--project-dir", project, "--answers", answer_file)
        print(f"{route}: actual isolated MATLAB preflight", flush=True)
        prepared = cli("prepare", "--project-dir", project, "--matlab-executable", args.matlab_executable, "--spm-root", args.spm_root)
        if prepared["phase"] != "awaiting_confirmation":
            raise RuntimeError(prepared)
        review = json.loads((Path(prepared["attempt_dir"]) / "review.json").read_text(encoding="utf-8"))
        assert review["preflight"]["status"] == "preflight_passed"
        assert not Path(review["output_root"]).exists()
        print(f"{route}: synthetic-test approval and actual execution", flush=True)
        prepared = reviewed(project,prepared)
        executed = cli("execute", "--project-dir", project, "--attempt-id", prepared["attempt_id"],
                       "--review-digest", prepared["review_digest"], "--confirmation", "确认执行")
        assert executed["phase"] == "complete", executed
        assert cli("execution-status", "--project-dir", project)["phase"] == "complete"
        receipt = json.loads((Path(executed["attempt_dir"]) / "receipt.json").read_text(encoding="utf-8"))
        if route == "glm":
            output_names = {Path(item["path"]).name for item in receipt["outputs"]}
            assert {"con_0001.nii", "spmT_0001.nii", "beta_0001.nii", "ResMS.nii", "mask.nii"} <= output_names
        if route == "fc":
            with (Path(executed["output_root"]) / "pilot/baseline/run1/fc_r.tsv").open(encoding="utf-8") as handle:
                matrix = [[float(v) for v in row] for row in csv.reader(handle, delimiter="\t")]
            assert max(abs(matrix[i][j] - pearson(series[i], series[j])) for i in range(3) for j in range(3)) < 1e-6
        reports[route] = {"prepare": prepared, "execute": executed, "approval_simulated_for_development_only": True}
        print(f"{route}: complete", flush=True)
    assert {str(p): digest(p) for p in source.iterdir()} == before
    write_json(output / "integration_report.json", {"status": "passed", "real_participant_data": False,
               "source_files_unchanged": len(before), "fc_independent_pearson_agreement_tolerance": 1e-6, "routes": reports})
    print(str(output / "integration_report.json"), flush=True)


if __name__ == "__main__":
    main()
