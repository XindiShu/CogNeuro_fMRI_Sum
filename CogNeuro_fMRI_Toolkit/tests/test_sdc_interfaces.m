function tests=test_sdc_interfaces
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=preprocess_config; addpath(cfg.spmPath); addpath(fullfile(cfg.spmPath,'toolbox','FieldMap'));
spm('defaults','fmri'); spm_jobman('initcfg');
end
function teardownOnce(t), path(t.TestData.oldPath); end
function setup(t)
root=tempname; mkdir(root); t.TestData.root=root;
[x,y,z]=ndgrid(linspace(-1,1,32),linspace(-1,1,32),linspace(-1,1,16));
mag=single(1000*exp(-3*(x.^2+y.^2+z.^2))+20);
frames=cell(8,1);
for k=1:8
    frames{k}=fullfile(root,sprintf('frame%d.nii',k));
    niftiwrite(mag.*single(1+.02*sin(k))+single(5*x+3*y),frames{k});
end
bold=fullfile(root,'bold.nii'); spm_file_merge(spm_vol(char(frames)),bold,0,2);
fieldMag=single(1000*exp(-8*(x.^2+y.^2+z.^2))+.001);
niftiwrite(fieldMag,fullfile(root,'mag.nii')); % 包含真实噪声估计所需的低信号背景。
truth=single(15+60*x+2*y); % 已知光滑频率场，不占满 [-pi,pi]，跨区域而非理想常量相位。
phase=single(2*pi*.002)*truth;
niftiwrite(phase,fullfile(root,'phase.nii'));
niftiwrite(single(.2*ones(size(mag))),fullfile(root,'phase1.nii'));
niftiwrite(phase+single(.2),fullfile(root,'phase2.nii'));
niftiwrite(fieldMag*cos(.2),fullfile(root,'real1.nii'));
niftiwrite(fieldMag*sin(.2),fullfile(root,'imaginary1.nii'));
niftiwrite(fieldMag.*cos(single(.2)+phase),fullfile(root,'real2.nii'));
niftiwrite(fieldMag.*sin(single(.2)+phase),fullfile(root,'imaginary2.nii'));
niftiwrite(truth,fullfile(root,'hz.nii'));
niftiwrite(-.6*ones(size(mag),'single'),fullfile(root,'vdm.nii'));
cfg=toolkit_config; cfg.sdc.spm.matchVdm=false; cfg.sdc.spm.unwrapFwhmMm=1e-6;
cfg.sdc.spm.weightedSmoothing=false; cfg.sdc.spm.maskBrain=false;
cfg.discardVolumes=0; cfg.sliceTiming.mode='off'; cfg.sliceTiming.enabled=false;
cfg.qc.enabled=false; cfg.qc.maxResliceNonfiniteFraction=.6; cfg.stopAfter='realign';
t.TestData.cfg=cfg; t.TestData.bold=bold;
end
function teardown(t), rmdir(t.TestData.root,'s'); end
function f=fieldmap(t,type)
r=t.TestData.root;
switch type
    case 'phasediff', roles={'phasediff','magnitude'}; files={'phase.nii','mag.nii'};
    case 'phase_magnitude', roles={'phase1','magnitude1','phase2','magnitude2'}; files={'phase1.nii','mag.nii','phase2.nii','mag.nii'};
    case 'real_imaginary', roles={'real1','imaginary1','real2','imaginary2'}; files=strcat(roles,'.nii');
    case 'fieldmap_hz', roles={'fieldmap_hz'}; files={'hz.nii'};
    case 'vdm', roles={'vdm'}; files={'vdm.nii'};
end
f=struct('Type',type,'Images',struct('Role',roles,'Path',files), ...
    'EchoTime1',.004,'EchoTime2',.006,'SPMBlipDirection',-1);
if strcmp(type,'fieldmap_hz'), f.Units='Hz'; elseif strcmp(type,'vdm'), f.Units='voxel'; else, f.Units='rad'; end
json=fullfile(r,[type '.json']); fid=fopen(json,'w'); fprintf(fid,'%s',jsonencode(f)); fclose(fid);
f=psy.inspect_fieldmaps(json);
end
function [plan,run,info]=plan_for(t,type,method,cfg)
f=fieldmap(t,type);
run=struct('subject','S01','session','','name','r1','bold',t.TestData.bold, ...
    't1',fullfile(t.TestData.root,'mag.nii'),'sbref','','sdcMethod',method,'eventFormat','none','events','','ev','');
info=struct('size',[32 32 16 8],'nVolumes',8,'trSeconds',2,'durationSeconds',16, ...
    'contract',struct('fieldmaps',f,'metadata',struct('PhaseEncodingDirection','j-','TotalReadoutTime',.04)));
plan=psy.preprocess_plan(run,info,cfg);
end
function testKnownRadianAndComplexAmplitude(t)
cfg=t.TestData.cfg;
original=niftiread(fullfile(t.TestData.root,'phase.nii'));
for type={'phasediff','phase_magnitude','real_imaginary','fieldmap_hz'}
    [p,~,~]=plan_for(t,type{1},'spm_vdm_only',cfg);
    out=fullfile(t.TestData.root,type{1}); mkdir(out);
    [vdm,outputs]=psy.spm_fieldmap_vdm(p.sdc,t.TestData.bold,out,cfg);
    values=spm_read_vols(spm_vol(vdm));
    expected=-.04*double(niftiread(fullfile(t.TestData.root,'hz.nii')));
    verifyEqual(t,values(12:21,12:21,6:11),expected(12:21,12:21,6:11),'AbsTol',.005);
    verifyTrue(t,all(cellfun(@isfile,outputs)));
    job=load(fullfile(out,'01_fieldmap_calculate_vdm.mat'));
    verifyTrue(t,job.execution.preserveRadianAmplitude);
    verifyFalse(t,isfile(fullfile(out,'spm_fieldmap','reference','ureference.nii')));
end
verifyEqual(t,niftiread(fullfile(t.TestData.root,'phase.nii')),original);
end
function testImportedVdmNoAcquisitionRescaling(t)
cfg=t.TestData.cfg;
[~,run,info]=plan_for(t,'vdm','spm_fieldmap_applyvdm',cfg);
info.contract.metadata=struct('PhaseEncodingDirection','j-'); % VDM 不需要 TE/readout。
p=psy.preprocess_plan(run,info,cfg);
out=fullfile(t.TestData.root,'imported');mkdir(out);
local=psy.stage_image(t.TestData.bold,out);
result=psy.spm_motion_step(local,8,cfg,out,p.sdc);
values=spm_read_vols(spm_vol(result.vdm)); verifyEqual(t,median(values,'all'),-.6,'AbsTol',1e-6);
verifyTrue(t,isfile(result.series)); verifyTrue(t,startsWith(string(spm_file(result.vdm,'basename')),'vdm5_'));
end
function testReferenceSelections(t)
cfg=t.TestData.cfg;
[p,run,info]=plan_for(t,'phasediff','spm_vdm_only',cfg);
out=fullfile(t.TestData.root,'ref');mkdir(out); local=psy.stage_image(t.TestData.bold,out);
cfg.sdc.spm.referenceEpi='volume';cfg.sdc.spm.referenceVolume=3;
ref=psy.fieldmap_reference(p.sdc,local,out,cfg);
v=spm_vol(local); verifyEqual(t,spm_read_vols(spm_vol(ref)),spm_read_vols(v(3)),'AbsTol',1e-4);
cfg.sdc.spm.referenceEpi='mean'; ref=psy.fieldmap_reference(p.sdc,local,out,cfg);
values=spm_read_vols(spm_vol(ref)); expected=mean(spm_read_vols(v),4);
[folder,name,ext]=fileparts(local); meanHeader=spm_vol(fullfile(folder,['mean' name ext]));
% 本机 SPM 均值写出为 int16；按其量化步长核对，而不是假定无损 float 输出。
verifyEqual(t,values(8:24,8:24,4:12),expected(8:24,8:24,4:12), ...
    'AbsTol',abs(meanHeader.pinfo(1))+1e-4);
for mode={'sbref','manifest'}
    cfg.sdc.spm.referenceEpi=mode{1};
    run.sbref=fullfile(t.TestData.root,'mag.nii');run.fieldmapEpi=run.sbref;
    p=psy.preprocess_plan(run,info,cfg);
    target=fullfile(t.TestData.root,mode{1}); mkdir(target);
    ref=psy.fieldmap_reference(p.sdc,local,target,cfg);
    verifyEqual(t,spm_read_vols(spm_vol(ref)),double(niftiread(run.sbref)),'AbsTol',1e-4);
end
cfg.sdc.spm.referenceEpi='volume';cfg.sdc.spm.referenceVolume=9;
verifyError(t,@()psy.preprocess_plan(run,info,cfg),'psy:SDCReference');
end
function testReferenceQcToggleAndMatch(t)
cfg=t.TestData.cfg;cfg.sdc.spm.matchVdm=true;cfg.sdc.spm.writeReferenceEpi=true;
cfg.sdc.spm.outputPrefix='qc_';
[p,~,~]=plan_for(t,'phasediff','spm_vdm_only',cfg);
out=fullfile(t.TestData.root,'qc'); mkdir(out);
[vdm,outputs]=psy.spm_fieldmap_vdm(p.sdc,t.TestData.bold,out,cfg);
verifyTrue(t,isfile(vdm));
verifyTrue(t,isfile(fullfile(out,'spm_fieldmap','reference','qc_reference.nii')));
verifyTrue(t,all(cellfun(@isfile,outputs)));
job=load(fullfile(out,'01_fieldmap_calculate_vdm.mat'));verifyTrue(t,job.execution.effectiveMatchVdm);
end
function testDynamicUnwarpWithoutVdm(t)
cfg=t.TestData.cfg;
[~,run,info]=plan_for(t,'phasediff','spm_unwarp',cfg);
info.contract=struct('metadata',struct('PhaseEncodingDirection','j-'));
p=psy.preprocess_plan(run,info,cfg); verifyFalse(t,isfield(p.sdc,'fieldmap'));
out=fullfile(t.TestData.root,'dynamic');mkdir(out);
local=psy.stage_image(t.TestData.bold,out);
r=psy.spm_motion_step(local,8,cfg,out,p.sdc);
verifyEmpty(t,r.vdm);verifyTrue(t,isfile(r.series));verifySize(t,readmatrix(r.motion),[8 6]);
job=load(fullfile(out,'02_realign_unwarp.mat'));
verifyEmpty(t,job.matlabbatch{1}.spm.spatial.realignunwarp.data.pmscan{1});
end
function testVdmOnlyBatchAllowsEmptyT1(t)
cfg=t.TestData.cfg; fieldmap(t,'phasediff');
meta=fullfile(t.TestData.root,'meta.json'); fid=fopen(meta,'w');
fprintf(fid,'{"RepetitionTime":2,"PhaseEncodingDirection":"j-","TotalReadoutTime":0.04}');fclose(fid);
manifest=fullfile(t.TestData.root,'runs.tsv');fid=fopen(manifest,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\tmetadata\tfieldmaps\n');
for subject={'A','B'}
    fprintf(fid,'%s\t\tr1\tbold.nii\t\traw\tmeta.json\tphasediff.json\n',subject{1});
end
fclose(fid);cfg.manifestFile=manifest;cfg.sdc.method='spm_vdm_only';cfg.execute=true;
cfg.sliceTiming.mode='metadata'; % 只准备 VDM 不应要求 STC 时间表。
cfg.realign.weightImage='D:/NOT_USED_IN_VDM_ONLY/weight.nii';
cfg.outputRoot=fullfile(t.TestData.root,'batch');
report=psy.preprocess_batch(cfg);verifyEqual(t,{report.status},{'vdm_generated_only','vdm_generated_only'});
for k=1:2
    verifyTrue(t,isfile(fullfile(report(k).output,'COMPLETE.mat')));
    verifyFalse(t,isfile(fullfile(report(k).output,'02_realign.mat')));
    verifyFalse(t,isfolder(fullfile(report(k).output,'anat')));
end
report=psy.preprocess_batch(cfg);verifyTrue(t,all(strcmp({report.status},'reused_completed_run')));
end
function testAllOnlyPrefixAndPipelineGuard(t)
cfg=t.TestData.cfg;cfg.sdc.spm.resliceImages='all';cfg.sdc.spm.outputPrefix='corr_';
[p,run,info]=plan_for(t,'vdm','spm_fieldmap_applyvdm',cfg);
out=fullfile(t.TestData.root,'all');mkdir(out);local=psy.stage_image(t.TestData.bold,out);
r=psy.spm_motion_step(local,8,cfg,out,p.sdc);
verifyEmpty(t,r.mean);verifyTrue(t,isfile(fullfile(out,'corr_bold.nii')));
verifyFalse(t,isfile(fullfile(out,'meancorr_bold.nii')));
cfg.stopAfter='smooth';verifyError(t,@()psy.preprocess_plan(run,info,cfg),'psy:SDCOutputChoice');
cfg.stopAfter='realign';cfg.sdc.spm.outputPrefix='../bad';
verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:PreprocessConfig');
end
function testExtendedSchemaAndDirectionGuards(t)
f=fieldmap(t,'vdm'); f.Units='Hz';
json=fullfile(t.TestData.root,'bad.json');fid=fopen(json,'w');fprintf(fid,'%s',jsonencode(f));fclose(fid);
verifyError(t,@()psy.inspect_fieldmaps(json),'psy:FieldmapSchema');
f=fieldmap(t,'phase_magnitude');
niftiwrite(4096*ones(32,32,16,'single'),fullfile(t.TestData.root,'phase1.nii'));
fid=fopen(json,'w');fprintf(fid,'%s',jsonencode(f));fclose(fid);
verifyError(t,@()psy.inspect_fieldmaps(json),'psy:PhaseUnits');
cfg=t.TestData.cfg;cfg.sdc.spm.distortionAxis='i';
[~,run,info]=plan_for(t,'phasediff','spm_fieldmap_applyvdm',t.TestData.cfg);
verifyError(t,@()psy.preprocess_plan(run,info,cfg),'psy:SPMDistortionAxis');
cfg=t.TestData.cfg;cfg.sdc.spm.referenceEpi='bad';
verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:PreprocessConfig');
end
function testImportedVdmWithDynamicUnwarp(t)
cfg=t.TestData.cfg;
[~,run,info]=plan_for(t,'vdm','spm_fieldmap_unwarp',cfg);
info.contract.metadata=struct('PhaseEncodingDirection','j-');
p=psy.preprocess_plan(run,info,cfg);
out=fullfile(t.TestData.root,'import_unwarp');mkdir(out);
local=psy.stage_image(t.TestData.bold,out);
r=psy.spm_motion_step(local,8,cfg,out,p.sdc);
verifyTrue(t,isfile(r.vdm));verifyTrue(t,isfile(r.series));
verifyTrue(t,all(isfinite(readmatrix(r.motion)),'all'));
end
function testMagnitudeFrameSelection(t)
cfg=t.TestData.cfg;cfg.sdc.spm.magnitudeVolume=2;
f=fieldmap(t,'phasediff'); mag=niftiread(fullfile(t.TestData.root,'mag.nii'));
dual=fullfile(t.TestData.root,'dual_magnitude.nii');niftiwrite(cat(4,2*mag,mag),dual);
f.Images(2).Path=dual;
info=struct('size',[32 32 16 8],'nVolumes',8,'trSeconds',2,'durationSeconds',16, ...
    'contract',struct('fieldmaps',f,'metadata',struct('PhaseEncodingDirection','j-','TotalReadoutTime',.04)));
run=struct('subject','S01','session','','name','r1','bold',t.TestData.bold,'sdcMethod','spm_vdm_only');
p=psy.preprocess_plan(run,info,cfg);
out=fullfile(t.TestData.root,'frame2');mkdir(out);
vdm=psy.spm_fieldmap_vdm(p.sdc,t.TestData.bold,out,cfg);verifyTrue(t,isfile(vdm));
job=load(fullfile(out,'01_fieldmap_calculate_vdm.mat'));
verifyTrue(t,endsWith(job.matlabbatch{1}.spm.tools.fieldmap.calculatevdm.subj.data.presubphasemag.magnitude{1},',2'));
end
function testAllOnlyThroughBatch(t)
cfg=t.TestData.cfg;fieldmap(t,'vdm');
meta=fullfile(t.TestData.root,'meta.json');fid=fopen(meta,'w');
fprintf(fid,'{"RepetitionTime":2,"PhaseEncodingDirection":"j-"}');fclose(fid);
manifest=fullfile(t.TestData.root,'all.tsv');fid=fopen(manifest,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\tmetadata\tfieldmaps\n');
fprintf(fid,'A\t\tr1\tbold.nii\tmag.nii\traw\tmeta.json\tvdm.json\n');fclose(fid);
cfg.manifestFile=manifest;cfg.outputRoot=fullfile(t.TestData.root,'all_batch');cfg.execute=true;
cfg.sdc.method='spm_fieldmap_applyvdm';cfg.sdc.spm.resliceImages='all';cfg.sdc.spm.outputPrefix='corr_';
cfg.qc.enabled=true;
r=psy.preprocess_batch(cfg);verifyEqual(t,r.status,'realigned_after_spm_fieldmap_applyvdm');
verifyTrue(t,isfile(fullfile(r.output,'COMPLETE.mat')));
verifyTrue(t,isfile(fullfile(r.output,'TIMESERIES_QC_SKIPPED.mat')));
verifyFalse(t,isfolder(fullfile(r.output,'timeseries_qc')));
end
