"""Synthetic transaction tests; MATLAB callbacks never run real imaging software."""
from __future__ import annotations

import csv
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest import mock


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
import fmri_project as project_module
import execution
sys.path.insert(0, str(Path(__file__).resolve().parent))
from approval_fixture import reviewed

FIXTURE_SPEC = importlib.util.spec_from_file_location("execution_fixture_helpers", Path(__file__).with_name("test_project.py"))
assert FIXTURE_SPEC is not None and FIXTURE_SPEC.loader is not None
fixture_helpers = importlib.util.module_from_spec(FIXTURE_SPEC)
FIXTURE_SPEC.loader.exec_module(fixture_helpers)
fact = fixture_helpers.fact
nifti1 = fixture_helpers.nifti1


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


class ExecutionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.data = self.root / "data"
        self.data.mkdir()
        self.project = self.root / "project"
        self.bold = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_bold.nii", nifti1())
        self.mask = self.put("mask.nii", nifti1((2, 2, 2)))
        self.roi = self.put("roi.nii", nifti1((2, 2, 2)))
        self.events = self.put("events.tsv", b"onset\tduration\ttrial_type\n0\t1\tA\n4\t1\tB\n")
        self.confounds = self.put("confounds.tsv", b"motion\n0\n1\n0\n1\n0\n1\n0\n1\n")
        self.matlab = self.root / "MATLAB directory's name" / "matlab.exe"
        self.matlab.parent.mkdir()
        self.matlab.write_bytes(b"Synthetic executable; tests use callbacks only")
        self.spm = self.root / "SPM directory's name"
        self.spm.mkdir()
        (self.spm / "spm.m").write_text("% Synthetic SPM source\n", encoding="utf-8")
        self.toolkits = {}
        for package, paths in {
            "function": ["run_function.m", "setup_function.m", "config/function_config.m",
                         *[f"matlab/+cog/{name}.m" for name in
                           ("read_runs", "read_tsv", "resolve_path", "check_grid", "load_bold",
                            "clean_timeseries", "roi_extract", "fc", "write_json")]],
            "glm": ["config/glm_config.m", "config/design_config.m",
                    *[f"matlab/+psy/{name}.m" for name in
                      ("glm_batch", "glm_framework_run", "confound_design", "glm_model_contrasts",
                       "glm_highpass_rank", "verify_glm", "spm_step", "run_output_dir")]],
            "preprocessing": ["matlab/+psy/preprocess_batch.m"],
        }.items():
            root = self.root / "toolkits" / package
            for relative in paths:
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(f"% Synthetic {relative}; never executed\n", encoding="utf-8")
            self.toolkits[package] = str(root)
        self.calls = []

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, relative, content):
        path = self.data / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def answers(self, inventory, route="fc"):
        run_id = next(row["run_id"] for row in inventory["runs"] if row.get("bold"))
        values = {"subject": "01", "session": "01", "run": "01", "input_stage": "preprocessed",
                  "tr_seconds": 2.0, "temporal_state": "unfiltered_unregressed", "smoothing_fwhm_mm": 0,
                  "confounds": "", "mask": str(self.mask), "roi_file": str(self.roi), "purpose": "rest"}
        choices = {"cleaning": fact({"detrend": False, "bandHz": [], "minResidualDimensions": 3}),
                   "fc_measure": fact("pearson"), "roi_definition": fact("预先定义的独立 ROI"),
                   "execution_options": fact({"max_matrix_gib": 2, "roi_min_voxels": 1})}
        if route in {"glm", "preprocess_glm"}:
            values.update(events=str(self.events), event_reference="retained_first_volume", discard_volumes=0,
                          confounds=str(self.confounds))
            options = {"highpass_seconds": 128, "microtime_resolution": 16, "microtime_onset": 8,
                       "serial_correlation": "AR(1)", "hrf": "canonical", "min_residual_df": 3,
                       "mask_threshold": 0, "confounds": {"motion_model": "none", "include_tissue_means": False,
                       "linear_trend": False, "add_spikes": False, "fd_threshold_mm": 0.5, "min_residual_df": 3}}
            choices = {"conditions": fact(["A", "B"]),
                       "contrasts": fact([{"name": "A_minus_B", "weights": [1, -1]}]),
                       "glm_options": fact(options), "execution_options": fact({"max_matrix_gib": 2})}
        if route not in {"fc", "glm", "preprocess_glm"}:
            choices.update({name: fact("预先确认的测试选择") for name in project_module.MODEL_FIELDS[route]})
        return {"schema_version": 1, "route": route, "goal": "检验预先定义的研究问题", "paradigm": "明确记录的任务或静息",
                "independent_unit": "被试，session/run 为重复测量", "selected_run_ids": [run_id],
                "toolkit_roots": self.toolkits, "runs": {run_id: {"facts": {k: fact(v) for k, v in values.items()}}},
                "parameter_choices": choices, "parameter_setup": fact("ready")}

    def build_project(self, route="fc", mutate=None):
        inventory = project_module.scan_dataset(self.data)
        answers = self.answers(inventory, route)
        if mutate:
            mutate(answers)
        self.project.mkdir()
        project_module.write_json(self.project / "inventory.json", inventory)
        state = {"schema_version": 1, "skill_version": project_module.VERSION,
                 "data_root": str(self.data.resolve()), "inventory_sha256": digest(self.project / "inventory.json")}
        revision, plan = project_module.create_revision(self.project, inventory, answers)
        project_module.update_pointer(self.project, state, revision, plan)
        self.revision = revision
        self.plan = plan
        return answers

    def fake_runner(self, job_file, matlab_executable):
        self.assertEqual(Path(matlab_executable), self.matlab.resolve())
        job = read_json(job_file)
        self.calls.append(job)
        if job["mode"] == "preflight":
            return {"status": "preflight_passed", "runs": []}
        output = Path(job["output_root"])
        output.mkdir(parents=True, exist_ok=True)
        (output / "BATCH_COMPLETE.mat").write_bytes(b"Synthetic batch completion")
        outputs = []
        for run in job["expected_runs"]:
            subject = "sub-" + run["subject"] if job["route"] == "glm" else run["subject"]
            target = output / subject
            if run.get("session"):
                target /= "ses-" + run["session"] if job["route"] == "glm" else run["session"]
            target /= run["run"]
            target.mkdir(parents=True, exist_ok=True)
            if job["route"] == "fc":
                names = ["COMPLETE.mat", "fc_r.tsv", "static_fc.mat", "roi_timeseries.mat", "roi_coverage.tsv"]
            else:
                names = ["GLM_FRAMEWORK_COMPLETE.mat", "model_outputs.tsv", "models/joint/COMPLETE.mat",
                         "models/joint/SPM.mat"]
            for name in names:
                destination = target / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(b"Synthetic completed result")
                outputs.append(str(destination))
        return {"status": "complete", "runs": [], "output_files": outputs}

    def prepare(self, runner=None):
        return reviewed(self.project, execution.prepare(self.project, self.matlab, self.spm, runner=runner or self.fake_runner))

    def execute(self, prepared, **changes):
        arguments = {"project_dir": self.project, "attempt_id": prepared["attempt_id"],
                     "review_digest": prepared["review_digest"], "confirmation": "确认执行", "runner": self.fake_runner}
        arguments.update(changes)
        return execution.execute(**arguments)

    def source_snapshot(self):
        return {path.relative_to(self.data).as_posix(): digest(path) for path in self.data.rglob("*") if path.is_file()}

    def test_fc_prepare_stages_private_inputs_and_freezes_review(self):
        self.build_project()
        before = self.source_snapshot()
        prepared = self.prepare()
        self.assertEqual(prepared["phase"], "awaiting_confirmation")
        self.assertTrue(prepared["review_digest"])
        self.assertEqual([job["mode"] for job in self.calls], ["preflight"])
        job = self.calls[0]
        self.assertEqual(job["route"], "fc")
        manifest = Path(job["manifest_file"])
        with manifest.open(encoding="utf-8-sig", newline="") as handle:
            row = next(csv.DictReader(handle, delimiter="\t"))
        self.assertNotEqual(Path(row["bold"]), self.bold)
        self.assertEqual(Path(row["bold"]).read_bytes(), self.bold.read_bytes())
        self.assertTrue(Path(row["bold"]).is_relative_to(Path(prepared["attempt_dir"])))
        self.assertTrue((Path(prepared["attempt_dir"]) / "review.json").is_file())
        self.assertTrue((Path(prepared["attempt_dir"]) / "review.md").is_file())
        self.assertEqual(before, self.source_snapshot())

    def test_gzipped_bold_is_expanded_only_in_attempt(self):
        original = self.bold.read_bytes()
        self.bold = self.bold.with_suffix(".nii.gz")
        self.bold.write_bytes(gzip.compress(original))
        self.bold.with_suffix("").unlink()
        self.build_project()
        before = self.source_snapshot()
        prepared = self.prepare()
        with Path(self.calls[0]["manifest_file"]).open(encoding="utf-8-sig", newline="") as handle:
            staged = Path(next(csv.DictReader(handle, delimiter="\t"))["bold"])
        self.assertEqual(staged.suffix, ".nii")
        self.assertEqual(staged.read_bytes(), original)
        self.assertTrue(staged.is_relative_to(Path(prepared["attempt_dir"])))
        self.assertEqual(before, self.source_snapshot())

    def test_draft_with_unanswered_items_cannot_prepare(self):
        self.build_project(mutate=lambda a: a.update(goal=""))
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_empty_selection_cannot_prepare(self):
        self.build_project(mutate=lambda a: a.update(selected_run_ids=[]))
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_unimplemented_analysis_route_cannot_prepare(self):
        self.build_project("spectral_dcm")
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_invalid_or_unconfirmed_execution_parameters_cannot_prepare(self):
        for value in ({"max_matrix_gib": 0, "roi_min_voxels": 1},
                      {"max_matrix_gib": 2, "roi_min_voxels": 0}, "a narrative is not a configuration"):
            with self.subTest(value=value):
                self.build_project(mutate=lambda a: a["parameter_choices"].update(execution_options=fact(value)))
                with self.assertRaises(ValueError):
                    self.prepare()
                self.assertEqual(self.calls, [])
                shutil.rmtree(self.project)

    def test_missing_execution_choice_confirmation_cannot_prepare(self):
        self.build_project(mutate=lambda a: a["parameter_choices"].update(
            execution_options=fact({"max_matrix_gib": 2, "roi_min_voxels": 1}, confirmed=False)))
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_invalid_cleaning_values_cannot_prepare(self):
        for options in ({"detrend": "false", "bandHz": [], "minResidualDimensions": 3},
                        {"detrend": False, "bandHz": [0.1, 0.01], "minResidualDimensions": 3},
                        {"detrend": False, "bandHz": [], "minResidualDimensions": 0}):
            with self.subTest(options=options):
                self.build_project(mutate=lambda a: a["parameter_choices"].update(cleaning=fact(options)))
                with self.assertRaises(ValueError):
                    self.prepare()
                self.assertEqual(self.calls, [])
                shutil.rmtree(self.project)

    def test_missing_matlab_or_spm_is_rejected_before_runner(self):
        self.build_project()
        for executable, spm in ((self.root / "missing-matlab.exe", self.spm),
                                (self.matlab, self.root / "missing-spm")):
            with self.subTest(executable=executable, spm=spm):
                with self.assertRaises((ValueError, OSError)):
                    execution.prepare(self.project, executable, spm, runner=self.fake_runner)
        self.assertEqual(self.calls, [])

    def test_failed_preflight_is_not_ready_and_cannot_execute(self):
        self.build_project()
        prepared = self.prepare(runner=lambda *_: {"status": "preflight_failed", "error": "synthetic rank failure"})
        self.assertEqual(prepared["phase"], "preflight_failed")
        self.assertFalse(prepared.get("execution_ready", False))
        with self.assertRaises(ValueError):
            self.execute({**prepared, "review_digest": prepared.get("review_digest", "")})
        self.assertEqual(self.calls, [])

    def test_preflight_exception_is_preserved_as_failure(self):
        self.build_project()
        def broken(*_):
            raise RuntimeError("synthetic backend failure")
        result = self.prepare(runner=broken)
        self.assertEqual(result["phase"], "preflight_failed")
        self.assertIn("synthetic backend failure", json.dumps(execution.status(self.project)))

    def test_wrong_digest_or_confirmation_prevents_execute(self):
        self.build_project()
        prepared = self.prepare()
        for changes in ({"review_digest": ""}, {"review_digest": "wrong"}, {"confirmation": ""},
                        {"confirmation": "maybe later"}):
            with self.subTest(changes=changes):
                with self.assertRaises(ValueError):
                    self.execute(prepared, **changes)
                self.assertEqual(len(self.calls), 1)
        self.assertEqual(execution.status(self.project)["phase"], "awaiting_confirmation")

    def test_tampered_or_missing_source_prevents_execute(self):
        self.build_project()
        prepared = self.prepare()
        original = self.bold.read_bytes()
        original_stat = self.bold.stat()
        self.bold.write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.bold.write_bytes(original)
        os.utime(self.bold, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))
        # A rejected attempt stays invalidated; a fresh preflight must independently catch deletion.
        prepared = self.prepare()
        self.bold.unlink()
        with self.assertRaises((ValueError, OSError)):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 2)

    def test_tampered_staged_input_prevents_execute(self):
        self.build_project()
        prepared = self.prepare()
        with Path(self.calls[0]["manifest_file"]).open(encoding="utf-8-sig", newline="") as handle:
            staged = Path(next(csv.DictReader(handle, delimiter="\t"))["bold"])
        staged.write_bytes(staged.read_bytes() + b"tampered")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_tampered_toolkit_code_prevents_execute(self):
        self.build_project()
        prepared = self.prepare()
        (Path(self.toolkits["function"]) / "run_function.m").write_text("% changed\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_tampered_spm_source_prevents_execute(self):
        self.build_project()
        prepared = self.prepare()
        (self.spm / "spm.m").write_text("% changed SPM source\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_missing_toolkit_marker_prevents_execute(self):
        self.build_project()
        prepared = self.prepare()
        (Path(self.toolkits["function"]) / "run_function.m").unlink()
        with self.assertRaises((ValueError, OSError)):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_changed_adapter_source_prevents_execute_without_touching_installed_skill(self):
        self.build_project()
        isolated_skill = self.root / "isolated_skill"
        shutil.copytree(SCRIPTS, isolated_skill / "scripts")
        shutil.copytree(SCRIPTS.parent / "matlab", isolated_skill / "matlab")
        with mock.patch.object(execution, "SKILL_ROOT", isolated_skill):
            prepared = self.prepare()
            adapter = isolated_skill / "matlab" / "cogneuro_fc_adapter.m"
            adapter.write_bytes(adapter.read_bytes() + b"\n% modified\n")
            with self.assertRaises(ValueError):
                self.execute(prepared)
        self.assertEqual(len(self.calls), 1)

    def test_new_private_adapter_code_invalidates_confirmation(self):
        self.build_project()
        for suffix in (".m", ".p", ".mexw64"):
            with self.subTest(suffix=suffix):
                prepared = self.prepare()
                extra = Path(prepared["attempt_dir"]) / "adapter" / ("unexpected_entry" + suffix)
                extra.write_bytes(b"Synthetic unreviewed code; never executed")
                with self.assertRaises(ValueError):
                    self.execute(prepared)
                self.assertEqual(execution.status(self.project, prepared["attempt_id"])["phase"], "invalidated")
                self.assertFalse((Path(prepared["attempt_dir"]) / "approval.json").exists())
        self.assertEqual([job["mode"] for job in self.calls], ["preflight"] * 3)

    def test_pending_status_detects_changed_source_and_code_without_writing_state(self):
        self.build_project()
        for path in (self.bold, Path(self.toolkits["function"]) / "run_function.m"):
            with self.subTest(path=path):
                prepared = self.prepare()
                state_file = Path(prepared["attempt_dir"]) / "state.json"
                state_before = state_file.read_bytes()
                before, original_stat = path.read_bytes(), path.stat()
                try:
                    path.write_bytes(before + b"changed after review")
                    reported = execution.status(self.project, prepared["attempt_id"])
                    self.assertEqual(reported["phase"], "needs_new_preflight")
                    self.assertFalse(reported["execution_ready"])
                    self.assertEqual(state_file.read_bytes(), state_before)
                finally:
                    path.write_bytes(before)
                    os.utime(path, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))
        self.assertEqual([job["mode"] for job in self.calls], ["preflight"] * 2)

    def test_changed_plan_answers_and_review_are_rejected(self):
        self.build_project()
        for path in (self.revision / "plan.json", self.revision / "answers.json",
                     "review.json", "review.md"):
            prepared = self.prepare()
            target = Path(prepared["attempt_dir"]) / path if isinstance(path, str) else path
            with self.subTest(path=target):
                before = target.read_bytes()
                target.write_bytes(before + b"\n")
                with self.assertRaises(ValueError):
                    self.execute(prepared)
                target.write_bytes(before)
                self.assertTrue(all(job["mode"] == "preflight" for job in self.calls))
        self.assertEqual(len(self.calls), 4)

    def test_fc_execute_reports_completion_and_never_repeats(self):
        self.build_project()
        before = self.source_snapshot()
        prepared = self.prepare()
        result = self.execute(prepared)
        self.assertEqual(result["phase"], "complete")
        self.assertEqual([job["mode"] for job in self.calls], ["preflight", "execute"])
        self.assertEqual(before, self.source_snapshot())
        self.assertEqual(execution.status(self.project, prepared["attempt_id"])["phase"], "complete")
        try:
            repeated = self.execute(prepared)
        except ValueError:
            pass
        else:
            self.assertEqual(repeated["phase"], "complete")
        self.assertEqual(len(self.calls), 2)

    def test_duplicate_execute_with_stale_snapshot_cannot_replace_completed_state(self):
        self.build_project()
        prepared = self.prepare()
        original_get_attempt = execution._get_attempt
        second_loaded, first_done = threading.Event(), threading.Event()
        reads, results = {}, {}

        def read_snapshot(*args, **kwargs):
            snapshot = original_get_attempt(*args, **kwargs)
            name = threading.current_thread().name
            reads[name] = reads.get(name, 0) + 1
            # Both requests read awaiting_confirmation before either can enter the lock.
            # The second request resumes only after the first committed its completion.
            if reads[name] == 1:
                if name == "first":
                    if not second_loaded.wait(10):
                        raise TimeoutError("Second request did not load its snapshot")
                elif name == "second":
                    second_loaded.set()
                    if not first_done.wait(10):
                        raise TimeoutError("First request did not complete")
            return snapshot

        def invoke(name):
            try:
                results[name] = self.execute(prepared)
            except Exception as error:
                results[name] = error
            finally:
                if name == "first":
                    first_done.set()

        with mock.patch.object(execution, "_get_attempt", side_effect=read_snapshot):
            first = threading.Thread(target=invoke, args=("first",), name="first", daemon=True)
            second = threading.Thread(target=invoke, args=("second",), name="second", daemon=True)
            first.start()
            second.start()
            first.join(15)
            second.join(15)
        self.assertFalse(first.is_alive())
        self.assertFalse(second.is_alive())
        self.assertIsInstance(results["first"], dict)
        self.assertEqual(results["first"]["phase"], "complete")
        self.assertIsInstance(results["second"], ValueError)
        self.assertEqual(execution.status(self.project, prepared["attempt_id"])["phase"], "complete")
        self.assertTrue((Path(prepared["attempt_dir"]) / "receipt.json").is_file())
        self.assertEqual([job["mode"] for job in self.calls], ["preflight", "execute"])

    def test_glm_route_passes_confirmed_model_and_private_events(self):
        self.build_project("glm")
        before = self.source_snapshot()
        prepared = self.prepare()
        job = self.calls[0]
        self.assertEqual(job["route"], "glm")
        self.assertEqual(job["options"]["conditions"], ["A", "B"])
        self.assertEqual(job["options"]["contrasts"][0]["weights"], [1, -1])
        with Path(job["manifest_file"]).open(encoding="utf-8-sig", newline="") as handle:
            row = next(csv.DictReader(handle, delimiter="\t"))
        self.assertNotEqual(Path(row["events"]), self.events)
        self.assertEqual(Path(row["events"]).read_bytes(), self.events.read_bytes())
        self.assertEqual(self.execute(prepared)["phase"], "complete")
        self.assertEqual(before, self.source_snapshot())

    def test_glm_narrative_model_choices_are_not_treated_as_executable(self):
        self.build_project("glm", mutate=lambda a: a["parameter_choices"].update(glm_options=fact("使用默认 GLM")))
        with self.assertRaises(ValueError):
            self.prepare()
        self.assertEqual(self.calls, [])

    def test_backend_claim_without_required_outputs_is_failure(self):
        self.build_project()
        prepared = self.prepare()
        result = self.execute(prepared, runner=lambda *_: {"status": "complete", "runs": []})
        self.assertEqual(result["phase"], "execution_failed")
        self.assertFalse(result.get("execution_ready", False))

    def test_code_change_during_execution_cannot_receive_completion_receipt(self):
        self.build_project()
        prepared = self.prepare()
        def changed_code(job_file, executable):
            completed = self.fake_runner(job_file, executable)
            source = Path(self.toolkits["function"]) / "run_function.m"
            source.write_text("% changed during calculation\n", encoding="utf-8")
            return completed
        result = self.execute(prepared, runner=changed_code)
        self.assertEqual(result["phase"], "execution_failed")
        attempt = Path(prepared["attempt_dir"])
        self.assertFalse((attempt / "receipt.json").exists())
        self.assertTrue((attempt / "results" / "BATCH_COMPLETE.mat").is_file())
        self.assertEqual(len(self.calls), 2)

    def test_failed_execution_preserves_partial_outputs_and_refuses_retry(self):
        self.build_project()
        prepared = self.prepare()
        def broken(job_file, _):
            job = read_json(job_file)
            self.calls.append(job)
            partial = Path(job["output_root"]) / "partial-result.txt"
            partial.parent.mkdir(parents=True, exist_ok=True)
            partial.write_text("preserve me", encoding="utf-8")
            raise RuntimeError("synthetic interrupted estimation")
        result = self.execute(prepared, runner=broken)
        self.assertEqual(result["phase"], "execution_failed")
        partial = Path(self.calls[-1]["output_root"]) / "partial-result.txt"
        self.assertEqual(partial.read_text(encoding="utf-8"), "preserve me")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(partial.read_text(encoding="utf-8"), "preserve me")

    def test_status_after_keyboard_interrupt_does_not_claim_complete_or_rerun(self):
        self.build_project()
        prepared = self.prepare()
        def interrupted(job_file, _):
            self.calls.append(read_json(job_file))
            raise KeyboardInterrupt("synthetic process interruption")
        with self.assertRaises(KeyboardInterrupt):
            self.execute(prepared, runner=interrupted)
        reported = execution.status(self.project, prepared["attempt_id"])
        self.assertNotEqual(reported["phase"], "complete")
        self.assertFalse(reported.get("execution_ready", False))
        self.assertEqual(len(self.calls), 2)
        with self.assertRaises(ValueError):
            self.execute(prepared)

    def test_preexisting_output_directory_is_never_overwritten(self):
        self.build_project()
        prepared = self.prepare()
        output = Path(self.calls[0]["output_root"])
        output.mkdir(parents=True, exist_ok=True)
        existing = output / "already_exists.txt"
        existing.write_text("successful prior work", encoding="utf-8")
        with self.assertRaises(ValueError):
            self.execute(prepared)
        self.assertEqual(existing.read_text(encoding="utf-8"), "successful prior work")
        self.assertEqual(len(self.calls), 1)

    def test_attempt_id_cannot_escape_project(self):
        self.build_project()
        prepared = self.prepare()
        for attempt in ("../outside", str(self.root), "0001/../0001"):
            with self.subTest(attempt=attempt):
                with self.assertRaises(ValueError):
                    execution.status(self.project, attempt)
                with self.assertRaises(ValueError):
                    self.execute(prepared, attempt_id=attempt)
        self.assertEqual(len(self.calls), 1)

    def test_complete_status_detects_missing_output_without_reexecution(self):
        self.build_project()
        prepared = self.prepare()
        result = self.execute(prepared)
        missing = Path(result["output_root"]) / "01" / "01" / "01" / "fc_r.tsv"
        missing.unlink()
        reported = execution.status(self.project, prepared["attempt_id"])
        self.assertEqual(reported["phase"], "outputs_changed")
        self.assertIn(str(missing), reported["missing_or_resized_outputs"])
        self.assertEqual(len(self.calls), 2)

    def test_glm_receipt_uses_toolkit_prefixed_identity_layout(self):
        self.build_project("glm")
        prepared = self.prepare()
        completed = self.execute(prepared)
        self.assertEqual(completed["phase"], "complete")
        expected = Path(completed["output_root"]) / "sub-01" / "ses-01" / "01" / "models" / "joint" / "SPM.mat"
        receipt = read_json(Path(completed["attempt_dir"]) / "receipt.json")
        self.assertIn(str(expected), {item["path"] for item in receipt["outputs"]})
        self.assertTrue(expected.is_file())

    def test_complete_status_remains_readable_when_source_data_is_offline(self):
        self.build_project()
        prepared = self.prepare()
        self.assertEqual(self.execute(prepared)["phase"], "complete")
        self.data.rename(self.root / "data_archived")
        reported = execution.status(self.project, prepared["attempt_id"])
        self.assertEqual(reported["phase"], "complete")
        self.assertIs(reported["source_available"], False)
        # Allowing an offline status query must not loosen ordinary project validation.
        with self.assertRaises((OSError, ValueError)):
            project_module.ensure_project(self.project)
        self.assertEqual([job["mode"] for job in self.calls], ["preflight", "execute"])

    def test_default_matlab_runner_uses_argument_list_and_escaped_fixed_entry(self):
        directory = self.root / "job's folder; literal text"
        directory.mkdir()
        job_file = directory / "job's name.json"
        result_file = directory / "result.json"
        project_module.write_json(job_file, {"mode": "preflight", "result_file": str(result_file)})
        def completed(command, **kwargs):
            self.assertIsInstance(command, list)
            self.assertEqual(command[0], str(self.matlab))
            self.assertIs(kwargs["shell"], False)
            self.assertEqual(command[-2], "-batch")
            expression = command[-1]
            self.assertIn(str(job_file).replace("'", "''"), expression)
            self.assertIn("cogneuro_job('", expression)
            project_module.write_json(result_file, {"status": "preflight_passed", "runs": []})
            return subprocess.CompletedProcess(command, 0)
        with mock.patch.object(execution.subprocess, "run", side_effect=completed) as called:
            result = execution.matlab_runner(job_file, self.matlab)
        self.assertEqual(result["status"], "preflight_passed")
        called.assert_called_once()


if __name__ == "__main__":
    unittest.main()
