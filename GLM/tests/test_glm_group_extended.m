function tests=test_glm_group_extended
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;t.TestData.oldDirectory=pwd;root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));c=preprocess_config;addpath(c.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
end
function teardownOnce(t)
path(t.TestData.oldPath);cd(t.TestData.oldDirectory);
end
function setup(t)
folder=tempname;mkdir(folder);t.TestData.root=folder;c=glm_config;c.level='group';c.execute=true;c.continueOnError=false;c.qc.plot=false;
c.manifestFile=fullfile(folder,'input.tsv');c.outputRoot=fullfile(folder,'output');t.TestData.cfg=c;
n=8;subject=compose('%03d',(1:n)');session=repmat("",n,1);contrast=repmat("effect",n,1);
group=[repmat("groupA",3,1);repmat("groupB",5,1)];score=[1;3;2;6;4;7;5;8];age=[30;24;41;27;50;36;44;33];
oldRng=rng;restore=onCleanup(@()rng(oldRng));rng(704,'twister');
y=(1+.5*(score-mean(score))-.02*(age-mean(age))+(group=="groupA"))*(1+.1*sin(1:64))+.25*randn(n,64);
baseline=2+randn(n,64);contrast_image=strings(n,1);pre=contrast_image;mask=contrast_image;
for k=1:n
    contrast_image(k)=fullfile(folder,sprintf('post%d.nii',k));pre(k)=fullfile(folder,sprintf('pre%d.nii',k));mask(k)=fullfile(folder,sprintf('mask%d.nii',k));
    writeImage(contrast_image(k),reshape(y(k,:),[4 4 4]));writeImage(pre(k),reshape(baseline(k,:),[4 4 4]));
    m=ones(4,4,4);if k==3,m(end)=0;end;writeImage(mask(k),m);
end
base=table(subject,session,contrast,contrast_image,mask);t.TestData.base=base;t.TestData.group=group;
t.TestData.covariates=table(score,age);t.TestData.pre=pre;clear restore;
end
function teardown(t)
cd(t.TestData.oldDirectory);rmdir(t.TestData.root,'s');
end
function testPairedMatchesIdsAndRejectsMissingOrDuplicatedPairs(t)
[c,tab]=paired(t);tab=tab(end:-1:1,:);write(tab,c);p=psy.glm_group_plan(c);
verifyEqual(t,p.nSubjects,8);verifyEqual(t,p.residualDF,7);
verifyEqual(t,p.rows.subject(1:2:end),p.rows.subject(2:2:end));verifyEqual(t,p.rows.pair_level(1:2:end),repmat("post",8,1));
verifyEqual(t,p.rows.subject(1),"008");
write(tab(1:end-1,:),c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupPair');verifyFalse(t,isfolder(c.outputRoot));
write([tab;tab(1,:)],c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupDuplicate');
end
function testPairedNativeTAndReverseDirection(t)
[c,tab]=paired(t);write(tab([9:16 8:-1:1],:),c);report=psy.glm_batch(c);verifyEqual(t,report.status,'group_paired_estimated');
checkOls(t,c);out=fullfile(c.outputRoot,'contrast_001');pairing=readtable(fullfile(out,'pairing.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,height(pairing),8);
v=spm_read_vols(spm_vol(fullfile(out,'spmT_0001.nii')));c.group.pairedLevels={'pre','post'};c.outputRoot=fullfile(t.TestData.root,'reverse');psy.glm_batch(c);
reverse=spm_read_vols(spm_vol(fullfile(c.outputRoot,'contrast_001','spmT_0001.nii')));verifyEqual(t,reverse,-v,'AbsTol',1e-5);
end
function testTwoSampleUnbalancedPooledTAndConfiguredDirection(t)
c=t.TestData.cfg;c.group.design='two_sample';c.group.groupLabels={'groupB','groupA'};
tab=addvars(t.TestData.base,t.TestData.group,'NewVariableNames','group');write(tab,c);report=psy.glm_batch(c);verifyEqual(t,report.status,'group_two_sample_estimated');
p=psy.glm_group_plan(c);verifyEqual(t,p.sampleCounts,[5 3]);verifyEqual(t,p.rows.subject(1),"004");checkOls(t,c);
out=fullfile(c.outputRoot,'contrast_001');data=effectData(p);a=data(1:5,:);b=data(6:8,:);
pooled=(4*var(a,0,1)+2*var(b,0,1))/6;expected=(mean(a)-mean(b))./sqrt(pooled*(1/5+1/3));
mask=spm_read_vols(spm_vol(fullfile(out,'mask.nii')))>0;v=spm_read_vols(spm_vol(fullfile(out,'spmT_0001.nii')));
verifyEqual(t,v(mask),expected(mask)','AbsTol',1e-4);
end
function testRegressionSlopesAndOneSampleUncenteredCovariates(t)
c=t.TestData.cfg;c.group.design='regression';c.group.covariateColumns={'score','age'};
tab=[t.TestData.base t.TestData.covariates];write(tab,c);r=psy.glm_batch(c);verifyEqual(t,r.status,'group_regression_estimated');checkOls(t,c);
p=psy.glm_group_plan(c);verifyEqual(t,p.designMatrix(:,2),t.TestData.covariates.score-mean(t.TestData.covariates.score));
c.outputRoot=fullfile(t.TestData.root,'uncentered');c.group.design='one_sample';c.group.covariateCenter='none';psy.glm_batch(c);checkOls(t,c);
p=psy.glm_group_plan(c);verifyEqual(t,p.designMatrix(:,2),t.TestData.covariates.score);
end
function testTwoSampleAdjustedSlopesAndCenterAudit(t)
c=t.TestData.cfg;c.group.design='two_sample';c.group.covariateColumns={'score','age'};
tab=[t.TestData.base t.TestData.covariates];tab.group=t.TestData.group;write(tab,c);psy.glm_batch(c);checkOls(t,c);
p=psy.glm_group_plan(c);verifyEqual(t,p.residualDF,4);verifyEqual(t,p.contrastWeights(1,:),[1 -1 0 0]);
verifyEqual(t,p.covariateAudit.raw_value(1:8),t.TestData.covariates.score);
end
function testCovariateMissingConstantCollinearAndResidualGuards(t)
c=t.TestData.cfg;c.group.design='regression';c.group.covariateColumns={'score','age'};tab=[t.TestData.base t.TestData.covariates];
bad=tab;bad.score(2)=NaN;write(bad,c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupCovariate');
bad=tab;bad.age(:)=40;write(bad,c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupCovariate');
bad=tab;bad.age=2*bad.score;write(bad,c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupDesign');
write(tab,c);c.group.minResidualDF=6;verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupDesign');verifyFalse(t,isfolder(c.outputRoot));
end
function testSubjectGroupAndCrossEffectConsistency(t)
c=t.TestData.cfg;c.group.design='two_sample';tab=addvars(t.TestData.base,t.TestData.group,'NewVariableNames','group');
bad=tab;bad.subject(4)=bad.subject(1);write(bad,c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupDuplicate');
bad=tab;bad.group(2:3)="groupB";write(bad,c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupSample');
bad=tab;bad.contrast(:)="effect2";bad.group(1)="groupB";write([tab;bad],c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupSample');
c.group.design='regression';c.group.covariateColumns={'score','age'};tab=[t.TestData.base t.TestData.covariates];bad=tab;bad.contrast(:)="effect2";bad.age(2)=35;
write([tab;bad],c);verifyError(t,@()psy.glm_batch(c),'psy:GLMGroupSample');
end
function testConfigurationCompatibilityPreparedAndInputProtection(t)
c=t.TestData.cfg;old=c;old.group=struct('design','one_sample','minSubjects',3);old=psy.glm_framework_options(old);verifyEqual(t,old.group.minPerGroup,2);
bad=c;bad.group.design='regression';verifyError(t,@()psy.glm_framework_options(bad),'psy:GLMGroupConfig');
bad=c;bad.group.design='paired';bad.group.covariateColumns={'score'};verifyError(t,@()psy.glm_framework_options(bad),'psy:GLMGroupConfig');
bad=c;bad.group.groupLabels={'same','same'};verifyError(t,@()psy.glm_framework_options(bad),'psy:GLMGroupConfig');
write(t.TestData.base,c);c.execute=false;r=psy.glm_batch(c);verifyEqual(t,r.status,'group_prepared_not_estimated');
out=fullfile(c.outputRoot,'contrast_001');verifyTrue(t,isfile(fullfile(out,'GLM_GROUP_PREPARED.mat')));verifyFalse(t,isfile(fullfile(out,'SPM.mat')));
before=readtable(fullfile(out,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');after=readtable(fullfile(out,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,before,after);
verifyError(t,@()psy.glm_batch(c),'psy:GLMExists');
end
function testRelativeManifestSurvivesSpmDirectoryChanges(t)
c=t.TestData.cfg;write(t.TestData.base,c);previous=pwd;restore=onCleanup(@()cd(previous));cd(t.TestData.root);
c.manifestFile='input.tsv';c.outputRoot='relative_output';p=psy.glm_group_plan(c);verifyEqual(t,p.nSubjects,8);
report=psy.glm_batch(c);verifyEqual(t,report.status,'group_one_sample_estimated');verifyEqual(t,pwd,t.TestData.root);
verifyTrue(t,isfolder(fullfile(t.TestData.root,c.outputRoot)));
s=load(fullfile(c.outputRoot,'contrast_001','SPM.mat'));verifyEqual(t,s.SPM.xCon(1).name,'effect_positive');
hashes=readtable(fullfile(c.outputRoot,'contrast_001','input_hashes_after.tsv'),'FileType','text','Delimiter','\t','TextType','string');
verifyTrue(t,all(arrayfun(@(p)java.io.File(char(p)).isAbsolute(),hashes.path)));clear restore;
end
function [c,tab]=paired(t)
c=t.TestData.cfg;c.group.design='paired';c.group.pairedLevels={'post','pre'};a=t.TestData.base;a.pair_level=repmat("post",8,1);
b=t.TestData.base;b.contrast_image=t.TestData.pre;b.pair_level=repmat("pre",8,1);tab=[a;b];
end
function write(tab,c)
writetable(tab,c.manifestFile,'FileType','text','Delimiter','\t');
end
function y=effectData(p)
y=zeros(p.nSubjects,64);
for k=1:p.nSubjects
    if strcmp(p.design,'paired')
        a=spm_read_vols(spm_vol(char(p.rows.contrast_image(2*k-1))));b=spm_read_vols(spm_vol(char(p.rows.contrast_image(2*k))));y(k,:)=double(single(a(:)-b(:)))';
    else
        a=spm_read_vols(spm_vol(char(p.rows.contrast_image(k))));y(k,:)=a(:)';
    end
end
end
function checkOls(t,c)
p=psy.glm_group_plan(c);x=p.designMatrix;y=effectData(p);b=x\y;residual=y-x*b;sigma2=sum(residual.^2,1)/p.residualDF;
out=fullfile(c.outputRoot,'contrast_001');mask=spm_read_vols(spm_vol(fullfile(out,'mask.nii')))>0;verifyFalse(t,mask(end));verifyTrue(t,mask(1));
s=load(fullfile(out,'SPM.mat'));verifyEqual(t,s.SPM.xX.erdf,p.residualDF,'AbsTol',1e-7);
for k=1:size(p.contrastWeights,1)
    w=p.contrastWeights(k,:);effect=w*b;expected=effect./sqrt((w*pinv(x'*x)*w')*sigma2);
    a=spm_read_vols(spm_vol(fullfile(out,sprintf('con_%04d.nii',k))));v=spm_read_vols(spm_vol(fullfile(out,sprintf('spmT_%04d.nii',k))));
    verifyEqual(t,a(mask),effect(mask)','AbsTol',1e-5);verifyEqual(t,v(mask),expected(mask)','AbsTol',1e-4);
end
before=readtable(fullfile(out,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');after=readtable(fullfile(out,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,before,after);
end
function writeImage(file,data)
ni=nifti;ni.dat=file_array(char(file),size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;create(ni);ni.dat(:)=single(data(:));
end
