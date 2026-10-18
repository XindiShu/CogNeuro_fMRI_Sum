function plan=glm_framework_plan(file,nSeconds,cfg)
%GLM_FRAMEWORK_PLAN 将真实事件语义映射为SPM条件；不读影像、不估计、不写原表。
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.engine,'spm_classical'),error('psy:GLMEngine','Use glmsingle_plan for the GLMsingle engine');end
e=psy.read_events_tsv(file,nSeconds);t=e.table;n=height(t);
reserved=intersect({'amplitude','modulation','pmod'},t.Properties.VariableNames);
declared={};if cfg.pmod.enabled,declared={cfg.pmod.modulators.column};end
if any(~ismember(reserved,declared))
    error('psy:GLMAmplitude','Amplitude/modulation/pmod columns must be explicitly declared as modulators; no silent amplitude weighting');
end
if ismember('modeled_duration_seconds',t.Properties.VariableNames)
    error('psy:GLMEventUnit','modeled_duration_seconds is reserved for the generated events_used table');
end
names=string(cfg.conditions(:));
if isempty(names)||numel(unique(names))~=numel(names)||any(cellfun(@isempty,regexp(cellstr(names),'^[A-Za-z][A-Za-z0-9_]*$','once')))
    error('psy:GLMConditions','conditions must contain distinct letter-led simple labels');
end
if ~all(ismember(t.trial_type,names))||~all(ismember(names,t.trial_type))
    error('psy:GLMConditions','Declare every observed condition, with no missing conditions');
end
usedDuration=e.durationSeconds;
switch cfg.events.expression
    case 'impulse', usedDuration(:)=0;
    case 'fixed', usedDuration(:)=cfg.events.fixedDurationSeconds;
end
unit=cfg.model.unit;
switch unit
    case 'condition'
        keys=table(t.trial_type,'VariableNames',{'id'});
    case 'event'
        keys=table("event_"+string((1:n)'),'VariableNames',{'id'});
    case {'trial','item','block'}
        column=struct('trial','trial_id','item','stimulus_id','block','block_id');
        id=getColumn(t,column.(unit));keys=table(id);
    case 'phase'
        phase=getColumn(t,'phase');keys=table(t.trial_type,phase,'VariableNames',{'id','phase'});
    case 'trial_phase'
        id=getColumn(t,'trial_id');phase=getColumn(t,'phase');keys=table(id,phase);
end
[unitKeys,~,group]=unique(keys,'rows','stable');
if strcmp(unit,'condition')
    % 条件顺序只由总配置决定，避免事件表排序改变对比含义。
    [~,group]=ismember(t.trial_type,names);unitKeys=table(names,'VariableNames',{'id'});
end
count=height(unitKeys);
if ismember(unit,{'trial','block','trial_phase'}) && count~=n
    error('psy:GLMEventUnit','%s requires one event row per unique unit; use phase/trial_phase or item for other designs',unit);
end
labels=compose('unit_%06d',(1:count)');
if strcmp(unit,'condition'),labels=names;end
unitConditions=strings(count,1);nRows=zeros(count,1);
for k=1:count
    observed=unique(t.trial_type(group==k));
    if numel(observed)~=1,error('psy:GLMEventUnit','A grouped unit cannot span different conditions');end
    unitConditions(k)=observed;nRows(k)=nnz(group==k);
end
requested=string(cfg.model.targetConditions);
if ~all(ismember(requested,names)),error('psy:GLMTargets','Unknown target condition');end
selected=true(count,1);
if ~isempty(requested),selected=ismember(unitConditions,requested);end
units=table((1:count)',labels,unitKeys.id,unitConditions,nRows,selected, ...
    'VariableNames',{'unit_index','model_label','source_id','condition','n_event_rows','target_selected'});
if ismember('phase',unitKeys.Properties.VariableNames),units.phase=unitKeys.phase;end
mapping=table((1:n)',t.trial_type,e.onsetSeconds,e.durationSeconds,usedDuration,group,labels(group),selected(group), ...
    'VariableNames',{'event_index','condition','onset_seconds','original_duration_seconds', ...
    'modeled_duration_seconds','unit_index','model_label','target_selected'});
models=struct('id',{},'conditions',{},'contrastNames',{},'contrastWeights',{},'targetUnits',{});
targets=find(selected);
pmodAudit=table;
if strcmp(cfg.fit.strategy,'joint')
    conditions=struct([]);
    for k=1:count,conditions=append(conditions,condition(labels(k),group==k,e.onsetSeconds,usedDuration));end
    [conditions,pmodAudit]=psy.glm_pmod(conditions,t,cfg);
    if strcmp(unit,'condition')
        cn=cellstr(string(cfg.contrastNames(:)));cw=cfg.contrastWeights;
        if any(strlength(strtrim(string(cn)))==0)||numel(unique(cn))~=numel(cn)|| ...
                ~isnumeric(cw)||~isreal(cw)||numel(cn)~=size(cw,1)||size(cw,2)~=count||isempty(cw)||any(~isfinite(cw),'all')||any(all(cw==0,2))
            error('psy:GLMContrast','Condition contrasts must be finite, nonzero and match declared conditions');
        end
        targetUnits=zeros(size(cw,1),1); % 条件对比可以涉及多个单元，不能伪造单一目标ID。
    else
        cn=cellstr(labels(targets));cw=zeros(numel(targets),count);
        cw(sub2ind(size(cw),(1:numel(targets))',targets))=1;targetUnits=targets;
    end
    models(1)=struct('id','joint','conditions',conditions,'contrastNames',{cn},'contrastWeights',cw,'targetUnits',targetUnits);
else
    for target=targets'
        isTarget=group==target;conditions=condition('target',isTarget,e.onsetSeconds,usedDuration);
        if strcmp(cfg.fit.lssGrouping,'pooled')
            if any(~isTarget),conditions=append(conditions,condition('other',~isTarget,e.onsetSeconds,usedDuration));end
        else
            for k=1:numel(names)
                other=t.trial_type==names(k)&~isTarget;
                if any(other),conditions=append(conditions,condition(sprintf('other_%03d',k),other,e.onsetSeconds,usedDuration));end
            end
        end
        cw=[1 zeros(1,numel(conditions)-1)];
        models(end+1)=struct('id',char("lss_"+labels(target)),'conditions',conditions, ...
            'contrastNames',{{char(labels(target))}},'contrastWeights',cw,'targetUnits',target); %#ok<AGROW>
    end
end
plan=struct('schemaVersion',1,'estimateUnit',unit,'strategy',cfg.fit.strategy, ...
    'lssGrouping',cfg.fit.lssGrouping,'hrf',cfg.hrf.type,'expression',cfg.events.expression, ...
    'nEvents',n,'nUnits',count,'nTargets',numel(targets),'nModels',numel(models), ...
    'sourceEvents',t,'mapping',mapping,'units',units,'models',models,'pmodAudit',pmodAudit, ...
    'negativeOnsetCount',e.negativeOnsetCount,'originalEndOverrunSeconds',e.endOverrunSeconds, ...
    'modeledEndOverrunSeconds',max(0,max(e.onsetSeconds+usedDuration)-nSeconds));
end

function values=getColumn(t,name)
if ~ismember(name,t.Properties.VariableNames),error('psy:GLMEventUnit','Required event column: %s',name);end
values=string(t.(name));
if any(ismissing(values)|strlength(strtrim(values))==0|values=="n/a")
    error('psy:GLMEventUnit','%s must contain explicit nonempty IDs',name);
end
end

function c=condition(name,select,onset,duration)
c=struct('name',char(name),'onset',onset(select),'duration',duration(select), ...
    'tmod',0,'pmod',struct('name',{},'param',{},'poly',{}),'orth',0);
end

function list=append(list,c)
if isempty(list),list=c;else,list(end+1)=c;end
end
