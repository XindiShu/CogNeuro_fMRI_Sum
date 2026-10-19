"""Synthetic raw-preprocessing transactions; callbacks never start MATLAB."""
from __future__ import annotations

import csv
import gzip
import json
from pathlib import Path
import shutil
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_execution as base_helpers

execution = base_helpers.execution
project_module = base_helpers.project_module
fact = base_helpers.fact
nifti1 = base_helpers.nifti1
read_json = base_helpers.read_json
digest = base_helpers.digest


class PreprocessingExecutionTests(unittest.TestCase):
    put = base_helpers.ExecutionTests.put
    prepare = base_helpers.ExecutionTests.prepare
    execute = base_helpers.ExecutionTests.execute
    source_snapshot = base_helpers.ExecutionTests.source_snapshot
    tearDown = base_helpers.ExecutionTests.tearDown

    def setUp(self):
        base_helpers.ExecutionTests.setUp(self)
        self.t1 = self.put("sub-01/anat/sub-01_T1w.nii", nifti1((2, 2, 2)))
        self.metadata = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_bold.json",
                                 b'{"RepetitionTime":2.0,"EchoTime":0.03}')
        prior = self.spm / "tpm" / "TPM.nii"
        prior.parent.mkdir()
        prior.write_bytes(nifti1((2, 2, 2, 6)))
        self.preprocessing_root = Path(self.toolkits["preprocessing"])
        self.official_config = self.preprocessing_root / "config" / "toolkit_config.m"
        self.official_config.parent.mkdir(parents=True, exist_ok=True)
        self.official_config.write_text("function cfg=toolkit_config\ncfg.execute=false;\nend\n", encoding="utf-8")
        self.fail_stage = None
        self.created_stage_outputs = []

    def answers(self, inventory, route="preprocess_glm"):
        answers = base_helpers.ExecutionTests.answers(self, inventory, "glm")
        answers["route"] = route
        for answer in answers["runs"].values():
            answer["facts"].update({key: fact(value) for key, value in {
                "input_stage": "raw", "t1": str(self.t1), "metadata": str(self.metadata),
                "sdc_method": "none", "discard_volumes": 2, "event_reference": "original_first_volume",
                "mask": str(self.mask)}.items()})
        choices = answers["parameter_choices"]
        choices["preprocessing_options"] = fact({
            "stop_after": "realign" if route == "preprocess" else "smooth",
            "toolkit_config_sha256": digest(self.official_config), "overrides": []})
        choices["handoff_options"] = fact({"bold_source": "smoothed", "include_tissue_means": False})
        if route == "preprocess":
            for name in ("conditions", "contrasts", "glm_options", "handoff_options"):
                choices.pop(name)
        return answers

    def build_project(self, route="preprocess_glm", mutate=None):
        return base_helpers.ExecutionTests.build_project(self, route, mutate)

    def put_output(self, path, content=b"Synthetic stage artifact"):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        self.created_stage_outputs.append(str(path))
        return str(path)

    @staticmethod
    def read_rows(path):
        with Path(path).open(encoding="utf-8-sig", newline="") as handle:
            return list(csv.DictReader(handle, delimiter="\t"))

    @staticmethod
    def native_run_dir(root, row):
        directory = Path(root) / ("sub-" + row["subject"])
        if row.get("session"):
            directory /= "ses-" + row["session"]
        return directory / row["run"]

    def fake_runner(self, job_file, matlab_executable):
        self.assertEqual(Path(matlab_executable), self.matlab.resolve())
        job = read_json(job_file)
        self.calls.append(job)
        label = "glm_preflight" if job["route"] == "glm" and job["mode"] == "preflight" else job["route"]
        if self.fail_stage == label:
            if job["mode"] == "execute":
                self.put_output(Path(job["output_root"]) / "partial-stage.txt", b"preserve failed stage")
            return {"status": "failed", "message": "synthetic " + label + " failure", "runs": []}
        if job["route"] == "preprocess":
            return self.fake_preprocessing(job)
        if job["route"] == "handoff":
            return self.fake_handoff(job)
        if job["route"] == "glm":
            return self.fake_glm(job)
        raise AssertionError("An unreviewed route was dispatched: " + str(job["route"]))

    def fake_preprocessing(self, job):
        manifests = self.read_rows(job["manifest_file"])
        outputs, runs = [], []
        for row, expected in zip(manifests, job["expected_runs"]):
            dummy = int(row["discard_volumes"])
            retained = 8 - dummy
            result = {**expected, "retained_frames": retained, "output_path": "", "completion_marker": "",
                      "realigned_bold": "", "normalized_bold": "", "smoothed_bold": "",
                      "motion_file": "", "adjusted_events": "", "plan_file": ""}
            if job["mode"] == "preflight":
                result["plan_file"] = self.put_output(self.native_run_dir(Path(job["work_root"]) / "input_checks", row) / "header.mat")
                outputs.append(result["plan_file"])
            else:
                directory = self.native_run_dir(job["output_root"], row)
                result["output_path"] = str(directory)
                result["completion_marker"] = self.put_output(directory / "COMPLETE.mat")
                outputs.append(self.put_output(directory / "input_info.mat"))
                result["realigned_bold"] = self.put_output(directory / "func" / "realigned.nii", nifti1((2, 2, 2, retained)))
                stop = job["options"]["preprocessing"]["stop_after"]
                if stop == "smooth":
                    result["normalized_bold"] = self.put_output(directory / "func" / "normalized.nii", nifti1((2, 2, 2, retained)))
                    result["smoothed_bold"] = self.put_output(directory / "func" / "smoothed.nii", nifti1((2, 2, 2, retained)))
                result["motion_file"] = self.put_output(directory / "func" / "rp_motion.txt", ("0 0 0 0 0 0\n" * retained).encode())
                if row.get("events"):
                    events = self.read_rows(row["events"])
                    shift = dummy * expected["tr_seconds"] if row["event_reference"] == "original_first_volume" else 0
                    content = "onset\tduration\ttrial_type\n" + "".join(
                        f"{float(event['onset']) - shift:g}\t{event['duration']}\t{event['trial_type']}\n" for event in events)
                    result["adjusted_events"] = self.put_output(directory / "dummy_trim" / "events_retained_first_volume.tsv", content.encode())
                plan = {"dummy": {"count": dummy, "eventShiftSeconds": dummy * expected["tr_seconds"]},
                        "input_events": row.get("events", ""), "stop_after": stop}
                result["plan_file"] = self.put_output(directory / "preprocessing_plan.json", json.dumps(plan).encode())
                for field in ("completion_marker", "realigned_bold", "normalized_bold", "smoothed_bold",
                              "motion_file", "adjusted_events", "plan_file"):
                    if result[field]:
                        outputs.append(result[field])
            runs.append(result)
        return {"schema_version": 1, "route": "preprocess", "mode": job["mode"],
                "status": "preflight_passed" if job["mode"] == "preflight" else "complete", "runs": runs,
                "output_files": outputs, "validation_scope": "synthetic callback only",
                "resolved_preprocessing_config": {"stopAfter": job["options"]["preprocessing"]["stop_after"]}}

    def fake_handoff(self, job):
        source = read_json(job["preprocessing_result_file"])
        expected = {(row["subject"], row["session"], row["run"]): row for row in job["expected_runs"]}
        source_field = {"realigned": "realigned_bold", "normalized_unsmoothed": "normalized_bold", "smoothed": "smoothed_bold"}[job["options"]["bold_source"]]
        outputs, runs = [], []
        for row in source["runs"]:
            identity = {key: row[key] for key in ("subject", "session", "run")}
            key = tuple(identity[field] for field in ("subject", "session", "run"))
            directory = self.native_run_dir(job["output_root"], row)
            # Native dummy adjustment is authoritative. Handoff copies its exact bytes.
            events = self.put_output(directory / "events.tsv", Path(row["adjusted_events"]).read_bytes())
            confounds = self.put_output(directory / "confounds.tsv", ("motion\n" + "0\n" * row["retained_frames"]).encode())
            outputs.extend([events, confounds])
            runs.append({**identity, "tr_seconds": row["tr_seconds"], "n_frames": row["retained_frames"],
                         "bold": row[source_field], "events": events, "confounds": confounds,
                         "mask": expected[key]["mask"], "temporal_state": "unfiltered_unregressed",
                         "source_completion": row["completion_marker"]})
        manifest = Path(job["output_root"]) / "runs.tsv"
        project_module.tsv(manifest, project_module.GLM_COLUMNS + ["mask"], runs)
        self.created_stage_outputs.append(str(manifest))
        outputs.append(str(manifest))
        outputs.append(self.put_output(Path(job["output_root"]) / "handoff_provenance.json", json.dumps({"source": job["preprocessing_result_file"]}).encode()))
        return {"schema_version": 1, "route": "handoff", "mode": "execute", "status": "complete",
                "manifest_file": str(manifest), "runs": runs, "output_files": outputs}

    def fake_glm(self, job):
        if job["mode"] == "preflight":
            return {"status": "preflight_passed", "runs": [], "output_files": []}
        outputs = []
        for row in job["expected_runs"]:
            directory = self.native_run_dir(job["output_root"], row)
            for name in ("GLM_FRAMEWORK_COMPLETE.mat", "model_outputs.tsv", "models/joint/COMPLETE.mat",
                         "models/joint/SPM.mat", "models/joint/beta_0001.nii", "models/joint/con_0001.nii"):
                outputs.append(self.put_output(directory / name))
        return {"status": "complete", "runs": [], "output_files": outputs}

    def test_preprocess_only_plans_without_glm_materials(self):
        def no_task_materials(answers):
            for run in answers["runs"].values():
                run["facts"]["events"] = fact("")
                run["facts"]["event_reference"] = fact("unspecified")
                run["facts"].pop("mask")
                run["facts"].pop("confounds")
        self.build_project("preprocess", mutate=no_task_materials)
        prepared = self.prepare()
        self.assertEqual(prepared["phase"], "awaiting_confirmation")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [("preprocess", "preflight")])
        self.assertNotIn("glm", self.plan["toolkit_roots"])

    def test_prepare_stages_raw_inputs_and_defers_actual_glm_design(self):
        self.build_project()
        before, config_before = self.source_snapshot(), self.official_config.read_bytes()
        prepared = self.prepare()
        self.assertEqual(prepared["phase"], "awaiting_confirmation")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [("preprocess", "preflight")])
        row = self.read_rows(self.calls[0]["manifest_file"])[0]
        for field, source in (("bold", self.bold), ("t1", self.t1), ("metadata", self.metadata), ("events", self.events)):
            self.assertNotEqual(Path(row[field]), source)
            self.assertEqual(Path(row[field]).read_bytes(), source.read_bytes())
        review = read_json(Path(prepared["attempt_dir"]) / "review.json")
        self.assertEqual(review["options"]["handoff"]["bold_source"], "smoothed")
        self.assertEqual(review["options"]["glm_options"]["conditions"], ["A", "B"])
        self.assertIn("GLM", (Path(prepared["attempt_dir"]) / "review.md").read_text(encoding="utf-8"))
        self.assertEqual(before, self.source_snapshot())
        self.assertEqual(config_before, self.official_config.read_bytes())

    def test_confirmed_pipeline_orders_stages_and_adjusts_events_exactly_once(self):
        self.build_project()
        before = self.source_snapshot()
        prepared = self.prepare()
        result = self.execute(prepared)
        self.assertEqual(result["phase"], "complete")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [
            ("preprocess", "preflight"), ("preprocess", "execute"), ("handoff", "execute"),
            ("glm", "preflight"), ("glm", "execute")])
        handoff = self.calls[2]
        preprocessing = read_json(handoff["preprocessing_result_file"])
        source_events = Path(preprocessing["runs"][0]["adjusted_events"])
        glm_rows = self.read_rows(self.calls[3]["manifest_file"])
        self.assertEqual(Path(glm_rows[0]["events"]).read_bytes(), source_events.read_bytes())
        self.assertEqual([float(row["onset"]) for row in self.read_rows(glm_rows[0]["events"])], [-4.0, 0.0])
        self.assertEqual(glm_rows[0]["bold"], preprocessing["runs"][0]["smoothed_bold"])
        self.assertIn("sub-01", glm_rows[0]["bold"])
        self.assertIn("ses-01", glm_rows[0]["bold"])
        self.assertEqual(self.calls[3]["manifest_file"], self.calls[4]["manifest_file"])
        self.assertEqual(before, self.source_snapshot())

    def test_preprocess_only_execution_never_starts_handoff_or_glm(self):
        self.build_project("preprocess")
        prepared = self.prepare()
        self.assertEqual(self.execute(prepared)["phase"], "complete")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [("preprocess", "preflight"), ("preprocess", "execute")])
        review = read_json(Path(prepared["attempt_dir"]) / "review.json")
        self.assertEqual(review["options"]["preprocessing"]["stop_after"], "realign")
        self.assertNotIn("glm_options", review["options"])

    def test_raw_t1_is_required_even_for_realign_only(self):
        self.build_project("preprocess", mutate=lambda a: [run["facts"].pop("t1") for run in a["runs"].values()])
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_realign_only_cannot_authorize_smoothed_handoff(self):
        self.build_project(mutate=lambda a: a["parameter_choices"]["preprocessing_options"]["value"].update(stop_after="realign"))
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_multiple_subjects_and_sessions_keep_native_output_identity(self):
        second_bold = self.put("sub-02/ses-02/func/sub-02_ses-02_task-memory_run-02_bold.nii", nifti1())
        second_t1 = self.put("sub-02/anat/sub-02_T1w.nii", nifti1((2, 2, 2)) + b"subject 02")
        second_metadata = self.put("sub-02/ses-02/func/sub-02_ses-02_task-memory_run-02_bold.json", b'{"RepetitionTime":2.0}')
        inventory = project_module.scan_dataset(self.data)
        second_id = next(row["run_id"] for row in inventory["runs"] if row.get("bold") == str(second_bold))
        def add_second(answers):
            first = answers["selected_run_ids"][0]
            facts = {key: dict(value) for key, value in answers["runs"][first]["facts"].items()}
            facts.update({key: fact(value) for key, value in {"subject": "02", "session": "02", "run": "02",
                         "t1": str(second_t1), "metadata": str(second_metadata)}.items()})
            answers["selected_run_ids"].append(second_id)
            answers["runs"][second_id] = {"facts": facts}
        self.build_project(mutate=add_second)
        prepared = self.prepare()
        self.assertEqual(self.execute(prepared)["phase"], "complete")
        handoff_rows = self.read_rows(self.calls[3]["manifest_file"])
        self.assertEqual([(row["subject"], row["session"], row["run"]) for row in handoff_rows],
                         [("01", "01", "01"), ("02", "02", "02")])
        for row in handoff_rows:
            self.assertIn("sub-" + row["subject"], row["bold"])
            self.assertIn("ses-" + row["session"], row["bold"])
        self.assertEqual(len({row["bold"] for row in handoff_rows}), 2)

    def test_wrong_official_config_sha_is_rejected_before_matlab(self):
        self.build_project(mutate=lambda a: a["parameter_choices"]["preprocessing_options"]["value"].update(toolkit_config_sha256="0" * 64))
        try:
            prepared = self.prepare()
        except ValueError:
            pass
        else:
            self.assertEqual(prepared["phase"], "preflight_failed")
        self.assertEqual(self.calls, [])

    def test_duplicate_override_paths_and_dispatch_overrides_are_rejected(self):
        for overrides in ([{"path": "sliceTiming.mode", "value": "off"}] * 2,
                          [{"path": "execute", "value": True}], [{"path": "outputRoot", "value": str(self.data)}]):
            with self.subTest(overrides=overrides):
                self.build_project(mutate=lambda a: a["parameter_choices"]["preprocessing_options"]["value"].update(overrides=overrides))
                with self.assertRaises(ValueError):
                    self.prepare()
                self.assertEqual(self.calls, [])
                shutil.rmtree(self.project)

    def test_unconfirmed_handoff_policy_prevents_raw_processing(self):
        self.build_project(mutate=lambda a: a["parameter_choices"]["handoff_options"].update(confirmed=False))
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_invalid_handoff_policy_or_tissue_means_is_rejected(self):
        for options in ({"bold_source": "auto", "include_tissue_means": False},
                        {"bold_source": "smoothed", "include_tissue_means": True}):
            with self.subTest(options=options):
                self.build_project(mutate=lambda a: a["parameter_choices"].update(handoff_options=fact(options)))
                with self.assertRaises(ValueError):
                    self.prepare()
                self.assertEqual(self.calls, [])
                shutil.rmtree(self.project)

    def test_pipeline_requires_confirmed_mask_before_preprocessing(self):
        self.build_project(mutate=lambda a: [run["facts"].pop("mask") for run in a["runs"].values()])
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_downstream_glm_code_is_frozen_before_raw_processing(self):
        self.build_project()
        prepared = self.prepare()
        source = Path(self.toolkits["glm"]) / "matlab" / "+psy" / "glm_batch.m"
        source.write_bytes(source.read_bytes() + b"\n% changed\n")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_preprocessing_config_change_invalidates_whole_pipeline(self):
        self.build_project()
        prepared = self.prepare()
        self.official_config.write_bytes(self.official_config.read_bytes() + b"\n% changed\n")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_handoff_failure_preserves_preprocessing_and_never_starts_glm(self):
        self.build_project()
        prepared = self.prepare()
        self.fail_stage = "handoff"
        result = self.execute(prepared)
        self.assertEqual(result["phase"], "execution_failed")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [
            ("preprocess", "preflight"), ("preprocess", "execute"), ("handoff", "execute")])
        self.assertTrue(any(Path(path).name == "COMPLETE.mat" and Path(path).is_file() for path in self.created_stage_outputs))
        self.assertTrue((Path(self.calls[-1]["output_root"]) / "partial-stage.txt").is_file())
        with self.assertRaises(ValueError):
            self.execute(prepared)

    def test_preprocessing_failure_preserves_partial_output_and_stops_pipeline(self):
        self.build_project()
        prepared = self.prepare()
        self.fail_stage = "preprocess"
        result = self.execute(prepared)
        self.assertEqual(result["phase"], "execution_failed")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [("preprocess", "preflight"), ("preprocess", "execute")])
        self.assertTrue((Path(self.calls[-1]["output_root"]) / "partial-stage.txt").is_file())
        self.assertFalse((Path(prepared["attempt_dir"]) / "receipt.json").exists())

    def test_failed_postprocessing_glm_design_never_estimates_images(self):
        self.build_project()
        prepared = self.prepare()
        self.fail_stage = "glm_preflight"
        result = self.execute(prepared)
        self.assertEqual(result["phase"], "execution_failed")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls], [
            ("preprocess", "preflight"), ("preprocess", "execute"), ("handoff", "execute"), ("glm", "preflight")])
        self.assertFalse((Path(prepared["attempt_dir"]) / "receipt.json").exists())

    def test_runtime_glm_job_change_cannot_receive_pipeline_receipt(self):
        self.build_project()
        prepared = self.prepare()
        def change_job(job_file, executable):
            job = read_json(job_file)
            if job["route"] == "glm" and job["mode"] == "execute":
                job["options"]["contrasts"][0]["weights"] = [-1, 1]
                Path(job_file).write_text(json.dumps(job), encoding="utf-8")
            return self.fake_runner(job_file, executable)
        result = self.execute(prepared, runner=change_job)
        self.assertEqual(result["phase"], "execution_failed")
        self.assertEqual(self.calls[-1]["options"]["contrasts"][0]["weights"], [-1, 1])
        self.assertFalse((Path(prepared["attempt_dir"]) / "receipt.json").exists())
        self.assertTrue(any(Path(path).name == "SPM.mat" and Path(path).is_file() for path in self.created_stage_outputs))

    def test_prior_stage_result_change_stops_before_glm_estimation(self):
        self.build_project()
        prepared = self.prepare()
        def change_prior_result(job_file, executable):
            job = read_json(job_file)
            if job["route"] == "glm" and job["mode"] == "preflight":
                previous = Path(prepared["attempt_dir"]) / "handoff_result.json"
                record = read_json(previous)
                record["unreviewed_note"] = "changed after its handoff stage"
                previous.write_text(json.dumps(record), encoding="utf-8")
            return self.fake_runner(job_file, executable)
        result = self.execute(prepared, runner=change_prior_result)
        self.assertEqual(result["phase"], "execution_failed")
        self.assertEqual([(j["route"], j["mode"]) for j in self.calls][-1], ("glm", "preflight"))
        self.assertFalse((Path(prepared["attempt_dir"]) / "receipt.json").exists())

    def test_receipt_covers_stage_outputs_and_complete_pipeline_is_not_repeated(self):
        self.build_project()
        prepared = self.prepare()
        self.assertEqual(self.execute(prepared)["phase"], "complete")
        receipt = read_json(Path(prepared["attempt_dir"]) / "receipt.json")
        self.assertEqual([item["stage"] for item in receipt["stages"]], [
            "preprocessing", "handoff", "glm_preflight", "glm_execute"])
        actual = {record["path"] for record in receipt["outputs"]}
        created_during_execution = {path for path in self.created_stage_outputs if "preflight_work" not in path}
        self.assertTrue(created_during_execution <= actual, created_during_execution - actual)
        before = len(self.calls)
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), before)

    def test_gzip_raw_is_only_decompressed_in_private_attempt(self):
        original = self.bold.read_bytes()
        compressed = self.bold.with_suffix(".nii.gz")
        compressed.write_bytes(gzip.compress(original))
        self.bold.unlink()
        self.bold = compressed
        self.build_project()
        before = self.source_snapshot()
        prepared = self.prepare()
        self.assertEqual(prepared["phase"], "awaiting_confirmation")
        staged = Path(self.read_rows(self.calls[0]["manifest_file"])[0]["bold"])
        self.assertEqual(staged.suffix, ".nii")
        self.assertEqual(staged.read_bytes(), original)
        self.assertEqual(before, self.source_snapshot())


if __name__ == "__main__":
    unittest.main()
