"""Copy a declared prefix of a NIfTI-1 .nii[.gz] to a NEW .nii, without changing input.

Engineering helper only; no preprocessing, interpolation, or HCP discovery.
"""
import argparse
import gzip
import hashlib
import json
import pathlib
import shutil
import struct


def stage(source, destination, frames):
    source, destination = pathlib.Path(source), pathlib.Path(destination)
    if destination.exists() or destination.suffix.lower() != '.nii':
        raise ValueError('Destination must be a new .nii file')
    opener = gzip.open if source.suffix.lower() == '.gz' else open
    with opener(source, 'rb') as src:
        header = bytearray(src.read(348))
        endian = '<' if struct.unpack('<i', header[:4])[0] == 348 else '>'
        if struct.unpack(endian + 'i', header[:4])[0] != 348 or header[344:347] != b'n+1':
            raise ValueError('Only single-file NIfTI-1 is supported')
        dims = list(struct.unpack(endian + '8h', header[40:56]))
        if dims[0] != 4 or not 4 <= frames <= dims[4] or any(x != 1 for x in dims[5:]):
            raise ValueError('Need 4D series and valid prefix length')
        bits = struct.unpack(endian + 'h', header[72:74])[0]
        offset = int(struct.unpack(endian + 'f', header[108:112])[0])
        if bits not in (8, 16, 32, 64) or offset < 352:
            raise ValueError('Unsupported bit depth or offset')
        original_frames = dims[4]
        dims[4] = frames
        header[40:56] = struct.pack(endian + '8h', *dims)
        extension = src.read(offset - 348)
        if len(extension) != offset - 348:
            raise ValueError('Truncated header')
        remaining = dims[1] * dims[2] * dims[3] * frames * bits // 8
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open('xb') as dst:
            dst.write(header)
            dst.write(extension)
            while remaining:
                chunk = src.read(min(8 * 1024 * 1024, remaining))
                if not chunk:
                    raise ValueError('Truncated image')
                dst.write(chunk)
                remaining -= len(chunk)
    digest = hashlib.file_digest(destination.open('rb'), 'sha256').hexdigest()
    record = dict(source=str(source.resolve()), destination=str(destination.resolve()),
                  source_frames=original_frames, retained_frames=frames,
                  operation='prefix copy only; no preprocessing', sha256=digest)
    destination.with_suffix('.json').write_text(json.dumps(record, indent=2), encoding='utf-8')
    print(json.dumps(record))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('source')
    p.add_argument('destination')
    p.add_argument('--frames', type=int, default=256)
    args = p.parse_args()
    stage(args.source, args.destination, args.frames)
