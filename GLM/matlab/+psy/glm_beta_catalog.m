function [catalog,links,files]=glm_beta_catalog(manifestFile)
%GLM_BETA_CATALOG 三种来源适配成统一估计目录；多事件合一的item只占一行beta。
manifestFile=psy.glm_absolute_path(manifestFile);entries=psy.glm_read_table(manifestFile,{'id','engine','source_dir','variant'});
if numel(unique(lower(entries.id)))~=height(entries),error('psy:GLMBetaCatalog','Duplicate source IDs');end
catalog=table;links=table;files=string(manifestFile);seen=strings(0,1);
for entry=1:height(entries)
    id=char(entries.id(entry));
    if isempty(regexp(id,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('psy:GLMBetaCatalog','Unsafe/empty source ID');end
    folder=psy.glm_absolute_path(entries.source_dir(entry),fileparts(manifestFile));engine=char(entries.engine(entry));variant=char(entries.variant(entry));
    key=lower(string(engine)+"|"+string(folder)+"|"+string(variant));
    if any(seen==key),error('psy:GLMBetaCatalog','Repeated source/variant under another ID');end
    seen(end+1)=key; %#ok<AGROW>
    switch engine
        case 'framework'
            if ~strcmp(variant,'auto'),error('psy:GLMBetaCatalog','Framework variant must be auto');end
            complete=fullfile(folder,'GLM_FRAMEWORK_COMPLETE.mat');require(complete);s=load(complete);
            p=load(fullfile(folder,'model_plan.mat'));plan=p.plan;
            if strcmp(plan.estimateUnit,'condition'),error('psy:GLMBetaCatalog','Use effect export for condition GLM; beta catalog requires explicit target units');end
            method='LSA';if strcmp(plan.strategy,'lss'),method='LSS';end
            outputs=psy.glm_read_table(fullfile(folder,'model_outputs.tsv'));units=plan.units;
            targets=str2double(outputs.target_unit_index);selected=targets>0&str2double(outputs.estimated)==1&strlength(outputs.canonical_beta)>0;
            if ismember('statistic',outputs.Properties.VariableNames),selected=selected&outputs.statistic=="T";end
            outputs=outputs(selected,:);targets=targets(selected);
            expected=find(units.target_selected);
            if isempty(targets)||numel(unique(targets))~=numel(targets)||~isequal(sort(targets),sort(expected))
                error('psy:GLMBetaCatalog','Missing/ambiguous estimated targets');
            end
            files=[files;string(complete);string(fullfile(folder,'model_plan.mat'));string(fullfile(folder,'model_outputs.tsv'))]; %#ok<AGROW>
            for k=1:numel(targets)
                u=targets(k);label=char(units.model_label(u));if strcmp(method,'LSS'),label='target';end
                model=fullfile(folder,'models',char(outputs.model(k)));[image,mask,spm]=spmBeta(model,label);
                if ~strcmpi(image,psy.glm_absolute_path(outputs.canonical_beta(k),folder)),error('psy:GLMBetaCatalog','Canonical beta does not match SPM column');end
                row=baseRow(id,u,s.run,folder,method,method,plan.estimateUnit,char(units.source_id(u)),char(units.condition(u)),s.cfg.hrf.type,plan.expression,image,1,mask,spm,spmUnits);
                catalog=append(catalog,row);files=[files;string(image);string(mask);string(spm)]; %#ok<AGROW>
                eventRows=find(plan.mapping.unit_index==u);
                for j=eventRows'
                    m=plan.mapping(j,:);links=append(links,eventRow(row.estimate_id,s.run.name,j,plan.sourceEvents,j,m.onset_seconds,m.onset_seconds,m.original_duration_seconds,m.modeled_duration_seconds));
                end
            end
        case 'single_trial'
            if ~ismember(variant,{'LSA','LSS'}),error('psy:GLMBetaCatalog','Legacy variant is LSA or LSS');end
            complete=fullfile(folder,'SINGLE_TRIAL_COMPLETE.mat');require(complete);s=load(complete);
            if ~ismember(variant,s.summary.methods),error('psy:GLMBetaCatalog','Requested legacy method not estimated');end
            events=table;
            if isfile(s.run.events),e=psy.read_events_tsv(s.run.events,Inf);events=e.table;files=[files;string(s.run.events)];end %#ok<AGROW>
            mapping=s.mapping;targets=find(mapping.target_selected);files=[files;string(complete)]; %#ok<AGROW>
            hrf='canonical';if isfield(s.cfg,'hrf'),hrf=s.cfg.hrf.type;end
            for u=targets'
                label=char(mapping.event_label(u));model=fullfile(folder,'LSA');
                if strcmp(variant,'LSS'),model=fullfile(folder,'LSS',label);label='target';end
                [image,mask,spm]=spmBeta(model,label);
                row=baseRow(id,u,s.run,folder,variant,variant,'event',char(mapping.event_label(u)),char(mapping.original_condition(u)),hrf,'duration',image,1,mask,spm,spmUnits);
                catalog=append(catalog,row);files=[files;string(image);string(mask);string(spm)]; %#ok<AGROW>
                links=append(links,eventRow(row.estimate_id,s.run.name,u,events,u,mapping.onset_seconds(u),mapping.onset_seconds(u),mapping.duration_seconds(u),mapping.duration_seconds(u)));
            end
        case 'glmsingle'
            if ~ismember(variant,{'B','C','D'}),error('psy:GLMBetaCatalog','GLMsingle event variants are B/C/D; A is on/off');end
            complete=fullfile(folder,'GLMSINGLE_COMPLETE.mat');require(complete);s=load(complete);p=load(fullfile(folder,'preflight.mat'));
            if ~ismember(variant,s.summary.modelTypes),error('psy:GLMBetaCatalog','Requested GLMsingle type not estimated');end
            betaFile=fullfile(folder,['TYPE' variant],'event_betas.nii');mask=fullfile(folder,'analysis_mask.nii');mapping=p.plan.mapping;
            check=psy.glm_read_table(fullfile(folder,['TYPE' variant],'beta_mapping.tsv'));
            if height(check)~=height(mapping)||~isequal(str2double(check.beta_index),mapping.beta_index)|| ...
                    ~isequal(str2double(check.run_index),mapping.run_index)||~isequal(str2double(check.source_event_index),mapping.source_event_index)|| ...
                    ~isequal(string(check.identity),string(mapping.identity))||~isequal(string(check.condition),string(mapping.condition))
                error('psy:GLMBetaCatalog','GLMsingle mapping mismatch');
            end
            header=spm_vol(betaFile);if numel(header)~=height(mapping),error('psy:GLMBetaCatalog','GLMsingle fourth-axis count mismatch');end
            files=[files;string(complete);string(fullfile(folder,'preflight.mat'));string(fullfile(folder,['TYPE' variant],'beta_mapping.tsv'));string(betaFile);string(mask)]; %#ok<AGROW>
            for k=1:height(mapping)
                m=mapping(k,:);r=p.runs(m.run_index);events=p.plan.sourceTables{m.run_index};j=m.source_event_index;
                row=baseRow(id,m.beta_index,r,folder,'GLMsingle',variant,'event',sprintf('event_%06d',m.beta_index),char(m.condition),s.cfg.hrf.type,s.cfg.events.expression,betaFile,m.beta_index,mask,'',s.summary.units);
                row.cv_identity=string(m.identity);
                catalog=append(catalog,row);
                links=append(links,eventRow(row.estimate_id,r.name,j,events,j,m.onset_seconds,m.grid_onset_seconds,m.original_duration_seconds,m.modeled_duration_seconds));
            end
        otherwise
            error('psy:GLMBetaCatalog','Engine is framework/single_trial/glmsingle');
    end
end
if isempty(catalog)||numel(unique(catalog.estimate_id))~=height(catalog),error('psy:GLMBetaCatalog','Empty/nonunique catalog');end
files=unique(files,'stable');
end
function r=baseRow(id,u,run,folder,method,variant,unit,unitId,condition,hrf,expression,image,frame,mask,spm,units)
r=table(string(sprintf('%s__%06d',id,u)),string(id),string(run.subject),string(run.session),string(run.name),string(method),string(variant), ...
    string(unit),string(unitId),double(u),string(condition),string(hrf),string(expression),string(units),string(image),double(frame),string(mask),string(spm),string(folder), ...
    'VariableNames',{'estimate_id','source_id','subject','session','run','method','variant','estimate_unit','unit_id','unit_index','condition','hrf','duration_model','units','image_path','volume_index','mask_path','spm_mat','source_dir'});
r.cv_identity="";r.source_engine="spm_classical";if strcmp(method,'GLMsingle'),r.source_engine="glmsingle";end
end
function r=eventRow(estimateId,run,prepared,events,j,onset,modeledOnset,duration,modeledDuration)
source=prepared;trial="";stimulus="";
if ~isempty(events)
    if ismember('original_event_index',events.Properties.VariableNames),source=str2double(string(events.original_event_index(j)));end
    if ismember('trial_id',events.Properties.VariableNames),trial=string(events.trial_id(j));end
    if ismember('stimulus_id',events.Properties.VariableNames),stimulus=string(events.stimulus_id(j));end
end
if ~isscalar(source)||~isfinite(source)||source<1||fix(source)~=source,error('psy:GLMBetaCatalog','Invalid original event index');end
r=table(string(estimateId),string(run),double(prepared),double(source),trial,stimulus,onset,modeledOnset,duration,modeledDuration, ...
    'VariableNames',{'estimate_id','run','prepared_event_index','source_event_index','trial_id','stimulus_id','onset_seconds','modeled_onset_seconds','original_duration_seconds','modeled_duration_seconds'});
r.onset_error_seconds=modeledOnset-onset;
end
function [image,mask,spm]=spmBeta(model,label)
spm=fullfile(model,'SPM.mat');require(spm);s=load(spm,'SPM');column=find(strcmp(s.SPM.xX.name,sprintf('Sn(1) %s*bf(1)',label)));
if numel(column)~=1,error('psy:GLMBetaCatalog','Ambiguous/missing canonical target column');end
image=psy.glm_absolute_path(s.SPM.Vbeta(column).fname,model);mask=fullfile(model,'mask.nii');require(image);require(mask);
end
function require(file)
if ~isfile(file),error('psy:GLMBetaCatalog','Completed model/file required: %s',file);end
end
function t=append(t,row)
if isempty(t),t=row;else,t=[t;row];end
end
function u=spmUnits
u='SPM scaled model amplitude; see source SPM.xGX; not automatically percent BOLD';
end
