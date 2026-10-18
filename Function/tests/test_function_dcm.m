function tests=test_function_dcm
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function('D:/matlab/atoolbox/spm12');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testTaskSpecificationAndRejectUnits(t)
[data,model,o]=fixture;d=cog.dcm_build(data,model,'task',o);verifySize(t,d.b,[2 2 1]);verifyEqual(t,d.delays,[.5;.5]);verifyEqual(t,d.Y.name,{'left';'right'});
bad=data;bad.TESeconds=30;verifyError(t,@()cog.dcm_build(bad,model,'task',o),'cog:DCMTiming');bad=model;bad.a(1,1)=0;verifyError(t,@()cog.dcm_build(data,bad,'task',o),'cog:DCMNetwork');
bad=data;bad.u=bad.u(1:20,:);verifyError(t,@()cog.dcm_build(bad,model,'task',o),'cog:DCMInput');
end
function testMultiSubjectPrepareAndNoFalseCompletion(t)
[data,model,~]=fixture;folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
file=fullfile(folder,'data.mat');save(file,'data');subject=["001";"002"];session=["s1";"s2"];run=["r1";"r2"];data_file=repmat(string(file),2,1);tab=table(subject,session,run,data_file);manifest=fullfile(folder,'runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');
c=dcm_config;c.manifestFile=manifest;c.models=model;c.outputRoot=fullfile(folder,'out');c.execute=false;r=run_dcm(c);verifyEqual(t,r.nRuns,2);verifyFalse(t,isfolder(c.outputRoot));c.execute=true;c.estimate=false;run_dcm(c);verifyTrue(t,isfile(fullfile(c.outputRoot,'001','s1','r1','full','DCM.mat')));verifyFalse(t,isfile(fullfile(c.outputRoot,'DCM_BATCH_COMPLETE.mat')));verifyError(t,@()run_dcm(c),'cog:Exists');
end
function testNativeSpectralPosterior(t)
[data,model,o]=fixture;model.b=[];model.c=[];d=cog.dcm_build(data,model,'spectral',o);folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
file=fullfile(folder,'DCM.mat');save(file,'d');DCM=d;save(file,'DCM');d=spm_dcm_fmri_csd(file);q=cog.dcm_check(d);verifyEqual(t,q.nRegions,2);verifyTrue(t,isfinite(q.freeEnergy));
end
function testModelEvidenceAndGroupGuards(t)
[data,model,o]=fixture;d=cog.dcm_build(data,model,'task',o);d.Ep=struct('A',zeros(2));d.Cp=eye(4);d.F=1000;d.M=struct;other=d;other.F=1000+log(3);
r=cog.dcm_model_probabilities({d,other});verifyEqual(t,r.posteriorModelProbability,[.25;.75],'AbsTol',1e-12);
other.Y.y(1)=other.Y.y(1)+1;verifyError(t,@()cog.dcm_model_probabilities({d,other}),'cog:DCMCompare');
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
subject=["a";"b";"c"];dcm_file=strings(3,1);for k=1:3,DCM=d;dcm_file(k)=fullfile(folder,sprintf('d%d.mat',k));save(dcm_file(k),'DCM');end
tab=table(subject,dcm_file);manifest=fullfile(folder,'group.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');c=dcm_group_config;c.manifestFile=manifest;c.outputRoot=fullfile(folder,'out');r=run_dcm_group(c);verifyEqual(t,r.nSubjects,3);verifyFalse(t,isfolder(c.outputRoot));
tab.dcm_file(2)=tab.dcm_file(1);writetable(tab,manifest,'FileType','text','Delimiter','\t');verifyError(t,@()run_dcm_group(c),'cog:DCMGroup');
end
function [data,model,o]=fixture
rng(41);n=96;a=filter(1,[1 -.7],randn(n,1));b=.4*a+filter(1,[1 -.5],randn(n,1));
data=struct('y',[a b],'trSeconds',1,'roiNames',{{'left','right'}},'TESeconds',.03,'delaysSeconds',[.5 .5],'u',repelem(double(mod(floor((0:n-1)'/12),2)),4),'inputDtSeconds',.25,'inputNames',{{'task'}},'X0',ones(n,1));
model=struct('id','full','a',ones(2),'b',zeros(2,2,1),'c',[1;0]);c=dcm_config;o=c.options;o.maxIterations=4;o.arOrder=4;
end
