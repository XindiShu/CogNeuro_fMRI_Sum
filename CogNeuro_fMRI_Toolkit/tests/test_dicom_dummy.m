function tests=test_dicom_dummy
tests=functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.oldPath=path;
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
end

function teardownOnce(t)
path(t.TestData.oldPath);
end

function setup(t)
root=tempname; mkdir(root); t.TestData.root=root;
end

function teardown(t)
rmdir(t.TestData.root,'s');
end

function testDummyTimeReferenceAndPerRunOverride(t)
cfg=toolkit_config; cfg.discardVolumes=1;
cfg.dummy.eventReference='original_first_volume';
run=struct('discardVolumes',2,'eventReference','', ...
    'events','events.tsv','eventFormat','none');
info=struct('nVolumes',6,'trSeconds',2,'durationSeconds',12, ...
    'contract',struct('events',struct('onsetSeconds',[0;5])));
p=psy.dummy_plan(run,info,cfg);
verifyEqual(t,p.retainedVolumes,4);
verifyEqual(t,p.eventShiftSeconds,4);
run.eventReference='retained_first_volume';
p=psy.dummy_plan(run,info,cfg);
verifyEqual(t,p.eventShiftSeconds,0);
cfg.dummy.eventReference='unspecified'; run.eventReference='';
verifyError(t,@()psy.dummy_plan(run,info,cfg),'psy:DummyEventReference');
end

function testTrimPreservesOriginalAndTr(t)
root=t.TestData.root; source=fullfile(root,'source.nii');
volumes=cell(5,1);
for k=1:5
    volumes{k}=fullfile(root,sprintf('frame%02d.nii',k));
    niftiwrite(single(k*ones(4,4,4)),volumes{k});
end
spm_file_merge(spm_vol(char(volumes)),source,0,2);
before=dir(source);
trimmed=psy.trim_dummy_bold(source,2,2,fullfile(root,'work'),5);
v=spm_vol(trimmed); after=dir(source);
verifyEqual(t,numel(v),3);
h=niftiinfo(trimmed); verifyEqual(t,h.PixelDimensions(4),2);
verifyEqual(t,mean(spm_read_vols(v(1)),'all'),3,'AbsTol',1e-6);
verifyEqual(t,[after.bytes after.datenum],[before.bytes before.datenum]);
end

function testShiftedEventsWrittenWithoutChangingSource(t)
root=t.TestData.root; source=fullfile(root,'events.tsv');
fid=fopen(source,'w'); fprintf(fid,'onset\tduration\ttrial_type\n0\t1\tA\n5\t1\tB\n'); fclose(fid);
run=struct('events',source,'eventFormat','none');
plan=struct('count',2,'eventShiftSeconds',4);
copy=psy.write_dummy_events(run,plan,fullfile(root,'output'));
verifyTrue(t,isfile(copy));
verifyTrue(t,contains(fileread(source),sprintf('0\t1\tA')));
e=psy.read_events_tsv(copy,8);
verifyEqual(t,e.onsetSeconds,[-4;1]);
end

function testDicomDirectoryMustBeEnabledAndNonempty(t)
root=t.TestData.root; mkdir(fullfile(root,'series'));
fid=fopen(fullfile(root,'t1.nii'),'w'); fclose(fid);
fid=fopen(fullfile(root,'runs.tsv'),'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\nS01\t\ttask\tseries\tt1.nii\traw\n'); fclose(fid);
cfg=toolkit_config; cfg.manifestFile=fullfile(root,'runs.tsv');
verifyError(t,@()psy.read_manifest(cfg),'psy:MissingImage');
cfg.dicom.enabled=true;
r=psy.read_manifest(cfg);
verifyTrue(t,isfolder(r.bold));
verifyError(t,@()psy.inspect_dicom_inventory(r),'psy:DICOMEmpty');
end

function testSpmDicomImportAndReuse(t)
% 合成小型 MR DICOM；验证 SPM batch 接线、4D 合并、TR 与完成标记。
assumeNotEmpty(t,which('dicomwrite'));
spm('defaults','fmri'); spm_jobman('initcfg');
root=t.TestData.root; source=fullfile(root,'dicom'); mkdir(source);
seriesUid=dicomuid; studyUid=dicomuid;
for frame=1:3
    for slice=1:2
        meta=struct('Modality','MR','SOPClassUID','1.2.840.10008.5.1.4.1.1.4', ...
            'SeriesInstanceUID',seriesUid,'StudyInstanceUID',studyUid, ...
            'PatientID','TEST01','SeriesNumber',1,'AcquisitionNumber',frame, ...
            'InstanceNumber',(frame-1)*2+slice, ...
            'ImagePositionPatient',[0;0;2*slice], ...
            'ImageOrientationPatient',[1;0;0;0;1;0], ...
            'PixelSpacing',[2;2],'SliceThickness',2,'RepetitionTime',2000);
        dicomwrite(uint16((frame*10+slice)*ones(8,8)), ...
            fullfile(source,sprintf('frame%d_slice%d.dcm',frame,slice)),meta,'CreateMode','Create');
    end
end
outDir=fullfile(root,'converted');
image=psy.import_dicom_series(source,outDir,'bold',2);
volumes=spm_vol(image); verifyEqual(t,numel(volumes),3);
means=arrayfun(@(v)mean(spm_read_vols(v),'all'),volumes);
verifyEqual(t,means(:)',[11.5 21.5 31.5],'AbsTol',1e-6);
h=niftiinfo(image); verifyEqual(t,h.PixelDimensions(4),2);
verifyTrue(t,isfile(fullfile(outDir,'DICOM_IMPORT_COMPLETE.mat')));
verifyEqual(t,psy.import_dicom_series(source,outDir,'bold',2),image);
end

function testNonzeroDummyThroughBatchRealign(t)
% 真实调用 SPM Realign，核查 6→4 帧、完成标记及事件副本。
root=t.TestData.root;
[x,y,z]=ndgrid(1:32,1:32,1:16);
base=single(1000*exp(-((x-16).^2+(y-16).^2+(z-8).^2)/70)+10);
frames=cell(6,1);
for k=1:6
    frames{k}=fullfile(root,sprintf('frame%d.nii',k));
    niftiwrite(base+single(k),frames{k});
end
bold=fullfile(root,'bold.nii');
spm_file_merge(spm_vol(char(frames)),bold,0,2);
t1=fullfile(root,'t1.nii'); niftiwrite(base,t1);
events=fullfile(root,'events.tsv');
fid=fopen(events,'w');
fprintf(fid,'onset\tduration\ttrial_type\n0\t1\tA\n8\t1\tB\n'); fclose(fid);
manifest=fullfile(root,'runs.tsv');
fid=fopen(manifest,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\tevents\n');
fprintf(fid,'S01\t\tlang\t%s\t%s\traw\t%s\n',bold,t1,events); fclose(fid);
cfg=toolkit_config; cfg.manifestFile=manifest;
cfg.outputRoot=fullfile(root,'output'); cfg.execute=true;
cfg.stopAfter='realign'; cfg.qc.enabled=false;
cfg.discardVolumes=2; cfg.dummy.eventReference='original_first_volume';
spm('defaults','fmri'); spm_jobman('initcfg');
result=psy.preprocess_batch(cfg);
verifyEqual(t,result.status,'realigned_without_distortion_correction');
out=psy.run_output_dir(cfg.outputRoot,struct('subject','S01','session','','name','lang'));
verifyTrue(t,isfile(fullfile(out,'COMPLETE.mat')));
verifyEqual(t,numel(spm_vol(bold)),6);
verifyEqual(t,numel(spm_vol(fullfile(out,'dummy_trim','bold_retained.nii'))),4);
shifted=psy.read_events_tsv(fullfile(out,'dummy_trim','events_retained_first_volume.tsv'),8);
verifyEqual(t,shifted.onsetSeconds,[-4;4]);
end
