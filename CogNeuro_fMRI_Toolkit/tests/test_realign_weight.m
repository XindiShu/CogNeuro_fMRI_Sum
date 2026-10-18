function tests=test_realign_weight
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=preprocess_config; addpath(cfg.spmPath);
spm('defaults','fmri'); spm_jobman('initcfg');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
folder=tempname; mkdir(folder); t.TestData.root=folder;
[x,y,z]=ndgrid(linspace(-1,1,32),linspace(-1,1,32),linspace(-1,1,16));
mag=single(1000*exp(-3*(x.^2+y.^2+z.^2))+20);
image=mag+single(5*x+3*y);
bold=fullfile(folder,'bold.nii');
frames=cell(8,1);
for k=1:8
    frames{k}=fullfile(folder,sprintf('frame%02d.nii',k));
    niftiwrite(mag.*single(1+.02*sin(k))+single(5*x+3*y),frames{k});
end
spm_file_merge(spm_vol(char(frames)),bold,0,2); % 写入真实时间单位与 TR，避免构造无时间单位的测试 BOLD。
niftiwrite(image,fullfile(folder,'t1.nii'));
weight=fullfile(folder,'weight.nii'); niftiwrite(ones(size(image),'single'),weight);
t.TestData.bold=bold; t.TestData.weight=weight; t.TestData.cfg=toolkit_config;
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testOptionalDefaultAndOverrides(t)
cfg=t.TestData.cfg;
if isfield(cfg.realign,'weightImage'), cfg.realign=rmfield(cfg.realign,'weightImage'); end
p=psy.realign_weight_plan(struct,cfg,t.TestData.bold); verifyFalse(t,p.enabled);
cfg.realign.weightImage=t.TestData.weight;
p=psy.realign_weight_plan(struct,cfg,t.TestData.bold);
verifyTrue(t,p.enabled); verifyEqual(t,p.source,'config'); verifyEqual(t,numel(p.sha256),64);
p=psy.realign_weight_plan(struct('realignWeightImage','none'),cfg,t.TestData.bold);
verifyFalse(t,p.enabled);
cfg.realign.weightImage='';
p=psy.realign_weight_plan(struct('realignWeightImage',t.TestData.weight),cfg,t.TestData.bold);
verifyEqual(t,p.source,'manifest'); verifyTrue(t,p.enabled);
cfg.realign.weightImage=42;
verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:RealignWeightPath');
end
function testBadWeightsAndPathsRejected(t)
cfg=t.TestData.cfg; file=t.TestData.weight;
cfg.realign.weightImage='relative.nii';
verifyError(t,@()psy.realign_weight_plan(struct,cfg,t.TestData.bold),'psy:RealignWeightPath');
cfg.realign.weightImage=fullfile(t.TestData.root,'missing.nii');
verifyError(t,@()psy.realign_weight_plan(struct,cfg,t.TestData.bold),'psy:RealignWeightPath');
cfg.realign.weightImage=file;
for value=[0 0.005 -1 NaN Inf]
    niftiwrite(single(value*ones(32,32,16)),file);
    verifyError(t,@()psy.realign_weight_plan(struct,cfg,t.TestData.bold),'psy:RealignWeightValues');
end
niftiwrite(ones(32,32,16,2,'single'),file);
verifyError(t,@()psy.realign_weight_plan(struct,cfg,t.TestData.bold),'psy:RealignWeightShape');
end
function testDifferentGridOverlapAndGzip(t)
cfg=t.TestData.cfg; cfg.realign.weightImage=t.TestData.weight;
niftiwrite(ones(16,16,8,'single'),t.TestData.weight);
spm_get_space(t.TestData.weight,diag([2 2 2 1]));
p=psy.realign_weight_plan(struct,cfg,t.TestData.bold);
verifyTrue(t,p.enabled); verifyGreaterThan(t,p.positiveReferenceVoxels,0);
gzip(t.TestData.weight); cfg.realign.weightImage=[t.TestData.weight '.gz'];
p=psy.realign_weight_plan(struct,cfg,t.TestData.bold); verifyTrue(t,p.enabled);
cfg.realign.weightImage=t.TestData.weight;
matrix=diag([2 2 2 1]); matrix(1,4)=1000; spm_get_space(t.TestData.weight,matrix);
verifyError(t,@()psy.realign_weight_plan(struct,cfg,t.TestData.bold),'psy:RealignWeightOverlap');
end
function testManifestRelativeWeightAndNone(t)
manifest=fullfile(t.TestData.root,'runs.tsv');
fid=fopen(manifest,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\trealign_weight\n');
fprintf(fid,'A\t\tr1\tbold.nii\tt1.nii\traw\tweight.nii\nB\t\tr1\tbold.nii\tt1.nii\traw\tnone\n'); fclose(fid);
cfg=t.TestData.cfg; cfg.manifestFile=manifest;
r=psy.read_manifest(cfg);
verifyEqual(t,r(1).realignWeightImage,t.TestData.weight);
verifyEqual(t,r(2).realignWeightImage,'none');
end
function testChangedWeightBetweenPlanAndExecution(t)
cfg=t.TestData.cfg; cfg.realign.weightImage=t.TestData.weight;
p=psy.realign_weight_plan(struct,cfg,t.TestData.bold);
niftiwrite(0.5*ones(32,32,16,'single'),t.TestData.weight);
out=fullfile(t.TestData.root,'changed'); mkdir(out);
local=psy.stage_image(t.TestData.bold,out);
verifyError(t,@()psy.spm_motion_step(local,8,cfg,out,struct('method','none'),p), ...
    'psy:RealignWeightChanged');
verifyFalse(t,isfile(fullfile(out,'02_realign.mat')));
end
function testBatchWeightingCopiesAndResume(t)
root=t.TestData.root; original=niftiread(t.TestData.weight);
gzip(t.TestData.weight);
manifest=fullfile(root,'runs.tsv'); fid=fopen(manifest,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\trealign_weight\n');
fprintf(fid,'A\t\tr1\tbold.nii\tt1.nii\traw\tweight.nii.gz\nB\t\tr1\tbold.nii\tt1.nii\traw\tnone\n'); fclose(fid);
cfg=t.TestData.cfg; cfg.manifestFile=manifest; cfg.outputRoot=fullfile(root,'output');
cfg.execute=true; cfg.stopAfter='realign'; cfg.qc.enabled=false;
cfg.discardVolumes=0;
cfg.sdc.method='none'; cfg.sliceTiming.mode='off'; cfg.sliceTiming.enabled=false;
cfg.realign.weightImage=t.TestData.weight;
report=psy.preprocess_batch(cfg);
verifyTrue(t,all(strcmp({report.status},'realigned_without_distortion_correction')));
a=load(fullfile(report(1).output,'02_realign.mat'));
b=load(fullfile(report(2).output,'02_realign.mat'));
verifyTrue(t,isfile(a.matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight{1}));
verifyEmpty(t,b.matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight{1});
verifyEqual(t,niftiread(t.TestData.weight),original);
for k=1:2
    verifyTrue(t,isfile(fullfile(report(k).output,'COMPLETE.mat')));
    verifySize(t,readmatrix(fullfile(report(k).output,'rp_bold.txt')),[8 6]);
end
report=psy.preprocess_batch(cfg);
verifyTrue(t,all(strcmp({report.status},'reused_completed_run')));
% 只修改合成权重文件：已完成 run 不得静默复用或覆盖。
niftiwrite(0.5*ones(32,32,16,'single'),t.TestData.weight);
gzip(t.TestData.weight);
report=psy.preprocess_batch(cfg);
verifyEqual(t,report(1).status,'failed');
verifyEqual(t,report(2).status,'reused_completed_run');
verifyTrue(t,isfile(fullfile(report(1).output,'COMPLETE.mat')));
end
function testWeightedFieldMapBranches(t)
cfg=t.TestData.cfg; root=t.TestData.root; cfg.realign.weightImage=t.TestData.weight;
[x,y,~]=ndgrid(linspace(-1,1,32),linspace(-1,1,32),linspace(-1,1,16));
phase=fullfile(root,'phase.nii'); niftiwrite(single(.4*x+.2*y),phase);
mag=fullfile(root,'field_magnitude.nii');
[x0,y0,z0]=ndgrid(linspace(-1,1,32),linspace(-1,1,32),linspace(-1,1,16));
niftiwrite(single(1000*exp(-8*(x0.^2+y0.^2+z0.^2))+.001),mag);
sdc=struct('fieldmap',struct('type','phasediff','phase',phase,'magnitude',mag, ...
    'echoTimesMs',[4 6]),'blipDirection',-1,'readoutMs',35,'phaseEncodingAxis',2);
for method={'spm_fieldmap_unwarp','spm_fieldmap_applyvdm'}
    sdc.method=method{1}; out=fullfile(root,method{1}); mkdir(out);
    local=psy.stage_image(t.TestData.bold,out);
    result=psy.spm_motion_step(local,8,cfg,out,sdc);
    if strcmp(method{1},'spm_fieldmap_unwarp')
        job=load(fullfile(out,'02_realign_unwarp.mat'));
        weight=job.matlabbatch{1}.spm.spatial.realignunwarp.eoptions.weight{1};
    else
        job=load(fullfile(out,'02_realign_estimate.mat'));
        weight=job.matlabbatch{1}.spm.spatial.realign.estimate.eoptions.weight{1};
    end
    verifyEqual(t,weight,result.weightImage); verifyTrue(t,isfile(weight));
    verifyEqual(t,numel(spm_vol(result.series)),8);
    movement=readmatrix(result.motion);
    verifySize(t,movement,[8 6]); verifyTrue(t,all(isfinite(movement(:))));
    frames=spm_vol(result.series); values=spm_read_vols(frames(1));
    % 小型合成 EPI 的外层会被共同视野 masking 排除；检查中央共同有效区，
    % 不把真实边界缺失误判为 Weighting 接线失败。
    interior=values(8:24,8:24,4:12);
    verifyTrue(t,all(isfinite(interior(:))));
    verifyGreaterThan(t,std(interior(:)),0);
end
end
