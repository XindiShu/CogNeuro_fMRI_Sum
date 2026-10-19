"""合成完整SPM空间处理→smoothed GLM，并独立核对未平滑交接；不读取真实被试。"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import subprocess

from run_synthetic_integration import cli, digest, fact, write_json, reviewed


def matlab(executable, expression, log):
    with log.open('xb') as handle:
        done = subprocess.run([executable, '-wait', '-batch', expression], shell=False,
                              stdout=handle, stderr=subprocess.STDOUT, check=False)
    if done.returncode:
        raise RuntimeError(f'MATLAB returned {done.returncode}; preserved log: {log}')


def literal(path):
    return str(path).replace("'", "''")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('matlab-executable','spm-root','preprocessing-root','glm-root','fixture-root','output-root'):
        parser.add_argument('--'+name, required=True, help='[必填] 实际绝对路径；输出目录必须全新')
    args = parser.parse_args()
    output = Path(args.output_root).resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = Path(args.fixture_root).resolve()
    fixture = json.loads((source/'fixture.json').read_text(encoding='utf-8'))
    assert fixture['synthetic_only'] is True
    config = Path(args.preprocessing_root)/'config/toolkit_config.m'
    before = {str(p):digest(p) for p in source.iterdir() if p.is_file()}
    for file in (config, Path(fixture['prior_source'])):
        before[str(file)] = digest(file)
    write_json(output/'source_hashes_before.json',before)
    project = output/'pipeline_project'
    cli('scan','--data-root',source,'--project-dir',project)
    inventory = json.loads((project/'inventory.json').read_text(encoding='utf-8'))
    run_id = next(row['run_id'] for row in inventory['runs'] if row['bold'])
    values = {name:fixture[name] for name in ('bold','t1','metadata','events','mask','tr_seconds','discard_volumes','event_reference')}
    values.update(subject='phantom',session='baseline',run='run1',input_stage='raw',sdc_method='none')
    choices = {'preprocessing_options':fact({'stop_after':'smooth','toolkit_config_sha256':digest(config),'overrides':fixture['overrides']}),
        'execution_options':fact({'max_matrix_gib':.5}),
        'handoff_options':fact({'bold_source':'smoothed','include_tissue_means':False}),
        'conditions':fact(['A','B']),'contrasts':fact([{'name':'A_minus_B','weights':[1,-1]}]),
        'glm_options':fact({'highpass_seconds':128,'microtime_resolution':16,'microtime_onset':8,
            'serial_correlation':'AR(1)','hrf':'canonical','min_residual_df':10,'mask_threshold':.5,
            'confounds':{'motion_model':'none','include_tissue_means':False,'linear_trend':False,'add_spikes':False,
                         'fd_threshold_mm':.5,'min_residual_df':10}})}
    answers = {'schema_version':1,'route':'preprocess_glm','goal':'完整空间链路合成工程验证；无参与者或科研推断',
        'paradigm':'合成双条件事件','independent_unit':'单个合成run','selected_run_ids':[run_id],
        'toolkit_roots':{'preprocessing':args.preprocessing_root,'glm':args.glm_root},
        'runs':{run_id:{'facts':{key:fact(value) for key,value in values.items()}}},'parameter_choices':choices,
        'parameter_setup':fact('ready')}
    answer_file = project/'answers.json'
    write_json(answer_file,answers)
    planned = cli('plan','--project-dir',project,'--answers',answer_file)
    assert planned['phase']=='draft_prepared',planned
    print('spatial pipeline: raw/native acquisition preflight',flush=True)
    prepared = cli('prepare','--project-dir',project,'--matlab-executable',args.matlab_executable,'--spm-root',args.spm_root)
    assert prepared['phase']=='awaiting_confirmation',prepared
    attempt = Path(prepared['attempt_dir'])
    review = json.loads((attempt/'review.json').read_text(encoding='utf-8'))
    assert review['deferred_checks'] and not Path(review['output_root']).exists()
    print('spatial pipeline: development-only confirmation; actual Segment/Coregister/Normalise/Smooth and GLM',flush=True)
    prepared = reviewed(project,prepared)
    executed = cli('execute','--project-dir',project,'--attempt-id',prepared['attempt_id'],
        '--review-digest',prepared['review_digest'],'--confirmation','确认执行')
    assert executed['phase']=='complete',executed
    receipt = json.loads((attempt/'receipt.json').read_text(encoding='utf-8'))
    assert [stage['stage'] for stage in receipt['stages']]==['preprocessing','handoff','glm_preflight','glm_execute']
    selected = receipt['result']['handoff']['runs']
    if isinstance(selected,list): selected=selected[0]
    with Path(selected['events']).open(encoding='utf-8-sig',newline='') as handle:
        events=list(csv.DictReader(handle,delimiter='\t'))
    assert [float(row['onset']) for row in events]==[value-fixture['discard_volumes']*fixture['tr_seconds'] for value in fixture['onsets']]
    with Path(selected['confounds']).open(encoding='utf-8-sig',newline='') as handle:
        reader=csv.DictReader(handle,delimiter='\t')
        assert len(reader.fieldnames)==25 and len(list(reader))==fixture['retained_frames']
    print('spatial pipeline: complete; independent geometry/record/known-contrast audit and unsmoothed handoff',flush=True)
    helper=Path(__file__).resolve().parent/'helpers'
    audit_file=output/'spatial_audit.json'
    expression=(f"addpath('{literal(helper)}');cogneuro_check_spatial_integration('{literal(attempt)}',"
                f"'{literal(source/'fixture.json')}','{literal(audit_file)}');")
    matlab(args.matlab_executable,expression,output/'spatial_audit.matlab.log')
    audited=json.loads(audit_file.read_text(encoding='utf-8'))
    assert audited['status']=='passed' and audited['known_A_gt_B_mean_contrast']>0
    for record in receipt['outputs']:
        assert digest(Path(record['path']))==record['sha256']
    for path,sha in before.items(): assert digest(Path(path))==sha,path
    assert cli('execution-status','--project-dir',project)['phase']=='complete'
    write_json(output/'integration_report.json',{'status':'passed','real_participant_data':False,
        'approval_simulated_for_development_only':True,'prepare':prepared,'execute':executed,
        'source_files_prior_and_config_unchanged':len(before),'receipt_outputs_verified':len(receipt['outputs']),
        'stages_verified':receipt['stages'],'spatial_audit':audited,'fixture_limits':fixture['limitations'],
        'limitations':['Single template-derived 4mm phantom, no SDC, canonical HRF/AR(1), motion_model=none; no participant/scientific-quality claim.']})
    print(str(output/'integration_report.json'),flush=True)


if __name__=='__main__':main()
