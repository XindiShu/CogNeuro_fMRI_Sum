function s=segment_options(cfg)
%SEGMENT_OPTIONS 新选项缺失时沿用旧版行为，旧项目无需补全全部字段。
s=cfg.segment;
defaults=struct('backend','spm','inputVolume',1,'channelsFile','', ...
    'channelAlignment','require_aligned','saveBias','corrected', ...
    'nativeOutputs',{{'native','native','native','none','none','none'}}, ...
    'warpedOutputs',{{'none','none','none','none','none','none'}}, ...
    'smoothnessMm',0);
for name=fieldnames(defaults)'
    if ~isfield(s,name{1}), s.(name{1})=defaults.(name{1}); end
end
if ~ismember(s.backend,{'spm','cat12'}) || ...
        ~ismember(s.channelAlignment,{'require_aligned','coregister_reslice'})
    error('psy:SegmentConfig','backend=spm/cat12；channelAlignment=require_aligned/coregister_reslice');
end
integer(s.inputVolume,'inputVolume');
psy.segment_output_flags('bias',s.saveBias);
if numel(s.nativeOutputs)~=6 || numel(s.warpedOutputs)~=6 || ...
        ~iscell(s.nativeOutputs) || ~iscell(s.warpedOutputs)
    error('psy:SegmentConfig','nativeOutputs/warpedOutputs 须为六元素 cell，各组织单独选择');
end
for k=1:6
    psy.segment_output_flags('native',s.nativeOutputs{k});
    psy.segment_output_flags('warped',s.warpedOutputs{k});
end
if ~isnumeric(s.smoothnessMm)||~isscalar(s.smoothnessMm)||~isfinite(s.smoothnessMm)||s.smoothnessMm<0
    error('psy:SegmentConfig','smoothnessMm 须为有限非负毫米数');
end
if ~isfield(s,'cat12'), s.cat12=struct; end
d=struct('path',fullfile(cfg.spmPath,'toolbox','cat12'), ...
    'nativeTissues',[1 1 1],'dartelTissues',[0 0 0], ...
    'warpedTissues',{{'none','none','none'}},'saveBiasCorrected',true, ...
    'accuracy','default');
for name=fieldnames(d)'
    if ~isfield(s.cat12,name{1}), s.cat12.(name{1})=d.(name{1}); end
end
for name={'nativeTissues','dartelTissues'}
    v=s.cat12.(name{1});
    if ~isnumeric(v)||~isequal(size(v),[1 3])||any(~ismember(v,[0 1]))
        error('psy:SegmentConfig','cat12.%s 须为 GM/WM/CSF 三个 0/1',name{1});
    end
end
if ~iscell(s.cat12.warpedTissues)||numel(s.cat12.warpedTissues)~=3
    error('psy:SegmentConfig','cat12.warpedTissues 须为 GM/WM/CSF 三元素 cell');
end
for k=1:3, psy.segment_output_flags('warped',s.cat12.warpedTissues{k}); end
if ~isscalar(s.cat12.saveBiasCorrected)||~ismember(s.cat12.saveBiasCorrected,[0 1])|| ...
        ~ismember(s.cat12.accuracy,{'default','high'})
    error('psy:SegmentConfig','CAT saveBiasCorrected=0/1，accuracy=default/high');
end
end
function integer(v,name)
if ~isnumeric(v)||~isscalar(v)||~isfinite(v)||v<1||v~=floor(v)
    error('psy:SegmentConfig','%s 须为从 1 开始的正整数 volume 编号',name);
end
end
