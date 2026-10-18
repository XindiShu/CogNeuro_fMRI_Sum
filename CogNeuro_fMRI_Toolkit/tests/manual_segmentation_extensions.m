function records=manual_segmentation_extensions(outputRoot,dataRoot,backend)
%MANUAL_SEGMENTATION_EXTENSIONS 新分割模块的真实 HCP 结构像工程验证。
% 示例只在此指定被试/布局；通用分割函数不含 HCP 路径或编号。
% outputRoot 必须为新的独立目录；不重复已有成功 fMRI 分析。
% backend='spm'：真实 T1+T2 的 2mm 工作副本、通道配准、全部输出菜单。
% backend='cat12'：真实 T1 的 1mm 工作副本，CAT 原生分割及双向场。
% 降采样是缩短工程验证时间的测试准备，不推荐据此确定研究采集分辨率。
if nargin<2,dataRoot='D:\IBM';end
if nargin<3,backend='spm';end
if isfolder(outputRoot),error('psy:ExistingOutput','请使用新的 manual 验证目录');end
mkdir(outputRoot);cfg=toolkit_config;cfg.stopAfter='segment';cfg.segment.backend=backend;
addpath(cfg.spmPath);addpath(fullfile(cfg.spmPath,'toolbox','cat12'));cat_defaults;
cat_get_defaults('extopts.send_info',0);spm('defaults','fmri');spm_jobman('initcfg');
cfg.segment.deformationFields='inverse_forward';
cfg.segment.saveBias='both';cfg.segment.nativeOutputs=repmat({'native_dartel'},1,6);
cfg.segment.warpedOutputs=repmat({'both'},1,6);cfg.segment.smoothnessMm=1;
cfg.segment.channelAlignment='coregister_reslice';
source=fullfile(dataRoot,'100206_extracted','100206_3T_Structural_unproc','100206','unprocessed','3T');
t1raw=fullfile(source,'T1w_MPR1','100206_3T_T1w_MPR1.nii.gz');
t2raw=fullfile(source,'T2w_SPC1','100206_3T_T2w_SPC1.nii.gz');
prepared=fullfile(outputRoot,'prepared');mkdir(prepared);
one=psy.stage_image(t1raw,fullfile(prepared,'original_t1'));v=spm_vol(one);
step=2;if strcmp(backend,'cat12'),step=1;end
% 相同世界坐标视野；调用 SPM 采样，并写测试专用低分辨率图。
t1=resample(v,step,fullfile(prepared,'T1.nii'));
run=struct('t1',t1,'anatomyChannels','','atlases','');
if strcmp(backend,'spm')
    two=psy.stage_image(t2raw,fullfile(prepared,'original_t2'));
    t2=resample(spm_vol(two),step,fullfile(prepared,'T2.nii'));
    j=struct('Channels',struct('Name',{'T1','T2'},'Path',{t1,t2},'Volume',{1,1},'SaveBias',{'both','both'}));
    run.anatomyChannels=fullfile(prepared,'channels.json');write_json(run.anatomyChannels,j);
else
    cfg.segment.cat12.dartelTissues=[1 1 1];
    cfg.segment.cat12.warpedTissues={'both','both','both'};
end
rawHashes={psy.file_sha256(t1raw),psy.file_sha256(t2raw)};
p=psy.segment_plan(run,cfg);out=fullfile(outputRoot,'run');mkdir(out);
diary(fullfile(outputRoot,'validation_log.txt'));cl=onCleanup(@()diary('off'));
result=psy.segment_run(run,cfg,out,p);
assert(all(cellfun(@isfile,result.requiredOutputs)));
assert(strcmp(rawHashes{1},psy.file_sha256(t1raw)) && strcmp(rawHashes{2},psy.file_sha256(t2raw)));
% 真实分割逆向场的图谱接线验证；用对应后端的模板生成测试概率 ROI。
if strcmp(backend,'spm')
    template=spm_vol(fullfile(cfg.spmPath,'tpm','TPM.nii'));template=template(1);space='spm_tpm_mni';
else
    template=spm_vol(fullfile(cfg.spmPath,'toolbox','cat12','templates_MNI152NLin2009cAsym','Template_T1.nii'));space='cat12_mni2009c';
end
atlas=fullfile(prepared,'test_roi.nii');mv=template;mv.fname=atlas;mv.dt=[16 0];mv.pinfo=[1;0;0];
x=spm_read_vols(template);spm_write_vol(mv,single(x>0.3*max(x(:))));
cfg.atlas.enabled=true;run.atlases=fullfile(prepared,'atlases.json');
write_json(run.atlases,struct('Atlases',struct('Name','TestROI','Path',atlas,'Kind','labels','Space',space)));
p=psy.segment_plan(run,cfg);atlasOutputs=psy.apply_atlases(p,result.inverse,result.t1,out);
assert(all(cellfun(@isfile,atlasOutputs)));
records=struct('status','real_structure_module_engineering_test','backend',backend, ...
    'voxelSizeMm',step,'result',result,'atlasOutputs',{atlasOutputs},'rawHashes',{rawHashes}, ...
    'limitations','未完成全切片人工 QC；测试 ROI 不是研究图谱；未运行三被试完整 BOLD 链');
save(fullfile(outputRoot,'MANUAL_VALIDATION_COMPLETE.mat'),'records');
end
function file=resample(v,step,file)
vox=sqrt(sum(v.mat(1:3,1:3).^2));dim=ceil((v.dim-1).*vox/step)+1;
mat=v.mat;mat(1:3,1:3)=v.mat(1:3,1:3)*diag(step./vox);
out=struct('fname',file,'dim',dim,'dt',[16 0],'mat',mat,'pinfo',[1;0;0]);out=spm_create_vol(out);
[x,y]=ndgrid(1:dim(1),1:dim(2));mapping=v.mat\mat;
for z=1:dim(3)
    xyz=mapping*[x(:)';y(:)';z*ones(1,numel(x));ones(1,numel(x))];
    values=spm_sample_vol(v,xyz(1,:),xyz(2,:),xyz(3,:),1);
    out=spm_write_plane(out,reshape(values,dim(1:2)),z);
end
end
function write_json(file,j)
fid=fopen(file,'w');fprintf(fid,'%s',jsonencode(j,PrettyPrint=true));fclose(fid);
end
