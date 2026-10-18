function [smoothed,record] = smooth_run(series,cfg,jobFile)
%SMOOTH_RUN 调用 SPM Smooth；整个4D文件交给SPM逐帧处理，不自行实现卷积。
% series 是流水线的工作副本；非空安全前缀保证不写回这个输入文件。
s=psy.smooth_options(cfg);
if s.native,error('psy:SmoothExecution','native 路线须使用对应原生写出函数，不额外叠加普通 Smooth');end
[folder,stem,ext]=fileparts(series);smoothed=fullfile(folder,[s.prefix stem ext]);
v=spm_vol(series);dtype=s.dtypeCode;if dtype==0,dtype=v(1).dt(1);end
integer4d=numel(v)>1&&isfinite(spm_type(dtype,'maxval'));
jobPrefix=s.prefix;jobType=s.dtypeCode;
if integer4d
    % stock Smooth逐帧选择整数缩放，不能在单一4D头中表达不同scale。
    % 仍由SPM卷积/恢复隐式掩模：浮点中间4D→spm_file_merge统一整数缩放，避免跨帧数值失真。
    jobPrefix=[s.prefix 'float64_'];jobType=64;
end
b={};b{1}.spm.spatial.smooth=struct('data',{{series}},'fwhm',cfg.smoothingFwhmMm, ...
    'dtype',jobType,'im',double(s.implicitMasking),'prefix',jobPrefix);
psy.spm_step(b,jobFile);
if integer4d
    intermediate=fullfile(folder,[jobPrefix stem ext]);h=nifti(series);
    mergeJob=struct('input',intermediate,'output',smoothed,'dtype',dtype,'trSeconds',h.timing.tspace);
    execution='spm_file_merge';[jobFolder,jobStem]=fileparts(jobFile);
    mergeFile=fullfile(jobFolder,[jobStem '_merge.mat']);save(mergeFile,'mergeJob','execution');
    spm_file_merge(spm_vol(intermediate),smoothed,dtype,h.timing.tspace);
end
record=psy.smooth_record(cfg,series,smoothed,'spm.spatial.smooth');
record.integer4dMerge=integer4d;
if integer4d,record.intermediate=intermediate;record.mergeJob=mergeFile;end
end
