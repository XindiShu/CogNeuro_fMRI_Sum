function info = inspect_run(run)
%INSPECT_RUN 通用 NIfTI 检查；任务条件由适配器声明，不根据文件名猜测。
h = niftiinfo(run.bold);
if numel(h.ImageSize)~=4 || h.ImageSize(4)<2
    error('psy:ImageShape','Expected a 4-D BOLD series: %s',run.bold);
end
tr = h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond', tr=tr/1000;
    case 'microsecond', tr=tr/1e6;
    otherwise, error('psy:TimeUnits','Unknown NIfTI time units: %s',h.TimeUnits);
end
if ~isfinite(tr) || tr<=0, error('psy:TR','Invalid TR'); end
if ~strcmpi(h.SpaceUnits,'millimeter'), error('psy:SpaceUnits','Expected millimeter units'); end
info = struct('subject',run.subject,'run',run.name,'size',h.ImageSize, ...
    'voxelSizeMm',h.PixelDimensions(1:3),'trSeconds',tr,'nVolumes',h.ImageSize(4), ...
    'durationSeconds',tr*h.ImageSize(4),'sbrefPresent',isfile(run.sbref));
if isfield(run,'session'), info.session=run.session; else, info.session=''; end
info.eventCheck='not_provided_for_spatial_preprocessing';
if isfield(run,'eventFormat') && strcmp(run.eventFormat,'hcp_ev')
    e = psy.read_hcp_events(run.ev,run.conditions,info.durationSeconds,"preserve");
    info.eventCheck='hcp_ev_checked';
    info.conditionCounts = cellfun(@numel,e.onsets);
    info.eventEndOverrunSeconds = cellfun(@(o,d)max(0,max(o+d)-info.durationSeconds),e.onsets,e.durations);
end
if ~isempty(run.t1)
    t = niftiinfo(run.t1);
    if ~ismember(numel(t.ImageSize),[3 4]), error('psy:T1Shape','Expected a 3-D T1 or 4-D anatomical container'); end
    % 4D 容器的具体 volume 由 segment_plan 检查并提取为私有 3D 输入。
end
info.contract=psy.inspect_contract(run,info);
end
