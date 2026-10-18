function result=segment_run(run,cfg,out,p)
%SEGMENT_RUN 可复用分割接口；原始输入只读，全部计算调用 SPM/CAT 官方实现。
if nargin<4,p=psy.segment_plan(run,cfg);end
files=psy.stage_anatomy(p,cfg,out);[folder,stem]=fileparts(files{1});
result=struct('backend',p.options.backend,'t1',files{1},'forward','', ...
    'inverse','','requiredOutputs',{files},'plan',p);
if isfield(run,'anatomyReuseDir')&&~isempty(run.anatomyReuseDir)
    % 旧复用协议只支持原有输出集合；新选项不允许假装已有旧结果。
    s=p.options;
    if ~strcmp(s.backend,'spm')||numel(files)~=1||s.inputVolume~=1|| ...
            ~strcmp(s.saveBias,'corrected')||~isequal(s.nativeOutputs,{'native','native','native','none','none','none'})|| ...
            ~all(strcmp(s.warpedOutputs,'none'))||s.smoothnessMm~=0|| ...
            ~isequal(p.deformationFlags,[0 1])||p.atlasOptions.enabled
        error('psy:AnatomyReuse','旧解剖复用仅支持默认 SPM 单通道输出；新选项请另选输出目录重新分割');
    end
    psy.reuse_anatomy(files{1},run.anatomyReuseDir,cfg);
    [~,expected]=psy.spm_segment_batch(files,p,cfg);
elseif strcmp(p.options.backend,'spm')
    [b,expected]=psy.spm_segment_batch(files,p,cfg);
    psy.spm_step(b,fullfile(out,'03_segment.mat'));
else
    [expected,forward,inverse]=psy.cat12_segment(files{1},p,out,cfg);
    result.forward=forward;result.inverse=inverse;
end
if strcmp(result.backend,'spm')
    if p.deformationFlags(2),result.forward=fullfile(folder,['y_' stem '.nii']);end
    if p.deformationFlags(1),result.inverse=fullfile(folder,['iy_' stem '.nii']);end
end
result.requiredOutputs=[result.requiredOutputs,expected];
if ~all(cellfun(@isfile,result.requiredOutputs)),error('psy:SegmentOutputs','分割缺少所请求的输出；不写完成标记');end
save(fullfile(out,'SEGMENT_COMPLETE.mat'),'result');
result.requiredOutputs{end+1}=fullfile(out,'SEGMENT_COMPLETE.mat');
end
