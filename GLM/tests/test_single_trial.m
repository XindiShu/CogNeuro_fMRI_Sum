function tests=test_single_trial
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
h=preprocess_config;addpath(h.spmPath);
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;
n=12;ni=nifti;ni.dat=file_array(fullfile(root,'bold.nii'),[3 3 3 n],'FLOAT32-LE',352,1,0);
ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;ni.timing=struct('toffset',0,'tspace',1);create(ni);
ni.dat(:,:,:,:)=single(repmat(10+reshape(1:n,1,1,1,n),3,3,3,1));
f=fopen(fullfile(root,'events.tsv'),'w');
fprintf(f,'onset\tduration\ttrial_type\n0\t2\tA\n4\t2\tB\n8\t2\tA\n');fclose(f);
writetable(table((1:n)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'), ...
    'FileType','text','Delimiter','\t');
f=fopen(fullfile(root,'runs.tsv'),'w');
fprintf(f,'subject\tsession\trun\tbold\tevents\tconfounds\ttemporal_state\n');
fprintf(f,'p1\tbaseline\ttask1\tbold.nii\tevents.tsv\tconfounds.tsv\tunfiltered_unregressed\n');
fprintf(f,'p2\tfollowup\ttask1\tbold.nii\tevents.tsv\tconfounds.tsv\tunfiltered_unregressed\n');
fclose(f);
cfg=single_trial_config;h=preprocess_config;cfg.spmPath=h.spmPath;
cfg.manifestFile=fullfile(root,'runs.tsv');cfg.outputRoot=fullfile(root,'out');
cfg.design.motionModel='none';cfg.design.includeTissueMeans=false;
cfg.design.linearTrend=false;cfg.design.minResidualDF=1;
t.TestData.cfg=cfg;
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testPreparedLsaLssAndTwoSubjects(t)
report=psy.single_trial_batch(t.TestData.cfg);
verifyEqual(t,{report.status},{'single_trial_prepared_not_estimated','single_trial_prepared_not_estimated'});
verifyEqual(t,[report.nEvents],[3 3]);verifyEqual(t,[report.nModels],[4 4]);
first=fullfile(t.TestData.cfg.outputRoot,'sub-p1','ses-baseline','task1');
second=fullfile(t.TestData.cfg.outputRoot,'sub-p2','ses-followup','task1');
verifyTrue(t,isfile(fullfile(first,'LSA','specification.mat')));
verifyTrue(t,isfile(fullfile(second,'LSS','event_003','specification.mat')));
verifyFalse(t,isfile(fullfile(first,'SINGLE_TRIAL_COMPLETE.mat')));
mapping=readtable(fullfile(first,'event_mapping.tsv'),'FileType','text','Delimiter','\t');
verifyEqual(t,string(mapping.original_condition),["A";"B";"A"]);
e=readtable(fullfile(first,'model_events','lss_event_002.tsv'),'FileType','text','Delimiter','\t');
verifyEqual(t,string(e.trial_type),["other";"target";"other"]);
end
function testByConditionKeepsSeparateOtherGroups(t)
cfg=t.TestData.cfg;cfg.methods={'LSS'};cfg.lssGrouping='by_condition';
run=struct('subject','p1','session','baseline','name','task1', ...
    'bold',fullfile(t.TestData.root,'bold.nii'), ...
    'events',fullfile(t.TestData.root,'events.tsv'), ...
    'confounds',fullfile(t.TestData.root,'confounds.tsv'), ...
    'temporal_state','unfiltered_unregressed');
out=fullfile(t.TestData.root,'by_condition');
s=psy.single_trial_run(run,cfg,out);
verifyEqual(t,s.nModels,3);
e=readtable(fullfile(out,'model_events','lss_event_001.tsv'),'FileType','text','Delimiter','\t');
verifyEqual(t,string(e.trial_type),["target";"other_condition_002";"other_condition_001"]);
end
function testRejectInvalidGrouping(t)
cfg=t.TestData.cfg;cfg.lssGrouping='unknown';
run=struct('temporal_state','unfiltered_unregressed');
verifyError(t,@()psy.single_trial_run(run,cfg,fullfile(t.TestData.root,'bad')),'psy:SingleTrialGrouping');
end
function testTargetConditionFiltersContrastsAndLssModels(t)
cfg=t.TestData.cfg;cfg.targetConditions={'B'};
run=struct('subject','p1','session','baseline','name','task1', ...
    'bold',fullfile(t.TestData.root,'bold.nii'), ...
    'events',fullfile(t.TestData.root,'events.tsv'), ...
    'confounds',fullfile(t.TestData.root,'confounds.tsv'), ...
    'temporal_state','unfiltered_unregressed');
out=fullfile(t.TestData.root,'selected');s=psy.single_trial_run(run,cfg,out);
verifyEqual(t,s.nTargets,1);verifyEqual(t,s.nModels,2);
verifyTrue(t,isfile(fullfile(out,'LSS','event_002','specification.mat')));
verifyFalse(t,isfolder(fullfile(out,'LSS','event_001')));
lsa=load(fullfile(out,'LSA','specification.mat'));
verifyEqual(t,lsa.cfg.conditions,{'event_001','event_002','event_003'}');
verifyEqual(t,lsa.cfg.contrastNames,{'event_002'});
end
