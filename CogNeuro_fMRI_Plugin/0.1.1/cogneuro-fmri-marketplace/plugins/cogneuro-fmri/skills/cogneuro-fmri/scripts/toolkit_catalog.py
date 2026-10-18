"""只读连接现成工具包：入口签名、配置来源、TSV列和说明，不运行MATLAB。"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re

REGISTRY_FILE=Path(__file__).resolve().parents[1]/'assets/toolkit-registry.json'
PACKAGE_MARKERS={'preprocessing':'matlab/+psy/preprocess_batch.m','glm':'matlab/+psy/glm_batch.m','function':'run_function.m'}


def registry():
    data=json.loads(REGISTRY_FILE.read_text(encoding='utf-8'))
    ids=[entry['id'] for entry in data['entries']]
    if len(ids)!=len(set(ids)):raise ValueError('Duplicate interface id')
    return data['entries']


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def under(root,relative):
    path=(root/relative).resolve()
    if root!=path and root not in path.parents:raise ValueError('Registry path escapes selected toolkit')
    return path


def source(root,relative):
    path=under(root,relative)
    return {'relative_path':relative,'path':str(path),'sha256':sha(path),'bytes':path.stat().st_size}


def configuration_sources(root,relative):
    """追踪配置工厂间的静态引用；保留源码行，不求值MATLAB表达式。"""
    records,parameters,seen=[],[],set()
    def visit(name):
        if not name or name in seen:return
        seen.add(name)
        path=under(root,name)
        if not path.is_file():return
        records.append(source(root,name))
        text=path.read_text(encoding='utf-8-sig')
        for line_number,line in enumerate(text.splitlines(),1):
            code=line.partition('%')[0]
            for match in re.finditer(r'\bcfg\.([A-Za-z]\w*(?:\.[A-Za-z]\w*)*)\s*=',code):
                parameters.append({'field':match.group(1),'source_path':name,'line':line_number,'matlab_source':line.strip()})
        for factory in sorted(set(re.findall(r'\b([A-Za-z]\w*_config)\b',text))):
            nested='config/'+factory+'.m'
            if under(root,nested).is_file():visit(nested)
    visit(relative)
    return records,parameters


def inspect_entry(entry,root):
    root=Path(root).expanduser()
    if not root.is_absolute() or not root.is_dir():raise ValueError('Toolkit root must be an existing absolute directory')
    root=root.resolve()
    record={**entry,'toolkit_root':str(root),'inspection_level':'source_and_schema_only','analysis_executed':False}
    target=entry['target']
    target_file=('matlab/+'+target.replace('.', '/')+'.m') if '.' in target else target+'.m'
    # +namespace/name，而非 +namespace.name；当前三包的公共目标均为单层包函数。
    if '.' in target:
        package,name=target.split('.',1);target_file=f'matlab/+{package}/{name}.m'
    missing=[name for name in (entry['entry_file'],target_file,entry['config_file']) if name and not under(root,name).is_file()]
    record['missing_package_files']=missing
    record['interface_status']='source_mapped' if not missing else 'missing_package_files'
    record['source_files']=[source(root,name) for name in dict.fromkeys([entry['entry_file'],target_file]) if under(root,name).is_file()]
    record['configuration_files'],record['parameters']=configuration_sources(root,entry['config_file'])
    record['has_native_execute']=any(item['field']=='execute' for item in record['parameters'])
    record['config_hashes']={item['relative_path']:item['sha256'] for item in record['configuration_files']}
    record['documentation']=[{**source(root,name),'exists':True} if under(root,name).is_file()
        else {'relative_path':name,'path':str(under(root,name)),'exists':False} for name in entry['docs']]
    tables={}
    for binding,variants in entry['templates'].items():
        tables[binding]=[]
        for variant in variants:
            if isinstance(variant,dict):
                tables[binding].append({**variant,'kind':'inline_native_schema','exists':under(root,variant['source']).is_file()})
                continue
            path=under(root,variant)
            item={'relative_path':variant,'kind':'installed_template','exists':path.is_file()}
            if path.is_file():
                with path.open(encoding='utf-8-sig',newline='') as handle:columns=next(csv.reader(handle,delimiter='\t'),[])
                item.update(source(root,variant),columns=columns)
            tables[binding].append(item)
    record['table_schemas']=tables
    if under(root,entry['entry_file']).is_file():
        lines=under(root,entry['entry_file']).read_text(encoding='utf-8-sig').splitlines()
        record['entry_signature']=next((line.strip() for line in lines if line.lstrip().startswith('function ')),'script; call underlying target with cfg')
        record['input_schema_hints']=[{'line':n,'source':line.strip()} for n,line in enumerate(lines,1)
            if any(token in line for token in ("load(cfg.","read_tsv(","isfield(d,","isfield(data,","read_runs(","required="))][:18]
        record['selector_hints']=[{'line':n,'source':line.strip()} for n,line in enumerate(lines,1)
            if any(token in line for token in ('allowed=','ismember(cfg.methods','ismember(cfg.method,','ismember(cfg.mode,','ismember(cfg.options.method'))][:12]
        record['output_name_hints']=sorted(set(re.findall(r"'([A-Za-z][A-Za-z0-9_]*\.(?:mat|tsv|json))'",'\n'.join(lines))))
    record['preflight_policy']='configuration_only; no native analysis or native execute=false call during prepare'
    return record


def inspect_toolkits(roots):
    entries=[];unmapped={}
    for package,root in roots.items():
        if package not in PACKAGE_MARKERS:raise ValueError('Unknown package: '+package)
        selected=Path(root).expanduser().resolve()
        if not selected.is_dir() or not (selected/PACKAGE_MARKERS[package]).is_file():raise ValueError('Invalid '+package+' toolkit root')
        own=[entry for entry in registry() if entry['package']==package]
        entries.extend(inspect_entry(entry,selected) for entry in own)
        mapped={entry['entry_file'] for entry in own}
        launchers={path.name for path in selected.glob('run_*.m')}|{p.name for p in selected.glob('validate_*.m')}
        unmapped[package]=sorted(launchers-mapped)
    return {'schema_version':1,'inspection_level':'source_and_schema_only','analysis_executed':False,
        'entries':entries,'unmapped_entrypoints':unmapped,
        'counts':{package:sum(entry['package']==package for entry in entries) for package in roots},
        'scope_note':'An existing toolkit method is not an unfinished algorithm merely because an interface needs wiring; native numerical/scientific validation remains owned by the toolkit.'}


def selected(method_id,roots):
    entry=next((item for item in registry() if item['id']==method_id),None)
    if not entry:raise ValueError('Unknown method_id; inspect actual installed entrypoints first')
    if entry['package'] not in roots:raise ValueError('Missing toolkit_roots.'+entry['package'])
    return inspect_entry(entry,roots[entry['package']])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for package in PACKAGE_MARKERS:parser.add_argument('--'+package+'-root')
    parser.add_argument('--method',help='仅展开选定方法及其真实配置源码行')
    parser.add_argument('--output',help='[可选] 新JSON文件；不覆盖已有文件')
    args=parser.parse_args();roots={name:getattr(args,name+'_root') for name in PACKAGE_MARKERS if getattr(args,name+'_root')}
    if not roots:parser.error('Provide at least one installed toolkit root')
    result=selected(args.method,roots) if args.method else inspect_toolkits(roots)
    if args.output:
        with Path(args.output).open('x',encoding='utf-8') as handle:json.dump(result,handle,ensure_ascii=False,indent=2)
        print(json.dumps({'output':str(Path(args.output).resolve()),'counts':result.get('counts'),'analysis_executed':False},ensure_ascii=False))
    else:print(json.dumps(result,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
