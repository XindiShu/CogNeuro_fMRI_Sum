function tests=test_segmentation_interfaces
% 原生菜单接线、4D volume、多个被试清单、原文件保护与图谱方向的工程验证。
tests=functiontests(localfunctions);
end
function setup(t)
folder=tempname;mkdir(folder);t.TestData.folder=folder;
[x,y,z]=ndgrid(1:16,1:16,1:12);image=single(x+y+z);
t1=fullfile(folder,'t1.nii');write_image(t1,image,eye(4));
t.TestData.run=struct('t1',t1,'anatomyChannels','','atlases','');
t.TestData.cfg=toolkit_config;t.TestData.cfg.stopAfter='segment';
end
function teardown(t)
rmdir(t.TestData.folder,'s');
end
function testNativeMenuFlags(t)
for kind={'bias','native','warped'}
    switch kind{1}
        case 'bias',choices={'none','field','corrected','both'};
        case 'native',choices={'none','native','dartel','native_dartel'};
        case 'warped',choices={'none','unmodulated','modulated','both'};
    end
    expected={[0 0],[1 0],[0 1],[1 1]};
    for k=1:4,verifyEqual(t,psy.segment_output_flags(kind{1},choices{k}),expected{k});end
    verifyError(t,@()psy.segment_output_flags(kind{1},'wrong'),'psy:SegmentOutput');
end
end
function testDefaultAndAllRequestedBatchFields(t)
cfg=t.TestData.cfg;run=t.TestData.run;
p=psy.segment_plan(run,cfg);out=fullfile(t.TestData.folder,'default');
files=psy.stage_anatomy(p,cfg,out);[b,expected]=psy.spm_segment_batch(files,p,cfg);
verifyEqual(t,b{1}.spm.spatial.preproc.channel.write,[0 1]);
verifyEqual(t,b{1}.spm.spatial.preproc.tissue(1).native,[1 0]);
verifyEqual(t,b{1}.spm.spatial.preproc.warp.fwhm,0);
verifyEqual(t,numel(expected),6); % seg8, mT1, c1-3, y
cfg.segment.saveBias='both';cfg.segment.nativeOutputs=repmat({'native_dartel'},1,6);
cfg.segment.warpedOutputs=repmat({'both'},1,6);cfg.segment.smoothnessMm=1;
cfg.segment.deformationFields='inverse_forward';p=psy.segment_plan(run,cfg);
[b,expected]=psy.spm_segment_batch(files,p,cfg);
verifyEqual(t,b{1}.spm.spatial.preproc.channel.write,[1 1]);
verifyEqual(t,b{1}.spm.spatial.preproc.tissue(6).native,[1 1]);
verifyEqual(t,b{1}.spm.spatial.preproc.tissue(6).warped,[1 1]);
verifyEqual(t,b{1}.spm.spatial.preproc.warp.write,[1 1]);
verifyEqual(t,b{1}.spm.spatial.preproc.warp.fwhm,1);
verifyEqual(t,numel(expected),29); % seg8, two bias,24 tissue,2 fields
end
function testMultichannelContractAndAlignment(t)
cfg=t.TestData.cfg;run=t.TestData.run;folder=t.TestData.folder;
t2=fullfile(folder,'t2.nii');v=spm_vol(run.t1);write_image(t2,100-spm_read_vols(v),v.mat);
file=fullfile(folder,'channels.json');
j=struct('Channels',struct('Name',{'T1','T2'},'Path',{'t1.nii','t2.nii'},'Volume',{1,1},'SaveBias',{'none','both'}));
write_json(file,j);run.anatomyChannels=file;p=psy.segment_plan(run,cfg);
verifyEqual(t,numel(p.channels),2);verifyEqual(t,p.channels(2).SaveBias,'both');
out=fullfile(folder,'multi');files=psy.stage_anatomy(p,cfg,out);[b,~]=psy.spm_segment_batch(files,p,cfg);
verifyEqual(t,b{1}.spm.spatial.preproc.channel(1).write,[0 0]);
verifyEqual(t,b{1}.spm.spatial.preproc.channel(2).write,[1 1]);
cfg.segment.backend='cat12';verifyError(t,@()psy.segment_plan(run,cfg),'psy:CATChannels');
cfg.segment.backend='spm';v.mat(1,4)=8;write_image(t2,100-spm_read_vols(v),v.mat);
verifyError(t,@()psy.segment_plan(run,cfg),'psy:AnatomyAlignment');
cfg.segment.channelAlignment='coregister_reslice';p=psy.segment_plan(run,cfg);verifyEqual(t,numel(p.channels),2);
end
function testVolumeSelectionAndSourceHash(t)
cfg=t.TestData.cfg;run=t.TestData.run;folder=t.TestData.folder;
v=spm_vol(run.t1);x=spm_read_vols(v);n=nifti;
n.dat=file_array(fullfile(folder,'container.nii'),[v.dim 2],'FLOAT32-LE',0,1,0);n.mat=v.mat;n.mat0=v.mat;create(n);
n.dat(:,:,:,1)=single(x);n.dat(:,:,:,2)=single(x+100);
run.t1=fullfile(folder,'container.nii');cfg.segment.inputVolume=2;
before=psy.file_sha256(run.t1);p=psy.segment_plan(run,cfg);
files=psy.stage_anatomy(p,cfg,fullfile(folder,'volume'));
verifyEqual(t,numel(spm_vol(files{1})),1);verifyEqual(t,spm_read_vols(spm_vol(files{1})),x+100);
verifyEqual(t,psy.file_sha256(run.t1),before);
cfg.segment.inputVolume=3;verifyError(t,@()psy.segment_plan(run,cfg),'psy:AnatomyVolume');
write_image(run.t1,x,v.mat);
verifyError(t,@()psy.stage_anatomy(p,cfg,fullfile(folder,'changed')),'psy:AnatomyChanged');
end
function testAtlasInverseAndSpaceGuards(t)
cfg=t.TestData.cfg;run=t.TestData.run;folder=t.TestData.folder;
v=spm_vol(run.t1);file=fullfile(folder,'labels.nii');write_image(file,double(spm_read_vols(v)>20),v.mat);
j=struct('Atlases',struct('Name','ROI','Path','labels.nii','Kind','labels','Space','spm_tpm_mni'));
json=fullfile(folder,'atlases.json');write_json(json,j);run.atlases=json;
cfg.atlas.enabled=true;p=psy.segment_plan(run,cfg);verifyEqual(t,p.deformationFlags,[1 1]);
cfg.atlas.ensureInverse=false;verifyError(t,@()psy.segment_plan(run,cfg),'psy:AtlasInverse');
cfg.segment.deformationFields='inverse_forward';psy.segment_plan(run,cfg);
j.Atlases.Space='cat12_mni2009c';write_json(json,j);
verifyError(t,@()psy.segment_plan(run,cfg),'psy:AtlasSpace');
end
function testActualInversePullPreservesGridDirectionAndLabels(t)
cfg=t.TestData.cfg;cfg.atlas.enabled=true;cfg.segment.deformationFields='inverse_forward';
run=t.TestData.run;folder=t.TestData.folder;ref=spm_vol(run.t1);
[x,y,z]=ndgrid(1:ref.dim(1),1:ref.dim(2),1:ref.dim(3));
labels=single(10*(x>=5 & x<=7)+20*(x>=10 & x<=12));
atlas=fullfile(folder,'labels.nii');write_image(atlas,labels,ref.mat);
json=fullfile(folder,'atlases.json');write_json(json,struct('Atlases', ...
    struct('Name','ROI','Path',atlas,'Kind','labels','Space','spm_tpm_mni')));
run.atlases=json;p=psy.segment_plan(run,cfg);
inverse=fullfile(folder,'iy_test.nii');n=nifti;
n.dat=file_array(inverse,[ref.dim 1 3],'FLOAT32-LE',0,1,0);n.mat=ref.mat;n.mat0=ref.mat;create(n);
n.dat(:,:,:,1,1)=single(x+2);n.dat(:,:,:,1,2)=single(y);n.dat(:,:,:,1,3)=single(z);
before=psy.file_sha256(atlas);outputs=psy.apply_atlases(p,inverse,run.t1,fullfile(folder,'out'));
verifyTrue(t,all(cellfun(@isfile,outputs)));
dest=fullfile(folder,'out','atlases','ROI','native_labels.nii');result=spm_read_vols(spm_vol(dest));
verifyEqual(t,result(2:12,2:15,2:11),double(labels(4:14,2:15,2:11)));
verifyEqual(t,psy.file_sha256(atlas),before);verifyEqual(t,unique(result),[0;10;20]);
end
function testExtendedManifestManySubjects(t)
folder=t.TestData.folder;file=fullfile(folder,'runs.tsv');fid=fopen(file,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\tanatomy_channels\tatlases\n');
bold=fullfile(folder,'bold.nii');write_image(bold,ones(16,16,12,3,'single'),eye(4));
for k=1:24
    for r=1:2,fprintf(fid,'S%02d\t\tr%d\t%s\t%s\traw\t\t\n',k,r,bold,t.TestData.run.t1);end
end
fclose(fid);cfg=t.TestData.cfg;cfg.manifestFile=file;
runs=psy.read_manifest(cfg);verifyEqual(t,numel(runs),48);verifyEmpty(t,runs(48).anatomyChannels);
end
function testRejectUnsupportedMenus(t)
cfg=t.TestData.cfg;cfg.segment.nativeOutputs={'native'};
verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:SegmentConfig');
cfg=t.TestData.cfg;cfg.segment.smoothnessMm=-1;
verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:SegmentConfig');
cfg=t.TestData.cfg;cfg.atlas.enabled=true;cfg.atlas.target='bold';
verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:AtlasConfig');
end
function testHashPreservesAllByteValues(t)
file=fullfile(t.TestData.folder,'bytes.bin');fid=fopen(file,'wb');fwrite(fid,uint8(0:255),'uint8');fclose(fid);
verifyEqual(t,psy.file_sha256(file),'40aff2e9d2d8922e47afd4648e6967497158785fbd1da870e7110266bf944880');
end
function testProbabilityAndDifferentTargetGrid(t)
cfg=t.TestData.cfg;cfg.atlas.enabled=true;cfg.segment.deformationFields='inverse_forward';
run=t.TestData.run;folder=t.TestData.folder;ref=spm_vol(run.t1);
[x,y,z]=ndgrid(1:ref.dim(1),1:ref.dim(2),1:ref.dim(3));
file=fullfile(folder,'probability.nii');write_image(file,single(x/16),ref.mat);
labels=fullfile(folder,'labels.nii');write_image(labels,single(7*(x>=8)),ref.mat);
j=struct('Atlases',struct('Name',{'Probability','Labels'},'Path',{file,labels}, ...
    'Kind',{'probability','labels'},'Space',{'spm_tpm_mni','spm_tpm_mni'}));
run.atlases=fullfile(folder,'atlases.json');write_json(run.atlases,j);p=psy.segment_plan(run,cfg);
inverse=fullfile(folder,'iy_identity.nii');n=nifti;
n.dat=file_array(inverse,[ref.dim 1 3],'FLOAT32-LE',0,1,0);n.mat=ref.mat;n.mat0=ref.mat;create(n);
n.dat(:,:,:,1,1)=single(x);n.dat(:,:,:,1,2)=single(y);n.dat(:,:,:,1,3)=single(z);
target=fullfile(folder,'mean_epi.nii');mat=eye(4);mat(1:3,1:3)=2*eye(3);mat(1:3,4)=[0;0;0];
write_image(target,ones(7,7,5),mat);
outputs=psy.apply_atlases(p,inverse,target,fullfile(folder,'probout'));verifyEqual(t,numel(outputs),10);
result=spm_read_vols(spm_vol(fullfile(folder,'probout','atlases','Probability','native_probability.nii')));
verifyEqual(t,squeeze(result(:,3,3)),(2:2:14)'/16,'AbsTol',1e-6);
end
function write_image(file,x,mat)
if ndims(x)==4
    n=nifti;n.dat=file_array(file,size(x),'FLOAT32-LE',0,1,0);n.mat=mat;n.mat0=mat;create(n);n.dat(:,:,:,:)=x;
else
    v=struct('fname',file,'dim',size(x),'dt',[16 0],'mat',mat,'pinfo',[1;0;0]);spm_write_vol(v,x);
end
end
function write_json(file,j)
fid=fopen(file,'w');fprintf(fid,'%s',jsonencode(j));fclose(fid);
end
