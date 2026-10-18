function tests=test_glm_multilevel
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
c=glm_config;p=preprocess_config;c.spmPath=p.spmPath;c.qc.plot=false;c.execute=true;
c.conditions={'A','B'};c.contrastNames={'A_minus_B'};c.contrastWeights=[1 -1];
c.design.motionModel='none';c.design.includeTissueMeans=false;c.design.linearTrend=false;
c.minResidualDF=5;c.design.minResidualDF=5;c.serialCorrelation='AR(1)';c.continueOnError=false;
c.manifestFile=fullfile(root,'runs.tsv');c.outputRoot=fullfile(root,'output');t.TestData.cfg=c;
end
function teardown(t)
cd(t.TestData.oldDirectory);rmdir(t.TestData.root,'s');
end
function testTwoRunDerivativesRecoverEqualRunEffect(t)
[runs,c]=knownRuns(t);out=fullfile(t.TestData.root,'subject');summary=psy.glm_subject_run(runs,c,out);
p=load(fullfile(out,'model','SPM.mat'));s=p.SPM;
verifyEqual(t,summary.nRuns,2);verifyEqual(t,[s.nscan],[120 150]);
verifyEqual(t,numel(s.xX.K),2);verifyEqual(t,summary.runWeights,[.5 .5]);
expected=[.5 0 0 -.5 0 0 .5 0 0 -.5 0 0 0 0];
verifyEqual(t,full(s.xCon(1).c)',expected);
a=spm_read_vols(spm_vol(fullfile(out,'model','con_0001.nii')));
truth=(3*s.xGX.gSF(1)+6*s.xGX.gSF(121))/2;
verifyEqual(t,median(a(:)),truth,'AbsTol',.002);
d=load(fullfile(out,'model','model_diagnostics.mat'));
verifyEqual(t,numel(d.diagnostics.residualAcfPerRun),2);
verifyEqual(t,d.diagnostics.highpassBasisRank,psy.glm_highpass_rank(s.xX.K));
end
function testSubjectSessionGroupingAndNoOverwrite(t)
[runs,c]=knownRuns(t);c.execute=false;
writeRuns(t,runs,c.manifestFile);report=psy.glm_batch(c);verifyEqual(t,numel(report),1);
verifyEqual(t,report.status,'subject_prepared_not_estimated');
verifyTrue(t,isfile(fullfile(c.outputRoot,'sub-p1','ses-baseline','combined','GLM_SUBJECT_PREPARED.mat')));
verifyError(t,@()psy.glm_batch(c),'psy:GLMExists');
runs(2).session='followup';c.outputRoot=fullfile(t.TestData.root,'split');writeRuns(t,runs,c.manifestFile);
report=psy.glm_batch(c);verifyEqual(t,numel(report),2);
c.outputRoot=fullfile(t.TestData.root,'combined');c.subject.combineSessions=true;
report=psy.glm_batch(c);verifyEqual(t,numel(report),1);
verifyTrue(t,isfile(fullfile(c.outputRoot,'sub-p1','combined','GLM_SUBJECT_PREPARED.mat')));
end
function testSubjectIdentityStateGridAndModelGuards(t)
[runs,c]=knownRuns(t);c.execute=false;out=fullfile(t.TestData.root,'bad');
r=runs;r(2).subject='p2';verifyError(t,@()psy.glm_subject_run(r,c,out),'psy:GLMSubject');
r=runs;r(2).bold=r(1).bold;verifyError(t,@()psy.glm_subject_run(r,c,out),'psy:DuplicateRun');
r=runs;r(2).temporal_state='residual';verifyError(t,@()psy.glm_subject_run(r,c,out),'psy:GLMState');
verifyFalse(t,isfolder(out));
makeImage(runs(2).bold,ones(3,3,3,150)*1000);
verifyError(t,@()psy.glm_subject_run(runs,c,out),'psy:GLMGrid');verifyFalse(t,isfolder(out));
c.model.unit='trial';verifyError(t,@()psy.glm_framework_options(c),'psy:GLMUnsupportedCombination');
end
function testGroupTAgainstIndependentArithmeticIncludingZero(t)
[c,values]=groupFixture(t);report=psy.glm_batch(c);verifyEqual(t,report.status,'group_one_sample_estimated');
out=fullfile(c.outputRoot,'contrast_001');s=load(fullfile(out,'SPM.mat'));
verifyEqual(t,s.SPM.xX.erdf,2,'AbsTol',1e-8);
mask=spm_read_vols(spm_vol(fullfile(out,'mask.nii')))>0;verifyTrue(t,mask(1));verifyFalse(t,mask(end));
expectedMean=mean(values,4);expectedT=expectedMean./(std(values,0,4)/sqrt(3));
con=spm_read_vols(spm_vol(fullfile(out,'con_0001.nii')));
pos=spm_read_vols(spm_vol(fullfile(out,'spmT_0001.nii')));
neg=spm_read_vols(spm_vol(fullfile(out,'spmT_0002.nii')));
verifyEqual(t,con(mask),expectedMean(mask),'AbsTol',1e-5);
verifyEqual(t,pos(mask),expectedT(mask),'AbsTol',1e-4);verifyEqual(t,neg(mask),-pos(mask),'AbsTol',1e-6);
end
function testGroupRejectsRepeatedSubjectsAndImagesAndSmallCohort(t)
[c,~]=groupFixture(t);tab=readtable(c.manifestFile,'FileType','text','Delimiter','\t','TextType','string');
bad=tab;bad.subject(2)=bad.subject(1);writetable(bad,c.manifestFile,'FileType','text','Delimiter','\t');
verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupDuplicate');verifyFalse(t,isfolder(c.outputRoot));
bad=tab;bad.contrast_image(2)=bad.contrast_image(1);writetable(bad,c.manifestFile,'FileType','text','Delimiter','\t');
verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupDuplicate');
writetable(tab(1:2,:),c.manifestFile,'FileType','text','Delimiter','\t');
verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupSample');
end
function testGroupGeometryFailsWithoutCompletion(t)
[c,~]=groupFixture(t);makeImage(fullfile(t.TestData.root,'effect2.nii'),ones(3,3,3));
verifyError(t,@()psy.glm_batch(c),'psy:GLMFailed');
verifyFalse(t,isfile(fullfile(c.outputRoot,'contrast_001','GLM_GROUP_COMPLETE.mat')));
end

function [runs,c]=knownRuns(t)
% 用stock SPM独立生成两session参考X，再植入不同基线/效应与HRF导数。
c=t.TestData.cfg;c.level='subject';c.hrf.type='canonical_time_dispersion';
root=t.TestData.root;empty=struct('name',{},'param',{},'poly',{});s=struct;s.dir={fullfile(root,'reference')};mkdir(s.dir{1});
s.timing=struct('units','secs','RT',1,'fmri_t',16,'fmri_t0',8);runs=struct([]);
for k=1:2
    n=90+30*k;bold=fullfile(root,sprintf('bold%d.nii',k));makeImage(bold,ones(4,4,4,n)*1000);
    onset=[10;20;40;50;70;80];duration=ones(6,1);trial_type=repmat(["A";"B"],3,1);
    events=fullfile(root,sprintf('events%d.tsv',k));writetable(table(onset,duration,trial_type),events,'FileType','text','Delimiter','\t');
    confounds=fullfile(root,sprintf('confounds%d.tsv',k));writetable(table((1:n)','VariableNames',{'unused'}),confounds,'FileType','text','Delimiter','\t');
    r=struct('subject','p1','session','baseline','name',sprintf('run%d',k),'temporal_state','unfiltered_unregressed', ...
        'bold',bold,'events',events,'confounds',confounds,'mask','');
    if isempty(runs),runs=r;else,runs(k)=r;end
    q=struct;q.scans=arrayfun(@(i)sprintf('%s,%d',bold,i),(1:n)','UniformOutput',false);
    q.cond(1)=struct('name','A','onset',[10;40;70],'duration',ones(3,1),'tmod',0,'pmod',empty,'orth',0);
    q.cond(2)=struct('name','B','onset',[20;50;80],'duration',ones(3,1),'tmod',0,'pmod',empty,'orth',0);
    q.multi={''};q.regress=struct('name',{},'val',{});q.multi_reg={''};q.hpf=128;s.sess(k)=q;
end
s.fact=struct('name',{},'levels',{});s.bases.hrf.derivs=[1 1];s.volt=1;
s.global='None';s.mthresh=.8;s.mask={''};s.cvi='AR(1)';b={};b{1}.spm.stats.fmri_spec=s;
previous=pwd;cleanup=onCleanup(@()cd(previous));spm_jobman('run',b);
p=load(fullfile(s.dir{1},'SPM.mat'));coeff=[2;.3;-.2;-1;-.1;.15;4;.2;.1;-2;.1;-.2;1000;500];
old=rng;restoreRng=onCleanup(@()rng(old));rng(516,'twister');y=p.SPM.xX.X*coeff+.01*randn(270,64);
for k=1:2,makeImage(runs(k).bold,reshape(y(p.SPM.Sess(k).row,:)',[4 4 4 p.SPM.nscan(k)]));end
clear restoreRng cleanup;
end
function writeRuns(~,runs,file)
subject=string({runs.subject})';session=string({runs.session})';run=string({runs.name})';
bold=string({runs.bold})';events=string({runs.events})';confounds=string({runs.confounds})';temporal_state=string({runs.temporal_state})';
writetable(table(subject,session,run,bold,events,confounds,temporal_state),file,'FileType','text','Delimiter','\t');
end
function [c,values]=groupFixture(t)
c=t.TestData.cfg;c.level='group';root=t.TestData.root;subject=["p1";"p2";"p3"];session=repmat("baseline",3,1);
contrast=repmat("A_minus_B",3,1);contrast_image=strings(3,1);mask=contrast_image;
old=rng;cleanup=onCleanup(@()rng(old));rng(619,'twister');values=zeros(4,4,4,3);
for k=1:3
    contrast_image(k)=fullfile(root,sprintf('effect%d.nii',k));mask(k)=fullfile(root,sprintf('mask%d.nii',k));
    levels=[1 2 4];v=levels(k)+.1*randn(4,4,4);if k==1,v(1)=0;end
    values(:,:,:,k)=v;makeImage(char(contrast_image(k)),v);
    m=ones(4,4,4);if k==2,m(end)=0;end;makeImage(char(mask(k)),m);
end
writetable(table(subject,session,contrast,contrast_image,mask),c.manifestFile,'FileType','text','Delimiter','\t');clear cleanup;
end
function makeImage(file,data)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;
ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:)=single(data(:));
end
