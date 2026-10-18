"""Read-only, bounded fMRI file discovery for the planning skill.

This module does not load voxel arrays, infer preprocessing from prefixes, or
execute MATLAB. File and metadata matches are candidates requiring review.
"""

from __future__ import annotations

import gzip
import json
import math
import os
from pathlib import Path
import re
import stat
import struct
from typing import Any


# 可调整的读取上限：JSON 最大 2 MiB；仅读取 352 字节 NIfTI-1 头，绝不读取体素数组。
MAX_JSON_BYTES = 2 * 1024 * 1024
NIFTI_HEADER_BYTES = 352
# 可调整的 TR 一致性容差，单位为秒；差异超限必须交由用户确认。
TR_ABSOLUTE_TOLERANCE_SECONDS = 1e-5

_ENTITY_NAMES = {
    "sub": "subject", "ses": "session", "run": "run", "task": "task",
    "acq": "acquisition", "echo": "echo",
}
_ENTITY_PATTERN = re.compile(r"(?:^|_)(sub|ses|run|task|acq|echo)-([^_]+)")
_TEMPORAL_UNITS = {8: ("s", 1.0), 16: ("ms", 0.001), 24: ("us", 0.000001)}
_DATATYPE_BITS = {
    2: 8, 4: 16, 8: 32, 16: 32, 32: 64, 64: 64, 128: 24, 256: 8,
    512: 16, 768: 32, 1024: 64, 1280: 64, 1536: 128, 1792: 128,
    2048: 256, 2304: 32,
}


def _empty_identity() -> dict[str, str | None]:
    return {value: None for value in _ENTITY_NAMES.values()}


def _stem(path: Path) -> str:
    name = path.name
    for suffix in (".nii.gz", ".tsv.gz", ".nii", ".tsv", ".json", ".mat"):
        if name.lower().endswith(suffix):
            return name[:-len(suffix)]
    return path.stem


def _identity(relative_path: Path) -> dict[str, str | None]:
    identity = _empty_identity()
    # 仅接受明确的 BIDS 实体；目录层级只提供被试与 session 候选身份。
    for directory in relative_path.parts[:-1]:
        for prefix, key in (("sub-", "subject"), ("ses-", "session")):
            if directory.startswith(prefix) and "_" not in directory:
                identity[key] = directory[len(prefix):] or None
    for key, value in _ENTITY_PATTERN.findall(_stem(relative_path)):
        identity[_ENTITY_NAMES[key]] = value
    return identity


def _is_link(st_result: os.stat_result) -> bool:
    return stat.S_ISLNK(st_result.st_mode) or bool(
        getattr(st_result, "st_file_attributes", 0)
        & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400)
    )


def _classify(path: Path) -> str:
    name = path.name.lower()
    stem = _stem(path).lower()
    if name.endswith((".nii", ".nii.gz")):
        if stem.endswith("_t1w"):
            return "t1"
        if stem.endswith("_mask") or stem == "mask":
            return "mask"
        if re.search(r"(?:^|_)(roi|atlas|dseg)(?:_|$)", stem):
            return "roi"
        return "nifti"
    if name == "spm.mat":
        return "spm_mat"
    if name.endswith((".tsv", ".tsv.gz")):
        if stem == "events" or stem.endswith("_events"):
            return "events"
        if "confounds" in stem:
            return "confounds"
    if name.endswith((".json", ".tsv", ".log", ".mat")) and re.search(
        r"provenance|manifest|processing|completion|run_summary|status", stem
    ):
        return "provenance"
    if name.endswith(".json"):
        return "json"
    return "other"


def _safe_files(root: Path, warnings: list[str]) -> list[tuple[Path, os.stat_result]]:
    files: list[tuple[Path, os.stat_result]] = []
    visited: set[tuple[int, int]] = set()

    def visit(directory: Path) -> None:
        try:
            directory_stat = directory.stat(follow_symlinks=False)
            directory_key = (directory_stat.st_dev, directory_stat.st_ino)
            if directory_key in visited:
                warnings.append(f"Skipped repeated directory: {directory.relative_to(root).as_posix()}")
                return
            visited.add(directory_key)
            with os.scandir(directory) as entries:
                children = sorted(entries, key=lambda item: (item.name.casefold(), item.name))
        except OSError as exc:
            warnings.append(f"Cannot list directory {directory}: {type(exc).__name__}: {exc}")
            return
        for entry in children:
            path = Path(entry.path)
            relative = path.relative_to(root).as_posix()
            try:
                entry_stat = entry.stat(follow_symlinks=False)
                if _is_link(entry_stat):
                    warnings.append(f"Skipped symbolic link or reparse point: {relative}")
                    continue
                if not path.resolve(strict=True).is_relative_to(root):
                    warnings.append(f"Skipped path outside data root: {relative}")
                    continue
                if stat.S_ISDIR(entry_stat.st_mode):
                    visit(path)
                elif stat.S_ISREG(entry_stat.st_mode):
                    files.append((path, entry_stat))
                else:
                    warnings.append(f"Skipped nonregular file: {relative}")
            except OSError as exc:
                warnings.append(f"Cannot inspect {relative}: {type(exc).__name__}: {exc}")

    visit(root)
    return sorted(files, key=lambda item: item[0].relative_to(root).as_posix())


def _read_header(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "shape": [], "tr_seconds": None, "temporal_units": "unknown", "status": "error",
        "format": "unknown", "diagnostics": [],
    }
    diagnostics = result["diagnostics"]
    try:
        opener = gzip.open if path.name.lower().endswith(".gz") else open
        with opener(path, "rb") as handle:
            raw = handle.read(NIFTI_HEADER_BYTES)
    except (OSError, EOFError) as exc:
        diagnostics.append(f"Cannot read image header: {type(exc).__name__}: {exc}")
        return result
    if len(raw) < 4:
        diagnostics.append("Truncated NIfTI header.")
        return result
    little_size, big_size = struct.unpack("<i", raw[:4])[0], struct.unpack(">i", raw[:4])[0]
    if 540 in (little_size, big_size):
        result.update(status="unsupported", format="NIfTI-2")
        diagnostics.append("NIfTI-2 header discovery is not implemented in version 0.1.")
        return result
    if 348 not in (little_size, big_size):
        diagnostics.append("Unsupported or corrupt NIfTI header size.")
        return result
    result["format"] = "NIfTI-1"
    endian = "<" if little_size == 348 else ">"
    result["byte_order"] = "little" if endian == "<" else "big"
    if len(raw) < NIFTI_HEADER_BYTES:
        diagnostics.append("Truncated single-file NIfTI-1 header (expected at least 352 bytes).")
        return result
    if raw[344:348] != b"n+1\x00":
        diagnostics.append("Unsupported NIfTI magic; only single-file n+1 NIfTI-1 is supported.")
        return result
    dimensions = struct.unpack_from(endian + "8h", raw, 40)
    dimension_count = dimensions[0]
    if dimension_count < 1 or dimension_count > 7 or any(
        value <= 0 for value in dimensions[1:dimension_count + 1]
    ):
        diagnostics.append("Invalid NIfTI dimension count or nonpositive active dimension.")
        return result
    result["shape"] = list(dimensions[1:dimension_count + 1])
    datatype, bitpix = struct.unpack_from(endian + "2h", raw, 70)
    if datatype not in _DATATYPE_BITS or _DATATYPE_BITS[datatype] != bitpix:
        diagnostics.append("Unsupported or inconsistent NIfTI datatype/bitpix.")
    pixdim = struct.unpack_from(endian + "8f", raw, 76)
    if any(not math.isfinite(value) or value <= 0 for value in pixdim[1:min(3, dimension_count) + 1]):
        diagnostics.append("Invalid NIfTI spatial voxel dimensions.")
    voxel_offset = struct.unpack_from(endian + "f", raw, 108)[0]
    if not math.isfinite(voxel_offset) or voxel_offset < NIFTI_HEADER_BYTES:
        diagnostics.append("Invalid single-file NIfTI voxel offset.")
    units = raw[123]
    spatial_units, temporal_units = units & 7, units & 56
    result["spatial_units"] = {0: "unknown", 1: "m", 2: "mm", 3: "um"}.get(spatial_units, "invalid")
    invalid_units = spatial_units not in (0, 1, 2, 3) or bool(units & 192)
    if invalid_units:
        diagnostics.append("Invalid or unsupported NIfTI units byte.")
    if dimension_count >= 4:
        if invalid_units:
            pass
        elif temporal_units not in _TEMPORAL_UNITS:
            diagnostics.append("Missing or unsupported temporal units; TR was not assumed to be seconds.")
        elif not math.isfinite(pixdim[4]) or pixdim[4] <= 0:
            diagnostics.append("Invalid NIfTI repetition time.")
        else:
            result["temporal_units"], scale = _TEMPORAL_UNITS[temporal_units]
            result["tr_seconds"] = pixdim[4] * scale
    result["status"] = "error" if diagnostics else "ok"
    return result


def _read_sidecar(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        with path.open("rb") as handle:
            raw = handle.read(MAX_JSON_BYTES + 1)
        if len(raw) > MAX_JSON_BYTES:
            return None, f"JSON sidecar exceeds {MAX_JSON_BYTES} byte limit."
        values = json.loads(raw.decode("utf-8-sig"), parse_constant=lambda value: (_ for _ in ()).throw(
            ValueError(f"Nonfinite JSON constant: {value}")
        ))
        if not isinstance(values, dict):
            return None, "JSON sidecar must contain an object."
        return values, None
    except (OSError, UnicodeError, ValueError) as exc:
        return None, f"Cannot parse JSON sidecar: {type(exc).__name__}: {exc}"


def _compatible(
    run_path: Path, run_identity: dict[str, str | None],
    candidate_path: Path, candidate_identity: dict[str, str | None], role: str,
) -> bool:
    if run_identity["subject"] is None:
        # 泛型数据没有可确认的身份：仅列出同目录的候选文件，禁止跨被试推断。
        return candidate_path.parent == run_path.parent
    if candidate_identity["subject"] != run_identity["subject"]:
        return False
    if candidate_identity["session"] != run_identity["session"]:
        if not (role == "t1" and candidate_identity["session"] is None):
            return False
    # T1 的 run/acq 编码属于解剖扫描，不能与功能扫描的同名实体强行等同。
    entities = () if role == "t1" else ("run", "task", "acquisition", "echo")
    for entity in entities:
        first, second = run_identity[entity], candidate_identity[entity]
        if first is not None and second is not None and first != second:
            return False
    return True


def _base_run(relative: Path, path: Path) -> dict[str, Any]:
    return {
        "run_id": relative.as_posix(), "bold": str(path), "identity": _empty_identity(),
        "header": {}, "metadata": {"values": {}, "sources": [], "conflicts": []},
        "candidates": {role: [] for role in ("events", "t1", "confounds", "mask", "roi", "provenance", "spm_mat")},
        "processing": {"input_stage": "unknown", "temporal_state": "unknown", "smoothing_fwhm_mm": None},
        "issues": [],
    }


def scan_dataset(data_root: str | Path) -> dict[str, Any]:
    """Return a deterministic inventory without changing or executing any input.

    BIDS entity labels omit their prefixes (e.g. subject='01'). Identity and
    matches remain unknown/candidates. A missing/non-directory root raises
    ValueError. Links and reparse points are reported and skipped.
    """
    supplied_root = Path(os.path.abspath(os.path.expanduser(os.fspath(data_root))))
    result: dict[str, Any] = {
        "schema_version": 1, "data_root": str(supplied_root), "files": [], "runs": [], "warnings": [],
        "limitations": [
            "Candidate discovery only; a 4D image is not proof of BOLD acquisition or processing stage.",
            "Only the directly corresponding JSON sidecar is read; BIDS metadata inheritance is not implemented.",
            "NIfTI-1 headers only; voxel arrays and existing SPM.mat designs are not read or validated.",
            "Preprocessing, dummy-volume removal, filtering and smoothing history remain unknown until verified.",
            "File size and mtime_ns are recorded for change detection, not cryptographic proof; no image hashes are computed.",
            "This inventory does not establish data provenance or completeness.",
        ],
    }
    try:
        root_stat = supplied_root.lstat()
    except OSError as exc:
        raise ValueError(f"Cannot access data root: {supplied_root}") from exc
    if _is_link(root_stat):
        result["warnings"].append("Data root is a symbolic link or reparse point; scanning was skipped.")
        return result
    if not stat.S_ISDIR(root_stat.st_mode):
        raise ValueError(f"Data root must be a directory: {supplied_root}")
    root = supplied_root.resolve(strict=True)
    result["data_root"] = str(root)
    warnings = result["warnings"]
    discovered = _safe_files(root, warnings)
    file_paths: dict[Path, str] = {}
    for path, file_stat in discovered:
        role = _classify(path)
        file_paths[path] = role
        result["files"].append({
            "path": str(path), "relative_path": path.relative_to(root).as_posix(),
            "kind": role, "size_bytes": file_stat.st_size, "mtime_ns": file_stat.st_mtime_ns,
        })
    for path, kind in file_paths.items():
        if kind != "nifti":
            continue
        relative = path.relative_to(root)
        is_bids_bold = _stem(path).lower().endswith("_bold")
        header = _read_header(path)
        is_generic_4d = len(header["shape"]) >= 4 and header["shape"][3] > 1
        if not is_bids_bold and not is_generic_4d:
            if header["status"] != "ok":
                warnings.append(f"NIfTI header not usable for discovery: {relative.as_posix()}: {'; '.join(header['diagnostics'])}")
            continue
        run = _base_run(relative, path)
        run["header"] = header
        if is_bids_bold:
            run["identity"] = _identity(relative)
            if run["identity"]["subject"] is None:
                run["issues"].append("BOLD filename has no confirmed subject entity.")
        else:
            run["issues"].append("Generic 4D image candidate; BOLD modality and all run identities require user confirmation.")
        if len(header["shape"]) < 4 or header["shape"][3] <= 1:
            run["issues"].append("BOLD candidate lacks a confirmed time series with more than one volume.")
        if len(header["shape"]) > 4 and any(value != 1 for value in header["shape"][4:]):
            run["issues"].append("Additional nonsingleton image dimensions require manual interpretation.")
        run["issues"].extend(header["diagnostics"])
        sidecar = path.with_name(_stem(path) + ".json")
        if sidecar in file_paths:
            run["metadata"]["sources"].append(str(sidecar))
            values, diagnostic = _read_sidecar(sidecar)
            if diagnostic:
                run["issues"].append(diagnostic)
            else:
                run["metadata"]["values"] = values
                if "RepetitionTime" in values:
                    json_tr = values["RepetitionTime"]
                    if isinstance(json_tr, bool) or not isinstance(json_tr, (int, float)) or not math.isfinite(json_tr) or json_tr <= 0:
                        run["issues"].append("JSON RepetitionTime must be a finite positive number in seconds.")
                    elif header["tr_seconds"] is not None and not math.isclose(
                        header["tr_seconds"], json_tr, rel_tol=1e-5, abs_tol=TR_ABSOLUTE_TOLERANCE_SECONDS
                    ):
                        run["metadata"]["conflicts"].append({
                            "field": "RepetitionTime", "header_seconds": header["tr_seconds"],
                            "json_seconds": json_tr, "source": str(sidecar),
                        })
                        run["issues"].append("Header and JSON repetition times conflict; no effective TR was chosen.")
        result["runs"].append(run)
    existing_run_ids = {run["run_id"] for run in result["runs"]}
    for path, kind in file_paths.items():
        relative = path.relative_to(root)
        if kind != "spm_mat" or relative.as_posix() in existing_run_ids:
            continue
        run = _base_run(relative, path)
        run["bold"] = ""
        run["identity"] = _identity(relative)
        run["header"] = {"status": "not_applicable", "shape": [], "tr_seconds": None, "temporal_units": "unknown", "diagnostics": []}
        run["candidates"]["spm_mat"] = [str(path)]
        run["issues"].append("Existing SPM.mat is an uninspected GLM candidate; design, estimates and identities require verification before PPI/DCM.")
        result["runs"].append(run)
        existing_run_ids.add(run["run_id"])
    for run in result["runs"]:
        run_path = Path(run["bold"]) if run["bold"] else root / run["run_id"]
        for path, role in file_paths.items():
            if role not in run["candidates"]:
                continue
            if _compatible(run_path, run["identity"], path, _identity(path.relative_to(root)), role):
                run["candidates"][role].append(str(path))
        for role, candidates in run["candidates"].items():
            run["candidates"][role] = sorted(set(candidates))
            if len(run["candidates"][role]) > 1:
                run["issues"].append(f"Multiple {role} candidates require explicit selection.")
        if any(_identity(Path(item).relative_to(root))["session"] is None for item in run["candidates"]["t1"]) and run["identity"]["session"] is not None:
            run["issues"].append("Subject-level T1 candidate has no session entity; anatomical correspondence needs confirmation.")
    result["runs"].sort(key=lambda item: item["run_id"])
    result["warnings"] = sorted(set(warnings))
    return result
