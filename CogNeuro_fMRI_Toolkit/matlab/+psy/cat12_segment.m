function [expected,forward,inverse]=cat12_segment(t1,p,out,cfg)
%CAT12_SEGMENT 调用 CAT12.9 官方 cat_run；保存可重放原生 job 和完整默认值。
% CAT 内部算法不是 SPM Segment。SPM 专属 smoothness/gaussians/MRF 不传入 CAT。
% 每个 run 一个 T1、nproc=0，批量调度由 preprocess_batch 完成，便于追踪失败。
environment=psy.cat12_environment(p.options.cat12.path);
if ~isequal(environment,p.backendVersion)
    error('psy:CATChanged','CAT 安装/模板在预检后改变，拒绝继续');
end
cat_defaults;cat_get_defaults('extopts.send_info',0); % 本地运行不发送安装统计。
c=p.options.cat12;
job=struct('data',{{[t1 ',1']}},'nproc',0,'opts',cat_get_defaults('opts'), ...
    'extopts',cat_get_defaults('extopts'),'output',cat_get_defaults('output'));
job.opts.affreg=p.options.affineRegistration;
job.opts.tpm={fullfile(cfg.spmPath,'tpm','TPM.nii')};
job.opts.accstr=.5;if strcmp(c.accuracy,'high'),job.opts.accstr=1;end
% CAT biasstr 默认 0.5。独立 CAT 路线不把 SPM biasreg/biasfwhm 当成等价控制。
job.extopts.ignoreErrors=0;job.extopts.lazy=0;job.extopts.print=0;
job.extopts.subfolders=1;job.extopts.send_info=0;
job.output.BIDS=struct('BIDSno',1);job.output.surface=0;job.output.ROI=0;
if isfield(job.output,'atlases')
    for name=fieldnames(job.output.atlases)',job.output.atlases.(name{1})=0;end
end
for name={'GM','WM','CSF','WMH','SL','TPMC','label','las','atlas','ct','pp'}
    if isfield(job.output,name{1})
        for field=fieldnames(job.output.(name{1}))',job.output.(name{1}).(field{1})=0;end
    end
end
job.output.bias=struct('native',double(c.saveBiasCorrected),'warped',0,'dartel',0);
job.output.jacobian=struct('warped',0);
% CAT 的位序是 [forward inverse]，与 SPM 的 [inverse forward] 相反。
job.output.warps=p.deformationFlags([2 1]);
names={'GM','WM','CSF'};
for k=1:3
    f=psy.segment_output_flags('warped',c.warpedTissues{k});
    job.output.(names{k})=struct('native',c.nativeTissues(k),'warped',f(1),'mod',f(2),'dartel',c.dartelTissues(k));
end
execution='cat_run';record=fullfile(out,'03_cat12_segment.mat');save(record,'job','execution');
% CAT 若需要日志，仅写本 run 工作目录；结束后恢复 MATLAB 当前目录。
old=pwd;cleanup=onCleanup(@()cd(old));cd(out);
cat_run(job);
[folder,stem]=fileparts(t1);mri=fullfile(folder,'mri');expected={record};
forward='';inverse='';
if p.deformationFlags(2),forward=fullfile(mri,['y_' stem '.nii']);expected{end+1}=forward;end
if p.deformationFlags(1),inverse=fullfile(mri,['iy_' stem '.nii']);expected{end+1}=inverse;end
if c.saveBiasCorrected,expected{end+1}=fullfile(mri,['m' stem '.nii']);end
for k=1:3
    if c.nativeTissues(k),expected{end+1}=fullfile(mri,sprintf('p%d%s.nii',k,stem));end %#ok<AGROW>
    if c.dartelTissues(k),expected{end+1}=fullfile(mri,sprintf('rp%d%s_rigid.nii',k,stem));end %#ok<AGROW>
    f=psy.segment_output_flags('warped',c.warpedTissues{k});
    if f(1),expected{end+1}=fullfile(mri,sprintf('wp%d%s.nii',k,stem));end %#ok<AGROW>
    if f(2),expected{end+1}=fullfile(mri,sprintf('mwp%d%s.nii',k,stem));end %#ok<AGROW>
end
% CAT report XML 保存真实算法版本/组织体积/QC；不伪造 c1/c2/c3 文件名。
expected{end+1}=fullfile(folder,'report',['cat_' stem '.xml']);
end
