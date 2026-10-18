"""Stream a NIfTI-1 .nii.gz to verify every voxel without loading 4D BOLD into RAM.

Usage: python scripts/verify_nifti_stream.py image.nii.gz [image2.nii.gz ...]
Read-only engineering QC: dimensions, datatype, finite values, range, gzip CRC.
"""
import gzip
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np


DTYPES = {2: np.dtype("u1"), 4: np.dtype("<i2"), 8: np.dtype("<i4"),
          16: np.dtype("<f4"), 64: np.dtype("<f8"), 512: np.dtype("<u2")}


def verify(path: Path) -> dict:
    with gzip.open(path, "rb") as stream:
        header = stream.read(352)
        if len(header) != 352 or struct.unpack_from("<i", header)[0] != 348:
            raise ValueError("Expected little-endian NIfTI-1")
        dims = struct.unpack_from("<8h", header, 40)
        ndim = dims[0]
        if ndim not in (3, 4):
            raise ValueError(f"Expected 3D/4D, found {ndim}D")
        shape = dims[1:ndim + 1]
        datatype = struct.unpack_from("<h", header, 70)[0]
        if datatype not in DTYPES:
            raise ValueError(f"Unsupported datatype {datatype}")
        dtype = DTYPES[datatype]
        offset = round(struct.unpack_from("<f", header, 108)[0])
        if offset < 352:
            raise ValueError("Invalid vox_offset")
        if offset > 352:
            stream.read(offset - 352)
        expected = math.prod(shape)
        count = nonfinite = zeros = 0
        minimum = math.inf
        maximum = -math.inf
        spare = b""
        while chunk := stream.read(8 * 1024 * 1024):
            chunk = spare + chunk
            usable = (len(chunk) // dtype.itemsize) * dtype.itemsize
            spare = chunk[usable:]
            if not usable:
                continue
            values = np.frombuffer(chunk[:usable], dtype=dtype)
            count += values.size
            good = np.isfinite(values)
            nonfinite += int(np.count_nonzero(~good))
            zeros += int(np.count_nonzero(values == 0))
            if np.any(good):
                minimum = min(minimum, float(np.min(values[good])))
                maximum = max(maximum, float(np.max(values[good])))
        if spare or count != expected:
            raise ValueError(f"Voxel count mismatch: {count} vs {expected}")
    return {"path": str(path), "shape": shape, "datatype": datatype,
            "voxels": count, "nonfinite": nonfinite, "zeros": zeros,
            "minimum": minimum, "maximum": maximum}


if __name__ == "__main__":
    for name in sys.argv[1:]:
        print(json.dumps(verify(Path(name)), ensure_ascii=False))
