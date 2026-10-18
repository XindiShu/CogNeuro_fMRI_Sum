"""Project preparation behavior using synthetic files; no MATLAB or real data."""
from __future__ import annotations

import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("fmri_project_under_test", SCRIPTS / "fmri_project.py")
assert SPEC is not None and SPEC.loader is not None
project_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(project_module)


def nifti1(shape=(2, 2, 2, 8), tr=2.0):
    """Minimal complete float32 single-file NIfTI-1, with seconds/mm units."""
    header = bytearray(352)
    struct.pack_into("<i", header, 0, 348)
    dimensions = [len(shape), *shape]
    struct.pack_into("<8h", header, 40, *(dimensions + [1] * (8 - len(dimensions))))
    struct.pack_into("<2h", header, 70, 16, 32)
    struct.pack_into("<8f", header, 76, 1, 2, 2, 2, tr, 1, 1, 1)
    struct.pack_into("<f", header, 108, 352)
    header[123] = 10
    header[344:348] = b"n+1\0"
    count = 1
    for dim in shape:
        count *= dim
    return bytes(header) + struct.pack("<" + "f" * count, *range(count))


def fact(value, source="用户确认：测试协议与原始记录", confirmed=True):
    return {"value": value, "source": source, "confirmed": confirmed}


class ProjectTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.data = self.root / "data"
        self.data.mkdir()
        self.project = self.root / "project"
        self.bold = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_bold.nii", nifti1())
        self.events = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_events.tsv",
                               b"onset\tduration\ttrial_type\n-2\t1\tA\n4\t0\tB\n")
        self.confounds = self.put("confounds.tsv", b"motion\n0\n1\n0\n1\n0\n1\n0\n1\n")
        self.mask = self.put("mask.nii", nifti1(shape=(2, 2, 2)))
        self.roi = self.put("roi.nii", nifti1(shape=(2, 2, 2)))
        self.t1 = self.put("sub-01/anat/sub-01_T1w.nii", nifti1(shape=(2, 2, 2)))
        self.metadata = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_bold.json",
                                 b'{"RepetitionTime": 2.0, "EchoTime": 0.03}')
        self.packages = {}
        for key, marker in {"preprocessing": "matlab/+psy/preprocess_batch.m",
                            "glm": "matlab/+psy/glm_batch.m", "function": "run_function.m"}.items():
            package = self.root / "toolkits" / key
            target = package / marker
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("% Synthetic marker, never executed\n", encoding="utf-8")
            self.packages[key] = str(package)
        self.inventory = project_module.scan_dataset(self.data)
        self.run_id = self.inventory["runs"][0]["run_id"]

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, relative, content):
        path = self.data / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def answers(self, route="fc", run_id=None):
        run_id = self.run_id if run_id is None else run_id
        values = {"subject": "01", "session": "01", "run": "01", "input_stage": "preprocessed",
                  "tr_seconds": 2.0, "temporal_state": "unfiltered_unregressed", "smoothing_fwhm_mm": 0,
                  "confounds": "", "mask": str(self.mask), "roi_file": str(self.roi), "purpose": "rest"}
        if route in {"glm", "preprocess_glm"}:
            values.update(events=str(self.events), event_reference="retained_first_volume", discard_volumes=0,
                          confounds=str(self.confounds))
        if route == "preprocess_glm":
            values.update(input_stage="raw", t1=str(self.t1), metadata=str(self.metadata), sdc_method="none")
        choices = {name: fact("明确记录的测试选择") for name in project_module.MODEL_FIELDS[route]}
        if route == "fc":
            choices["fc_measure"] = fact("pearson")
        if route == "ppi":
            choices["ppi_method"] = fact("classic")
        return {"schema_version": 1, "route": route, "goal": "检验预先定义的研究问题", "paradigm": "静息或明确的记忆任务",
                "independent_unit": "被试，session/run 为重复测量", "selected_run_ids": [run_id],
                "toolkit_roots": self.packages, "runs": {run_id: {"facts": {k: fact(v) for k, v in values.items()}}},
                "parameter_choices": choices}

    def plan(self, answers=None):
        return project_module.make_plan(self.inventory, self.answers() if answers is None else answers)

    def cli(self, *arguments, expected=0):
        completed = subprocess.run([sys.executable, "-X", "utf8", str(SCRIPTS / "fmri_project.py"), *map(str, arguments)],
                                   capture_output=True, text=True, encoding="utf-8", check=False)
        self.assertEqual(completed.returncode, expected, completed.stdout + completed.stderr)
        return json.loads(completed.stdout if expected == 0 else completed.stderr)

    def scan_cli(self, target=None):
        return self.cli("scan", "--data-root", self.data, "--project-dir", self.project if target is None else target)

    def save_answers(self, answers):
        path = self.root / "answers.json"
        path.write_text(json.dumps(answers, ensure_ascii=False), encoding="utf-8")
        return path

    def data_snapshot(self):
        return {p.relative_to(self.data).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.data.rglob("*") if p.is_file()}

    def test_scan_plan_status_creates_immutable_revisions_and_updates_pointer(self):
        before = self.data_snapshot()
        scanned = self.scan_cli()
        first = Path(scanned["revision"])
        self.assertEqual(first.name, "0001")
        self.assertEqual(scanned["phase"], "needs_answers")
        first_bytes = (first / "plan.json").read_bytes()
        planned = self.cli("plan", "--project-dir", self.project, "--answers", self.save_answers(self.answers()))
        self.assertEqual(Path(planned["revision"]).name, "0002")
        self.assertEqual(planned["phase"], "draft_prepared")
        self.assertFalse(planned["execution_ready"])
        current = json.loads((self.project / "project.json").read_text(encoding="utf-8"))
        self.assertEqual(current["current_revision"], "revisions/0002")
        self.assertEqual(self.cli("status", "--project-dir", self.project), planned)
        self.assertEqual((first / "plan.json").read_bytes(), first_bytes)
        self.assertEqual(self.data_snapshot(), before)
        self.assertTrue((first / "answers.json").is_file())
        self.assertTrue((Path(planned["revision"]) / "questions.json").is_file())

    def test_scan_refuses_existing_project_without_overwriting(self):
        self.scan_cli()
        before = (self.project / "project.json").read_bytes()
        result = self.cli("scan", "--data-root", self.data, "--project-dir", self.project, expected=2)
        self.assertIn("已存在", result["error"])
        self.assertEqual((self.project / "project.json").read_bytes(), before)

    def test_v030_project_can_be_read_and_replanned_without_rewriting_prior_revision(self):
        scanned = self.scan_cli()
        prior = Path(scanned["revision"]) / "plan.json"
        prior_bytes = prior.read_bytes()
        state_file = self.project / "project.json"
        state = json.loads(state_file.read_text(encoding="utf-8"))
        state["skill_version"] = "0.3.0"
        state_file.write_text(json.dumps(state), encoding="utf-8")
        state_bytes = state_file.read_bytes()
        self.assertEqual(self.cli("status", "--project-dir", self.project)["revision"], scanned["revision"])
        self.assertEqual(state_file.read_bytes(), state_bytes)
        updated = self.cli("plan", "--project-dir", self.project, "--answers", self.save_answers(self.answers()))
        self.assertEqual(updated["phase"], "draft_prepared")
        self.assertEqual(json.loads(state_file.read_text(encoding="utf-8"))["skill_version"], project_module.VERSION)
        self.assertEqual(prior.read_bytes(), prior_bytes)

    def test_scan_refuses_project_inside_input_or_input_inside_project(self):
        for target in (self.data / "analysis", self.root):
            with self.subTest(target=target):
                result = self.cli("scan", "--data-root", self.data, "--project-dir", target, expected=2)
                self.assertIn("不能互相包含", result["error"])

    def test_inventory_tampering_cannot_reuse_old_answers(self):
        self.scan_cli()
        with (self.project / "inventory.json").open("a", encoding="utf-8") as handle:
            handle.write("\n")
        result = self.cli("status", "--project-dir", self.project, expected=2)
        self.assertIn("inventory.json", result["error"])

    def test_selected_bold_changed_after_scan_blocks_replanning(self):
        self.bold.write_bytes(self.bold.read_bytes() + b"changed")
        plan = self.plan()
        self.assertTrue(any("扫描后输入" in text and str(self.bold) in text for text in plan["blockers"]))
        self.assertEqual(plan["phase"], "needs_answers")

    def test_selected_bold_removed_after_scan_blocks_replanning(self):
        self.bold.unlink()
        self.assertTrue(any("扫描后输入" in text and str(self.bold) in text for text in self.plan()["blockers"]))

    def test_status_reports_stale_inputs_without_rewriting_revision(self):
        self.scan_cli()
        prepared = self.cli("plan", "--project-dir", self.project, "--answers", self.save_answers(self.answers()))
        original = Path(prepared["plan"]).read_bytes()
        self.bold.write_bytes(self.bold.read_bytes() + b"changed")
        status = self.cli("status", "--project-dir", self.project)
        self.assertEqual(status["phase"], "stale_inputs")
        self.assertTrue(any("扫描后输入" in text and str(self.bold) in text for text in status["blockers"]))
        self.assertFalse(status["execution_ready"])
        self.assertEqual(Path(prepared["plan"]).read_bytes(), original)

    def test_three_dimensional_bold_is_not_accepted_as_time_series(self):
        self.bold.write_bytes(nifti1(shape=(2, 2, 2)))
        self.inventory = project_module.scan_dataset(self.data)
        plan = self.plan()
        self.assertTrue(any("4D" in text for text in plan["blockers"]))

    def test_dcm_echo_time_over_interface_limit_is_rejected(self):
        answers = self.answers("spectral_dcm")
        answers["runs"][self.run_id]["facts"].update(te_seconds=fact(0.11),
            region_sampling_delays_seconds=fact([1.0, 1.0]))
        plan = self.plan(answers)
        self.assertTrue(any("TE" in text or "te_seconds" in text for text in plan["blockers"]))

    def test_unknown_selected_id_is_rejected(self):
        answers = self.answers()
        answers["selected_run_ids"] = ["not-in-scan"]
        with self.assertRaises(ValueError):
            self.plan(answers)

    def test_duplicate_selected_ids_are_rejected(self):
        answers = self.answers()
        answers["selected_run_ids"] *= 2
        with self.assertRaises(ValueError):
            self.plan(answers)

    def test_no_selection_keeps_candidates_as_questions(self):
        answers = self.answers()
        answers["selected_run_ids"] = []
        plan = self.plan(answers)
        self.assertEqual(plan["runs"], [])
        self.assertIn("selected_run_ids", {q["id"] for q in plan["questions"]})

    def test_confirmed_fact_retains_provenance(self):
        plan = self.plan()
        self.assertEqual(plan["phase"], "draft_prepared")
        provenance = next(x for x in plan["verified_facts"] if x["field"] == "tr_seconds")
        self.assertEqual(provenance["value"], 2.0)
        self.assertIn("原始记录", provenance["source"])

    def test_unconfirmed_or_missing_source_fact_requires_question(self):
        for bad in (fact(2, confirmed=False), fact(2, source=""), {"value": 2, "confirmed": True}):
            with self.subTest(bad=bad):
                answers = self.answers()
                answers["runs"][self.run_id]["facts"]["tr_seconds"] = bad
                plan = self.plan(answers)
                self.assertIn(self.run_id + "::tr_seconds", {q["id"] for q in plan["questions"]})
                self.assertNotIn("tr_seconds", plan["runs"][0]["values"])

    def test_parameter_choice_requires_provenance_and_confirmation(self):
        for bad in (fact("pearson", confirmed=False), fact("pearson", source=" ")):
            with self.subTest(bad=bad):
                answers = self.answers()
                answers["parameter_choices"]["fc_measure"] = bad
                self.assertIn("parameter_choices.fc_measure", {q["id"] for q in self.plan(answers)["questions"]})

    def test_fc_does_not_require_task_events(self):
        plan = self.plan()
        self.assertEqual(plan["questions"], [])
        self.assertEqual(plan["blockers"], [])
        self.assertNotIn("events", plan["runs"][0]["values"])
        self.assertEqual(set(plan["toolkit_roots"]), {"function"})

    def test_glm_requires_real_events_and_confounds(self):
        answers = self.answers("glm")
        del answers["runs"][self.run_id]["facts"]["events"]
        answers["runs"][self.run_id]["facts"]["confounds"] = fact("")
        plan = self.plan(answers)
        self.assertIn(self.run_id + "::events", {q["id"] for q in plan["questions"]})
        self.assertTrue(any("confounds" in text for text in plan["blockers"]))

    def test_glm_rejects_denoised_residual_input(self):
        answers = self.answers("glm")
        answers["runs"][self.run_id]["facts"]["temporal_state"] = fact("denoised_bandpassed")
        plan = self.plan(answers)
        self.assertTrue(any("unfiltered_unregressed" in text for text in plan["blockers"]))
        self.assertEqual(plan["phase"], "needs_answers")

    def test_duplicate_confirmed_subject_session_run_is_blocked(self):
        self.put("sub-01/ses-01/func/sub-01_ses-01_task-other_run-01_bold.nii", nifti1())
        self.inventory = project_module.scan_dataset(self.data)
        answers = self.answers()
        second_id = next(r["run_id"] for r in self.inventory["runs"] if r["run_id"] != self.run_id)
        answers["selected_run_ids"].append(second_id)
        answers["runs"][second_id] = {"facts": {k: dict(v) for k, v in answers["runs"][self.run_id]["facts"].items()}}
        self.assertTrue(any("身份重复" in text for text in self.plan(answers)["blockers"]))

    def test_raw_to_glm_leaves_future_derivative_paths_empty(self):
        self.scan_cli()
        result = self.cli("plan", "--project-dir", self.project, "--answers", self.save_answers(self.answers("preprocess_glm")))
        drafts = Path(result["revision"]) / "draft_manifests"
        with (drafts / "glm_runs.DRAFT.tsv").open(encoding="utf-8", newline="") as handle:
            rows = list(csv.DictReader(handle, delimiter="\t"))
        self.assertEqual(rows[0]["subject"], "01")
        for key in ("bold", "events", "confounds", "temporal_state"):
            self.assertEqual(rows[0][key], "")
        plan = json.loads(Path(result["plan"]).read_text(encoding="utf-8"))
        self.assertEqual(plan["deferred_outputs"][0]["status"], "validated_after_preprocessing")
        self.assertFalse(plan["execution_ready"])

    def test_spm_only_ppi_writes_candidate_draft_without_bold_requirement(self):
        spm = self.put("sub-02/ses-02/model/SPM.mat", b"Synthetic opaque SPM candidate")
        self.scan_cli()
        inventory = json.loads((self.project / "inventory.json").read_text(encoding="utf-8"))
        run_id = next(r["run_id"] for r in inventory["runs"] if not r["bold"])
        answers = self.answers("ppi", run_id)
        answers["runs"][run_id]["facts"] = {k: fact(v) for k, v in {
            "subject": "02", "session": "02", "run": "01", "spm_mat": str(spm),
            "spm_session_index": 1, "seed_mask": str(self.roi)}.items()}
        result = self.cli("plan", "--project-dir", self.project, "--answers", self.save_answers(answers))
        with (Path(result["revision"]) / "draft_manifests/ppi_runs.DRAFT.tsv").open(encoding="utf-8", newline="") as handle:
            row = next(csv.DictReader(handle, delimiter="\t"))
        self.assertEqual(row["spm_mat"], str(spm.resolve()))
        self.assertEqual(row["spm_session_index"], "1")
        self.assertEqual(result["phase"], "draft_prepared")
        self.assertFalse(result["execution_ready"])

    def test_negative_event_onset_is_allowed(self):
        self.assertEqual(project_module.event_issues(self.events), [])
        self.assertEqual(self.plan(self.answers("glm"))["blockers"], [])

    def test_negative_duration_and_nonfinite_events_are_rejected(self):
        for row in ("0\t-1\tA", "nan\t1\tA", "0\tinf\tA"):
            with self.subTest(row=row):
                self.events.write_text("onset\tduration\ttrial_type\n" + row + "\n", encoding="utf-8")
                self.assertTrue(project_module.event_issues(self.events))

    def test_event_columns_empty_events_and_missing_labels_are_rejected(self):
        for content in ("onset\tduration\n0\t1\n", "onset\tduration\ttrial_type\n",
                        "onset\tduration\ttrial_type\n0\t1\t\n"):
            with self.subTest(content=content):
                self.events.write_text(content, encoding="utf-8")
                self.assertTrue(project_module.event_issues(self.events))

    def test_invalid_ids_paths_numeric_values_and_states_remain_questions(self):
        for name, value in (("subject", "../01"), ("session", "ses 01"), ("run", ""),
                            ("mask", "relative.nii"), ("roi_file", str(self.root / "missing.nii")),
                            ("tr_seconds", True), ("tr_seconds", 0), ("tr_seconds", float("inf")),
                            ("smoothing_fwhm_mm", -1), ("temporal_state", "looks_smooth")):
            with self.subTest(name=name, value=value):
                answers = self.answers()
                answers["runs"][self.run_id]["facts"][name] = fact(value)
                self.assertIn(self.run_id + "::" + name, {q["id"] for q in self.plan(answers)["questions"]})

    def test_invalid_fc_and_ppi_method_choices_are_blocked(self):
        for route, name, value in (("fc", "fc_measure", "unknown"), ("ppi", "ppi_method", "automatic")):
            with self.subTest(route=route):
                answers = self.answers(route)
                answers["parameter_choices"][name] = fact(value)
                self.assertTrue(self.plan(answers)["blockers"])

    def test_invalid_answer_shapes_are_rejected(self):
        for key, value in (("runs", []), ("parameter_choices", []), ("toolkit_roots", []),
                            ("selected_run_ids", self.run_id), ("selected_run_ids", [1])):
            with self.subTest(key=key):
                answers = self.answers()
                answers[key] = value
                with self.assertRaises(ValueError):
                    self.plan(answers)

    def test_missing_independent_unit_is_requested(self):
        answers = self.answers()
        del answers["independent_unit"]
        self.assertIn("independent_unit", {q["id"] for q in self.plan(answers)["questions"]})

    def test_relative_or_missing_toolkit_directory_is_blocked(self):
        for root in ("toolkits/function", str(self.root / "missing")):
            with self.subTest(root=root):
                answers = self.answers()
                answers["toolkit_roots"]["function"] = root
                self.assertTrue(any("function" in text for text in self.plan(answers)["blockers"]))

    def test_project_inside_toolkit_is_rejected_before_new_revision(self):
        package = Path(self.packages["function"])
        nested_project = package / "project"
        self.scan_cli(nested_project)
        result = self.cli("plan", "--project-dir", nested_project, "--answers", self.save_answers(self.answers()), expected=2)
        self.assertIn("工具包", result["error"])
        self.assertFalse((nested_project / "revisions/0002").exists())


if __name__ == "__main__":
    unittest.main()
