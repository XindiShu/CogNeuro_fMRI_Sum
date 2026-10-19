"""Synthetic input tests: no participant data or imaging dependency needed."""

from __future__ import annotations

import gzip
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest


_MODULE_PATH = Path(__file__).resolve().parents[1] / "scripts" / "inventory.py"
_SPEC = importlib.util.spec_from_file_location("fmri_inventory", _MODULE_PATH)
assert _SPEC is not None and _SPEC.loader is not None
inventory = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(inventory)


def make_header(*, shape=(3, 4, 5, 8), tr=2.0, units=10, endian="<", datatype=16, bitpix=32):
    data = bytearray(352)
    struct.pack_into(endian + "i", data, 0, 348)
    dimensions = [len(shape), *shape]
    dimensions += [1] * (8 - len(dimensions))
    struct.pack_into(endian + "8h", data, 40, *dimensions)
    struct.pack_into(endian + "2h", data, 70, datatype, bitpix)
    struct.pack_into(endian + "8f", data, 76, 1, 2, 2, 2, tr, 1, 1, 1)
    struct.pack_into(endian + "f", data, 108, 352)
    data[123] = units
    data[344:348] = b"n+1\x00"
    return bytes(data)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "dataset"
        self.root.mkdir()

    def tearDown(self):
        self.temporary.cleanup()

    def put(self, relative: str, data: bytes = b"") -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        if relative.endswith(".nii.gz"):
            with gzip.open(path, "wb") as stream:
                stream.write(data)
        else:
            path.write_bytes(data)
        return path

    def bold(self, *, subject="01", session="01", run="01", task="memory", ext=".nii", header=None):
        return self.put(
            f"sub-{subject}/ses-{session}/func/sub-{subject}_ses-{session}_task-{task}_run-{run}_bold{ext}",
            make_header() if header is None else header,
        )

    def scan(self):
        return inventory.scan_dataset(self.root)

    def test_nifti_units_seconds_milliseconds_microseconds_and_big_endian(self):
        cases = [(8, 2.0, "<", ".nii"), (16, 2000, ">", ".nii.gz"), (24, 2000000, "<", ".nii.gz")]
        for index, (units, tr, endian, extension) in enumerate(cases):
            self.bold(run=str(index + 1), ext=extension, header=make_header(tr=tr, units=units | 2, endian=endian))
        output = self.scan()
        self.assertEqual(len(output["runs"]), 3)
        for run in output["runs"]:
            self.assertEqual(run["header"]["status"], "ok")
            self.assertAlmostEqual(run["header"]["tr_seconds"], 2.0)
            self.assertEqual(run["header"]["shape"], [3, 4, 5, 8])
            self.assertEqual(run["identity"]["subject"], "01")

    def test_corrupt_and_unsupported_bids_headers_remain_unusable_candidates(self):
        self.bold(run="01", header=b"broken")
        invalid_dimensions = bytearray(make_header())
        struct.pack_into("<h", invalid_dimensions, 42, 0)
        self.bold(run="02", header=bytes(invalid_dimensions))
        invalid_magic = bytearray(make_header())
        invalid_magic[344:348] = b"ni1\x00"
        self.bold(run="03", header=bytes(invalid_magic))
        self.bold(run="04", header=struct.pack("<i", 540) + bytes(536))
        self.put("corrupt_generic.nii", b"broken")
        result = self.scan()
        self.assertEqual(len(result["runs"]), 4)
        self.assertTrue(all(run["header"]["status"] != "ok" for run in result["runs"]))
        self.assertTrue(all(run["issues"] for run in result["runs"]))
        self.assertTrue(any("corrupt_generic" in warning for warning in result["warnings"]))

    def test_unknown_frequency_and_reserved_units_do_not_supply_tr(self):
        for index, units in enumerate((2, 34, 74, 15)):
            self.bold(run=str(index), header=make_header(units=units))
        result = self.scan()
        self.assertEqual(len(result["runs"]), 4)
        self.assertTrue(all(run["header"]["status"] == "error" for run in result["runs"]))
        self.assertTrue(all(run["header"]["tr_seconds"] is None for run in result["runs"]))

    def test_invalid_tr_spatial_dimensions_and_datatype_are_rejected(self):
        bad_voxel = bytearray(make_header())
        struct.pack_into("<f", bad_voxel, 80, float("nan"))
        self.bold(run="1", header=bytes(bad_voxel))
        self.bold(run="2", header=make_header(tr=0))
        self.bold(run="3", header=make_header(bitpix=8))
        result = self.scan()
        self.assertTrue(all(run["header"]["status"] == "error" for run in result["runs"]))

    def test_direct_sidecar_conflict_and_no_bids_inheritance(self):
        bold = self.bold()
        direct_json = bold.with_suffix(".json")
        direct_json.write_text(json.dumps({"RepetitionTime": 3, "TaskName": "memory"}), encoding="utf-8")
        self.put("task-memory_bold.json", json.dumps({"RepetitionTime": 9, "InheritedOnly": True}).encode())
        run = self.scan()["runs"][0]
        self.assertEqual(run["metadata"]["sources"], [str(direct_json)])
        self.assertEqual(run["metadata"]["values"]["RepetitionTime"], 3)
        self.assertNotIn("InheritedOnly", run["metadata"]["values"])
        self.assertAlmostEqual(run["header"]["tr_seconds"], 2)
        self.assertEqual(len(run["metadata"]["conflicts"]), 1)
        self.assertEqual(run["metadata"]["conflicts"][0]["header_seconds"], 2)
        self.assertTrue(any("no effective TR" in issue for issue in run["issues"]))

    def test_gzip_sidecar_name_and_bad_json_diagnostics(self):
        bold = self.bold(ext=".nii.gz")
        sidecar = bold.with_name(bold.name[:-7] + ".json")
        for value in (b"{", b"[]", b'{"RepetitionTime": NaN}', b"\xff"):
            sidecar.write_bytes(value)
            with self.subTest(value=value):
                run = self.scan()["runs"][0]
                self.assertEqual(run["metadata"]["values"], {})
                self.assertTrue(any("JSON" in issue for issue in run["issues"]))

    def test_bounded_sidecar_read_and_invalid_repetition_time(self):
        bold = self.bold()
        sidecar = bold.with_suffix(".json")
        sidecar.write_bytes(b" " * (inventory.MAX_JSON_BYTES + 1))
        self.assertTrue(any("limit" in issue for issue in self.scan()["runs"][0]["issues"]))
        for value in (True, -1, "2000", None):
            sidecar.write_text(json.dumps({"RepetitionTime": value}), encoding="utf-8")
            with self.subTest(value=value):
                self.assertTrue(any("finite positive" in issue for issue in self.scan()["runs"][0]["issues"]))

    def test_matching_subject_session_run_task_and_multiple_candidates(self):
        self.bold()
        valid_events = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_events.tsv")
        alternate_events = self.put("sub-01/ses-01/events/sub-01_ses-01_task-memory_run-01_events.tsv")
        self.put("sub-02/ses-01/func/sub-02_ses-01_task-memory_run-01_events.tsv")
        self.put("sub-01/ses-02/func/sub-01_ses-02_task-memory_run-01_events.tsv")
        self.put("sub-01/ses-01/func/sub-01_ses-01_task-other_run-01_events.tsv")
        self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-02_events.tsv")
        good_confounds = self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-01_desc-confounds_timeseries.tsv")
        self.put("sub-01/ses-01/func/sub-01_ses-01_task-memory_run-02_desc-confounds_timeseries.tsv")
        anatomy = self.put("sub-01/ses-01/anat/sub-01_ses-01_acq-MPRAGE_run-02_T1w.nii", make_header(shape=(3, 4, 5)))
        run = self.scan()["runs"][0]
        self.assertEqual(run["candidates"]["events"], sorted([str(valid_events), str(alternate_events)]))
        self.assertEqual(run["candidates"]["confounds"], [str(good_confounds)])
        self.assertEqual(run["candidates"]["t1"], [str(anatomy)])
        self.assertTrue(any("Multiple events" in issue for issue in run["issues"]))

    def test_acquisition_echo_confounds_are_not_cross_matched(self):
        self.put("sub-01/func/sub-01_task-rest_acq-fast_run-01_echo-1_bold.nii", make_header())
        good = self.put("sub-01/func/sub-01_task-rest_acq-fast_run-01_echo-1_desc-confounds_timeseries.tsv")
        self.put("sub-01/func/sub-01_task-rest_acq-fast_run-01_echo-2_desc-confounds_timeseries.tsv")
        self.put("sub-01/func/sub-01_task-rest_acq-slow_run-01_echo-1_desc-confounds_timeseries.tsv")
        self.assertEqual(self.scan()["runs"][0]["candidates"]["confounds"], [str(good)])

    def test_generic_identity_and_processing_remain_unknown_and_local(self):
        self.put("sub-01/ses-02/func/swraimage.nii.gz", make_header())
        self.put("sub-01/ses-02/func/events.tsv")
        self.put("sub-02/ses-02/func/events.tsv")
        self.put("single_volume.nii", make_header(shape=(3, 4, 5)))
        run = self.scan()["runs"][0]
        self.assertTrue(all(value is None for value in run["identity"].values()))
        self.assertEqual(len(run["candidates"]["events"]), 1)
        self.assertEqual(run["processing"], {"input_stage": "unknown", "temporal_state": "unknown", "smoothing_fwhm_mm": None})
        self.assertTrue(any("Generic 4D" in issue for issue in run["issues"]))

    def test_existing_spm_without_bold_is_an_uninspected_candidate(self):
        spm = self.put("sub-01/ses-02/task-memory/SPM.mat", b"uninspected MAT content")
        run = self.scan()["runs"][0]
        self.assertEqual(run["bold"], "")
        self.assertEqual(run["run_id"], "sub-01/ses-02/task-memory/SPM.mat")
        self.assertEqual(run["header"]["status"], "not_applicable")
        self.assertEqual(run["candidates"]["spm_mat"], [str(spm)])
        self.assertEqual(run["identity"]["subject"], "01")
        self.assertEqual(run["identity"]["session"], "02")
        self.assertEqual(run["processing"]["input_stage"], "unknown")

    def test_missing_root_file_root_and_empty_root(self):
        with self.assertRaises(ValueError):
            inventory.scan_dataset(self.root / "missing")
        file = self.put("not-a-directory", b"text")
        with self.assertRaises(ValueError):
            inventory.scan_dataset(file)
        self.assertEqual(self.scan()["runs"], [])

    def test_mixed_bold_and_spm_preserve_explicit_glm_sources(self):
        self.bold()
        first = self.put("sub-01/ses-01/glm/model-one/SPM.mat", b"model one")
        second = self.put("sub-01/ses-01/glm/model-two/SPM.mat", b"model two")
        result = self.scan()
        self.assertEqual(len(result["runs"]), 3)
        self.assertEqual(len({run["run_id"] for run in result["runs"]}), 3)
        glm_runs = [run for run in result["runs"] if not run["bold"]]
        self.assertEqual(len(glm_runs), 2)
        self.assertEqual({run["run_id"] for run in glm_runs}, {
            first.relative_to(self.root).as_posix(), second.relative_to(self.root).as_posix(),
        })
        self.assertTrue(all(run["header"]["status"] == "not_applicable" for run in glm_runs))

    def test_file_stat_metadata_is_recorded_and_tracks_updates(self):
        bold = self.bold()
        sidecar = bold.with_suffix(".json")
        sidecar.write_bytes(b'{"RepetitionTime":2}')
        before = {item["path"]: item for item in self.scan()["files"]}
        for path in (bold, sidecar):
            self.assertEqual(before[str(path)]["mtime_ns"], path.stat().st_mtime_ns)
            self.assertEqual(before[str(path)]["size_bytes"], path.stat().st_size)
        sidecar.write_bytes(b'{"RepetitionTime":2,"TaskName":"memory"}')
        after = {item["path"]: item for item in self.scan()["files"]}
        self.assertNotEqual(before[str(sidecar)]["size_bytes"], after[str(sidecar)]["size_bytes"])
        self.assertEqual(after[str(sidecar)]["mtime_ns"], sidecar.stat().st_mtime_ns)

    def test_determinism_and_input_bytes_are_unchanged(self):
        self.bold(run="02", ext=".nii.gz")
        bold = self.bold(run="01")
        bold.with_suffix(".json").write_bytes(b'{"RepetitionTime":2}')
        self.put("arbitrary.txt", b"unchanged\x00\xff")
        before = {path.relative_to(self.root).as_posix(): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        first, second = self.scan(), self.scan()
        after = {path.relative_to(self.root).as_posix(): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(before, after)
        self.assertEqual(first, second)
        self.assertEqual([item["relative_path"] for item in first["files"]], sorted(before))
        self.assertEqual([item["run_id"] for item in first["runs"]], sorted(item["run_id"] for item in first["runs"]))

    def test_external_symlink_file_directory_loop_and_root_are_skipped(self):
        self.bold()
        outside = self.root.parent / "outside"
        outside.mkdir()
        (outside / "secret_bold.nii").write_bytes(make_header())
        outside_file = outside / "sub-99_task-secret_bold.nii"
        outside_file.write_bytes(make_header())
        try:
            (self.root / "external").symlink_to(outside, target_is_directory=True)
            (self.root / "loop").symlink_to(self.root, target_is_directory=True)
            (self.root / "external_bold.nii").symlink_to(outside_file)
            root_link = self.root.parent / "root-link"
            root_link.symlink_to(self.root, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("Creating symbolic links is unavailable for this account.")
        result = self.scan()
        self.assertEqual(len(result["runs"]), 1)
        self.assertEqual(len(result["warnings"]), 3)
        self.assertFalse(any("external" in item["relative_path"] for item in result["files"]))
        linked_root = inventory.scan_dataset(root_link)
        self.assertEqual(linked_root["files"], [])
        self.assertEqual(linked_root["runs"], [])
        self.assertTrue(linked_root["warnings"])


if __name__ == "__main__":
    unittest.main()
