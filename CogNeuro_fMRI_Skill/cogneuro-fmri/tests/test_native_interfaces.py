"""只测目录/配置/表格与调用交接；回调不运行MATLAB或任何分析算法。"""
import csv
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import execution
import fmri_project as project
import native_plan
import native_jobs
import toolkit_catalog as catalog


def fact(value):return {'value':value,'source':'用户确认：合成接口测试的文件/选择，不代表真实研究','confirmed':True}
def read(path):return json.loads(Path(path).read_text(encoding='utf-8'))


class NativeInterfacesTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name)
        self.data=self.root/'data';self.data.mkdir();self.project=self.root/'project'
        self.toolkit=self.root/'native';self.toolkit.mkdir()
        for file,text in {
            'run_function.m':'function x=run_function(cfg)\nx=cfg;end',
            'run_prediction.m':'function x=run_prediction(cfg)\nx=cfg;end',
            'run_ppi_batch.m':'function x=run_ppi_batch(cfg,manifest)\nx=cfg;end',
            'config/prediction_config.m':"function cfg=prediction_config\ncfg.dataFile='example.mat';\ncfg.outputRoot='example';cfg.execute=false;\ncfg.options.method='ridge';end",
            'config/ppi_config.m':"function cfg=ppi_config\ncfg.spmMat='';cfg.seedMask='';cfg.outputRoot='example';cfg.execute=false;cfg.mode='gppi';end",
            'config/ppi_runs_template.tsv':'subject\tsession\trun\tspm_mat\tseed_mask\tspm_session_index\n',
        }.items():
            p=self.toolkit/file;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text,encoding='utf-8')
        self.mat=self.data/'matrix.mat';self.mat.write_bytes(b'not imaging data; no MATLAB reads it')
        self.matlab=self.root/'matlab.exe';self.matlab.write_bytes(b'sentinel launcher; callbacks only')
        self.calls=[]

    def tearDown(self):self.tmp.cleanup()

    def answers(self,method='function.prediction'):
        entry=catalog.selected(method,{'function':str(self.toolkit)})
        return {'schema_version':1,'route':'toolkit_method','method_id':method,'goal':'现成方法接入',
            'paradigm':'矩阵测试','independent_unit':'每行一个独立被试','toolkit_roots':{'function':str(self.toolkit)},
            'inputs':{'dataFile':fact(str(self.mat))} if method.endswith('prediction') else {},
            'parameter_choices':{'native_config':fact({'config_hashes':entry['config_hashes'],'native_execute':True,
                'overrides':[{'path':'options.method','value':'cpm'}] if method.endswith('prediction') else []})}}

    def build(self,answers=None):
        inventory=project.scan_dataset(self.data);self.project.mkdir()
        project.write_json(self.project/'inventory.json',inventory)
        revision,plan=project.create_revision(self.project,inventory,self.answers() if answers is None else answers)
        state={'schema_version':1,'skill_version':project.VERSION,'data_root':str(self.data),
            'inventory_sha256':hashlib.sha256((self.project/'inventory.json').read_bytes()).hexdigest()}
        project.update_pointer(self.project,state,revision,plan)
        return plan,revision

    def runner(self,job_file,matlab_executable):
        job=read(job_file);self.calls.append(job)
        entry=next(x for x in catalog.registry() if x['id']==job['method_id'])
        if job['mode']=='preflight':
            return {'status':'preflight_passed','method_id':job['method_id'],'target':entry['target'],
                'native_analysis_called':False,'resolved_config':{'execute':job['native_execute']},'output_files':[]}
        output=Path(job['output_root']);output.mkdir();artifact=output/'native_result.mat';artifact.write_bytes(b'sentinel callback result')
        return {'status':'complete','method_id':job['method_id'],'target':entry['target'],
            'native_analysis_called':True,'native_statuses':['complete'],'output_files':[str(artifact)]}

    def test_registered_interfaces_have_unique_ids_and_explicit_signatures(self):
        entries=catalog.registry();self.assertEqual(len(entries),len({x['id'] for x in entries}))
        self.assertGreater(len(entries),30)
        self.assertEqual(next(x for x in entries if x['id']=='function.ppi_batch')['style'],'cfg_manifest')
        self.assertEqual(next(x for x in entries if x['id']=='function.prepare_dcm_spm')['style'],'dcm_spm')

    def test_mat_only_method_needs_no_bold_run_candidates(self):
        plan,_=self.build();self.assertEqual(plan['phase'],'draft_prepared');self.assertEqual(plan['runs'],[])
        self.assertEqual(plan['method_id'],'function.prediction')

    def test_initial_mat_only_scan_does_not_claim_bold_is_required(self):
        plan=project.make_plan(project.scan_dataset(self.data),{})
        self.assertEqual(plan['blockers'],[])
        self.assertFalse(any(q['id']=='selected_run_ids' for q in plan['questions']))

    def test_missing_matrix_is_asked_with_read_only_file_candidates(self):
        answers=self.answers();answers['inputs']={}
        plan=project.make_plan(project.scan_dataset(self.data),answers)
        item=next(q for q in plan['questions'] if q['id']=='inputs.dataFile')
        self.assertIn(str(self.mat),item['candidates'])

    def test_actual_config_change_requires_review_again(self):
        answers=self.answers();(self.toolkit/'config/prediction_config.m').write_text('function cfg=prediction_config\ncfg.execute=false;end',encoding='utf-8')
        plan=project.make_plan(project.scan_dataset(self.data),answers)
        self.assertTrue(any(q['id']=='native_config.config_hashes' for q in plan['questions']))

    def test_ppi_table_is_written_from_confirmed_template_cells(self):
        answers=self.answers('function.ppi_batch')
        source=self.data/'SPM.mat';source.write_bytes(b'only a path fixture')
        mask=self.data/'seed.nii';mask.write_bytes(b'only a path fixture')
        values=dict(subject='p1',session='',run='r1',spm_mat=str(source),seed_mask=str(mask),spm_session_index=1)
        answers['inputs']={'argument_manifest':{'template':'config/ppi_runs_template.tsv','rows':[{k:fact(v) for k,v in values.items()}]}}
        plan,revision=self.build(answers);self.assertEqual(plan['phase'],'draft_prepared')
        draft=revision/'draft_manifests/argument_manifest.DRAFT.tsv'
        with draft.open(encoding='utf-8',newline='') as handle:row=next(csv.DictReader(handle,delimiter='\t'))
        self.assertEqual(row['session'],'');self.assertEqual(row['spm_mat'],str(source))

    def test_unconfirmed_table_cells_remain_questions(self):
        answers=self.answers('function.ppi_batch')
        answers['inputs']={'argument_manifest':{'template':'config/ppi_runs_template.tsv','rows':[{'subject':fact('p1')}]}}
        plan=project.make_plan(project.scan_dataset(self.data),answers)
        self.assertEqual(plan['phase'],'needs_answers');self.assertTrue(any('seed_mask' in q['id'] for q in plan['questions']))

    def test_existing_table_missing_referenced_file_is_reported(self):
        answers=self.answers('function.ppi_batch');manifest=self.data/'runs.tsv'
        manifest.write_text('subject\tsession\trun\tspm_mat\tseed_mask\tspm_session_index\np1\t\tr1\tmissing.mat\tmissing.nii\t1\n',encoding='utf-8')
        answers['inputs']={'argument_manifest':fact(str(manifest))}
        plan=project.make_plan(project.scan_dataset(self.data),answers)
        self.assertTrue(any('missing.mat' in b for b in plan['blockers']))

    def test_prepare_only_inspects_configuration_and_preserves_sources(self):
        self.build();before=self.mat.read_bytes();cfg=(self.toolkit/'config/prediction_config.m').read_bytes()
        prepared=execution.prepare(self.project,str(self.matlab),None,runner=self.runner)
        self.assertEqual(prepared['phase'],'awaiting_confirmation');self.assertEqual(len(self.calls),1)
        self.assertEqual(self.calls[0]['mode'],'preflight');self.assertFalse((Path(prepared['attempt_dir'])/'results').exists())
        self.assertEqual(self.mat.read_bytes(),before);self.assertEqual((self.toolkit/'config/prediction_config.m').read_bytes(),cfg)

    def test_confirmed_generic_call_records_native_outputs_and_cannot_repeat(self):
        self.build();prepared=execution.prepare(self.project,str(self.matlab),None,runner=self.runner)
        done=execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=self.runner)
        self.assertEqual(done['phase'],'complete');self.assertEqual([j['mode'] for j in self.calls],['preflight','execute'])
        self.assertEqual(execution.status(self.project)['phase'],'complete')
        with self.assertRaises(ValueError):execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=self.runner)

    def test_native_prepare_selection_is_preserved_not_forced_to_estimate(self):
        answers=self.answers();answers['parameter_choices']['native_config']['value']['native_execute']=False
        self.build(answers);prepared=execution.prepare(self.project,str(self.matlab),None,runner=self.runner)
        done=execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=self.runner)
        self.assertEqual(done['phase'],'complete');self.assertFalse(self.calls[1]['native_execute'])

    def test_wrong_backend_identity_is_rejected_during_configuration_inspection(self):
        self.build()
        def wrong(job,exe):
            result=self.runner(job,exe);result['method_id']='function.dcm';return result
        result=execution.prepare(self.project,str(self.matlab),None,runner=wrong)
        self.assertEqual(result['phase'],'preflight_failed')

    def test_changed_declared_input_invalidates_exact_approval(self):
        self.build();prepared=execution.prepare(self.project,str(self.matlab),None,runner=self.runner)
        self.mat.write_bytes(b'changed after review')
        with self.assertRaises(ValueError):execution.execute(self.project,prepared['attempt_id'],prepared['review_digest'],'确认执行',runner=self.runner)
        self.assertEqual(execution.status(self.project)['phase'],'invalidated')

    def test_controlled_output_and_execute_overrides_are_blocked(self):
        for name in ['outputRoot','execute']:
            answers=self.answers();answers['parameter_choices']['native_config']['value']['overrides']=[{'path':name,'value':'forbidden'}]
            plan=project.make_plan(project.scan_dataset(self.data),answers)
            self.assertTrue(plan['blockers'])

    def test_native_mat_parameter_file_is_frozen_with_its_source(self):
        parameters=self.data/'models.mat';parameters.write_bytes(b'callback-only MAT parameter fixture')
        answers=self.answers();answers['parameter_choices']['native_config']['value']['overrides']=[{
            'path':'options','value':{'matlab_value_file':str(parameters),'variable':'nativeOptions'}}]
        self.build(answers);prepared=execution.prepare(self.project,str(self.matlab),None,runner=self.runner)
        review=read(Path(prepared['attempt_dir'])/'review.json')
        self.assertTrue(any(item['path']==str(parameters) for item in review['frozen_files']))

    def test_prior_stage_directory_can_feed_next_stage_without_output_overlap(self):
        old=self.project/'execution/0001/results';old.mkdir(parents=True)
        new=self.project/'execution/0002/results'
        native_jobs.check_output_separation(new,[{'path':str(old)}])
        with self.assertRaises(ValueError):native_jobs.check_output_separation(new,[{'path':str(self.project)}])


if __name__=='__main__':unittest.main()
