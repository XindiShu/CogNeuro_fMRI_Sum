function trimmed=trim_dummy_bold(source,count,trSeconds,folder,expectedVolumes)
%TRIM_DUMMY_BOLD 用 SPM 合并保留帧，原始 NIfTI 不修改。
if count<=0, error('psy:Discard','此函数只用于正数 dummy 帧删除'); end
if ~isfolder(folder), mkdir(folder); end
rawCopy=psy.stage_image(source,folder);
volumes=spm_vol(rawCopy);
if nargin>=5 && numel(volumes)~=expectedVolumes
    error('psy:DummyFrames','输入帧数在预检之后发生变化');
end
if count>=numel(volumes)-1
    error('psy:Discard','删除后至少应保留 2 帧');
end
trimmed=fullfile(folder,'bold_retained.nii');
spm_file_merge(volumes(count+1:end),trimmed,0,trSeconds);
end
