function tests=test_glm_framework
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;t.TestData.oldDirectory=pwd;
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
h=preprocess_config;addpath(h.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
end
function teardownOnce(t)
cd(t.TestData.oldDirectory);path(t.TestData.oldPath);
end
function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;
onset=[2;12;22;32;42;52];duration=[1;2;1;2;1;2];trial_type=["B";"A";"B";"A";"B";"A"];
trial_id="trial_"+string((1:6)');stimulus_id=["b1";"a1";"b1";"a2";"b2";"a2"];
block_id="block_"+string((1:6)');phase=["cue";"cue";"response";"response";"cue";"cue"];
events=table(onset,duration,trial_type,trial_id,stimulus_id,block_id,phase);
t.TestData.events=fullfile(root,'events.tsv');writeEvents(t,events);
cfg=glm_config;h=preprocess_config;cfg.spmPath=h.spmPath;
cfg.conditions={'A','B'};cfg.contrastNames={'A_minus_B'};cfg.contrastWeights=[1 -1];
cfg.design.motionModel='none';cfg.design.includeTissueMeans=false;cfg.design.linearTrend=false;
cfg.design.minResidualDF=5;cfg.minResidualDF=5;cfg.qc.plot=false;
cfg.outputRoot=fullfile(root,'batch');cfg.manifestFile=fullfile(root,'runs.tsv');
t.TestData.cfg=cfg;
end
function teardown(t)
cd(t.TestData.oldDirectory);rmdir(t.TestData.root,'s');
end
function testConditionOrderAndOriginalDurations(t)
p=psy.glm_framework_plan(t.TestData.events,100,t.TestData.cfg);
verifyEqual(t,{p.models.conditions.name},{'A','B'});
verifyEqual(t,p.models.conditions(1).onset,[12;32;52]);
verifyEqual(t,p.models.conditions(1).duration,[2;2;2]);
verifyEqual(t,p.models.contrastWeights,[1 -1]);
verifyEqual(t,p.units.model_label,["A";"B"]);
end
function testExplicitEventExpressionsPreserveSource(t)
before=fileread(t.TestData.events);cfg=t.TestData.cfg;
cfg.events.expression='impulse';p=psy.glm_framework_plan(t.TestData.events,100,cfg);
verifyEqual(t,p.mapping.modeled_duration_seconds,zeros(6,1));
verifyEqual(t,p.mapping.original_duration_seconds,[1;2;1;2;1;2]);
cfg.events.expression='fixed';cfg.events.fixedDurationSeconds=3.5;
p=psy.glm_framework_plan(t.TestData.events,100,cfg);
verifyEqual(t,p.models.conditions(1).duration,[3.5;3.5;3.5]);
verifyEqual(t,fileread(t.TestData.events),before);
end
function testTrialRequiresRealUniqueIds(t)
cfg=t.TestData.cfg;cfg.model.unit='trial';
p=psy.glm_framework_plan(t.TestData.events,100,cfg);verifyEqual(t,p.nUnits,6);
events=readtable(t.TestData.events,'FileType','text','Delimiter','\t','TextType','string');
events.trial_id=[];writeEvents(t,events);
verifyError(t,@()psy.glm_framework_plan(t.TestData.events,100,cfg),'psy:GLMEventUnit');
events.trial_id=repmat("same",6,1);writeEvents(t,events);
verifyError(t,@()psy.glm_framework_plan(t.TestData.events,100,cfg),'psy:GLMEventUnit');
end
function testRepeatedItemsAndCrossConditionAmbiguity(t)
cfg=t.TestData.cfg;cfg.model.unit='item';
p=psy.glm_framework_plan(t.TestData.events,100,cfg);
verifyEqual(t,p.nUnits,4);verifyEqual(t,p.units.n_event_rows,[2;1;2;1]);
verifyEqual(t,p.models.conditions(1).onset,[2;22]);
events=readtable(t.TestData.events,'FileType','text','Delimiter','\t','TextType','string');
events.stimulus_id(2)="b1";writeEvents(t,events);
verifyError(t,@()psy.glm_framework_plan(t.TestData.events,100,cfg),'psy:GLMEventUnit');
end
function testBlockAndPhaseUnits(t)
cfg=t.TestData.cfg;cfg.model.unit='block';
p=psy.glm_framework_plan(t.TestData.events,100,cfg);verifyEqual(t,p.nUnits,6);
cfg.model.unit='phase';p=psy.glm_framework_plan(t.TestData.events,100,cfg);
verifyEqual(t,p.nUnits,4);verifyEqual(t,p.units.phase,["cue";"cue";"response";"response"]);
cfg.model.unit='trial_phase';p=psy.glm_framework_plan(t.TestData.events,100,cfg);verifyEqual(t,p.nUnits,6);
end
function testJointTargetsKeepAllOtherUnits(t)
cfg=t.TestData.cfg;cfg.model.unit='event';cfg.model.targetConditions={'A'};
p=psy.glm_framework_plan(t.TestData.events,100,cfg);
verifyEqual(t,p.nTargets,3);verifyEqual(t,numel(p.models.conditions),6);
verifyEqual(t,p.models.contrastWeights,[0 1 0 0 0 0;0 0 0 1 0 0;0 0 0 0 0 1]);
end
function testLssGroupingAndTargetRemoval(t)
cfg=t.TestData.cfg;cfg.model.unit='trial';cfg.model.targetConditions={'A'};cfg.fit.strategy='lss';
cfg.fit.lssGrouping='condition';p=psy.glm_framework_plan(t.TestData.events,100,cfg);
verifyEqual(t,p.nModels,3);c=p.models(1).conditions;
verifyEqual(t,{c.name},{'target','other_001','other_002'});
verifyEqual(t,c(1).onset,12);verifyEqual(t,c(2).onset,[32;52]);verifyEqual(t,c(3).onset,[2;22;42]);
cfg.fit.lssGrouping='pooled';p=psy.glm_framework_plan(t.TestData.events,100,cfg);c=p.models(1).conditions;
verifyEqual(t,numel(c),2);verifyEqual(t,c(2).onset,[2;22;32;42;52]);
end
function testUnsupportedOptionsAndIgnoredMetadataRejected(t)
cfg=t.TestData.cfg;cfg.level='population';
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMUnsupportedOption');
cfg=t.TestData.cfg;cfg.hrf.type='fourier';
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMUnsupportedHRF');
cfg=t.TestData.cfg;cfg.fit.strategy='lss';
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMUnsupportedCombination');
cfg=t.TestData.cfg;cfg.events.pmod='difficulty';
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMFrameworkConfig');
cfg=t.TestData.cfg;cfg.pmod='difficulty';
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMFrameworkConfig');
cfg=t.TestData.cfg;cfg.minResidualDF=NaN;
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMFrameworkConfig');
cfg=t.TestData.cfg;cfg.microtimeResolution=Inf;
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMFrameworkConfig');
cfg=t.TestData.cfg;cfg.design.motionModle='none';
verifyError(t,@()psy.glm_framework_options(cfg),'psy:GLMFrameworkConfig');
cfg=t.TestData.cfg;events=readtable(t.TestData.events,'FileType','text','Delimiter','\t');
events.amplitude=ones(6,1);writeEvents(t,events);
verifyError(t,@()psy.glm_framework_plan(t.TestData.events,100,cfg),'psy:GLMAmplitude');
end
function testPreparedBatchIsolationAndNoOverwrite(t)
root=t.TestData.root;makeBold(fullfile(root,'bold.nii'),ones(4,4,4,80)*1000);
writetable(table((1:80)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'),'FileType','text','Delimiter','\t');
subject=["p1";"p2"];session=["baseline";"followup"];run=repmat("task1",2,1);
bold=repmat("bold.nii",2,1);events=repmat("events.tsv",2,1);confounds=repmat("confounds.tsv",2,1);
temporal_state=repmat("unfiltered_unregressed",2,1);
writetable(table(subject,session,run,bold,events,confounds,temporal_state),t.TestData.cfg.manifestFile,'FileType','text','Delimiter','\t');
cfg=t.TestData.cfg;cfg.model.unit='trial';cfg.fit.strategy='lss';cfg.model.targetConditions={'A'};
report=psy.glm_batch(cfg);verifyEqual(t,{report.status},{'framework_prepared_not_estimated','framework_prepared_not_estimated'});
verifyEqual(t,[report.nModels],[3 3]);
verifyTrue(t,isfile(fullfile(cfg.outputRoot,'sub-p2','ses-followup','task1','GLM_FRAMEWORK_PREPARED.mat')));
verifyFalse(t,isfile(fullfile(cfg.outputRoot,'sub-p1','ses-baseline','task1','GLM_FRAMEWORK_COMPLETE.mat')));
verifyError(t,@()psy.glm_batch(cfg),'psy:GLMExists');
end
function testUnsupportedLevelFailsBeforeCreatingOutput(t)
cfg=t.TestData.cfg;cfg.level='population';
verifyError(t,@()psy.glm_batch(cfg),'psy:GLMUnsupportedOption');verifyFalse(t,isfolder(cfg.outputRoot));
end
function testMaskGeometryGuard(t)
root=t.TestData.root;makeBold(fullfile(root,'bold.nii'),ones(4,4,4,80)*1000);
makeBold(fullfile(root,'mask.nii'),ones(3,3,3));
writetable(table((1:80)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'),'FileType','text','Delimiter','\t');
run=runDefinition(t);cfg=t.TestData.cfg;run.mask=fullfile(root,'mask.nii');
verifyError(t,@()psy.glm_framework_run(run,cfg,fullfile(root,'badmask')),'psy:GLMMask');
verifyFalse(t,isfile(fullfile(root,'badmask','GLM_FRAMEWORK_PREPARED.mat')));
end
function testGlobalMaskFallbackAndProvenance(t)
root=t.TestData.root;makeBold(fullfile(root,'bold.nii'),ones(4,4,4,80)*1000);
makeBold(fullfile(root,'mask.nii'),ones(4,4,4));
writetable(table((1:80)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'),'FileType','text','Delimiter','\t');
cfg=t.TestData.cfg;cfg.explicitMask=fullfile(root,'mask.nii');run=runDefinition(t);
out=fullfile(root,'globalmask');psy.glm_framework_run(run,cfg,out);
p=load(fullfile(out,'models','joint','specification.mat'));
verifyEqual(t,p.b{1}.spm.stats.fmri_spec.mask,{cfg.explicitMask});
inputs=readtable(fullfile(out,'input_files.tsv'),'FileType','text','Delimiter','\t','TextType','string');
verifyEqual(t,inputs.path(inputs.role=="mask"),string(cfg.explicitMask));
end
function testSpmKnownConditionEffectsAndResidualDiagnostics(t)
[run,cfg]=knownData(t,'canonical');before=spm_read_vols(spm_vol(run.bold));old=pwd;
out=fullfile(t.TestData.root,'condition_fit');summary=psy.glm_framework_run(run,cfg,out);
verifyEqual(t,pwd,old);verifyEqual(t,summary.status,'framework_models_estimated');
p=load(fullfile(out,'models','joint','SPM.mat'));s=p.SPM;
beta=spm_read_vols(spm_vol(fullfile(out,'models','joint','beta_0001.nii')));
constant=spm_read_vols(spm_vol(fullfile(out,'models','joint',sprintf('beta_%04d.nii',size(s.xX.X,2)))));
verifyEqual(t,median(beta(:)./constant(:)),.002,'AbsTol',2e-5);
diagnostics=jsondecode(fileread(fullfile(out,'models','joint','model_diagnostics.json')));
verifyEqual(t,diagnostics.nResidualVoxels,32);verifyEqual(t,numel(diagnostics.rawResidualAcfMedian),10);
verifyEqual(t,diagnostics.undefinedCorrelationColumnIndices,size(s.xX.X,2));
verifyTrue(t,isfile(fullfile(out,'models','joint','model_diagnostics.png')));
verifyEqual(t,spm_read_vols(spm_vol(run.bold)),before);
end
function testSpmDerivativeBasisAndCanonicalMapping(t)
[run,cfg]=knownData(t,'canonical_time_dispersion');cfg.qc.plot=false;
out=fullfile(t.TestData.root,'derivative_fit');psy.glm_framework_run(run,cfg,out);
p=load(fullfile(out,'models','joint','SPM.mat'));s=p.SPM;
verifyEqual(t,numel(s.Sess.U),2);verifyEqual(t,size(s.xBF.bf,2),3);
verifyEqual(t,full(s.xCon(1).c(:))',[1 0 0 -1 0 0 0]);
a=spm_read_vols(spm_vol(fullfile(out,'models','joint','con_0001.nii')));
b=spm_read_vols(spm_vol(fullfile(out,'models','joint','beta_0007.nii')));
verifyEqual(t,median(a(:)./b(:)),.003,'AbsTol',2e-5);
end
function testSpmJointAndBothLssStrategies(t)
[run,cfg]=knownData(t,'canonical');cfg.model.unit='trial';cfg.model.targetConditions={'A'};cfg.qc.plot=false;
out=fullfile(t.TestData.root,'trial_joint');psy.glm_framework_run(run,cfg,out);
outputs=readtable(fullfile(out,'model_outputs.tsv'),'FileType','text','Delimiter','\t','TextType','string');
verifyEqual(t,height(outputs),3);verifyTrue(t,all(isfile(outputs.canonical_beta)));
for grouping={'pooled','condition'}
    cfg.fit.strategy='lss';cfg.fit.lssGrouping=grouping{1};
    out=fullfile(t.TestData.root,['lss_' grouping{1}]);summary=psy.glm_framework_run(run,cfg,out);
    verifyEqual(t,summary.nModels,3);verifyTrue(t,isfile(fullfile(out,'GLM_FRAMEWORK_COMPLETE.mat')));
    outputs=readtable(fullfile(out,'model_outputs.tsv'),'FileType','text','Delimiter','\t','TextType','string');
    verifyTrue(t,all(isfile(outputs.canonical_beta)));verifyEqual(t,outputs.target_unit_index,[2;4;6]);
end
end

function writeEvents(t,events)
writetable(events,t.TestData.events,'FileType','text','Delimiter','\t');
end
function run=runDefinition(t)
run=struct('subject','p1','session','baseline','name','task1','temporal_state','unfiltered_unregressed', ...
    'bold',fullfile(t.TestData.root,'bold.nii'),'events',t.TestData.events, ...
    'confounds',fullfile(t.TestData.root,'confounds.tsv'),'mask','');
end
function makeBold(file,data)
dim=size(data);ni=nifti;ni.dat=file_array(file,dim,'FLOAT32-LE',352,1,0);
ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:)=single(data(:));
end
function [run,cfg]=knownData(t,hrf)
% 独立调用stock SPM指定条件参考设计，植入已知系数，再检验通用框架的恢复。
cfg=t.TestData.cfg;cfg.hrf.type=hrf;cfg.execute=true;cfg.qc.plot=true;cfg.serialCorrelation='AR(1)';
root=t.TestData.root;n=160;file=fullfile(root,'bold.nii');makeBold(file,ones(4,4,4,n)*1000);
writetable(table((1:n)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'),'FileType','text','Delimiter','\t');
reference=fullfile(root,'reference');mkdir(reference);s=struct;s.dir={reference};
s.timing=struct('units','secs','RT',1,'fmri_t',16,'fmri_t0',8);
s.sess.scans=arrayfun(@(k)sprintf('%s,%d',file,k),(1:n)','UniformOutput',false);
emptyPmod=struct('name',{},'param',{},'poly',{});
s.sess.cond(1)=struct('name','A','onset',[12;32;52],'duration',[2;2;2],'tmod',0,'pmod',emptyPmod,'orth',0);
s.sess.cond(2)=struct('name','B','onset',[2;22;42],'duration',[1;1;1],'tmod',0,'pmod',emptyPmod,'orth',0);
s.sess.multi={''};s.sess.regress=struct('name',{},'val',{});s.sess.multi_reg={''};s.sess.hpf=128;
s.fact=struct('name',{},'levels',{});s.bases.hrf.derivs=[0 0];
if strcmp(hrf,'canonical_time_dispersion'),s.bases.hrf.derivs=[1 1];end
s.volt=1;s.global='None';s.mthresh=.8;s.mask={''};s.cvi='AR(1)';
b={};b{1}.spm.stats.fmri_spec=s;previous=pwd;cleanup=onCleanup(@()cd(previous));spm_jobman('run',b);
p=load(fullfile(reference,'SPM.mat'));x=p.SPM.xX.X;coefficients=[2;-1;1000];
if strcmp(hrf,'canonical_time_dispersion'),coefficients=[2;.3;-.2;-1;-.1;.15;1000];end
oldRng=rng;restoreRng=onCleanup(@()rng(oldRng));rng(9401,'twister');
y=x*coefficients+.02*randn(n,64);data=reshape(y',[4 4 4 n]);makeBold(file,data);
run=runDefinition(t);clear restoreRng cleanup;
end
