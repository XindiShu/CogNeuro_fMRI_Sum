"""Validate MD5 and safely extract each HCP ZIP into its own package directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import zipfile

def extract(root, subjects=None, layout='flat'):
    root = Path(root).resolve()
    if subjects:
        for subject in subjects:
            if not re.fullmatch(r'[0-9]{6}', subject):
                raise ValueError(f'Invalid HCP subject ID: {subject}')
        archives = [p for subject in subjects for p in (root / subject).glob('*.zip')]
        missing = [subject for subject in subjects if not (root / subject).is_dir() or not list((root / subject).glob('*.zip'))]
        if missing:
            raise FileNotFoundError(f'No ZIP packages for: {missing}')
    else:
        archives = list(root.glob('*/*.zip'))
    archives = sorted(archives, key=lambda p: (p.parent.name, 'LANGUAGE' not in p.name, 'Structural_unproc' not in p.name, p.name))
    if layout not in {'flat', 'subject'}:
        raise ValueError('layout must be flat or subject')
    reports = {}
    for archive in archives:
        out = root / (f'{archive.parent.name}_extracted' if layout == 'subject' else 'extracted')
        out.mkdir(exist_ok=True)
        report = reports.setdefault(out, [])
        expected = archive.with_suffix('.zip.md5').read_text().split()[0].lower()
        if not re.fullmatch('[0-9a-f]{32}', expected):
            raise ValueError(f'Invalid checksum: {archive.name}')
        print(f'Checking {archive.name}', flush=True)
        with archive.open('rb') as f:
            actual = hashlib.file_digest(f, 'md5').hexdigest()
        if actual != expected:
            raise ValueError(f'MD5 mismatch: {archive.name}')
        dest = out / archive.stem
        marker = dest / 'EXTRACTION_COMPLETE.json'
        if marker.exists():
            old = json.loads(marker.read_text())
            if old['md5'] != actual:
                raise ValueError(f'Existing extraction differs: {dest}')
            report.append(old)
            (out / 'extraction_manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
            continue
        if dest.exists() and any(dest.iterdir()):
            raise FileExistsError(f'Nonempty extraction without completion marker: {dest}')
        dest.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            required = sum(i.file_size for i in z.infolist())
            if shutil.disk_usage(out).free < required + 2**30:
                raise OSError('Insufficient disk space')
            for entry in z.infolist():
                target = (dest / entry.filename).resolve()
                if not target.is_relative_to(dest.resolve()) or ':' in entry.filename or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('Unsafe ZIP entry')
            print(f'Extracting {archive.name} ({required / 2**30:.2f} GiB)', flush=True)
            for entry in z.infolist():
                target = dest / entry.filename
                if entry.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                partial = target.with_name(target.name + '.extracting')
                with z.open(entry) as src, partial.open('wb') as dst:
                    shutil.copyfileobj(src, dst, 8 * 1024 * 1024)
                os.replace(partial, target)
        record = dict(archive=str(archive), directory=str(dest), md5=actual, bytes=required)
        marker.write_text(json.dumps(record, indent=2), encoding='utf-8')
        report.append(record)
        (out / 'extraction_manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(f'Complete: {sum(len(report) for report in reports.values())} verified packages', flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('root')
    parser.add_argument('--subjects', nargs='+', help='Only these six-digit HCP subjects')
    parser.add_argument('--layout', choices=['flat', 'subject'], default='flat',
                        help='subject writes to <subject>_extracted; flat preserves legacy output')
    args = parser.parse_args()
    extract(args.root, args.subjects, args.layout)
