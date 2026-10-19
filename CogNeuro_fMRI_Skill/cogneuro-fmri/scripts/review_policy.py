"""项目参数审阅与确认记录；不推断科学参数，不修改原工具包。"""
from __future__ import annotations

import copy
import json
from pathlib import Path
import uuid

STATES = {'ready', 'not_started', 'partial'}


def require_setup(plan, answers):
    import fmri_project as api
    value, ok = api.fact_value(answers, 'parameter_setup')
    plan['parameter_setup'] = answers.get('parameter_setup')
    if not ok or not isinstance(value,str) or value not in STATES:
        plan['questions'].insert(0, {'id': 'parameter_setup',
            'prompt': '你是否已修改本次相关.m参数？请选择：已经修改 / 尚未修改 / 部分修改，并说明涉及文件。',
            'reason': '必须记录用户回答；不能从文件时间或参数值推断是否曾修改。',
            'choices': ['ready', 'not_started', 'partial']})
        plan['phase'] = 'needs_answers'
    return plan


def flatten(value, prefix=''):
    if isinstance(value, dict) and value:
        result = {}
        for key, item in value.items():
            result.update(flatten(item, prefix + '.' + key if prefix else key))
        return result
    return {prefix: value}


def parameter_rows(review):
    checked = review['preflight']
    if review['route'] == 'toolkit_method':
        if 'baseline_config' not in checked or 'resolved_config' not in checked:
            raise ValueError('当前调用桥未返回覆盖前/后配置，请使用0.5.0调用桥重新prepare；不要运行分析。')
        before = flatten(checked['baseline_config'])
        after = flatten(checked['resolved_config'])
        if checked.get('baseline_demo') or checked.get('resolved_demo'):
            before.update(flatten(checked.get('baseline_demo', {}), 'demo'))
            after.update(flatten(checked.get('resolved_demo', {}), 'demo'))
    else:
        # 旧专用适配器的配置是显式组装的，不能冒充原包默认值。
        before = {}
        after = flatten(review['options'])
    return [{'path': path, 'baseline_available': path in before,
             'before': before.get(path), 'effective': value,
             'changed': before.get(path) != value if path in before else None}
            for path, value in sorted(after.items()) if path]


def initialize(review, answers):
    import fmri_project as api
    value, ok = api.fact_value(answers, 'parameter_setup')
    if not ok or not isinstance(value,str) or value not in STATES:
        raise ValueError('必须先询问并记录用户参数准备状态，再prepare。')
    review['parameter_setup'] = copy.deepcopy(answers['parameter_setup'])
    review['parameter_review'] = {'status': 'needs_assessment', 'rows': parameter_rows(review),
        'baseline_meaning': '执行时读取的本机配置；不能据此断言是发行包默认值或用户未改过。'}


def template(review):
    return {'summary': '', 'items': [{'path': row['path'], 'applicability': '', 'unit': '',
        'reason': '', 'basis': []} for row in review['parameter_review']['rows']]}


def _text(value):
    return isinstance(value, str) and bool(value.strip())


def _pending(project_dir, attempt_id, digest):
    import execution as ctl
    import fmri_project as api
    project, state, attempt, current = ctl._get_attempt(project_dir, attempt_id)
    if current['phase'] != 'awaiting_confirmation':
        raise ValueError('只允许审阅尚未执行的尝试；失败或成功尝试不能复用。')
    if current['review_digest'] != digest or ctl.sha256(attempt/'review.json') != digest:
        raise ValueError('审阅摘要已变化，请读取当前版本。')
    if ctl.sha256(attempt/'review.md') != current['review_markdown_sha256']:
        raise ValueError('审阅文本已变化，请重新prepare。')
    review = api.read_json(attempt/'review.json')
    if str(ctl._safe_child(project, state['current_revision'])) != review['revision']:
        raise ValueError('问答或参数已产生新修订，旧确认失效，请重新prepare。')
    ctl._verify(review['frozen_files'])
    ctl._verify_code(review['code_groups'])
    return project, attempt, current, review


def assess(project_dir, attempt_id, digest, assessment_file):
    import execution as ctl
    import fmri_project as api
    _, _, attempt, _ = ctl._get_attempt(project_dir, attempt_id)
    with ctl._lock(attempt):
        _, attempt, current, review = _pending(project_dir, attempt_id, digest)
        if review.get('parameter_review', {}).get('status') != 'needs_assessment':
            raise ValueError('该尝试已完成参数评估；修改方案请plan新修订并重新prepare。')
        assessment = api.read_json(assessment_file)
        if not _text(assessment.get('summary')) or not isinstance(assessment.get('items'), list):
            raise ValueError('参数评估需要summary和完整items数组。')
        initial_review = copy.deepcopy(review)
        rows = {row['path']: row for row in review['parameter_review']['rows']}
        seen = set()
        for item in assessment['items']:
            key = item.get('path') if isinstance(item, dict) else None
            if key not in rows or key in seen:
                raise ValueError('未知或重复的参数评估：'+str(key))
            if item.get('applicability') not in {'active', 'inactive', 'operational'}:
                raise ValueError('参数须标记active/inactive/operational：'+key)
            if not _text(item.get('reason')) or not _text(item.get('unit')):
                raise ValueError('每项需提供理由及单位；无量纲写“无量纲”：'+key)
            basis = item.get('basis')
            if not isinstance(basis, list) or not basis or any(
                    not isinstance(b, dict) or b.get('kind') not in {'package_doc', 'source_code', 'official_web', 'paper', 'user', 'judgment'}
                    or not _text(b.get('reference')) for b in basis):
                raise ValueError('每项需记录文档/源码/用户/判断等真实依据：'+key)
            # 不允许评估表夹带新参数值；修改必须走新的plan/prepare。
            if set(item) != {'path', 'applicability', 'unit', 'reason', 'basis'}:
                raise ValueError('评估项只能包含path/applicability/unit/reason/basis。')
            rows[key].update(copy.deepcopy(item))
            seen.add(key)
        if seen != set(rows):
            raise ValueError('仍缺少参数评估：'+', '.join(sorted(set(rows)-seen)))
        ctl._json(attempt/'initial_review.json', initial_review)
        (attempt/'initial_review.md').write_text((attempt/'review.md').read_text(encoding='utf-8'),encoding='utf-8')
        ctl._json(attempt/'parameter_assessment.json', assessment)
        review['frozen_files'].append(ctl._record(attempt/'parameter_assessment.json', 'parameter_assessment'))
        review['parameter_review'].update(status='assessed', summary=assessment['summary'], rows=list(rows.values()))
        temporary = attempt/('.assessed_review.'+uuid.uuid4().hex+'.json')
        ctl._json(temporary, review)
        temporary.replace(attempt/'review.json')
        (attempt/'review.md').write_text(ctl._review_markdown(review), encoding='utf-8')
        return ctl._state(attempt, 'awaiting_confirmation', parameter_review_status='assessed',
            review_digest=ctl.sha256(attempt/'review.json'), review_markdown_sha256=ctl.sha256(attempt/'review.md'),
            user_confirmation_sha256=None)


def approve(project_dir, attempt_id, digest, source, reply, actor='human', delegation_source=None):
    import execution as ctl
    import fmri_project as api
    if not _text(source) or not _text(reply) or actor not in {'human', 'delegated_demo'}:
        raise ValueError('必须记录真实回复及其来源，actor须为human或delegated_demo。')
    if actor == 'delegated_demo' and not _text(delegation_source):
        raise ValueError('演示代理确认必须记录人类明确授权代答的来源。')
    _, _, attempt, _ = ctl._get_attempt(project_dir, attempt_id)
    with ctl._lock(attempt):
        _, attempt, current, review = _pending(project_dir, attempt_id, digest)
        if review.get('parameter_review', {}).get('status') != 'assessed':
            raise ValueError('请先完成全部参数评估，展示具体表格并等待用户确认。')
        target = attempt/'user_confirmation.json'
        if target.exists():
            raise ValueError('该尝试已有确认记录；不可覆盖，变更方案应创建新修订。')
        record = {'schema_version': 1, 'review_digest': digest, 'actor': actor, 'source': source,
                  'reply': reply, 'delegation_source': delegation_source, 'recorded_utc': api.now(),
                  'scope': 'this_exact_review', 'identity_verification': 'recorded_provenance_not_human_authentication'}
        ctl._json(target, record)
        return ctl._state(attempt, 'awaiting_confirmation', user_confirmation_sha256=ctl.sha256(target),
                          parameter_review_status='approved')


def require_approval(attempt, state, review):
    import execution as ctl
    if review.get('parameter_review', {}).get('status') != 'assessed':
        raise ValueError('缺少完整参数审阅；不能仅凭确认短语启动分析。')
    target = attempt/'user_confirmation.json'
    if not target.is_file() or ctl.sha256(target) != state.get('user_confirmation_sha256'):
        raise ValueError('缺少或已变更的用户确认记录；请展示参数表并记录真实回复。')
    record = ctl._read(target)
    if record.get('review_digest') != state['review_digest']:
        raise ValueError('用户确认不对应当前参数版本。')


def markdown(review):
    audit = review.get('parameter_review')
    if not audit:
        return '\n旧版记录未包含逐项参数审阅。\n'
    def show(value):
        return json.dumps(value, ensure_ascii=False).replace('|', '\\|').replace('\n', ' ')
    lines = ['\n## 参数逐项审阅\n', '用户参数准备状态：'+show(review.get('parameter_setup')),
             audit['baseline_meaning'], '评估状态：'+audit['status'], audit.get('summary', ''), '',
             '| 参数 | 本机原值 | 本次有效值 | 是否改变 | 适用性/单位 | 理由与依据 |',
             '| --- | --- | --- | --- | --- | --- |']
    for row in audit['rows']:
        before = show(row['before']) if row['baseline_available'] else '未捕获，不冒充默认值'
        reason = row.get('reason', '待Codex评估并交用户确认')
        refs = '; '.join(b['kind']+': '+b['reference'] for b in row.get('basis', []))
        cells = [row['path'], before, show(row['effective']), show(row['changed']),
                 row.get('applicability', '待评估')+'/'+row.get('unit', '待核对'), reason+' '+refs]
        lines.append('| '+' | '.join(str(c).replace('|', '\\|').replace('\n', ' ') for c in cells)+' |')
    return '\n'.join(lines)+'\n'
