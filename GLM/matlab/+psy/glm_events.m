function conditions=glm_events(file,nSeconds,names)
%GLM_EVENTS 明确条件全集；不静默丢弃未知条件或把幅度当作单位幅度。
if isempty(names)||numel(unique(names))~=numel(names), error('psy:GLMConditions','Distinct condition names required'); end
for k=1:numel(names)
    if isempty(regexp(names{k},'^[A-Za-z][A-Za-z0-9_]*$','once')), error('psy:GLMConditions','Use letter-led simple condition names'); end
end
e=psy.read_events_tsv(file,nSeconds);
if any(ismember({'amplitude','modulation','pmod'},e.table.Properties.VariableNames))
    error('psy:GLMAmplitude','Amplitude/parametric modulation not yet supported');
end
if ~all(ismember(e.table.trial_type,string(names))), error('psy:GLMConditions','Unknown trial_type; include every condition'); end
conditions=struct([]);
for k=1:numel(names)
    select=e.table.trial_type==string(names{k});
    if ~any(select), error('psy:GLMConditions','Missing condition %s',names{k}); end
    c=struct('name',names{k},'onset',e.onsetSeconds(select),'duration',e.durationSeconds(select), ...
        'tmod',0,'pmod',struct('name',{},'param',{},'poly',{}),'orth',0);
    if isempty(conditions), conditions=c; else, conditions(end+1)=c; end %#ok<AGROW>
end
end
