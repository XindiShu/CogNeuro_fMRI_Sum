"""将已确认的研究配置交给现成入口；prepare只读取配置，不运行分析。"""
from __future__ import annotations

from pathlib import Path
import shutil

import fmri_project as api
import native_plan
import toolkit_catalog as catalog


def prepare(project_dir,matlab_executable,spm_root=None,runner=None):
    import execution as ctl
    project,revision,inventory,answers,plan=ctl._current(project_dir)
    problems=native_plan.input_changes(api.read_json(revision/'plan.json'))
    if problems:raise ValueError('; '.join(problems))
    native=plan['native'];entry=native['entry'];toolkit=Path(entry['toolkit_root'])
    executable=Path(matlab_executable).expanduser()
    if not executable.is_absolute() or not executable.is_file():raise ValueError('MATLAB程序需要存在的绝对路径')
    executable=executable.resolve()
    spm=Path(spm_root).expanduser().resolve() if spm_root else None
    if spm and not (spm/'spm.m').is_file():raise ValueError('SPM目录无spm.m')
    for root in [Path(value) for value in plan['toolkit_roots'].values()]+[ctl.SKILL_ROOT]+([spm] if spm else []):
        if ctl._inside(project,root) or ctl._inside(root,project):raise ValueError('项目不能与工具包/skill/SPM互相包含')
    executions=ctl._safe_child(project,'execution');executions.mkdir(exist_ok=True)
    for n in range(1,1000000):
        attempt=executions/f'{n:04d}'
        try:attempt.mkdir();break
        except FileExistsError:continue
    else:raise ValueError('Too many attempts')
    with ctl._lock(attempt):
        ctl._state(attempt,'preflighting',route='toolkit_method',method_id=entry['id'],revision=str(revision))
        try:
            check_output_separation(attempt/'results',native['directories'])
            inputs=attempt/'inputs';inputs.mkdir();bindings=[]
            frozen=[ctl._record(revision/name,name) for name in ['answers.json','plan.json']]
            frozen += [ctl._record(project/'inventory.json','inventory'),ctl._record(executable,'matlab_launcher'),
                       ctl._record(catalog.REGISTRY_FILE,'registry_source')]
            frozen += [ctl._record(p,'planner_source') for p in sorted((ctl.SKILL_ROOT/'scripts').glob('*.py'))]
            frozen += [ctl._record(row['path'],'config_source') for row in entry['configuration_files']]
            frozen += [ctl._record(row['path'],'declared_input') for row in native['files']]
            for table in native['tables']:
                destination=inputs/table['name'];api.tsv(destination,table['columns'],table['rows'])
                frozen.append(ctl._record(destination,'generated_native_table'))
            for key,value in native['bindings'].items():
                resolved=str(inputs/value['generated_table']) if 'generated_table' in value else value['value']
                bindings.append({'path':key,'value':resolved})
            adapter=attempt/'adapter';adapter.mkdir()
            for source in sorted((ctl.SKILL_ROOT/'matlab').glob('*.m')):
                target=adapter/source.name;shutil.copyfile(source,target);frozen.append(ctl._record(target,'adapter_copy'))
            registry_copy=attempt/'toolkit-registry.json';shutil.copyfile(catalog.REGISTRY_FILE,registry_copy)
            frozen.append(ctl._record(registry_copy,'private_registry'))
            groups=[ctl._code_snapshot(toolkit,'selected_native_code'),ctl._code_snapshot(ctl.SKILL_ROOT/'matlab','adapter_source'),
                    ctl._code_snapshot(adapter,'private_adapter_code')]
            if spm:groups.append(ctl._code_snapshot(spm,'selected_spm_code'))
            base={'schema_version':1,'route':'toolkit_method','method_id':entry['id'],'toolkit_root':str(toolkit),
                'catalog_file':str(registry_copy),'spm_root':str(spm) if spm else '',
                'output_root':str(attempt/'results'),'work_root':str(attempt/'configuration_work'),
                'expected_runs':[],'bindings':bindings,'overrides':native['overrides'],'native_execute':native['native_execute']}
            pre={**base,'mode':'preflight','result_file':str(attempt/'preflight_result.json')}
            execute={**base,'mode':'execute','result_file':str(attempt/'execution_result.json')}
            ctl._json(attempt/'preflight_job.json',pre);ctl._json(attempt/'execution_job.json',execute)
            frozen += [ctl._record(attempt/name,name) for name in ['preflight_job.json','execution_job.json']]
            checked=ctl._invoke(attempt/'preflight_job.json',executable,runner)
            if checked.get('native_analysis_called') is not False or checked.get('method_id')!=entry['id'] or checked.get('target')!=entry['target']:
                raise ValueError('配置检查不得运行分析入口，且返回的方法/目标须匹配当前接口')
            ctl._verify(frozen);ctl._verify_code(groups)
            frozen.append(ctl._record(attempt/'preflight_result.json','resolved_config'))
            review={'schema_version':1,'skill_version':api.VERSION,'attempt_id':attempt.name,'project_dir':str(project),
                'revision':str(revision),'route':'toolkit_method','method_id':entry['id'],'method_label':entry['label_zh'],
                'goal':answers['goal'],'paradigm':answers['paradigm'],'independent_unit':answers['independent_unit'],
                'runs':[],'options':{'native_overrides':native['overrides'],'bindings':bindings,'native_execute':native['native_execute']},'parameter_choices':plan['parameter_choices'],
                'verified_facts':plan['verified_facts'],'toolkit_root':str(toolkit),'matlab_executable':str(executable),
                'spm_root':str(spm) if spm else '', 'output_root':base['output_root'],'preflight':checked,
                'frozen_files':frozen,'code_groups':groups,'directory_inputs':native['directories'],
                'execution_ready':False,'scientific_qc_passed':False,
                'scope':'Existing native entry call only; configuration inspection is not scientific/data validation.'}
            ctl._json(attempt/'review.json',review)
            text=ctl._review_markdown(review)
            text+='\n## 现成入口接入范围\n\n方法：'+entry['label_zh']+' (`'+entry['id']+'`)。\n'
            text+='实际调用 `'+entry['target']+'`；配置工厂 '+(entry['config_file'] or '无，按原生参数签名')+'。\n'
            text+='prepare仅读取配置和文件/表格结构，未调用分析入口，也未以execute=false运行分析。原生数值、模型及依赖检查在原入口承担。\n'
            text+='原包代码/正式配置不修改。输出使用本次新目录；目录输入只记录目录元数据，MAT内部引用不声称全内容冻结。\n'
            text+='如已有明确批准的完整工作流覆盖本阶段且参数/选图规则未变，沿用该授权；材料或研究选择改变时停止并重新确认。\n'
            (attempt/'review.md').write_text(text,encoding='utf-8')
            return ctl._state(attempt,'awaiting_confirmation',review_digest=ctl.sha256(attempt/'review.json'),
                review_path=str(attempt/'review.md'),review_markdown_sha256=ctl.sha256(attempt/'review.md'),job_file=str(attempt/'execution_job.json'))
        except Exception as exc:return ctl._state(attempt,'preflight_failed',error=str(exc),retry_policy='new_attempt_only')


def check_directory_inputs(review):
    for old in review.get('directory_inputs',[]):
        p=Path(old['path'])
        if not p.is_dir() or p.stat().st_mtime_ns!=old['mtime_ns']:raise ValueError('目录输入已变更或缺失：'+str(p))


def check_output_separation(output,directories):
    import execution as ctl
    for item in directories:
        if ctl._inside(output,item['path']) or ctl._inside(item['path'],output):
            raise ValueError('新输出不能与目录输入互相包含；可读取同项目中此前已完成的独立阶段目录')
