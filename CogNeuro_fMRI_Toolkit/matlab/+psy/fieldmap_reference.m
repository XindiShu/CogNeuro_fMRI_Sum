function reference=fieldmap_reference(sdc,bold,out,cfg)
%FIELDMAP_REFERENCE 用当前工作 BOLD/SBRef/显式 EPI 准备私有三维参考。
% mean 由 SPM Reslice 根据当前图像头求均值，不暗中先做额外 Realign。
options=psy.sdc_spm_options(cfg); folder=fullfile(out,'spm_fieldmap','reference');
if ~isfolder(folder), mkdir(folder); end
input=bold; frame=1;
if ismember(options.referenceEpi,{'sbref','manifest'})
    if ~isfield(sdc,'referenceSource') || ~isfile(sdc.referenceSource)
        error('psy:SDCReference','缺少所选的代表 EPI 文件');
    end
    input=psy.stage_image(sdc.referenceSource,folder);
elseif strcmp(options.referenceEpi,'mean')
    volumes=spm_vol(bold);
    scans=arrayfun(@(k)sprintf('%s,%d',bold,k),(1:numel(volumes))','UniformOutput',false);
    b={}; b{1}.spm.spatial.realign.write.data=scans;
    b{1}.spm.spatial.realign.write.roptions=struct('which',[0 1], ...
        'interp',cfg.realign.writeInterpolation,'wrap',cfg.realign.wrap,'mask',double(cfg.realign.mask),'prefix','r');
    psy.spm_step(b,fullfile(folder,'reference_mean_job.mat'));
    [location,name,ext]=fileparts(bold); input=fullfile(location,['mean' name ext]);
elseif strcmp(options.referenceEpi,'volume')
    frame=options.referenceVolume;
end
v=spm_vol(input);
if frame>numel(v), error('psy:SDCReference','代表 EPI 帧编号超出当前保留序列'); end
v=v(frame); values=spm_read_vols(v);
if any(~isfinite(values(:))), error('psy:SDCReference','代表 EPI 包含非有限值，请准备有效三维参考'); end
reference=fullfile(folder,'reference.nii');
v.fname=reference; v.n=[1 1]; v.dt=[spm_type('float32') spm_platform('bigend')]; v.pinfo=[1;0;0];
spm_write_vol(v,values);
end
