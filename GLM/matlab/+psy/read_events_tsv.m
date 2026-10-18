function e=read_events_tsv(file,durationSeconds)
%READ_EVENTS_TSV 通用任务事件；秒，零点为当前 BOLD 第一帧。保留负 onset。
% 不裁剪、不平移、不猜测条件；尾部超出扫描时长只记录。
o=detectImportOptions(file,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
o.DataLines=[2 Inf]; o.ConsecutiveDelimitersRule='split';
assert(all(ismember({'onset','duration','trial_type'},o.VariableNames)),'psy:EventColumns','Need onset/duration/trial_type');
o=setvartype(o,o.VariableNames,'string'); t=readtable(file,o);
onset=str2double(t.onset); duration=str2double(t.duration);
if isempty(onset) || any(~isfinite(onset)|~isfinite(duration)|duration<0) || ...
        any(ismissing(t.trial_type)|strlength(strtrim(t.trial_type))==0|t.trial_type=="n/a")
    error('psy:EventValues','Events require finite onset/duration, duration >=0 and nonempty trial_type');
end
if any(onset>=durationSeconds), error('psy:EventOutside','Event starts at/after end of acquisition'); end
e=struct('table',t,'onsetSeconds',onset,'durationSeconds',duration, ...
    'negativeOnsetCount',sum(onset<0),'endOverrunSeconds',max(0,max(onset+duration)-durationSeconds));
end
