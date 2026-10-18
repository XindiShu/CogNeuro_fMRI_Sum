function tests=test_glmsingle
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;t.TestData.oldDirectory=pwd;
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
c=preprocess_config;addpath(c.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
end
function teardownOnce(t)
cd(t.TestData.oldDirectory);path(t.TestData.oldPath);
end
function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;
c=glm_config;p=preprocess_config;c.spmPath=p.spmPath;c.engine='glmsingle';c.level='subject';c.model.unit='event';
c.conditions={'A','B'};c.contrastNames={'A_minus_B'};c.contrastWeights=[1 -1];c.qc.plot=false;
c.design.motionModel='none';c.design.includeTissueMeans=false;c.design.linearTrend=false;c.minResidualDF=10;c.design.minResidualDF=10;
c.glmsingle.maxPCs=2;c.glmsingle.noiseR2Threshold=5;c.glmsingle.pcR2Threshold=10;c.glmsingle.fracs=[1 .75 .5];
c.glmsingle.maxPolyDegree=1;c.glmsingle.wantDenoise=false;c.glmsingle.wantRidge=false;c.execute=true;c.continueOnError=false;
c.manifestFile=fullfile(root,'runs.tsv');c.outputRoot=fullfile(root,'batch');t.TestData.cfg=c;
onset=(10:12:190)';duration=ones(size(onset))*2;stimulus_id="stim_"+compose('%02d',mod((0:numel(onset)-1)',8)+1);
trial_type=repmat(["A";"B"],numel(onset)/2,1);trial_id="trial_"+string((1:numel(onset))');
e=table(onset,duration,trial_type,stimulus_id,trial_id);t.TestData.events=e;
writetable(e,fullfile(root,'events1.tsv'),'FileType','text','Delimiter','\t');
writetable(e,fullfile(root,'events2.tsv'),'FileType','text','Delimiter','\t');
end
function teardown(t)
cd(t.TestData.oldDirectory);rmdir(t.TestData.root,'s');
end
function testChronologicalMappingAndExplicitIdentity(t)
c=t.TestData.cfg;e=t.TestData.events;e=e(end:-1:1,:);
writetable(e,fullfile(t.TestData.root,'events1.tsv'),'FileType','text','Delimiter','\t');
p=psy.glmsingle_plan(eventFiles(t),[240 240],1,c);
verifyTrue(t,p.ready);verifyEqual(t,p.nEvents,32);verifyEqual(t,p.repeatedAcrossRuns,8);
verifyEqual(t,p.sharedIdentitiesPerFold,[8;8]);verifyEqual(t,p.mapping.source_event_index(1:16),(16:-1:1)');
verifyEqual(t,p.mapping.grid_onset_seconds(1:16),t.TestData.events.onset);
verifyEqual(t,sum(p.design{1},'all'),16);
end
function testNoRepeatsNeverSilentlyDisablesRequestedCv(t)
c=t.TestData.cfg;c.glmsingle.wantDenoise=true;c.glmsingle.wantRidge=true;
e=t.TestData.events;e.stimulus_id=e.stimulus_id+"_other";
writetable(e,fullfile(t.TestData.root,'events2.tsv'),'FileType','text','Delimiter','\t');
p=psy.glmsingle_plan(eventFiles(t),[240 240],1,c);verifyFalse(t,p.ready);verifyEqual(t,p.repeatedAcrossRuns,0);
verifyTrue(t,any(contains(p.issues,'cross-validation')));
end
function testAllReadinessFailuresRetainedAndBlockedMarker(t)
[runs,c]=knownData(t,false);e=t.TestData.events;e.duration(2)=3;e.onset(1)=10.4;e.onset(end)=237;
writetable(e,runs(1).events,'FileType','text','Delimiter','\t');c.execute=false;
out=fullfile(t.TestData.root,'blocked');s=psy.glmsingle_run(runs,c,out);
verifyFalse(t,s.ready);verifyTrue(t,any(contains(s.issues,'duration')));verifyTrue(t,any(contains(s.issues,'grid')));
verifyTrue(t,any(contains(s.issues,'buffer')));verifyTrue(t,isfile(fullfile(out,'GLMSINGLE_BLOCKED.mat')));
verifyFalse(t,isfile(fullfile(out,'GLMSINGLE_COMPLETE.mat')));
c.execute=true;verifyError(t,@()psy.glmsingle_run(runs,c,fullfile(t.TestData.root,'blocked_execute')),'psy:GLMsingleNotReady');
end
function testNearestOnsetsRecordErrorsAndRejectCollisions(t)
c=t.TestData.cfg;c.glmsingle.onsetMode='nearest';c.glmsingle.maxOnsetErrorSeconds=.4;
e=t.TestData.events;e.onset=e.onset+.25;
writetable(e,fullfile(t.TestData.root,'events1.tsv'),'FileType','text','Delimiter','\t');
p=psy.glmsingle_plan(eventFiles(t),[240 240],1,c);verifyTrue(t,p.ready);
verifyEqual(t,p.mapping.onset_error_seconds(1:16),repmat(-.25,16,1));
e.onset(2)=e.onset(1)+.1;writetable(e,fullfile(t.TestData.root,'events1.tsv'),'FileType','text','Delimiter','\t');
p=psy.glmsingle_plan(eventFiles(t),[240 240],1,c);verifyFalse(t,p.ready);verifyTrue(t,any(contains(p.issues,'collide')));
end
function testIdentitySemanticsMissingTrialIdsAndContradiction(t)
c=t.TestData.cfg;c.model.unit='trial';e=t.TestData.events;e.trial_id(:)="same";
e.trial_type(1)="B";writetable(e,fullfile(t.TestData.root,'events1.tsv'),'FileType','text','Delimiter','\t');
p=psy.glmsingle_plan(eventFiles(t),[240 240],1,c);verifyFalse(t,p.ready);
verifyTrue(t,any(contains(p.issues,'trial_id')));verifyTrue(t,any(contains(p.issues,'multiple trial_type')));
e.stimulus_id=[];writetable(e,fullfile(t.TestData.root,'events1.tsv'),'FileType','text','Delimiter','\t');
p=psy.glmsingle_plan(eventFiles(t),[240 240],1,c);verifyTrue(t,any(contains(p.issues,'missing identity')));
end
function testNativeCanonicalBetaTruthStateAndInputPreserved(t)
[runs,c,truth]=knownData(t,false);out=fullfile(t.TestData.root,'canonical');
before=psy.file_sha256(runs(1).bold);oldPath=path;oldRng=rng;oldDirectory=pwd;
s=psy.glmsingle_run(runs,c,out);verifyEqual(t,s.status,'glmsingle_models_estimated');verifyEqual(t,s.modelTypes,{'A','B'});
verifyEqual(t,path,oldPath);verifyEqual(t,pwd,oldDirectory);verifyEqual(t,rng,oldRng);verifyEqual(t,psy.file_sha256(runs(1).bold),before);
p=load(fullfile(out,'native_results.mat'));actual=reshape(p.results{2}.modelmd,[],32);
expected=100*truth(1,:)/double(p.results{2}.meanvol(1));
verifyEqual(t,double(actual(1,:)),expected,'AbsTol',.004);
v=spm_read_vols(spm_vol(fullfile(out,'TYPEB','event_betas.nii')));verifyEqual(t,size(v),[6 6 4 32]);
verifyTrue(t,all(isnan(reshape(v(6,6,4,:),[],1))));verifyFalse(t,isfile(fullfile(out,'SPM.mat')));
verifyFalse(t,isfile(fullfile(out,'subject_contrasts.tsv')));
end
function testNativeLibraryDenoiseAndRidgeAllRequestedModels(t)
[runs,c]=knownData(t,true);c.hrf.type='library';c.glmsingle.wantDenoise=true;c.glmsingle.wantRidge=true;
out=fullfile(t.TestData.root,'all_models');s=psy.glmsingle_run(runs,c,out);
verifyEqual(t,s.modelTypes,{'A','B','C','D'});verifyEqual(t,s.pcnum,1);
p=load(fullfile(out,'native_results.mat'));verifyEqual(t,p.resultsdesign.opt.wantglmdenoise,1);verifyEqual(t,p.resultsdesign.opt.wantfracridge,1);
verifyFalse(t,isempty(p.results{4}.rrbadness));verifyFalse(t,isempty(p.results{3}.glmbadness));
verifyTrue(t,all(ismembertol(double(p.results{4}.FRACvalue(:)),[1 .75 .5],1e-5)));
verifyTrue(t,all(p.results{2}.HRFindex(:)>=1&p.results{2}.HRFindex(:)<=20));
verifyTrue(t,isfile(fullfile(out,'TYPED','FRACvalue.nii')));verifyTrue(t,isfile(fullfile(out,'TYPEC','run_001_candidate_PCs.tsv')));
verifyEqual(t,readtable(fullfile(out,'TYPED','beta_mapping.tsv'),'FileType','text','Delimiter','\t').beta_index,(1:32)');
end
function testCoverageBudgetAndUnfilteredGuards(t)
[runs,c]=knownData(t,false);bad=runs;bad(1).mask='';
verifyError(t,@()psy.glmsingle_run(bad,c,fullfile(t.TestData.root,'no_mask')),'psy:GLMsingleMask');
c.glmsingle.maxInputGiB=1e-8;c.execute=false;s=psy.glmsingle_run(runs,c,fullfile(t.TestData.root,'budget'));
verifyFalse(t,s.ready);verifyTrue(t,any(contains(s.issues,'maxInputGiB')));
c=t.TestData.cfg;bad=runs;bad(1).temporal_state='residual';
verifyError(t,@()psy.glmsingle_run(bad,c,fullfile(t.TestData.root,'residual')),'psy:GLMState');
data=spm_read_vols(spm_vol(runs(1).bold));data(1,1,1,1)=NaN;makeImage(runs(1).bold,data);
verifyError(t,@()psy.glmsingle_run(runs,c,fullfile(t.TestData.root,'nonfinite')),'psy:GLMsingleData');
end
function testConfigurationCombinationsAndPinnedDependency(t)
c=t.TestData.cfg;c.model.unit='condition';verifyError(t,@()psy.glm_framework_options(c),'psy:GLMUnsupportedCombination');
c=t.TestData.cfg;c.glmsingle.fracs=1;verifyError(t,@()psy.glm_framework_options(c),'psy:GLMsingleConfig');
c=t.TestData.cfg;c.level='group';verifyError(t,@()psy.glm_framework_options(c),'psy:GLMUnsupportedCombination');
c=t.TestData.cfg;verifyError(t,@()psy.glm_framework_plan(fullfile(t.TestData.root,'events1.tsv'),240,c),'psy:GLMEngine');
folder=fullfile(t.TestData.root,'tampered');copyfile(t.TestData.cfg.glmsingle.path,folder);
f=fopen(fullfile(folder,'matlab','GLMestimatesingletrial.m'),'a');fprintf(f,'\n%% changed\n');fclose(f);
verifyError(t,@()psy.glmsingle_dependency(folder),'psy:GLMsingleDependency');
end
function testBatchDispatchPrepareAndNoOverwrite(t)
[runs,c]=knownData(t,false);c.execute=false;writeManifest(runs,c.manifestFile);report=psy.glm_batch(c);
verifyEqual(t,report.status,'glmsingle_prepared_not_estimated');verifyEqual(t,report.nModels,2);
verifyTrue(t,isfile(fullfile(c.outputRoot,'sub-p1','combined','GLMSINGLE_PREPARED.mat')));
verifyError(t,@()psy.glm_batch(c),'psy:GLMExists');
end

function files=eventFiles(t)
files={fullfile(t.TestData.root,'events1.tsv'),fullfile(t.TestData.root,'events2.tsv')};
end
function [runs,c,truth]=knownData(t,wantNoise)
c=t.TestData.cfg;root=t.TestData.root;oldPath=path;restorePath=onCleanup(@()path(oldPath));psy.glmsingle_dependency(c.glmsingle.path);
hrf=getcanonicalhrf(2,1);hrf=hrf(:)/max(hrf);n=240;ev=t.TestData.events;trials=height(ev);voxels=144;
oldRng=rng;restoreRng=onCleanup(@()rng(oldRng));rng(189,'twister');runs=struct([]);truth=zeros(voxels,2*trials);
mask=ones(6,6,4);mask(6,6,4)=0;maskFile=fullfile(root,'mask.nii');makeImage(maskFile,mask);
for r=1:2
    stimulus=zeros(n,trials);stimulus(sub2ind(size(stimulus),ev.onset+1,(1:trials)'))=1;
    x=conv2(stimulus,hrf);x=x(1:n,:);amplitude=repmat((mod(0:trials-1,8)+1)*.7,voxels,1);
    amplitude(73:end,:)=0;truth(:,(r-1)*trials+(1:trials))=amplitude;
    noise=.01*randn(n,voxels);
    if wantNoise
        shared=sin((1:n)'/7+r)+.5*sin((1:n)'/17+r);noise=noise+shared*(1+3*rand(1,voxels));
    end
    y=1000+x*amplitude'+noise;file=fullfile(root,sprintf('bold%d.nii',r));makeImage(file,reshape(y',[6 6 4 n]));
    confounds=fullfile(root,sprintf('confounds%d.tsv',r));writetable(table((1:n)','VariableNames',{'unused'}),confounds,'FileType','text','Delimiter','\t');
    run=struct('subject','p1','session','','name',sprintf('run%d',r),'temporal_state','unfiltered_unregressed', ...
        'bold',file,'events',fullfile(root,sprintf('events%d.tsv',r)),'confounds',confounds,'mask',maskFile);
    if isempty(runs),runs=run;else,runs(r)=run;end
end
clear restoreRng restorePath;
end
function writeManifest(runs,file)
subject=string({runs.subject})';session=string({runs.session})';run=string({runs.name})';bold=string({runs.bold})';
events=string({runs.events})';confounds=string({runs.confounds})';temporal_state=string({runs.temporal_state})';mask=string({runs.mask})';
writetable(table(subject,session,run,bold,events,confounds,temporal_state,mask),file,'FileType','text','Delimiter','\t');
end
function makeImage(file,data)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;
ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:)=single(data(:));
end
