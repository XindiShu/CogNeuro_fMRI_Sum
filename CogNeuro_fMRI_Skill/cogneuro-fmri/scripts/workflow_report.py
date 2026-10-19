"""从真实review/state/receipt生成版本化中文报告；从不重跑分析。"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import uuid

import fmri_project as api

PACKAGES = {'preprocessing': '预处理工具包', 'glm': 'GLM工具包', 'function': '分析方法工具包'}


def pointer(path, value):
    path = Path(path)
    temporary = path.with_name('.'+path.name+'.'+uuid.uuid4().hex)
    api.write_json(temporary,value)
    temporary.replace(path)


def load(path, default=None):
    return api.read_json(path) if Path(path).is_file() else default


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024*1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def register(project_dir, spec_file):
    project, _, _ = api.ensure_project(project_dir, require_data_root=False)
    spec = api.read_json(spec_file)
    if not isinstance(spec.get('steps'), list) or not spec['steps']:
        raise ValueError('workflow需要非空steps，显式列出执行、复用和跳过步骤。')
    ids, packages, children = set(), set(), set()
    for step in spec['steps']:
        if not isinstance(step, dict) or not isinstance(step.get('id'), str) or not api.ID_PATTERN.fullmatch(step['id']) or step['id'] in ids:
            raise ValueError('工作流步骤ID须唯一且有效。')
        ids.add(step['id'])
        if step.get('package') not in {*PACKAGES, 'project'} or step.get('action') not in {'execute', 'reuse', 'skip'}:
            raise ValueError('package须为preprocessing/glm/function/project，action须为execute/reuse/skip。')
        packages.add(step['package'])
        if not all(isinstance(step.get(key), str) and step[key].strip() for key in ('reason', 'source')):
            raise ValueError('每步均需说明原因和真实来源。')
        if step['action'] == 'execute':
            child, _, _ = api.ensure_project(step['project_dir'], require_data_root=False)
            step['project_dir'] = str(child)
            if not isinstance(step.get('method_id'), str) or not step['method_id']:
                raise ValueError('执行步骤必须有method_id，与实际review核对。')
            children.add(child)
    if not set(PACKAGES).issubset(packages):
        raise ValueError('完整工作流须交代三个包：未使用的包明确写skip及原因。')
    # 先检查全部父指针，避免写入一半后才发现归属冲突。
    for child in children-{project}:
        previous = load(child/'workflow-parent.json', {})
        if previous and Path(previous['project_dir']).resolve() != project:
            raise ValueError('阶段已登记到另一工作流，保留原归属。')
    directory = project/'workflow_revisions'
    directory.mkdir(exist_ok=True)
    number = next(n for n in range(1, 100000) if not (directory/f'{n:04d}.json').exists())
    target = directory/f'{number:04d}.json'
    api.write_json(target, {**spec, 'schema_version': 1, 'recorded_utc': api.now()})
    pointer(project/'workflow.json', {'revision': target.relative_to(project).as_posix(), 'sha256': sha(target)})
    for child in children-{project}:
        if not (child/'workflow-parent.json').exists():
            api.write_json(child/'workflow-parent.json', {'project_dir': str(project)})
    return {'workflow_revision': str(target), 'steps': len(spec['steps']), 'analysis_executed': False}


def workflow(project):
    pointer = load(project/'workflow.json')
    if not pointer:
        return None
    target = (project/pointer['revision']).resolve()
    if not api.within(target, project/'workflow_revisions') or sha(target) != pointer['sha256']:
        raise ValueError('工作流登记文件已变化或越界。')
    return api.read_json(target)


def package(review):
    if review.get('route') == 'toolkit_method':
        prefix = review.get('method_id', '').split('.')[0]
        return prefix if prefix in PACKAGES else 'project'
    return {'preprocess': 'preprocessing', 'preprocess_glm': 'preprocessing+glm', 'glm': 'glm', 'fc': 'function'}.get(review.get('route'), 'project')


def attempts(project):
    rows = []
    for attempt in sorted((project/'execution').glob('[0-9][0-9][0-9][0-9]')):
        if not attempt.is_dir() or not api.within(attempt.resolve(), project):
            raise ValueError('执行记录目录越界。')
        state = load(attempt/'state.json', {})
        review = load(attempt/'review.json', {})
        receipt = load(attempt/'receipt.json')
        confirmation = load(attempt/'user_confirmation.json')
        issues = []
        if receipt and state.get('receipt_sha256') != sha(attempt/'receipt.json'):
            issues.append('receipt哈希与状态不符')
        if review and state.get('review_digest') != sha(attempt/'review.json'):
            issues.append('review哈希与状态不符')
        if confirmation and state.get('user_confirmation_sha256') != sha(attempt/'user_confirmation.json'):
            issues.append('确认记录哈希与状态不符')
        outputs = receipt.get('outputs', []) if receipt else []
        missing = [item['path'] for item in outputs if not Path(item['path']).is_file() or Path(item['path']).stat().st_size != item['bytes']]
        if missing:
            issues.append('产物缺失或大小改变：'+str(missing))
        result = receipt.get('result', {}) if receipt else load(attempt/'execution_result.json', {})
        effective = result.get('resolved_config')
        expected = review.get('preflight', {}).get('resolved_config')
        if effective is not None and expected is not None and effective != expected:
            issues.append('入口执行时配置与审阅配置不同；须人工复核')
        rows.append({'project_dir': str(project), 'attempt_id': attempt.name,
            'package': package(review), 'method_id': review.get('method_id', review.get('route', '未确定')),
            'phase': state.get('phase', 'unknown'), 'error': state.get('error'),
            'analysis_invocation_started': (attempt/'approval.json').is_file(),
            'native_execute': review.get('options', {}).get('native_execute'),
            'review_path': str(attempt/'review.json') if review else None,
            'review_digest': state.get('review_digest'), 'confirmation': confirmation,
            'revision': review.get('revision'),
            'parameter_setup': review.get('parameter_setup'),
            'parameter_review': review.get('parameter_review'),
            'effective_config': expected if expected is not None else review.get('options'),
            'execution_config': effective, 'software': review.get('preflight', {}).get('software', {}),
            'config_sources': [r for r in review.get('frozen_files', []) if r.get('role') == 'config_source'],
            'toolkit_root': review.get('toolkit_root'), 'output_root': state.get('output_root', review.get('output_root')),
            'inputs': review.get('verified_facts', []), 'native_result': result,
            'logs': [str(p) for p in sorted(attempt.glob('*.log'))],
            'pipeline_stages': receipt.get('stages', []) if receipt else [],
            'outputs': outputs, 'record_issues': issues,
            'scientific_qc_passed': receipt.get('scientific_qc_passed', False) if receipt else False,
            'output_check_scope': 'existence_and_size; original SHA256 retained, no automatic large-file rehash'})
    return rows


def generate(project_dir):
    project, project_state, _ = api.ensure_project(project_dir, require_data_root=False)
    spec = workflow(project)
    projects = {project}
    declarations = spec['steps'] if spec else []
    for step in declarations:
        if step['action'] == 'execute':
            child, _, _ = api.ensure_project(step['project_dir'], require_data_root=False)
            projects.add(child)
    records = [item for child in sorted(projects) for item in attempts(child)]
    declared = []
    for step in declarations:
        revision = None
        if step['action']=='execute':
            child = Path(step['project_dir'])
            revision = str((child/api.read_json(child/'project.json')['current_revision']).resolve())
        actual = [row for row in records if row['project_dir'] == step.get('project_dir')
                  and row['method_id'] == step.get('method_id') and row['revision'] == revision]
        item = {**step, 'actual_attempts': [row['attempt_id'] for row in actual]}
        if step['action'] == 'execute':
            item['reported_status'] = 'complete' if any(row['phase'] == 'complete' and not row['record_issues'] for row in actual) else 'not_complete'
        else:
            item['reported_status'] = 'declared_'+step['action']
            item['evidence_scope'] = '用户/工作流声明；不记成本次原生执行'
        declared.append(item)
    coverage = {}
    for key, label in PACKAGES.items():
        found = [r for r in records if key in r['package'].split('+') and r['analysis_invocation_started']]
        notes = [s for s in declared if s['package'] == key]
        coverage[key] = {'label': label, 'invoked_attempts': len(found), 'completed_attempts': sum(r['phase']=='complete' for r in found),
                         'declarations': notes, 'note': '按真实调用记录计数；配置检查、外部上游处理不记作本次分析。'}
    complete = bool(records) and all(step['reported_status']=='complete' for step in declared if step['action']=='execute')
    if not spec:
        # 无完整工作流登记时只能报告已观察记录，不声称全研究已经结束。
        complete = False
    report = {'schema_version': 1, 'skill_version': api.VERSION, 'created_utc': api.now(),
        'project_dir': str(project), 'workflow_registered': bool(spec), 'declared_workflow_complete': complete,
        'package_coverage': coverage, 'declared_steps': declared, 'attempts': records,
        'analysis_rerun': False, 'report_scope': '执行与参数可追溯报告；不自动替代方法专属结果解释、人工QC或科学质量判定。',
        'environment': project_state.get('environment', {})}
    directory = project/'reports'
    directory.mkdir(exist_ok=True)
    for number in range(1, 100000):
        out = directory/f'{number:04d}'
        try:
            out.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise ValueError('报告版本过多。')
    api.write_json(out/'report.json', report)
    steps = [{'project_dir': r['project_dir'], 'attempt': r['attempt_id'], 'package': r['package'],
              'method': r['method_id'], 'phase': r['phase'], 'invocation_started': r['analysis_invocation_started'],
              'error': r['error'] or '', 'record_issues': json.dumps(r['record_issues'], ensure_ascii=False)} for r in records]
    api.tsv(out/'steps.tsv', ['project_dir','attempt','package','method','phase','invocation_started','error','record_issues'], steps)
    parameters = []
    for record in records:
        for row in (record.get('parameter_review') or {}).get('rows', []):
            parameters.append({'project_dir': record['project_dir'], 'attempt': record['attempt_id'], 'method': record['method_id'],
                **{k: json.dumps(row.get(k), ensure_ascii=False) for k in ['path','before','effective','changed','applicability','unit','reason','basis']}})
        if not record.get('parameter_review'):
            import review_policy
            for path,value in review_policy.flatten(record.get('effective_config') or {}).items():
                parameters.append({'project_dir':record['project_dir'],'attempt':record['attempt_id'],'method':record['method_id'],
                    'path':json.dumps(path,ensure_ascii=False),'before':'未捕获','effective':json.dumps(value,ensure_ascii=False),
                    'changed':'未记录','applicability':'旧版未记录','unit':'旧版未记录',
                    'reason':'旧版未记录逐项评估，不补造','basis':'[]'})
    api.tsv(out/'parameters.tsv', ['project_dir','attempt','method','path','before','effective','changed','applicability','unit','reason','basis'], parameters)
    def cell(value):
        return str(value).replace('|', '\\|').replace('\n', ' ')
    lines = ['# fMRI工作流执行与参数报告', '', '生成时间：'+report['created_utc'], report['report_scope'],
             '完整工作流登记：'+str(bool(spec))+'；登记的执行步骤全部完成：'+str(complete), '',
             '## 三个工具包的本次调用', '', '| 工具包 | 已提交入口调用次数 | 完成次数 |', '| --- | --- | --- |']
    for row in coverage.values():
        lines.append(f"| {row['label']} | {row['invoked_attempts']} | {row['completed_attempts']} |")
    lines += ['', '调用次数包括失败尝试；native_execute=false仍须按原生返回区分检查/准备/计算。未发现调用记录不代表上游从未处理。', '',
              '## 声明的起止路线、复用与跳过', '']
    if not declared:
        lines.append('未登记完整工作流。本报告仅覆盖这些项目中的真实记录，不推断未记录步骤或整项研究完成。')
    for step in declared:
        lines.append('- '+cell(step['id'])+' / '+cell(step['package'])+' / '+cell(step['reported_status'])+'：'+cell(step['reason'])+'；来源：'+cell(step['source']))
    lines += ['', '## 实际尝试与状态', '', '| 项目/尝试 | 方法 | 状态 | 错误/记录问题 |', '| --- | --- | --- | --- |']
    for row in records:
        lines.append('| '+' | '.join(cell(x) for x in [row['project_dir']+'/'+row['attempt_id'], row['method_id'], row['phase'], row['error'] or row['record_issues']])+' |')
    import review_policy
    for row in records:
        lines += ['', '## '+cell(row['method_id'])+' / '+row['attempt_id'],
                  '原生入口目录：'+str(row['toolkit_root']), '输出目录：'+str(row['output_root']),
                  '用户参数准备状态：'+json.dumps(row['parameter_setup'], ensure_ascii=False),
                  '确认记录：'+json.dumps(row['confirmation'], ensure_ascii=False),
                  '软件信息：'+json.dumps(row['software'], ensure_ascii=False)]
        if row['parameter_review']:
            lines.append(review_policy.markdown({'parameter_review': row['parameter_review'], 'parameter_setup': row['parameter_setup']}))
        else:
            lines += ['旧版记录未包含逐项参数审阅；实际记录的配置如下，不能补称已获新版确认。', '```json',
                      json.dumps(row['effective_config'], ensure_ascii=False, indent=2), '```']
        lines += ['实际预检/原生返回、逐项输入来源、源码指纹和产物SHA256见同目录report.json。',
                  '流水线子阶段记录：'+json.dumps(row['pipeline_stages'], ensure_ascii=False),
                  'scientific_qc_passed：'+str(row['scientific_qc_passed'])+'；不据完成状态自动宣称科研质量通过。']
    lines += ['', '## 文件', '', '- report.json：完整机器记录、输入来源、软件信息、原生返回和产物清单。',
              '- steps.tsv：实际尝试、成功/失败及错误。', '- parameters.tsv：逐项原值、有效值、适用性、依据和确认来源。',
              '本报告仅读既有记录，没有重复分析。方法专属图表及结论须由Codex读取真实输出后补充，不伪造未知结果。']
    (out/'REPORT_ZH.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    pointer(project/'latest_report.json', {'report_dir': str(out), 'created_utc': report['created_utc']})
    return {'report_dir': str(out), 'report': str(out/'REPORT_ZH.md'), 'analysis_rerun': False,
            'declared_workflow_complete': complete}


def after_execution(project, result):
    try:
        own = generate(project)
        parent = load(Path(project)/'workflow-parent.json')
        aggregated = None
        if parent:
            root = Path(parent['project_dir']).resolve()
            spec = workflow(root)
            if spec and any(s.get('project_dir') == str(Path(project).resolve()) for s in spec['steps']):
                aggregated = generate(root)
        return {**result, 'report': own, 'workflow_report': aggregated}
    except Exception as exc:
        # 报告失败不能把成功计算变成可重跑状态，但必须明确报告失败。
        pointer(Path(project)/'report_error.json', {'created_utc': api.now(), 'error': str(exc), 'analysis_preserved': True})
        return {**result, 'report_error': str(exc), 'analysis_preserved': True}
