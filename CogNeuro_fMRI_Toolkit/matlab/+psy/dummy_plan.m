function plan=dummy_plan(run,info,cfg)
%DUMMY_PLAN 删除 dummy 帧前检查帧数与事件时间基准；不猜扫描仪是否已丢帧。
count=cfg.discardVolumes;
if isfield(run,'discardVolumes') && ~isempty(run.discardVolumes)
    count=run.discardVolumes; % 可选清单列逐 run 覆盖全局默认。
end
if ~isnumeric(count) || ~isscalar(count) || ~isfinite(count) || ...
        count<0 || count~=floor(count) || count>=info.nVolumes-1
    error('psy:Discard','discardVolumes 必须为非负整数，且删除后至少保留 2 帧');
end
reference='unspecified';
if isfield(cfg,'dummy') && isfield(cfg.dummy,'eventReference')
    reference=char(string(cfg.dummy.eventReference));
end
if isfield(run,'eventReference') && ~isempty(run.eventReference)
    reference=run.eventReference;
end
if ~ismember(reference,{'unspecified','original_first_volume','retained_first_volume'})
    error('psy:DummyEventReference','eventReference 可选 unspecified/original_first_volume/retained_first_volume');
end
hasEvents=(isfield(run,'events') && ~isempty(run.events)) || ...
    (isfield(run,'eventFormat') && strcmp(run.eventFormat,'hcp_ev'));
if count>0 && hasEvents && strcmp(reference,'unspecified')
    error('psy:DummyEventReference','有事件且删除 dummy 时，必须明确事件是相对原首帧还是保留后的首帧');
end
shift=0;
if count>0 && strcmp(reference,'original_first_volume')
    shift=count*info.trSeconds;
end
retained=(info.nVolumes-count)*info.trSeconds;
if count>0 && isfield(info,'contract') && isfield(info.contract,'events')
    onsets=info.contract.events.onsetSeconds-shift;
    if any(onsets>=retained)
        error('psy:DummyEventOutside','删除 dummy 后有事件开始时间不在保留的扫描时长内');
    end
end
if count>0 && isfield(run,'eventFormat') && strcmp(run.eventFormat,'hcp_ev')
    e=psy.read_hcp_events(string(run.ev),run.conditions,info.durationSeconds,"preserve");
    for k=1:numel(e.onsets)
        if any(e.onsets{k}-shift>=retained)
            error('psy:DummyEventOutside','删除 dummy 后有 HCP 事件开始时间不在保留的扫描时长内');
        end
    end
end
plan=struct('count',count,'originalVolumes',info.nVolumes, ...
    'retainedVolumes',info.nVolumes-count,'trSeconds',info.trSeconds, ...
    'discardedSeconds',count*info.trSeconds,'eventReference',reference, ...
    'eventShiftSeconds',shift,'retainedDurationSeconds',retained);
end
