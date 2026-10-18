function tests=test_glmsingle_demo
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'matlab'),fullfile(root,'config'));
c=preprocess_config;addpath(c.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
folder=tempname;mkdir(folder);t.TestData.folder=folder;
[cfg,demo]=glmsingle_demo_config;cfg.conditions={'A','B'};cfg.qc.plot=false;
cfg.design.motionModel='none';cfg.glmsingle.maxPolyDegree=1;
cfg.manifestFile=fullfile(folder,'runs.tsv');cfg.outputRoot=fullfile(folder,'output');
demo.maxVoxelsPerSubject=64;t.TestData.cfg=cfg;t.TestData.demo=demo;
oldPath=path;restorePath=onCleanup(@()path(oldPath));psy.glmsingle_dependency(cfg.glmsingle.path);
oldRng=rng;restoreRng=onCleanup(@()rng(oldRng));rng(971,'twister');
onset=(10:12:190)'+.25;onset(end)=237.25;
duration=10+mod((1:numel(onset))',5)*4;trial_type=repmat(["A";"B"],numel(onset)/2,1);
n=240;hrf=getcanonicalhrf(20,1);stim=zeros(n,numel(onset));
stim(sub2ind(size(stim),round(onset)+1,(1:numel(onset))'))=1;
x=conv2(stim,hrf(:));x=x(1:n,:);mask=ones(6,6,4);mask(end)=0;
maskFile=fullfile(folder,'mask.nii');writeImage(maskFile,mask);
subject=repmat("demo",2,1);session=repmat("",2,1);run=["LR";"RL"];
bold=strings(2,1);events=bold;confounds=bold;temporal_state=repmat("unfiltered_unregressed",2,1);
for k=1:2
    stimulus_id="audio_"+k+"_"+(1:numel(onset))';
    events(k)=fullfile(folder,sprintf('events%d.tsv',k));
    writetable(table(onset,duration,trial_type,stimulus_id),events(k),'FileType','text','Delimiter','\t');
    amplitude=repmat((1:numel(onset))*.08,144,1);amplitude(73:end,:)=0;
    shared=sin((1:n)'/7+k);y=1000+x*amplitude'+shared*(1+rand(1,144))+.01*randn(n,144);
    bold(k)=fullfile(folder,sprintf('bold%d.nii',k));writeImage(bold(k),reshape(y',[6 6 4 n]));
    confounds(k)=fullfile(folder,sprintf('confounds%d.tsv',k));
    writetable(table((1:n)','VariableNames',{'unused'}),confounds(k),'FileType','text','Delimiter','\t');
end
mask=repmat(string(maskFile),2,1);
writetable(table(subject,session,run,bold,events,confounds,temporal_state,mask),cfg.manifestFile,'FileType','text','Delimiter','\t');
t.TestData.input=struct('events',events,'bold',bold);clear restoreRng restorePath;
end
function teardown(t)
rmdir(t.TestData.folder,'s');
end
function testPreparationPreservesSourcesAndAuditsExclusions(t)
c=t.TestData.cfg;oldHash=psy.file_sha256(char(t.TestData.input.events(1)));oldPath=path;
report=run_glmsingle_demo(c,t.TestData.demo);verifyEqual(t,report.status,'glmsingle_prepared_not_estimated');
verifyEqual(t,path,oldPath);verifyEqual(t,psy.file_sha256(char(t.TestData.input.events(1))),oldHash);
a=readtable(fullfile(c.outputRoot,'demo_event_audit.tsv'),'FileType','text','Delimiter','\t','TextType','string');
verifyEqual(t,height(a),32);verifyEqual(t,nnz(a.included_in_demo),30);
verifyEqual(t,a.original_duration_seconds(1:5),[14;18;22;26;10]);
verifyEqual(t,unique(a.modeled_duration_seconds),20);verifyEqual(t,a.onset_error_seconds,repmat(-.25,32,1));
verifyTrue(t,all(isnan(a.beta_index(~a.included_in_demo))));
verifyEqual(t,a.source_event_index(~a.included_in_demo),[16;16]);
verifyEqual(t,a.beta_index(logical(a.included_in_demo)),(1:30)');
m=readtable(fullfile(c.outputRoot,'demo_mask_audit.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,m.demoVoxels,64);
verifyTrue(t,isfile(fullfile(c.outputRoot,'GLMSINGLE_DEMO_PREPARED.mat')));
verifyFalse(t,isfile(fullfile(c.outputRoot,'GLMSINGLE_DEMO_COMPLETE.mat')));
verifyError(t,@()run_glmsingle_demo(c,t.TestData.demo),'psy:GLMExists');
end
function testNativeAllModelsAfterExplicitApproximation(t)
c=t.TestData.cfg;c.execute=true;oldRng=rng;report=run_glmsingle_demo(c,t.TestData.demo);
verifyEqual(t,rng,oldRng);verifyEqual(t,report.status,'glmsingle_models_estimated');verifyEqual(t,report.nEvents,30);
p=fullfile(c.outputRoot,'models','sub-demo','combined');s=jsondecode(fileread(fullfile(p,'summary.json')));
verifyEqual(t,string(s.modelTypes(:)),["A";"B";"C";"D"]);verifyEqual(t,s.nIdentities,2);
verifyEqual(t,s.sharedIdentitiesPerFold,[2;2]);verifyEqual(t,s.maskedVoxels,64);
native=load(fullfile(p,'native_results.mat'));verifyFalse(t,isempty(native.results{4}.rrbadness));
verifyFalse(t,isempty(native.results{3}.glmbadness));
v=spm_vol(fullfile(p,'TYPED','event_betas.nii'));verifyEqual(t,numel(v),30);
verifyTrue(t,isfile(fullfile(c.outputRoot,'GLMSINGLE_DEMO_COMPLETE.mat')));
before=readtable(fullfile(c.outputRoot,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');
after=readtable(fullfile(c.outputRoot,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,before,after);
end
function testExplicitProfileAndEmptyTailSelectionFail(t)
c=t.TestData.cfg;c.glmsingle.identityColumn='stimulus_id';
verifyError(t,@()run_glmsingle_demo(c,t.TestData.demo),'psy:GLMsingleDemo');verifyFalse(t,isfolder(c.outputRoot));
c=t.TestData.cfg;c.glmsingle.minEndBufferSeconds=1000;
verifyError(t,@()run_glmsingle_demo(c,t.TestData.demo),'psy:GLMsingleDemo');
verifyTrue(t,isfile(fullfile(c.outputRoot,'GLMSINGLE_DEMO_FAILED.mat')));
verifyFalse(t,isfile(fullfile(c.outputRoot,'GLMSINGLE_DEMO_COMPLETE.mat')));
end
function writeImage(file,data)
ni=nifti;ni.dat=file_array(char(file),size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;
ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:)=single(data(:));
end
