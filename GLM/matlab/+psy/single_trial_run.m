function summary=single_trial_run(run,cfg,out)
%SINGLE_TRIAL_RUN 每行事件为一个估计单元；条件平均、LSA、LSS 使用独立模型。
% LSA：全部事件行各一列；LSS：目标事件一列、其他事件按配置合并。保留原时长。
if ~strcmp(run.temporal_state,'unfiltered_unregressed')
    error('psy:SingleTrialState','Use unfiltered/unregressed BOLD');
end
if isfolder(out), error('psy:SingleTrialExists','Choose a new output directory'); end
methods=string(cfg.methods);
if isempty(methods) || numel(unique(methods))~=numel(methods) || ...
        any(~ismember(methods,["LSA","LSS"]))
    error('psy:SingleTrialMethods','Choose unique LSA/LSS methods');
end
if ~ismember(string(cfg.lssGrouping),["all_other","by_condition"])
    error('psy:SingleTrialGrouping','Use all_other or by_condition');
end
v=spm_vol(run.bold); h=niftiinfo(run.bold); tr=h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond', tr=tr/1000;
    case 'microsecond', tr=tr/1e6;
    otherwise, error('psy:TimeUnits','Unknown time units');
end
if numel(v)<3 || ~isfinite(tr) || tr<=0, error('psy:SingleTrialTR','Invalid BOLD/TR'); end
e=psy.read_events_tsv(run.events,numel(v)*tr);
if any(ismember({'amplitude','modulation','pmod'},e.table.Properties.VariableNames))
    error('psy:SingleTrialAmplitude','Event amplitudes/modulation not yet supported');
end
n=numel(e.onsetSeconds);
if n<2, error('psy:SingleTrialEvents','At least two event rows required'); end
targets=1:n;
if isfield(cfg,'targetConditions') && ~isempty(cfg.targetConditions)
    requested=string(cfg.targetConditions);
    if numel(unique(requested))~=numel(requested) || ...
            ~all(ismember(requested,e.table.trial_type))
        error('psy:SingleTrialTargets','Target conditions must be distinct and present');
    end
    targets=find(ismember(e.table.trial_type,requested))';
end
labels=arrayfun(@(k)sprintf('event_%03d',k),(1:n)','UniformOutput',false);
mapping=table((1:n)',string(labels),e.onsetSeconds,e.durationSeconds,e.table.trial_type, ...
    'VariableNames',{'event_index','event_label','onset_seconds','duration_seconds','original_condition'});
mapping.target_selected=ismember((1:n)',targets);
mkdir(out); eventDir=fullfile(out,'model_events'); mkdir(eventDir);
writetable(mapping,fullfile(out,'event_mapping.tsv'),'FileType','text','Delimiter','\t');
models=struct('method',{},'eventIndex',{},'status',{},'modelDir',{});
if any(methods=="LSA")
    file=fullfile(eventDir,'lsa_events.tsv');
    writeEvents(file,e.onsetSeconds,e.durationSeconds,string(labels));
    c=cfg;c.conditions=labels;c.contrastNames=labels(targets);
    contrasts=eye(n);c.contrastWeights=contrasts(targets,:);
    r=run;r.events=file; modelDir=fullfile(out,'LSA');
    status=psy.glm_run(r,c,modelDir);
    models(end+1)=struct('method','LSA','eventIndex',0,'status',status,'modelDir',modelDir);
end
if any(methods=="LSS")
    for target=targets
        [trialLabels,names]=lssLabels(e.table.trial_type,target,cfg.lssGrouping);
        file=fullfile(eventDir,sprintf('lss_event_%03d.tsv',target));
        writeEvents(file,e.onsetSeconds,e.durationSeconds,trialLabels);
        c=cfg;c.conditions=names;c.contrastNames=labels(target);
        c.contrastWeights=[1 zeros(1,numel(names)-1)];
        r=run;r.events=file;modelDir=fullfile(out,'LSS',labels{target});
        status=psy.glm_run(r,c,modelDir);
        models(end+1)=struct('method','LSS','eventIndex',target,'status',status,'modelDir',modelDir); %#ok<AGROW>
    end
end
summary=struct('nEvents',n,'nTargets',numel(targets),'nFrames',numel(v),'trSeconds',tr, ...
    'methods',{cellstr(methods)},'lssGrouping',cfg.lssGrouping,'nModels',numel(models), ...
    'eventUnit','one row of the supplied events TSV; may represent a block, not a stimulus trial', ...
    'status','single_trial_prepared_not_estimated');
if cfg.execute
    if ~all(strcmp({models.status},'run_glm_estimated_spatial_limitations_unchanged'))
        error('psy:SingleTrialIncomplete','At least one model was not estimated');
    end
    summary.status='single_trial_models_estimated';
end
marker='SINGLE_TRIAL_PREPARED.mat';
if cfg.execute, marker='SINGLE_TRIAL_COMPLETE.mat'; end
save(fullfile(out,marker),'summary','models','mapping','run','cfg');
f=fopen(fullfile(out,'summary.json'),'w');
if f<0, error('psy:SingleTrialOutput','Cannot write summary JSON'); end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(summary,PrettyPrint=true));clear cleanup;
end

function writeEvents(file,onset,duration,labels)
t=table(onset,duration,labels,'VariableNames',{'onset','duration','trial_type'});
writetable(t,file,'FileType','text','Delimiter','\t');
end

function [labels,names]=lssLabels(original,target,grouping)
n=numel(original);labels=repmat("other",n,1);labels(target)="target";
if strcmp(grouping,'by_condition')
    groups=unique(original,'stable');
    for k=1:numel(groups)
        idx=original==groups(k);idx(target)=false;
        labels(idx)=sprintf('other_condition_%03d',k);
    end
end
names=[{'target'} cellstr(unique(labels(labels~="target"),'stable'))'];
end
