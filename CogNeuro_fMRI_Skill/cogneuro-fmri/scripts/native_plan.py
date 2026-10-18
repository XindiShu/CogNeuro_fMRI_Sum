"""现成工具包的研究配置/表格问答层；不实现或验证分析算法。"""
from __future__ import annotations

import csv
import math
from pathlib import Path

import fmri_project as api
import toolkit_catalog as catalog


def path_column(name):
    return (name.endswith(('_file','_path','_image','_dir')) or name in {
        'bold','t1','events','confounds','spm_mat','mask','roi_file','seed_mask','motion','wm','csf','mean_epi','brain_mask',
        'metadata','provenance','fieldmaps','fieldmap_epi','sbref','anatomy_channels','atlases'})


def make_plan(inventory,answers):
    questions,blockers,verified=[],[],[]
    def ask(name,prompt):
        item={'id':name,'prompt':prompt,'reason':'现成入口需要该信息或用户确认'}
        if name.startswith('inputs.'):
            field=name.split('.')[1].lower();paths=[row['path'] for row in inventory.get('files',[])]
            if field=='inputroot':candidates=[inventory['data_root']]
            elif 'manifest' in field or 'catalog' in field:candidates=[p for p in paths if p.lower().endswith(('.tsv','.csv'))]
            elif 'spmmat' in field:candidates=[p for p in paths if Path(p).name.lower()=='spm.mat']
            elif 'datafile' in field:candidates=[p for p in paths if p.lower().endswith('.mat') and Path(p).name.lower()!='spm.mat']
            else:candidates=[]
            if candidates:item['candidates']=candidates[:20]
        questions.append(item)
    for key in ('goal','paradigm','independent_unit'):
        if not isinstance(answers.get(key),str) or not answers[key].strip():ask(key,'请说明 '+key+'，并据此选择工具包现成方法。')
    roots=answers.get('toolkit_roots',{})
    method_id=answers.get('method_id')
    entry=None
    if not method_id:ask('method_id','请从安装包入口目录选择研究目标对应的方法；不局限于旧四条路线。')
    else:
        try:entry=catalog.selected(method_id,roots)
        except (ValueError,OSError) as exc:blockers.append(str(exc))
    if entry and entry['role']=='validation':blockers.append('开发验证脚本不是研究分析入口；不能因分析目标而运行全套测试。')
    if entry and entry['missing_package_files']:blockers.append('所选安装位置缺少接口文件：'+str(entry['missing_package_files']))
    config,confirmed=api.fact_value(answers.get('parameter_choices',{}),'native_config')
    if not confirmed or not isinstance(config,dict):
        ask('parameter_choices.native_config','请审阅当前配置，确认config_hashes、native_execute及本研究overrides；不修改原包配置。');config={}
    if config and (set(config)!={'config_hashes','overrides','native_execute'} or not isinstance(config.get('config_hashes'),dict) or
                   not isinstance(config.get('overrides'),list) or not isinstance(config.get('native_execute'),bool)):
        blockers.append('native_config应只含config_hashes映射、native_execute布尔值及{path,value}覆盖数组。')
    if entry and config.get('native_execute') is False and not entry['has_native_execute']:
        blockers.append('该现成入口没有execute开关；prepare只检查配置，调用入口时native_execute须明确为true。')
    if entry and config and config.get('config_hashes')!=entry['config_hashes']:
        ask('native_config.config_hashes','配置工厂或其继承配置已变更，读取当前版本后重新确认；不得恢复旧文件。')
    overrides=config.get('overrides',[])
    if not isinstance(overrides,list):overrides=[]
    seen=set()
    for item in overrides:
        if not isinstance(item,dict) or set(item)!={'path','value'} or not isinstance(item['path'],str):
            blockers.append('每个override必须是path/value对象。');continue
        key=item['path']
        if key in {'execute','outputRoot'} or key in seen or any(not api.ID_PATTERN.fullmatch(part) for part in key.split('.')):
            blockers.append('重复或不允许的override路径：'+key)
        seen.add(key)
    raw_inputs=answers.get('inputs',{})
    if not isinstance(raw_inputs,dict):raise ValueError('answers.inputs必须为对象')
    bindings,tables,files,dirs={},[],{},{}
    def register(path,kind):
        p=Path(path).expanduser()
        if not p.is_absolute() or not p.exists() or (kind=='directory' and not p.is_dir()) or (kind!='directory' and not p.is_file()):
            raise ValueError('需要存在的绝对'+kind+'路径：'+str(path))
        p=p.resolve();s=p.stat();item={'path':str(p),'bytes':s.st_size,'mtime_ns':s.st_mtime_ns}
        (dirs if p.is_dir() else files)[str(p)]=item
        return str(p)
    for override in overrides:
        value=override.get('value') if isinstance(override,dict) else None
        if isinstance(value,dict) and set(value)=={'matlab_value_file','variable'}:
            try:
                register(value['matlab_value_file'],'file')
                if not isinstance(value['variable'],str) or not value['variable'].isidentifier():raise ValueError('MAT变量名无效')
            except (ValueError,TypeError) as exc:blockers.append(str(exc))
    inputs=entry['inputs'] if entry else {}
    for key in raw_inputs:
        if key not in inputs:blockers.append('该入口没有声明输入绑定 '+key+'；额外配置路径应在审阅后的overrides中提供。')
    for key,schema in inputs.items():
        item=raw_inputs.get(key)
        if item is None:
            if schema['required']:ask('inputs.'+key,'请提供 '+key+'：'+schema.get('note_zh','')+'；可给现成文件或按当前模板填表。')
            continue
        if isinstance(item,dict) and 'rows' in item:
            variants=entry['table_schemas'].get(key,[])
            selected=[variant for variant in variants if (item.get('template') and variant.get('relative_path')==item['template']) or
                (item.get('schema')=='native' and variant.get('kind')=='inline_native_schema')]
            if len(selected)!=1 or not selected[0]['exists']:
                ask('inputs.'+key+'.template','请选择当前安装包的一个有效模板；不得猜表头。');continue
            columns=selected[0]['columns'];rows=item['rows']
            extra=item.get('extra_columns',[])
            if not isinstance(extra,list) or any(not isinstance(x,str) or not api.ID_PATTERN.fullmatch(x) for x in extra):
                blockers.append(key+'的extra_columns无效');continue
            columns=list(dict.fromkeys(columns+extra))
            if not isinstance(rows,list) or not rows:ask('inputs.'+key+'.rows','按真实数据提供非空表格行。');continue
            filled=[]
            for n,row in enumerate(rows,1):
                if not isinstance(row,dict):raise ValueError('Table rows must be objects')
                values={}
                for name in columns:
                    value,ok=api.fact_value(row,name)
                    if not ok or not isinstance(value,(str,int,float,bool)) or isinstance(value,float) and not math.isfinite(value):
                        ask(f'inputs.{key}.rows.{n}.{name}','确认该单元格的真实值与来源；允许明确为空，不得补造。');continue
                    if isinstance(value,str) and value and path_column(name):
                        try:value=register(value,'directory' if name.endswith('_dir') else 'file')
                        except ValueError as exc:blockers.append(str(exc))
                    values[name]=value;verified.append({'field':f'{key}[{n}].{name}','value':value,'source':row[name]['source']})
                filled.append(values)
            name=key.replace('.','__')+'.tsv'
            tables.append({'binding':key,'name':name,'columns':columns,'rows':filled,'schema_source':selected[0]})
            bindings[key]={'generated_table':name}
        else:
            value,ok=api.fact_value(raw_inputs,key)
            if not ok:ask('inputs.'+key,'请确认 '+key+' 的实际值和来源。');continue
            if value=='' and not schema['required']:bindings[key]={'value':''};continue
            try:
                if schema['kind']!='value':
                    value=register(value,schema['kind'])
                    if key in entry['table_schemas'] and Path(value).suffix.lower()=='.tsv':
                        with Path(value).open(encoding='utf-8-sig',newline='') as handle:
                            reader=csv.DictReader(handle,delimiter='\t');header=reader.fieldnames or []
                            variants=entry['table_schemas'][key]
                            if not any(set(v.get('columns',[])).issubset(header) for v in variants if v.get('exists')):
                                ask('inputs.'+key+'.schema','现有清单列不匹配登记模板，请按当前原生读表函数核对列和条件分支。')
                            for row_number,row in enumerate(reader,1):
                                for column,cell in row.items():
                                    if cell and path_column(column):
                                        referenced=Path(cell)
                                        if not referenced.is_absolute():referenced=Path(value).parent/referenced
                                        register(str(referenced.resolve()),'directory' if column.endswith('_dir') else 'file')
                elif not isinstance(value,(str,int,float,bool,list,dict)):raise ValueError('参数值不能表示为JSON')
                bindings[key]={'value':value};verified.append({'field':key,'value':value,'source':raw_inputs[key]['source']})
            except (ValueError,TypeError) as exc:blockers.append(str(exc))
    # 导出入口的两类主清单取决于mode；不把示例文件当作用户数据。
    if entry and method_id=='glm.outputs':
        mode=next((x['value'] for x in overrides if x.get('path')=='mode'),'results')
        for key,needed in [('results.manifestFile',mode in ('results','both')),('betas.manifestFile',mode in ('betas','both'))]:
            if needed and key not in bindings:ask('inputs.'+key,'当前mode需要显式提供此清单。')
    known_roots={name:str(Path(value).expanduser().resolve()) for name,value in roots.items()
        if name in catalog.PACKAGE_MARKERS and isinstance(value,str) and value and Path(value).expanduser().is_dir()}
    if entry:known_roots[entry['package']]=entry['toolkit_root']
    return {'schema_version':1,'skill_version':api.VERSION,'route':'toolkit_method',
        'route_label':entry['label_zh'] if entry else '现成工具包入口','method_id':method_id,
        'phase':'needs_answers' if questions or blockers else 'draft_prepared','goal':answers.get('goal'),'paradigm':answers.get('paradigm'),
        'questions':questions,'blockers':blockers,'selected_run_ids':answers.get('selected_run_ids',[]),'runs':[],
        'toolkit_roots':known_roots,
        'parameter_choices':answers.get('parameter_choices',{}),'verified_facts':verified,'deferred_outputs':[],
        'native':{'entry':entry,'config_hashes':config.get('config_hashes',{}),'overrides':overrides,'native_execute':config.get('native_execute'),
            'bindings':bindings,'tables':tables,'files':list(files.values()),'directories':list(dirs.values())},
        'execution_ready':False,'limitations':['只做现成接口、配置和表格检查；不新增算法或重验工具包方法。',
            'MAT内部字段、科学约束与第三方依赖由所选原生入口检查；目录输入不声称已全内容哈希。']}


def input_changes(plan):
    problems=[]
    for item in plan.get('native',{}).get('files',[])+plan.get('native',{}).get('directories',[]):
        p=Path(item['path'])
        try:
            s=p.stat()
            if s.st_size!=item['bytes'] or s.st_mtime_ns!=item['mtime_ns']:problems.append('规划后输入已变化，请重新核对：'+str(p))
        except OSError:problems.append('规划后输入缺失：'+str(p))
    return problems


def write_drafts(root,plan):
    for table in plan['native']['tables']:
        api.tsv(root/(table['name'].replace('.tsv','.DRAFT.tsv')),table['columns'],table['rows'])
