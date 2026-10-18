"""Read raw HCP NIfTI headers and EVs without altering or preprocessing data."""
import gzip
import json
import re
import struct
from pathlib import Path
import sys

def audit(root):
    rows=[]
    for p in sorted(Path(root).glob('**/*.nii.gz')):
        match=re.search(r'/([0-9]{6})/unprocessed/3T/((?:tfMRI_LANGUAGE|rfMRI_REST[12])_(?:LR|RL))/\1_3T_\2\.nii.gz$',p.as_posix())
        if not match:
            continue
        with gzip.open(p,'rb') as stream:
            h=stream.read(352)
        endian='<' if struct.unpack('<i',h[:4])[0]==348 else '>'
        if struct.unpack(endian+'i',h[:4])[0]!=348:
            raise ValueError(f'Not NIfTI-1: {p}')
        dim=struct.unpack(endian+'8h',h[40:56])
        pix=struct.unpack(endian+'8f',h[76:108])
        if dim[0]!=4 or (h[123]&7)!=2 or (h[123]&56)!=8:
            raise ValueError('Expected 4D, millimeters and seconds')
        row=dict(subject=match[1],run=match[2],path=str(p),dimensions=dim[1:5],voxel_mm=pix[1:4],tr_seconds=pix[4],conditions={})
        if match[2].startswith('tfMRI_LANGUAGE'):
            for condition in ('story','math'):
                file=p.parent/'LINKED_DATA'/'EPRIME'/'EVs'/(condition+'.txt')
                evs=[list(map(float,line.split())) for line in file.read_text().splitlines() if line.strip()]
                assert evs and all(len(v)==3 and 0<=v[0]<dim[4]*pix[4] and v[1]>=0 and v[2]==1 for v in evs)
                row['conditions'][condition]=dict(count=len(evs),end_overrun_seconds=max(0,max(sum(v[:2]) for v in evs)-dim[4]*pix[4]))
        rows.append(row)
    return rows

if __name__=='__main__':
    rows=audit(sys.argv[1]); output=Path(sys.argv[2]); output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(rows,indent=2),encoding='utf-8')
    for row in rows:
        print(row['subject'],row['run'],row['dimensions'],row['tr_seconds'],row['conditions'])
