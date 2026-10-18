"""HCP-specific read-only ROI preparation from released compressed volumes."""
import json
import sys
from pathlib import Path
import numpy as np
import nibabel as nib
from scipy.io import savemat

request = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
roi_image = nib.load(request["roiFile"])
labels = np.asarray(roi_image.dataobj)
ids = np.unique(labels[labels > 0])
for record in request["records"]:
    output = Path(record["outputFile"])
    if output.exists():
        raise FileExistsError(output)
    image = nib.load(record["bold"])
    if image.shape[:3] != labels.shape or not np.allclose(image.affine, roi_image.affine, atol=1e-4):
        raise ValueError("ROI/bold world-space mismatch")
    if image.header.get_xyzt_units()[1] != "sec":
        raise ValueError("Explicit seconds timing required")
    tr = float(image.header.get_zooms()[3])
    volume = image.get_fdata(dtype=np.float32)
    series = np.empty((image.shape[3], len(ids)))
    counts = []
    for k, label in enumerate(ids):
        voxels = volume[labels == label, :]
        if voxels.shape[0] < 3 or not np.isfinite(voxels).all():
            raise ValueError("Insufficient/nonfinite fixed ROI coverage")
        series[:, k] = voxels.mean(axis=0, dtype=np.float64)
        counts.append(voxels.shape[0])
    if np.any(series.std(axis=0) <= np.finfo(float).eps):
        raise ValueError("Constant ROI time series")
    savemat(output, dict(roi=series, trSeconds=tr, roiLabels=ids, nVoxels=counts), do_compression=True)
    del volume, image
    print(f"Prepared {record['subject']}: {series.shape}", flush=True)
