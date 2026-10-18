function [conditions,audit]=glm_pmod(conditions,events,cfg)
%GLM_PMOD 显式读取逐事件调节量；不填补缺失，不更改源事件表。
audit=table;
if ~cfg.pmod.enabled,return;end
for k=1:numel(conditions),conditions(k).orth=double(cfg.pmod.orthogonalize);end
for k=1:numel(cfg.pmod.modulators)
    m=cfg.pmod.modulators(k);selected=events.trial_type==string(m.condition);indices=find(selected);
    if ~ismember(m.column,events.Properties.VariableNames),error('psy:GLMPmodValues','Missing pmod column: %s',m.column);end
    raw=str2double(string(events.(m.column)(selected)));
    if numel(raw)<2||any(~isfinite(raw))||std(raw)==0,error('psy:GLMPmodValues','pmod needs finite, varying values for every modeled event');end
    center=0;scale=1;
    if strcmp(cfg.pmod.center,'within_condition'),center=mean(raw);end
    if strcmp(cfg.pmod.scale,'zscore'),scale=std(raw);end
    values=(raw-center)/scale;
    polynomial=values.^(0:m.poly);
    if any(~isfinite(polynomial),'all')||rank(polynomial)<m.poly+1
        error('psy:GLMPmodValues','Polynomial pmod expansion is nonfinite or rank-deficient');
    end
    id=strcmp({conditions.name},m.condition);
    conditions(id).pmod(end+1)=struct('name',char(m.name),'param',values,'poly',m.poly);
    n=numel(values);entry=table(indices,repmat(string(m.condition),n,1),repmat(string(m.column),n,1), ...
        repmat(string(m.name),n,1),raw,values,repmat(center,n,1),repmat(scale,n,1),repmat(m.poly,n,1), ...
        'VariableNames',{'event_index','condition','source_column','modulator','raw_value','model_value','center','scale','poly'});
    if isempty(audit),audit=entry;else,audit=[audit;entry];end %#ok<AGROW>
end
end
