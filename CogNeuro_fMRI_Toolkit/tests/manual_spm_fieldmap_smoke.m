function results = manual_spm_fieldmap_smoke(root)
%MANUAL_SPM_FIELDMAP_SMOKE 用合成影像真实运行本机 SPM FieldMap 的两条 batch。
% 这是手动集成检查，不进入常规单元测试；输出必须是全新的私有目录。
if nargin<1
    root=fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'derivatives',['spm_fieldmap_smoke_' datestr(now,'yyyymmdd_HHMMSSFFF')]);
end
if isfolder(root), error('psy:SmokeExisting','测试目录已存在: %s',root); end
mkdir(root);
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'matlab'));
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'config'));
cfg=toolkit_config;
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [本机测试] SPM 安装目录；其他电脑需替换。
addpath(cfg.spmPath); spm('defaults','fmri'); spm_jobman('initcfg');
source=fullfile(root,'source'); mkdir(source);
[x,y,z]=ndgrid(linspace(-1,1,32),linspace(-1,1,32),linspace(-1,1,16));
mag=single(1000*exp(-3*(x.^2+y.^2+z.^2))+20);
phase=single(0.4*x+0.2*y); % 弧度，合成、平滑、无需相位展开。
epi=zeros(32,32,16,8,'single');
for k=1:8
    epi(:,:,:,k)=mag.*single(1+0.02*sin(k))+single(5*x+3*y);
end
phaseFile=fullfile(source,'phasediff.nii');
magFile=fullfile(source,'magnitude.nii');
epiFile=fullfile(source,'bold.nii');
hzFile=fullfile(source,'fieldmap_hz.nii');
niftiwrite(phase,phaseFile);
niftiwrite(single(1000*exp(-8*(x.^2+y.^2+z.^2))+.001),magFile);
niftiwrite(epi,epiFile);
niftiwrite(single(phase/(2*pi*.002)),hzFile);
sdc=struct('fieldmap',struct('type','phasediff','phase',phaseFile, ...
    'magnitude',magFile,'echoTimesMs',[4 6]), ...
    'blipDirection',-1,'readoutMs',35,'phaseEncodingAxis',2);
methods={'spm_fieldmap_applyvdm','spm_fieldmap_unwarp', ...
    'spm_fieldmap_applyvdm_hz'};
results=struct('method',{},'series',{},'mean',{},'motion',{},'vdm',{});
for k=1:numel(methods)
    out=fullfile(root,methods{k}); mkdir(out);
    localBold=psy.stage_image(epiFile,out);
    if strcmp(methods{k},'spm_fieldmap_applyvdm_hz')
        sdc.method='spm_fieldmap_applyvdm';
        sdc.fieldmap=struct('type','fieldmap_hz','hz',hzFile, ...
            'magnitude','','echoTimesMs',[1 2]); % SPM 的 Hz 模式允许不提供幅度图。
    else
        sdc.method=methods{k};
    end
    r=psy.spm_motion_step(localBold,8,cfg,out,sdc);
    d=spm_read_vols(spm_vol(r.vdm));
    assert(all(isfinite(d(:))) && max(abs(d(:)))>0,'VDM 必须有限且非零');
    movement=readmatrix(r.motion);
    assert(isequal(size(movement),[8 6]) && all(isfinite(movement(:))), ...
        '头动参数应是有限的 8×6 矩阵');
    frames=spm_vol(r.series);
    assert(numel(frames)==8,'SPM 校正序列应包含全部 8 帧');
    first=spm_read_vols(frames(1));
    assert(nnz(isfinite(first))/numel(first)>.8,'校正图像有限体素不足');
    results(k)=struct('method',methods{k},'series',r.series, ...
        'mean',r.mean,'motion',r.motion,'vdm',r.vdm);
end
% 普通 Realign 的均值图命名为 mean<输入名>，不带重采样前缀 r。
out=fullfile(root,'normal_realign');mkdir(out);
localBold=psy.stage_image(epiFile,out);
normal=psy.spm_motion_step(localBold,8,cfg,out,struct('method','none'));
assert(isfile(normal.mean) && isempty(normal.vdm),'普通 Realign 均值图或 VDM 状态错误');
save(fullfile(root,'smoke_results.mat'),'results');
end
