function record = smooth_record(cfg,source,output,execution)
%SMOOTH_RECORD 核对平滑前后帧数/TR/网格，区分请求菜单与原生实际行为。
% 这里只检查工程一致性，不估计GLM残差的有效FWHM，也不证明解剖质量。
s=psy.smooth_options(cfg);a=spm_vol(source);b=spm_vol(output);
if numel(a)~=numel(b),error('psy:SmoothOutput','平滑改变了时间帧数');end
for k=1:numel(a)
    if ~isequal(a(k).dim,b(k).dim)||max(abs(a(k).mat(:)-b(k).mat(:)))>1e-5
        error('psy:SmoothOutput','平滑改变了空间网格');
    end
end
ha=nifti(source);hb=nifti(output);
if ~isequaln(ha.timing.tspace,hb.timing.tspace)
    error('psy:SmoothOutput','平滑改变了 NIfTI TR');
end
record=struct('input',source,'output',output,'execution',execution, ...
    'fwhmMm',cfg.smoothingFwhmMm,'requestedDataType',s.dataType, ...
    'requestedImplicitMasking',s.implicitMasking,'prefix',s.prefix, ...
    'effectiveDataTypeCode',b(1).dt(1),'nVolumes',numel(b),'trSeconds',hb.timing.tspace, ...
    'dimensions',b(1).dim,'affine',b(1).mat);
if s.native
    record.effectiveImplicitMasking=[]; % 不伪造原生函数没有的普通im菜单。
    record.maskingImplementation='native_weighted_writer';
else
    record.effectiveImplicitMasking=s.implicitMasking;
    record.maskingImplementation='spm_smooth_im';
end
end
