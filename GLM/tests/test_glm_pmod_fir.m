function tests=test_glm_pmod_fir
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
c.conditions={'A','B'};c.contrastNames={'A_minus_B'};c.contrastWeights=[1 -1];c.events.expression='impulse';
c.design.motionModel='none';c.design.includeTissueMeans=false;c.design.linearTrend=false;
c.minResidualDF=5;c.design.minResidualDF=5;c.serialCorrelation='AR(1)';c.continueOnError=false;
c.manifestFile=fullfile(root,'runs.tsv');c.outputRoot=fullfile(root,'output');t.TestData.cfg=c;
onset=[5;17;29;44;56;70;85;99;113;128;141;155;169;181;193;209;221;235];
duration=zeros(18,1);trial_type=repmat(["A";"B"],9,1);
difficulty=repelem([3;1;6;2;9;4;8;5;7],2);rt=repelem([4;1;6;8;3;9;2;5;7],2);
t.TestData.events=table(onset,duration,trial_type,difficulty,rt);
writetable(t.TestData.events,fullfile(root,'events.tsv'),'FileType','text','Delimiter','\t');
end
function teardown(t)
cd(t.TestData.oldDirectory);rmdir(t.TestData.root,'s');
end
function testPmodCenterScaleOrderAndSourcePreservation(t)
c=pmodConfig(t);c.pmod.scale='zscore';c.pmod.orthogonalize=true;file=fullfile(t.TestData.root,'events.tsv');before=fileread(file);
p=psy.glm_framework_plan(file,260,c);v=t.TestData.events.difficulty(1:2:end);z=(v-mean(v))/std(v);
verifyEqual(t,p.models.conditions(1).pmod(1).param,z);verifyEqual(t,p.models.conditions(1).pmod(1).poly,2);
verifyEqual(t,{p.models.conditions(1).pmod.name},{'difficulty','rt'});verifyEqual(t,p.models.conditions(1).orth,1);
verifyEqual(t,p.pmodAudit.event_index(1:9),(1:2:17)');verifyEqual(t,p.pmodAudit.raw_value(1:9),v);
verifyEqual(t,p.pmodAudit.scale(1:9),repmat(std(v),9,1));verifyEqual(t,fileread(file),before);
c.pmod.center='none';c.pmod.scale='none';c.pmod.orthogonalize=false;
p=psy.glm_framework_plan(file,260,c);verifyEqual(t,p.models.conditions(1).pmod(1).param,v);
end
function testPmodInvalidValuesAndCombinations(t)
c=pmodConfig(t);file=fullfile(t.TestData.root,'events.tsv');events=t.TestData.events;
events.difficulty(1)=NaN;writetable(events,file,'FileType','text','Delimiter','\t');
verifyError(t,@()psy.glm_framework_plan(file,260,c),'psy:GLMPmodValues');
events.difficulty(:)=1;writetable(events,file,'FileType','text','Delimiter','\t');
verifyError(t,@()psy.glm_framework_plan(file,260,c),'psy:GLMPmodValues');
c.pmod.modulators(1).column='missing';verifyError(t,@()psy.glm_framework_plan(file,260,c),'psy:GLMPmodValues');
c=pmodConfig(t);c.pmod.modulators(2).name='difficulty';verifyError(t,@()psy.glm_framework_options(c),'psy:GLMPmodConfig');
c=pmodConfig(t);c.hrf.type='fir';verifyError(t,@()psy.glm_framework_options(c),'psy:GLMUnsupportedCombination');
c=pmodConfig(t);c.model.unit='event';verifyError(t,@()psy.glm_framework_options(c),'psy:GLMUnsupportedCombination');
c=pmodConfig(t);c.pmod.modulators(1).poly=0;verifyError(t,@()psy.glm_framework_options(c),'psy:GLMPmodConfig');
end
function testSpmPmodKnownSlopesAndDerivativeZeroWeights(t)
c=pmodConfig(t);c.hrf.type='canonical_time_dispersion';[runs,c,coeff]=knownData(t,c,1,false);
out=fullfile(t.TestData.root,'pmod_fit');psy.glm_framework_run(runs,c,out);
p=load(fullfile(out,'models','joint','SPM.mat'));s=p.SPM;
verifyEqual(t,numel(s.xCon),4);names=string(s.xX.name);
for id=2:4
    cols=find(s.xCon(id).c);verifyEqual(t,numel(cols),1);verifyTrue(t,endsWith(names(cols),'*bf(1)'));
    con=spm_read_vols(spm_vol(fullfile(out,'models','joint',sprintf('con_%04d.nii',id))));
    verifyEqual(t,median(con(:)),coeff(cols)*s.xGX.gSF(1),'AbsTol',.003);
end
verifyTrue(t,isfile(fullfile(out,'pmod_values.tsv')));
end
function testSpmSerialOrthogonalizationMatchesStockDesign(t)
c=pmodConfig(t);c.pmod.orthogonalize=true;[runs,c,~]=knownData(t,c,1,true);
out=fullfile(t.TestData.root,'orth_fit');psy.glm_framework_run(runs,c,out);
p=load(fullfile(out,'models','joint','SPM.mat'));r=load(fullfile(t.TestData.root,'reference','SPM.mat'));
verifyEqual(t,p.SPM.xX.X,r.SPM.xX.X,'AbsTol',1e-10);
end
function testFirTwoRunTimeCourseMeanAndFByIndependentFormula(t)
c=t.TestData.cfg;c.level='subject';c.hrf.type='fir';c.hrf.fir.windowSeconds=12;c.hrf.fir.nBins=4;c.hrf.fir.summaryBins=[2 3];
[runs,c,coeff]=knownData(t,c,2,false);out=fullfile(t.TestData.root,'fir_fit');psy.glm_subject_run(runs,c,out);
model=fullfile(out,'model');p=load(fullfile(model,'SPM.mat'));s=p.SPM;
verifyEqual(t,numel(s.xCon),6);verifyEqual(t,{s.xCon.STAT},{'T','T','T','T','T','F'});
for bin=1:4
    expected=(coeff(bin)-coeff(4+bin))*mean([s.xGX.gSF(1) s.xGX.gSF(261)]);
    con=spm_read_vols(spm_vol(fullfile(model,sprintf('con_%04d.nii',bin))));
    verifyEqual(t,median(con(:)),expected,'AbsTol',.003);
end
verifyEqual(t,full(s.xCon(5).c)',mean(full([s.xCon(2).c s.xCon(3).c]),2)');
mask=spm_read_vols(spm_vol(fullfile(model,'mask.nii')))>0;ids=find(mask);voxel=ids(1);
beta=zeros(numel(s.Vbeta),1);
for k=1:numel(beta),v=spm_read_vols(spm_vol(fullfile(model,sprintf('beta_%04d.nii',k))));beta(k)=v(voxel);end
variance=spm_read_vols(spm_vol(fullfile(model,'ResMS.nii')));C=full(s.xCon(6).c)';theta=C*beta;
expected=theta'*pinv(C*s.xX.Bcov*C')*theta/4/variance(voxel);
actual=spm_read_vols(spm_vol(fullfile(model,'spmF_0006.nii')));
verifyEqual(t,actual(voxel),expected,'RelTol',2e-5);
effects=readtable(fullfile(out,'subject_contrasts.tsv'),'FileType','text','Delimiter','\t');
verifyEqual(t,height(effects),5);verifyTrue(t,all(isfile(effects.contrast_image)));
axis=readtable(fullfile(model,'fir_time_bins.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,axis.start_seconds,[0;3;6;9]);
end
function testFirConfigGridAndLssGuards(t)
c=t.TestData.cfg;c.hrf.type='fir';c.hrf.fir.nBins=2.5;
verifyError(t,@()psy.glm_framework_options(c),'psy:GLMFIRConfig');
c.hrf.fir.nBins=4;c.hrf.fir.summaryBins=[1 1];verifyError(t,@()psy.glm_framework_options(c),'psy:GLMFIRConfig');
c.hrf.fir.summaryBins=[];c.model.unit='trial';c.fit.strategy='lss';
verifyError(t,@()psy.glm_framework_options(c),'psy:GLMUnsupportedCombination');
c=t.TestData.cfg;c.hrf.type='fir';c.hrf.fir.windowSeconds=12;c.hrf.fir.nBins=4;
[runs,c,~]=knownData(t,c,1,false);c.execute=false;c.hrf.fir.windowSeconds=12.1;
verifyError(t,@()psy.glm_framework_run(runs,c,fullfile(t.TestData.root,'bad_grid')),'psy:GLMFIRGrid');
verifyFalse(t,isfile(fullfile(t.TestData.root,'bad_grid','GLM_FRAMEWORK_PREPARED.mat')));
end
function testPreparedFirCatalogHasNoFakeCanonicalBeta(t)
c=t.TestData.cfg;c.hrf.type='fir';c.hrf.fir.windowSeconds=12;c.hrf.fir.nBins=4;
[runs,c,~]=knownData(t,c,1,false);c.execute=false;out=fullfile(t.TestData.root,'prepared');
psy.glm_framework_run(runs,c,out);tab=readtable(fullfile(out,'model_outputs.tsv'),'FileType','text','Delimiter','\t','TextType','string');
verifyEqual(t,height(tab),6);verifyFalse(t,any(tab.estimated));verifyEqual(t,tab.statistic(end),"F");
verifyFalse(t,isfile(fullfile(out,'models','joint','SPM.mat')));
end
function testNonestimablePmodNeverAccepted(t)
c=pmodConfig(t);x=eye(5);names={'Sn(1) A*bf(1)','Sn(1) Axdifficulty^1*bf(1)', ...
    'Sn(1) Axdifficulty^2*bf(1)','Sn(1) Axrt^1*bf(1)','Sn(1) B*bf(1)'};
x(:,4)=x(:,2);verifyError(t,@()psy.glm_model_contrasts(names,c,x,0),'psy:GLMEstimability');
end
function testGroupRejectsFirEssAndFImages(t)
c=t.TestData.cfg;c.level='group';root=t.TestData.root;
subject=["p1";"p2";"p3"];session=repmat("baseline",3,1);contrast=repmat("FIR_omnibus",3,1);
mask=repmat(string(fullfile(root,'mask.nii')),3,1);makeImage(char(mask(1)),ones(4,4,4));
for prefix={'ess','spmF'}
    contrast_image=strings(3,1);
    for k=1:3
        contrast_image(k)=fullfile(root,sprintf('%s_%04d.nii',prefix{1},k));makeImage(char(contrast_image(k)),ones(4,4,4));
    end
    writetable(table(subject,session,contrast,contrast_image,mask),c.manifestFile,'FileType','text','Delimiter','\t');
    verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupInput');verifyFalse(t,isfolder(c.outputRoot));
end
end

function c=pmodConfig(t)
c=t.TestData.cfg;c.pmod.enabled=true;
c.pmod.modulators=struct('condition',{'A','A'},'column',{'difficulty','rt'},'name',{'difficulty','rt'},'poly',{2,1});
end
function [runs,c,coeff]=knownData(t,c,nRuns,orth)
% 参考设计单独调用stock SPM构造，不调用待测pmod/FIR映射函数。
root=t.TestData.root;n=260;events=t.TestData.events;v=events.difficulty(1:2:end);v=v-mean(v);w=events.rt(1:2:end);w=w-mean(w);
empty=struct('name',{},'param',{},'poly',{});s=struct;s.dir={fullfile(root,'reference')};mkdir(s.dir{1});
s.timing=struct('units','secs','RT',1,'fmri_t',16,'fmri_t0',8);runs=struct([]);
for r=1:nRuns
    bold=fullfile(root,sprintf('bold%d.nii',r));makeImage(bold,ones(4,4,4,n)*1000);
    confounds=fullfile(root,sprintf('confounds%d.tsv',r));writetable(table((1:n)','VariableNames',{'unused'}),confounds,'FileType','text','Delimiter','\t');
    q=struct;q.scans=arrayfun(@(k)sprintf('%s,%d',bold,k),(1:n)','UniformOutput',false);
    for k=1:2
        label={'A','B'};selected=events.trial_type==string(label{k});
        q.cond(k)=struct('name',label{k},'onset',events.onset(selected),'duration',zeros(nnz(selected),1),'tmod',0,'pmod',empty,'orth',0);
    end
    if c.pmod.enabled
        q.cond(1).pmod(1)=struct('name','difficulty','param',v,'poly',2);
        q.cond(1).pmod(2)=struct('name','rt','param',w,'poly',1);q.cond(1).orth=double(orth);q.cond(2).orth=double(orth);
    end
    q.multi={''};q.regress=struct('name',{},'val',{});q.multi_reg={''};q.hpf=128;s.sess(r)=q;
    def=struct('subject','p1','session','','name',sprintf('run%d',r),'temporal_state','unfiltered_unregressed', ...
        'bold',bold,'events',fullfile(root,'events.tsv'),'confounds',confounds,'mask','');
    if isempty(runs),runs=def;else,runs(r)=def;end
end
s.fact=struct('name',{},'levels',{});s.volt=1;s.global='None';s.mthresh=.8;s.mask={''};s.cvi='AR(1)';
if strcmp(c.hrf.type,'fir')
    s.bases.fir=struct('length',12,'order',4);task=[1;3;2;.5;-.5;0;.5;0];
else
    s.bases.hrf.derivs=[0 0];task=[2;.7;-.2;.3;-1];
    if strcmp(c.hrf.type,'canonical_time_dispersion')
        s.bases.hrf.derivs=[1 1];task=reshape([task .05*ones(5,1) -.03*ones(5,1)]',[],1);
    end
end
b={};b{1}.spm.stats.fmri_spec=s;previous=pwd;cleanup=onCleanup(@()cd(previous));spm_jobman('run',b);
p=load(fullfile(s.dir{1},'SPM.mat'));coeff=[repmat(task,nRuns,1);1000*ones(nRuns,1)];
old=rng;restoreRng=onCleanup(@()rng(old));rng(691,'twister');y=p.SPM.xX.X*coeff+.01*randn(n*nRuns,64);
for r=1:nRuns,makeImage(runs(r).bold,reshape(y(p.SPM.Sess(r).row,:)',[4 4 4 n]));end
clear restoreRng cleanup;
end
function makeImage(file,data)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;
ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:)=single(data(:));
end
