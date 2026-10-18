function tests=test_smoothing_interfaces
% 真正调用SPM的类型/隐式掩模/三轴卷积与原生写出，检查时间、网格和源文件保护。
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
addpath(fullfile(spm('Dir'),'toolbox','DARTEL'),fullfile(spm('Dir'),'toolbox','Shoot'));
spm('defaults','fmri');spm_jobman('initcfg');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
t.TestData.folder=tempname;mkdir(t.TestData.folder);
t.TestData.cfg=toolkit_config;
end
function teardown(t)
rmdir(t.TestData.folder,'s');
end
function testLegacyAndAllMenus(t)
cfg=t.TestData.cfg;if isfield(cfg,'smooth'),cfg=rmfield(cfg,'smooth');end
s=psy.smooth_options(cfg);verifyEqual(t,s.dataType,'same');verifyFalse(t,s.implicitMasking);verifyEqual(t,s.prefix,'s');
names={'same','uint8','int16','int32','float32','float64'};codes=[0 2 4 8 16 64];
for k=1:numel(names)
    cfg.smooth.dataType=names{k};s=psy.smooth_options(cfg);verifyEqual(t,s.dtypeCode,codes(k));
end
cfg.smooth.dataType="FLOAT32";cfg.smooth.prefix="sm6_";cfg.smooth.implicitMasking=true;
s=psy.smooth_options(cfg);verifyEqual(t,s.dataType,'float32');verifyEqual(t,s.prefix,'sm6_');verifyTrue(t,s.implicitMasking);
end
function testBadInputsAndNativeRestrictions(t)
cfg=t.TestData.cfg;
for prefix={'','../s','a/b','a\b','0s','s.nii'}
    c=cfg;c.smooth.prefix=prefix{1};verifyError(t,@()psy.smooth_options(c),'psy:SmoothConfig');
end
for value={-1,NaN,Inf,'yes',[0 1]}
    c=cfg;c.smooth.implicitMasking=value{1};verifyError(t,@()psy.smooth_options(c),'psy:SmoothConfig');
end
for value={'double','unknown',16,{ 'same' }}
    c=cfg;c.smooth.dataType=value{1};verifyError(t,@()psy.smooth_options(c),'psy:SmoothConfig');
end
for value={6,[6;6;6],[-1 2 3],[NaN 2 3],[Inf 2 3],[1 2 3i]}
    c=cfg;c.smoothingFwhmMm=value{1};verifyError(t,@()psy.smooth_options(c),'psy:SmoothConfig');
end
for method={'dartel','shooting'}
    c=cfg;c.normalise.method=method{1};c.normalise.group.writeMethod='native';
    c.smooth.prefix='custom_';psy.smooth_options(c);
    c.smooth.dataType='float32';verifyError(t,@()psy.validate_preprocess_config(c),'psy:SmoothNativeOptions');
    c.smooth.dataType='same';c.smooth.implicitMasking=true;verifyError(t,@()psy.validate_preprocess_config(c),'psy:SmoothNativeOptions');
    c.smooth.implicitMasking=false;c.smoothingFwhmMm=[6 6 4];verifyError(t,@()psy.smooth_options(c),'psy:NormaliseNativeSmoothing');
    c.normalise.group.writeMethod='deformations';c.smooth.dataType='float64';c.smooth.implicitMasking=true;
    psy.validate_preprocess_config(c);
end
end
function testActualAnisotropicKernelAndAllFrames(t)
cfg=t.TestData.cfg;folder=t.TestData.folder;data=zeros(21,21,21,2,'single');
data(11,11,11,1)=1000;data(11,11,11,2)=2000;
series=fullfile(folder,'input.nii');mat=diag([2 2 2 1]);write4d(series,data,mat,1.5,16);
before=psy.file_sha256(series);cfg.smooth=struct('dataType','float32','implicitMasking',false,'prefix','aniso_');
cfg.smoothingFwhmMm=[6 6 2];[file,r]=psy.smooth_run(series,cfg,fullfile(folder,'smooth_job.mat'));
v=spm_vol(file);a=spm_read_vols(v(1));b=spm_read_vols(v(2));
h=nifti(file);verifyEqual(t,numel(v),2);verifyEqual(t,h.timing.tspace,1.5);verifyEqual(t,v(1).mat,mat);
verifyEqual(t,r.effectiveDataTypeCode,16);verifyEqual(t,b,2*a,'AbsTol',1e-5);
distance=-10:10;wx=squeeze(a(:,11,11))';wz=squeeze(a(11,11,:))';
varianceX=sum(distance.^2.*wx)/sum(wx);varianceZ=sum(distance.^2.*wz)/sum(wz);
verifyGreaterThan(t,varianceX,2*varianceZ); % 实际核沿x更宽，而非仅检查batch字段。
verifyEqual(t,psy.file_sha256(series),before);verifyTrue(t,endsWith(file,'aniso_input.nii'));
end
function testActualDataTypesAndZeroKernel(t)
cfg=t.TestData.cfg;folder=t.TestData.folder;[x,y,z]=ndgrid(1:9,1:9,1:9);
series=fullfile(folder,'types.nii');write4d(series,cat(4,x+y+z+.25,10*(x+y+z)+.75),eye(4),2,16);
input=spm_vol(series);reference=spm_read_vols(input);
names={'same','uint8','int16','int32','float32','float64'};codes=[16 2 4 8 16 64];
before=psy.file_sha256(series);cfg.smoothingFwhmMm=[0 0 0];
for k=1:numel(names)
    cfg.smooth=struct('dataType',names{k},'implicitMasking',false,'prefix',[names{k} '_']);
    [file,r]=psy.smooth_run(series,cfg,fullfile(folder,[names{k} '_job.mat']));
    verifyEqual(t,r.effectiveDataTypeCode,codes(k));verifyEqual(t,r.nVolumes,2);
    v=spm_vol(file);a=spm_read_vols(v);verifyTrue(t,all(isfinite(a(:))));verifyGreaterThan(t,max(a(:)),min(a(:)));
    tolerance=1e-5;
    if ismember(names{k},{'uint8','int16','int32'})
        % 量化步长，加NIfTI-1浮点缩放头的相对精度；INT32步长可能小于头部精度。
        tolerance=1.1*v(1).pinfo(1)+eps('single')*max(abs(reference(:)));verifyTrue(t,r.integer4dMerge);
        verifyTrue(t,isfile(r.mergeJob));
    end
    verifyLessThanOrEqual(t,max(abs(a(:)-reference(:))),tolerance); % 防止仅检查类型却漏过跨帧scale错误。
end
verifyEqual(t,psy.file_sha256(series),before);
end
function testSameInteger4DAndImplicitZeroMask(t)
cfg=t.TestData.cfg;folder=t.TestData.folder;data=100*ones(11,11,11,2);data(:,:,:,2)=1000;
data(1,:,:,:)=0;series=fullfile(folder,'int_input.nii');write4d(series,data,eye(4),1.25,4);
before=psy.file_sha256(series);cfg.smooth=struct('dataType','same','implicitMasking',true,'prefix','integer_');
cfg.smoothingFwhmMm=[2 2 2];[file,r]=psy.smooth_run(series,cfg,fullfile(folder,'integer_job.mat'));
verifyEqual(t,r.effectiveDataTypeCode,4);verifyTrue(t,r.integer4dMerge);v=spm_vol(file);a=spm_read_vols(v);
verifyEqual(t,a(1,:,:,:),zeros(size(a(1,:,:,:))));
% a2-10*a1 的量化误差界约为(1+10)/2个步长，不能只给2个步长。
verifyLessThan(t,abs(a(6,6,6,2)-10*a(6,6,6,1)),6*v(1).pinfo(1));
verifyLessThan(t,max(abs(squeeze(a(6,6,6,:))-[100;1000])),v(1).pinfo(1)+1e-4);
verifyEqual(t,r.trSeconds,1.25);verifyEqual(t,psy.file_sha256(series),before);
end
function testActualImplicitMaskingPreservesNaNButNotFloatZero(t)
cfg=t.TestData.cfg;folder=t.TestData.folder;data=100*ones(13,13,13,2,'single');
data(1,:,:,:)=NaN;data(7,7,7,:)=0;
series=fullfile(folder,'nan_input.nii');write4d(series,data,eye(4),.8,16);
before=psy.file_sha256(series);cfg.smoothingFwhmMm=[2 2 2];
cfg.smooth=struct('dataType','float32','implicitMasking',true,'prefix','masked_');
[file,r]=psy.smooth_run(series,cfg,fullfile(folder,'mask_job.mat'));
v=spm_vol(file);a=spm_read_vols(v(1));verifyTrue(t,all(isnan(a(1,:,:)),'all'));
verifyGreaterThan(t,a(7,7,7),0);verifyTrue(t,r.effectiveImplicitMasking);
cfg.smooth.implicitMasking=false;cfg.smooth.prefix='unmasked_';
file=psy.smooth_run(series,cfg,fullfile(folder,'unmask_job.mat'));v=spm_vol(file);a=spm_read_vols(v(1));
verifyTrue(t,all(isfinite(a(1,:,:)),'all'));verifyEqual(t,psy.file_sha256(series),before);
end
function testBothNativeWritersCustomPrefixesAndZeroKernel(t)
[cfg,ctx,series,meanImage]=native_fixture(t);folder=t.TestData.folder;before=psy.file_sha256(series);
for method={'dartel','shooting'}
    cfg.normalise.method=method{1};cfg.normalise.group.writeMethod='native';
    for preserve=0:1
        cfg.normalise.group.preserve=preserve;cfg.smooth=struct('dataType','same','implicitMasking',false,'prefix',sprintf('%s%d_',method{1},preserve));
        cfg.smoothingFwhmMm=[2 2 2];if preserve==1,cfg.smoothingFwhmMm=[0 0 0];end
        ctx.options=psy.normalise_options(cfg);ctx.anatomy.registrationField=ctx.fields.(method{1});
        out=fullfile(folder,sprintf('%s_%d',method{1},preserve));mkdir(out);
        files=psy.group_normalise_write(ctx,cfg,out,series,meanImage,3);saved=load(files{end});r=saved.record;
        [~,stem]=fileparts(r.normalized);[~,smoothedStem]=fileparts(r.smoothed);
        verifyEqual(t,smoothedStem,[cfg.smooth.prefix stem]);verifyTrue(t,all(cellfun(@isfile,files)));
        verifyEqual(t,r.smoothing.effectiveImplicitMasking,[]);verifyEqual(t,r.smoothing.maskingImplementation,'native_weighted_writer');
        verifyEqual(t,r.smoothing.nVolumes,3);verifyEqual(t,r.smoothing.trSeconds,2);
        marker=load(fullfile(out,'SMOOTHING_COMPLETE.mat'));verifyEqual(t,marker.record.output,r.smoothed);
        if preserve==1,verifyEqual(t,psy.file_sha256(r.normalized),psy.file_sha256(r.smoothed));end
        verifyFalse(t,isfile(fullfile(folder,['s' stem '.nii']))); % 默认临时命名已移走。
    end
end
verifyEqual(t,psy.file_sha256(series),before);
end
function testBothDeformationWritersExposeMenus(t)
[cfg,ctx,series,meanImage]=native_fixture(t);folder=t.TestData.folder;before=psy.file_sha256(series);
cfg.normalise.group.writeMethod='deformations';cfg.smoothingFwhmMm=[2 4 6];
for method={'dartel','shooting'}
    cfg.normalise.method=method{1};cfg.smooth=struct('dataType','float64','implicitMasking',true,'prefix',[method{1} '_deform_']);
    ctx.options=psy.normalise_options(cfg);out=fullfile(folder,[method{1} '_deform']);mkdir(out);
    files=psy.group_normalise_write(ctx,cfg,out,series,meanImage,3);saved=load(files{end});r=saved.record;
    verifyEqual(t,r.smoothing.effectiveDataTypeCode,64);verifyTrue(t,r.smoothing.effectiveImplicitMasking);
    verifyEqual(t,r.smoothing.fwhmMm,[2 4 6]);verifyEqual(t,r.nVolumes,3);verifyEqual(t,r.trSeconds,2);
end
verifyEqual(t,psy.file_sha256(series),before);
end
function testLegacyLayoutQCUsesRecordedPrefixAndImplicitMask(t)
cfg=t.TestData.cfg;folder=t.TestData.folder;[x,y,z]=ndgrid(1:13,1:13,1:13);
data=single(100+x+y+z);data(1,:,:)=NaN;
normalized=fullfile(folder,'wbold.nii');write4d(normalized,cat(4,data,data+1),eye(4),2,16);
cfg.voxelSizeMm=[1 1 1];cfg.smoothingFwhmMm=[2 2 2];
cfg.smooth=struct('dataType','float32','implicitMasking',true,'prefix','qc_custom_');
[~,record]=psy.smooth_run(normalized,cfg,fullfile(folder,'06_smooth.mat'));
save(fullfile(folder,'SMOOTHING_COMPLETE.mat'),'record');
info=struct('nVolumes',4);plan=struct('dummy',struct('retainedVolumes',2));
save(fullfile(folder,'input_info.mat'),'cfg','info','plan');
mkdir(fullfile(folder,'anat'));write4d(fullfile(folder,'anat','c1T1.nii'),single(x/30),eye(4),2,16);
write4d(fullfile(folder,'anat','c2T1.nii'),single(y/30),eye(4),2,16);
finiteData=data;finiteData(~isfinite(finiteData))=0;
write4d(fullfile(folder,'meanbold.nii'),finiteData,eye(4),2,16);
write4d(fullfile(folder,'wmeanbold.nii'),finiteData,eye(4),2,16);
qc=psy.verify_spatial(folder);verifyEqual(t,qc.nVolumes,2);verifyTrue(t,qc.implicitMasking);
verifyTrue(t,isfile(fullfile(folder,'spatial_checks.json')));
verifyTrue(t,isfile(fullfile(folder,'mni_qc.png')));
end
function [cfg,ctx,series,meanImage]=native_fixture(t)
cfg=t.TestData.cfg;folder=t.TestData.folder;[x,y,z]=ndgrid(1:16,1:16,1:16);mat=eye(4);
data=single(100+x+y+z);series=fullfile(folder,'bold.nii');write4d(series,cat(4,data+1,data+2,data+3),mat,2,16);
meanImage=fullfile(folder,'mean.nii');write4d(meanImage,data+2,mat,2,16);
flow=fullfile(folder,'u_test.nii');field=fullfile(folder,'y_test.nii');
write_vector(flow,zeros([16 16 16 3],'single'),mat);write_vector(field,cat(4,x,y,z),mat);
template=fullfile(folder,'Template.nii');write4d(template,data,mat,2,16);
mni=struct('affine',mat,'code','MNI152');save(fullfile(folder,'Template_2mni.mat'),'mni');
group=fullfile(folder,'GROUP_COMPLETE.mat');save(group,'mni');
cfg.voxelSizeMm=[1 1 1];cfg.boundingBoxMm=[1 1 1;16 16 16];
ctx=struct('anatomy',struct('forward',field),'finalTemplate',template,'groupComplete',group, ...
    'groupSha256',psy.file_sha256(group),'fields',struct('dartel',flow,'shooting',field));
end
function write4d(file,data,mat,tr,dtype)
n=nifti;n.dat=file_array(file,size(data),[spm_type(dtype) '-LE'],0,1,0);
n.mat=mat;n.mat0=mat;n.timing.tspace=tr;create(n);n.dat(:,:,:,:)=data;
end
function write_vector(file,data,mat)
n=nifti;n.dat=file_array(file,[size(data,1) size(data,2) size(data,3) 1 3],'FLOAT32-LE',0,1,0);
n.mat=mat;n.mat0=mat;create(n);n.dat(:,:,:,:,:)=reshape(single(data),n.dat.dim);
end
