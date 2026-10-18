function plan=glmsingle_plan(files,nFrames,tr,cfg)
%GLMSINGLE_PLAN 事件→二值TR设计及完整beta行映射；收集阻断原因，不静默降级。
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.engine,'glmsingle'),error('psy:GLMsingleConfig','Set engine=glmsingle');end
if ~iscell(files)||numel(files)~=numel(nFrames)||isempty(files)||~isscalar(tr)||~isfinite(tr)||tr<=0|| ...
        any(~isfinite(nFrames)|nFrames<3|fix(nFrames)~=nFrames)
    error('psy:GLMsinglePlan','Invalid run files/frame counts/TR');
end
issues=strings(0,1);mapping=table;tables=cell(1,numel(files));
for r=1:numel(files)
    e=psy.read_events_tsv(files{r},nFrames(r)*tr);t=e.table;tables{r}=t;n=height(t);
    if ~ismember(cfg.glmsingle.identityColumn,t.Properties.VariableNames)
        identity=repmat("",n,1);issues(end+1)="missing identity column in run "+r;
    else
        identity=string(t.(cfg.glmsingle.identityColumn));
        if any(ismissing(identity)|strlength(strtrim(identity))==0|identity=="n/a")
            issues(end+1)="missing/invalid event identity in run "+r;identity(ismissing(identity))="";
        end
    end
    if strcmp(cfg.model.unit,'trial')
        if ~ismember('trial_id',t.Properties.VariableNames)||any(ismissing(t.trial_id)|strlength(strtrim(t.trial_id))==0|t.trial_id=="n/a")||numel(unique(t.trial_id))~=n
            issues(end+1)="trial unit requires unique explicit trial_id within run "+r;
        end
    end
    modeled=e.durationSeconds;
    if strcmp(cfg.events.expression,'fixed'),modeled(:)=cfg.events.fixedDurationSeconds;end
    frames=round(e.onsetSeconds/tr);grid=frames*tr;delta=grid-e.onsetSeconds;
    tolerance=1e-6;
    if strcmp(cfg.glmsingle.onsetMode,'nearest'),tolerance=cfg.glmsingle.maxOnsetErrorSeconds;end
    if any(abs(delta)>tolerance),issues(end+1)="onset grid/tolerance violated in run "+r;end
    if any(e.onsetSeconds<0|frames<0|frames>=nFrames(r)),issues(end+1)="onset cannot be represented inside run "+r;end
    if numel(unique(frames))~=n,issues(end+1)="multiple events collide at one TR in run "+r;end
    if (nFrames(r)-1-max(frames))*tr<cfg.glmsingle.minEndBufferSeconds-1e-6
        issues(end+1)="insufficient ending buffer in run "+r;
    end
    observed=setdiff(intersect({'amplitude','modulation','pmod'},t.Properties.VariableNames),{cfg.glmsingle.identityColumn});
    if ~isempty(observed),issues(end+1)="unsupported amplitude/modulation fields in run "+r;end
    entry=table(repmat(r,n,1),(1:n)',identity,t.trial_type,e.onsetSeconds,e.durationSeconds,modeled,grid,delta,frames+1, ...
        'VariableNames',{'run_index','source_event_index','identity','condition','onset_seconds','original_duration_seconds', ...
        'modeled_duration_seconds','grid_onset_seconds','onset_error_seconds','frame_index'});
    entry=sortrows(entry,{'frame_index','source_event_index'});
    if isempty(mapping),mapping=entry;else,mapping=[mapping;entry];end %#ok<AGROW>
end
mapping.beta_index=(1:height(mapping))';
if ~isequal(sort(unique(mapping.condition)),sort(string(cfg.conditions(:))))
    issues(end+1)="conditions must exactly match the observed trial_type set";
end
durations=mapping.modeled_duration_seconds;stimdur=durations(1);
if any(~isfinite(durations)|durations<=0)||max(abs(durations-stimdur))>1e-6
    issues(end+1)="GLMsingle needs one common positive modeled event duration across all runs";
end
if abs(stimdur*10-round(stimdur*10))>1e-5
    issues(end+1)="stimulus duration must be a multiple of 0.1 seconds for the native HRF library";
end
identities=unique(mapping.identity,'stable');idIndex=zeros(height(mapping),1);runCounts=zeros(numel(identities),1);eventCounts=runCounts;
for k=1:numel(identities)
    selected=mapping.identity==identities(k);idIndex(selected)=k;runCounts(k)=numel(unique(mapping.run_index(selected)));eventCounts(k)=nnz(selected);
    if numel(unique(mapping.condition(selected)))~=1,issues(end+1)="one identity spans multiple trial_type labels";end
end
mapping.identity_index=idIndex;design=cell(1,numel(files));foldShared=zeros(numel(files),1);
for r=1:numel(files)
    selected=mapping.run_index==r;frames=mapping.frame_index(selected);ids=mapping.identity_index(selected);
    design{r}=zeros(nFrames(r),numel(identities));
    valid=frames>=1&frames<=nFrames(r);
    design{r}(sub2ind(size(design{r}),frames(valid),ids(valid)))=1;
    testIds=unique(mapping.identity(selected));trainIds=unique(mapping.identity(~selected));foldShared(r)=numel(intersect(testIds,trainIds));
end
if (cfg.glmsingle.wantDenoise||cfg.glmsingle.wantRidge)&&(numel(files)<2||any(foldShared<1))
    issues(end+1)="denoise/ridge cross-validation requires shared identities in every held-out run";
end
identityTable=table((1:numel(identities))',identities,eventCounts,runCounts,'VariableNames',{'identity_index','identity','n_events','n_runs'});
plan=struct('ready',isempty(issues),'issues',unique(issues,'stable'),'mapping',mapping,'identities',identityTable, ...
    'design',{design},'sourceTables',{tables},'stimdurSeconds',stimdur,'trSeconds',tr,'nEvents',height(mapping), ...
    'nIdentities',numel(identities),'repeatedAcrossRuns',nnz(runCounts>1),'sharedIdentitiesPerFold',foldShared);
end
