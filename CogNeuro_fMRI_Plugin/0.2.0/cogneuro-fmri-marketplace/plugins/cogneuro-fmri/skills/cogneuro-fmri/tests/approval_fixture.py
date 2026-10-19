"""仅测试用的显式评估/演示确认；不作为用户自动批准入口。"""
import json
from pathlib import Path
import review_policy


def reviewed(project, prepared):
    if prepared['phase'] != 'awaiting_confirmation':
        return prepared
    folder = Path(prepared['attempt_dir'])
    assessment = json.loads((folder/'parameter_assessment.template.json').read_text(encoding='utf-8'))
    assessment['summary'] = '仅合成接口测试；不代表真实研究参数建议。'
    for item in assessment['items']:
        item.update(applicability='operational', unit='测试单位', reason='显式合成测试选择，验证连接机制。',
                    basis=[{'kind': 'source_code', 'reference': 'synthetic test fixture'}])
    file = folder/'test_assessment_input.json'
    file.write_text(json.dumps(assessment, ensure_ascii=False), encoding='utf-8')
    assessed = review_policy.assess(project, prepared['attempt_id'], prepared['review_digest'], file)
    return review_policy.approve(project, assessed['attempt_id'], assessed['review_digest'],
        'synthetic test harness', '确认仅运行哑入口接口测试', 'delegated_demo', 'explicit synthetic test invocation')
