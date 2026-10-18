function file=write_dummy_events(run,plan,folder)
%WRITE_DUMMY_EVENTS 保存可用于后续分析的事件副本，原始 TSV/HCP EV 不修改。
file='';
if plan.count==0, return; end
if isfield(run,'events') && ~isempty(run.events)
    opts=detectImportOptions(run.events,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
    opts.DataLines=[2 Inf]; opts.ConsecutiveDelimitersRule='split';
    opts=setvartype(opts,opts.VariableNames,'string');
    t=readtable(run.events,opts);
    t.onset=compose('%.15g',str2double(t.onset)-plan.eventShiftSeconds);
elseif isfield(run,'eventFormat') && strcmp(run.eventFormat,'hcp_ev')
    t=table(strings(0,1),strings(0,1),strings(0,1), ...
        'VariableNames',{'onset','duration','trial_type'});
    e=psy.read_hcp_events(string(run.ev),run.conditions, ...
        plan.originalVolumes*plan.trSeconds,"preserve");
    for k=1:numel(e.names)
        n=numel(e.onsets{k});
        part=table(compose('%.15g',e.onsets{k}(:)-plan.eventShiftSeconds), ...
            compose('%.15g',e.durations{k}(:)),repmat(string(e.names{k}),n,1), ...
            'VariableNames',{'onset','duration','trial_type'});
        t=[t;part]; %#ok<AGROW>
    end
    [~,order]=sort(str2double(t.onset)); t=t(order,:);
else
    return
end
if ~isfolder(folder), mkdir(folder); end
file=fullfile(folder,'events_retained_first_volume.tsv');
writetable(t,file,'FileType','text','Delimiter','\t');
end
