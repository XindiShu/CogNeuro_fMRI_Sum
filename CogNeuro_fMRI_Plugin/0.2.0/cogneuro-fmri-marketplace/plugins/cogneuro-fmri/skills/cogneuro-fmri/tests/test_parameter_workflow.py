"""参数必答、逐项评估、真实确认溯源和报告集成；仅哑入口回调。"""
import copy
import json
from pathlib import Path
import unittest
from unittest import mock

import test_native_interfaces as native_fixtures
from test_native_interfaces import fact, read
import execution
import fmri_project as api
import review_policy
import workflow_report
from approval_fixture import reviewed


class ParameterWorkflowTests(unittest.TestCase):
    setUp = native_fixtures.NativeInterfacesTests.setUp
    tearDown = native_fixtures.NativeInterfacesTests.tearDown
    answers = native_fixtures.NativeInterfacesTests.answers
    build = native_fixtures.NativeInterfacesTests.build

    def runner(self, job_file, executable):
        result = native_fixtures.NativeInterfacesTests.runner(self, job_file, executable)
        if read(job_file)['mode']=='preflight':
            result['baseline_config']={'execute':False,'options':{'method':'ridge','seed':53},'outputRoot':'original'}
            result['resolved_config']={'execute':True,'options':{'method':'cpm','seed':53},'outputRoot':read(job_file)['output_root']}
        return result

    def prepare(self):
        self.build()
        return execution.prepare(self.project,str(self.matlab),None,runner=self.runner)

    def assessment(self, prepared):
        file=Path(prepared['attempt_dir'])/'assessment_input.json'
        document=read(Path(prepared['attempt_dir'])/'parameter_assessment.template.json')
        document['summary']='针对合成入口的参数复核'
        for item in document['items']:
            item.update(applicability='active',unit='无量纲',reason='本测试明确保留或调整的参数。',
                        basis=[{'kind':'source_code','reference':'synthetic fixture, not a scientific recommendation'}])
        return file,document

    def assess(self, prepared, document=None):
        file,original=self.assessment(prepared)
        file.write_text(json.dumps(document if document is not None else original),encoding='utf-8')
        return review_policy.assess(self.project,prepared['attempt_id'],prepared['review_digest'],file)

    def test_unknown_parameter_status_is_a_required_question(self):
        for value in (None,[], 'unknown'):
            answers=self.answers()
            if value is None:answers.pop('parameter_setup')
            else:answers['parameter_setup']=fact(value)
            plan=api.make_plan(api.scan_dataset(self.data),answers)
            self.assertEqual(plan['phase'],'needs_answers')
            self.assertTrue(any(q['id']=='parameter_setup' for q in plan['questions']))

    def test_three_user_parameter_states_are_recorded_without_guessing(self):
        for value in ('ready','not_started','partial'):
            answers=self.answers();answers['parameter_setup']=fact(value)
            plan=api.make_plan(api.scan_dataset(self.data),answers)
            self.assertEqual(plan['phase'],'draft_prepared')
            self.assertEqual(plan['parameter_setup']['value'],value)

    def test_prepared_table_captures_changed_and_retained_values(self):
        prepared=self.prepare();review=read(Path(prepared['attempt_dir'])/'review.json')
        rows={r['path']:r for r in review['parameter_review']['rows']}
        self.assertEqual(rows['options.method']['before'],'ridge')
        self.assertEqual(rows['options.method']['effective'],'cpm')
        self.assertTrue(rows['options.method']['changed'])
        self.assertFalse(rows['options.seed']['changed'])
        self.assertEqual(len(self.calls),1)

    def test_confirmation_phrase_alone_cannot_execute(self):
        prepared=self.prepare()
        with self.assertRaises(ValueError):
            execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=self.runner)
        self.assertEqual(len(self.calls),1)
        self.assertFalse((Path(prepared['attempt_dir'])/'results').exists())

    def test_approve_before_complete_assessment_is_rejected(self):
        prepared=self.prepare()
        with self.assertRaises(ValueError):
            review_policy.approve(self.project,prepared['attempt_id'],prepared['review_digest'],'message 1','确认')

    def test_missing_field_reason_basis_and_value_injection_are_rejected(self):
        prepared=self.prepare();_,document=self.assessment(prepared)
        changes=[lambda d:d['items'].pop(),lambda d:d['items'][0].update(reason=''),
                 lambda d:d['items'][0].update(basis=[]),lambda d:d['items'][0].update(effective='unauthorized')]
        for change in changes:
            altered=copy.deepcopy(document);change(altered)
            with self.assertRaises(ValueError):self.assess(prepared,altered)
        self.assertEqual(len(self.calls),1)

    def test_assessment_changes_digest_and_requires_final_confirmation(self):
        prepared=self.prepare();assessed=self.assess(prepared)
        self.assertNotEqual(prepared['review_digest'],assessed['review_digest'])
        with self.assertRaises(ValueError):
            execution.execute(self.project,assessed['attempt_id'],assessed['review_digest'],'确认执行',runner=self.runner)
        with self.assertRaises(ValueError):
            review_policy.approve(self.project,assessed['attempt_id'],prepared['review_digest'],'message 2','确认')
        confirmed=review_policy.approve(self.project,assessed['attempt_id'],assessed['review_digest'],'message 2','参数确认无误')
        self.assertEqual(confirmed['parameter_review_status'],'approved')

    def test_demo_approval_needs_explicit_delegation_and_is_not_human(self):
        prepared=self.prepare();assessed=self.assess(prepared)
        with self.assertRaises(ValueError):
            review_policy.approve(self.project,assessed['attempt_id'],assessed['review_digest'],'demo','确认','delegated_demo')
        review_policy.approve(self.project,assessed['attempt_id'],assessed['review_digest'],'demo','确认','delegated_demo','human authorized this demo')
        self.assertEqual(read(Path(assessed['attempt_dir'])/'user_confirmation.json')['actor'],'delegated_demo')

    def test_new_parameter_revision_invalidates_prior_confirmation(self):
        prepared=reviewed(self.project,self.prepare())
        answers=self.answers();answers['parameter_choices']['native_config']['value']['overrides'][0]['value']='krr'
        project,state,inventory=api.ensure_project(self.project)
        revision,plan=api.create_revision(project,inventory,answers);api.update_pointer(project,state,revision,plan)
        with self.assertRaises(ValueError):
            execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=self.runner)
        self.assertEqual(len(self.calls),1)

    def spec(self):
        return {'steps':[
            {'id':'pre','package':'preprocessing','action':'reuse','reason':'已有处理输入','source':'synthetic declared input history'},
            {'id':'glm','package':'glm','action':'skip','reason':'本目标不需要GLM','source':'synthetic goal'},
            {'id':'analysis','package':'function','action':'execute','method_id':'function.prediction',
             'project_dir':str(self.project),'reason':'所选分析入口','source':'synthetic research plan'}]}

    def register(self):
        file=self.root/'workflow_spec.json';file.write_text(json.dumps(self.spec()),encoding='utf-8')
        return workflow_report.register(self.project,file)

    def execute(self,prepared,runner=None):
        return execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=runner or self.runner)

    def test_automatic_report_separates_reuse_skip_and_actual_execution(self):
        prepared=reviewed(self.project,self.prepare());self.register();done=self.execute(prepared)
        self.assertEqual(done['phase'],'complete');self.assertNotIn('report_error',done)
        report=read(Path(done['report']['report_dir'])/'report.json')
        self.assertTrue(report['declared_workflow_complete'])
        self.assertEqual(report['package_coverage']['preprocessing']['invoked_attempts'],0)
        self.assertEqual(report['package_coverage']['glm']['invoked_attempts'],0)
        self.assertEqual(report['package_coverage']['function']['invoked_attempts'],1)
        self.assertEqual(report['declared_steps'][0]['reported_status'],'declared_reuse')
        self.assertEqual(report['attempts'][0]['confirmation']['actor'],'delegated_demo')
        self.assertEqual(len(self.calls),2)
        later=workflow_report.generate(self.project)
        self.assertNotEqual(later['report_dir'],done['report']['report_dir']);self.assertEqual(len(self.calls),2)

    def test_workflow_requires_reasons_for_unused_packages(self):
        self.prepare();document=self.spec();document['steps']=document['steps'][2:]
        file=self.root/'incomplete_workflow.json';file.write_text(json.dumps(document),encoding='utf-8')
        with self.assertRaises(ValueError):workflow_report.register(self.project,file)

    def test_report_failure_preserves_completed_analysis_and_prevents_rerun(self):
        prepared=reviewed(self.project,self.prepare())
        with mock.patch.object(workflow_report,'generate',side_effect=OSError('simulated report failure')):
            done=self.execute(prepared)
        self.assertEqual(done['phase'],'complete');self.assertIn('report_error',done)
        self.assertTrue((Path(prepared['attempt_dir'])/'receipt.json').exists())
        with self.assertRaises(ValueError):self.execute(prepared)
        self.assertEqual(len(self.calls),2)

    def test_failed_analysis_also_has_report_without_repeating(self):
        prepared=reviewed(self.project,self.prepare())
        def fail(job,exe):
            self.calls.append(read(job));raise RuntimeError('native failure fixture')
        done=self.execute(prepared,fail)
        self.assertEqual(done['phase'],'execution_failed');self.assertIn('report',done)
        report=read(Path(done['report']['report_dir'])/'report.json')
        self.assertEqual(report['attempts'][0]['error'],'native failure fixture')

    def test_prior_completed_revision_does_not_complete_new_plan(self):
        prepared=reviewed(self.project,self.prepare());self.register();self.execute(prepared)
        project,state,inventory=api.ensure_project(self.project)
        revision,plan=api.create_revision(project,inventory,self.answers());api.update_pointer(project,state,revision,plan)
        report=read(Path(workflow_report.generate(project)['report_dir'])/'report.json')
        self.assertFalse(report['declared_workflow_complete'])

    def test_changed_confirmation_record_cannot_execute(self):
        prepared=reviewed(self.project,self.prepare())
        file=Path(prepared['attempt_dir'])/'user_confirmation.json'
        file.write_text('{"review_digest":"changed"}',encoding='utf-8')
        with self.assertRaises(ValueError):self.execute(prepared)
        self.assertEqual(len(self.calls),1)

    def test_child_completion_automatically_updates_parent_report(self):
        self.build();parent=self.project
        child=self.root/'child_stage'
        self.project=child;prepared=reviewed(child,self.prepare())
        document=self.spec();document['steps'][2]['project_dir']=str(child)
        file=self.root/'parent_workflow.json';file.write_text(json.dumps(document),encoding='utf-8')
        workflow_report.register(parent,file)
        done=self.execute(prepared)
        self.assertTrue(done['workflow_report']['declared_workflow_complete'])
        report=read(Path(done['workflow_report']['report_dir'])/'report.json')
        self.assertEqual(report['project_dir'],str(parent))
        self.assertEqual(report['package_coverage']['function']['completed_attempts'],1)

    def test_unregistered_report_does_not_claim_whole_research_complete(self):
        prepared=reviewed(self.project,self.prepare());done=self.execute(prepared)
        self.assertFalse(done['report']['declared_workflow_complete'])
        self.assertEqual(len(self.calls),2)


if __name__=='__main__':unittest.main()
