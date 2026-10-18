function [batch,expected]=spm_segment_batch(files,p,cfg)
%SPM_SEGMENT_BATCH 只映射本机 SPM Segment 官方 batch 字段。
s=p.options;job=struct;
for k=1:numel(files)
    c=p.channels(k);
    job.channel(k)=struct('vols',{{[files{k} ',1']}}, ...
        'biasreg',c.BiasRegularisation,'biasfwhm',c.BiasFwhmMm, ...
        'write',psy.segment_output_flags('bias',c.SaveBias));
end
for k=1:6
    job.tissue(k)=struct('tpm',{{sprintf('%s,%d',fullfile(cfg.spmPath,'tpm','TPM.nii'),k)}}, ...
        'ngaus',s.gaussians(k),'native',psy.segment_output_flags('native',s.nativeOutputs{k}), ...
        'warped',psy.segment_output_flags('warped',s.warpedOutputs{k}));
end
job.warp=struct('mrf',s.mrf,'cleanup',s.cleanup,'reg',s.warpRegularisation, ...
    'affreg',s.affineRegistration,'fwhm',s.smoothnessMm,'samp',s.warpSamplingMm,'write',p.deformationFlags);
batch={};batch{1}.spm.spatial.preproc=job;
[folder,stem]=fileparts(files{1});
expected={fullfile(folder,[stem '_seg8.mat'])};
for k=1:numel(files)
    [channelFolder,channelStem]=fileparts(files{k});f=job.channel(k).write;
    if f(1),expected{end+1}=fullfile(channelFolder,['BiasField_' channelStem '.nii']);end %#ok<AGROW>
    if f(2),expected{end+1}=fullfile(channelFolder,['m' channelStem '.nii']);end %#ok<AGROW>
end
for k=1:6
    f=[job.tissue(k).native job.tissue(k).warped];prefix={'c','rc','wc','mwc'};
    for n=1:4
        if f(n),expected{end+1}=fullfile(folder,sprintf('%s%d%s.nii',prefix{n},k,stem));end %#ok<AGROW>
    end
end
if p.deformationFlags(1),expected{end+1}=fullfile(folder,['iy_' stem '.nii']);end
if p.deformationFlags(2),expected{end+1}=fullfile(folder,['y_' stem '.nii']);end
end
