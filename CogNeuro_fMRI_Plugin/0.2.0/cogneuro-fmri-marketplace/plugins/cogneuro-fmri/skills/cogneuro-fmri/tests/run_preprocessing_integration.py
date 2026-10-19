"""合成raw→Realign/dummy→来源交接→SPM条件GLM；只用于开发验收。"""
from __future__ import annotations

import argparse
import csv
import gzip
import json
import math
from pathlib import Path
import random
import struct

from run_synthetic_integration import cli, digest, fact, nifti, write_json, reviewed


def contrast_mean(file, mask):
    """独立读取SPM的3D NIfTI-1浮点对比图，检查合成A>B方向。"""
    data = Path(file).read_bytes()
    endian = '<' if struct.unpack_from('<i',data)[0] == 348 else '>'
    assert struct.unpack_from(endian+'i',data)[0] == 348
    datatype = struct.unpack_from(endian+'h',data,70)[0]
    code = {16:'f',64:'d'}[datatype]
    offset = int(struct.unpack_from(endian+'f',data,108)[0])
    slope, intercept = struct.unpack_from(endian+'2f',data,112)
    if slope == 0: slope, intercept = 1, 0
    values = struct.unpack_from(endian+str(len(mask))+code,data,offset)
    selected = [value*slope+intercept for value,include in zip(values,mask) if include]
    assert all(math.isfinite(value) for value in selected)
    return sum(selected)/len(selected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("matlab-executable", "spm-root", "preprocessing-root", "glm-root", "output-root"):
        parser.add_argument("--" + name, required=True, help="[必填] 绝对路径；输出使用全新目录")
    args = parser.parse_args()
    output = Path(args.output_root).resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = output / "synthetic_source"
    source.mkdir()
    # [合成设定] 32×32×16、2mm、TR=2秒、66帧，删除前2帧，绝非正式研究推荐值。
    nx, ny, nz, frames, dummy, tr = 32, 32, 16, 66, 2, 2.0
    rng = random.Random(20261018)
    base, mask_values = [], []
    for z in range(nz):
        for y in range(ny):
            for x in range(nx):
                r = ((x-15.5)**2 + (y-15.5)**2 + 2*(z-7.5)**2)
                base.append(1000*math.exp(-r/85) + 50 + 90*math.exp(-((x-10)**2+(y-20)**2+(z-9)**2)/16))
                mask_values.append(int(11 <= x <= 20 and 11 <= y <= 20 and 5 <= z <= 10))
    dt, resolution = .125, 16
    hrf = [math.exp(-k*dt)*((k*dt)**5/math.gamma(6)-(k*dt)**15/(6*math.gamma(16))) for k in range(257)]
    scale = sum(hrf)
    hrf = [value/scale for value in hrf]
    onsets = [4+i*12 for i in range(10)]
    stimulus = [0.0]*(frames*resolution)
    for index, onset in enumerate(onsets):
        for tick in range(round(onset/dt), round((onset+2)/dt)):
            stimulus[tick] = 35 if index % 2 == 0 else -20
    values = []
    for frame in range(frames):
        tick = frame*resolution+7
        task = sum(hrf[k]*stimulus[tick-k] for k in range(min(tick,len(hrf)-1)+1))
        for voxel, intensity in enumerate(base):
            values.append(intensity*(1+task/1000) + rng.gauss(0,.25))
    bold = source / "sub-pilot_ses-baseline_task-test_run-01_bold.nii.gz"
    with gzip.open(bold,"wb") as handle:
        handle.write(nifti((nx,ny,nz,frames), values, tr=tr))
    t1, mask = source/"sub-pilot_T1w.nii", source/"analysis_mask.nii"
    t1.write_bytes(nifti((nx,ny,nz),base,tr=tr))
    mask.write_bytes(nifti((nx,ny,nz),mask_values,tr=tr))
    metadata = source/"sub-pilot_ses-baseline_task-test_run-01_bold.json"
    write_json(metadata,{"RepetitionTime":tr,"EchoTime":.03,"SyntheticTestOnly":True})
    events = source/"events.tsv"
    events.write_text("onset\tduration\ttrial_type\n"+"".join(f"{onset}\t2\t{'A' if i%2==0 else 'B'}\n" for i,onset in enumerate(onsets)),encoding="utf-8")
    config = Path(args.preprocessing_root)/"config/toolkit_config.m"
    before = {str(path):digest(path) for path in source.iterdir()}
    before[str(config)] = digest(config)
    write_json(output/"source_hashes_before.json",before)
    project = output/"pipeline_project"
    cli("scan","--data-root",source,"--project-dir",project)
    inventory = json.loads((project/"inventory.json").read_text(encoding="utf-8"))
    run_id = next(run["run_id"] for run in inventory["runs"] if run["bold"])
    facts = {"subject":"pilot","session":"baseline","run":"run1","input_stage":"raw","tr_seconds":tr,
             "t1":str(t1),"metadata":str(metadata),"events":str(events),"mask":str(mask),"sdc_method":"none",
             "discard_volumes":dummy,"event_reference":"original_first_volume"}
    options = {"conditions":fact(["A","B"]),"contrasts":fact([{"name":"A_minus_B","weights":[1,-1]}]),
               "execution_options":fact({"max_matrix_gib":.25}),
               "preprocessing_options":fact({"stop_after":"realign","toolkit_config_sha256":digest(config),
                   "overrides":[{"path":"qc.enabled","value":False},{"path":"sliceTiming.mode","value":"off"},
                                {"path":"realign.mask","value":False}]}),
               "handoff_options":fact({"bold_source":"realigned","include_tissue_means":False}),
               "glm_options":fact({"highpass_seconds":128,"microtime_resolution":16,"microtime_onset":8,
                   "serial_correlation":"AR(1)","hrf":"canonical","min_residual_df":10,"mask_threshold":.5,
                   "confounds":{"motion_model":"none","include_tissue_means":False,"linear_trend":False,
                                "add_spikes":False,"fd_threshold_mm":.5,"min_residual_df":10}})}
    # [合成约束] 幻影无真实运动；明确不将近零估计运动列放进GLM，仍校验完整运动交接输出。
    answers = {"schema_version":1,"route":"preprocess_glm","goal":"合成预处理到GLM工程接线验收，无科研推断",
               "paradigm":"合成双条件事件","independent_unit":"单个合成run",
               "selected_run_ids":[run_id],"toolkit_roots":{"preprocessing":args.preprocessing_root,"glm":args.glm_root},
               "runs":{run_id:{"facts":{name:fact(value) for name,value in facts.items()}}},"parameter_choices":options,
               "parameter_setup":fact("ready")}
    answer_file = project/"answers.json"
    write_json(answer_file,answers)
    planned = cli("plan","--project-dir",project,"--answers",answer_file)
    assert planned["phase"] == "draft_prepared", planned
    print("pipeline: isolated MATLAB raw-input preflight",flush=True)
    prepared = cli("prepare","--project-dir",project,"--matlab-executable",args.matlab_executable,"--spm-root",args.spm_root)
    assert prepared["phase"] == "awaiting_confirmation", prepared
    attempt = Path(prepared["attempt_dir"])
    assert not (attempt/"results").exists()
    print("pipeline: simulated development confirmation; preprocessing/handoff/GLM preflight/estimate",flush=True)
    prepared = reviewed(project,prepared)
    executed = cli("execute","--project-dir",project,"--attempt-id",prepared["attempt_id"],
                   "--review-digest",prepared["review_digest"],"--confirmation","确认执行")
    assert executed["phase"] == "complete", executed
    receipt = json.loads((attempt/"receipt.json").read_text(encoding="utf-8"))
    assert [stage["stage"] for stage in receipt["stages"]] == ["preprocessing","handoff","glm_preflight","glm_execute"]
    handed = receipt["result"]["handoff"]["runs"]
    row = handed[0] if isinstance(handed,list) else handed
    with Path(row["events"]).open(encoding="utf-8-sig",newline="") as handle:
        adjusted = list(csv.DictReader(handle,delimiter="\t"))
    assert [float(item["onset"]) for item in adjusted] == [onset-dummy*tr for onset in onsets]
    with Path(row["confounds"]).open(encoding="utf-8-sig",newline="") as handle:
        reader = csv.DictReader(handle,delimiter="\t")
        assert len(reader.fieldnames) == 25
        assert len(list(reader)) == frames-dummy
    assert row["n_frames"] == frames-dummy
    assert row["temporal_state"] == "unfiltered_unregressed"
    names = {Path(record["path"]).name for record in receipt["outputs"]}
    assert {"con_0001.nii","spmT_0001.nii","SPM.mat","COMPLETE.mat","handoff_provenance.json"} <= names
    contrast = next(record['path'] for record in receipt['outputs'] if Path(record['path']).name=='con_0001.nii')
    effect = contrast_mean(contrast,mask_values)
    assert effect > 0, effect
    for record in receipt["outputs"]:
        assert digest(Path(record["path"])) == record["sha256"]
    for file,sha in before.items():
        assert digest(Path(file)) == sha
    assert cli("execution-status","--project-dir",project)["phase"] == "complete"
    write_json(output/"integration_report.json",{"status":"passed","real_participant_data":False,
               "approval_simulated_for_development_only":True,"prepare":prepared,"execute":executed,
               "source_files_and_config_unchanged":len(before),"stages_verified":receipt["stages"],
               "retained_frames":frames-dummy,"event_shift_seconds":dummy*tr,"motion_columns_including_fd":25,
               "known_A_gt_B_mean_contrast":effect,
               "limitations":["Synthetic realign-only spatial path; no segmentation/normalisation/smoothing validation in this integration",
                              "Synthetic motion_model=none; full motion handoff is validated separately"]})
    print(str(output/"integration_report.json"),flush=True)


if __name__ == "__main__":
    main()
