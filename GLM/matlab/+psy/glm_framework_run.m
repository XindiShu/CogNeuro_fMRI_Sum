function summary=glm_framework_run(run,cfg,out)
%GLM_FRAMEWORK_RUN 先生成估计单元及模型计划，再复用SPM计算层；不重跑预处理。
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.engine,'spm_classical'),error('psy:GLMEngine','Use glmsingle_run for the GLMsingle engine');end
out=char(java.io.File(out).getCanonicalPath());
if ~isfield(run,'mask')||isempty(run.mask),run.mask=cfg.explicitMask;end
if ~strcmp(run.temporal_state,'unfiltered_unregressed'),error('psy:GLMState','Use verified unfiltered/unregressed BOLD');end
if isfolder(out)||isfile(out),error('psy:GLMExists','Choose a new run output directory');end
v=spm_vol(run.bold);h=niftiinfo(run.bold);
if numel(h.PixelDimensions)<4,error('psy:GLMTR','A 4-D BOLD with time spacing is required');end
tr=h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond',tr=tr/1000;
    case 'microsecond',tr=tr/1e6;
    otherwise,error('psy:TimeUnits','Unknown time units');
end
if numel(v)<3||~isfinite(tr)||tr<=0,error('psy:GLMTR','Invalid series/TR');end
plan=psy.glm_framework_plan(run.events,numel(v)*tr,cfg);
confounds=psy.confound_design(run.confounds,cfg.design);
if confounds.nFrames~=numel(v),error('psy:GLMLength','BOLD/confounds length mismatch');end
mkdir(out);save(fullfile(out,'model_plan.mat'),'plan','cfg','run');
writetable(plan.mapping,fullfile(out,'event_mapping.tsv'),'FileType','text','Delimiter','\t');
writetable(plan.units,fullfile(out,'unit_mapping.tsv'),'FileType','text','Delimiter','\t');
if ~isempty(plan.pmodAudit),writetable(plan.pmodAudit,fullfile(out,'pmod_values.tsv'),'FileType','text','Delimiter','\t');end
used=plan.sourceEvents;used.modeled_duration_seconds=plan.mapping.modeled_duration_seconds;
writetable(used,fullfile(out,'events_used.tsv'),'FileType','text','Delimiter','\t');
inputFields={'bold','events','confounds'};
if isfield(run,'mask')&&~isempty(run.mask),inputFields{end+1}='mask';end
inputPaths=string(cellfun(@(field)run.(field),inputFields,'UniformOutput',false))';
inputBytes=zeros(numel(inputPaths),1);
for k=1:numel(inputPaths),entry=dir(inputPaths(k));inputBytes(k)=entry.bytes;end
inputs=table(string(inputFields)',inputPaths,inputBytes,'VariableNames',{'role','path','bytes'});
writetable(inputs,fullfile(out,'input_files.tsv'),'FileType','text','Delimiter','\t');
modelRows=struct([]);outputRows=struct([]);
for k=1:numel(plan.models)
    model=plan.models(k);c=cfg;c.conditions={model.conditions.name};
    c.contrastNames=model.contrastNames;c.contrastWeights=model.contrastWeights;
    modelDir=fullfile(out,'models',model.id);
    status=psy.glm_run(run,c,modelDir,model);
    row=struct('model',model.id,'status',status,'path',modelDir);
    if isempty(modelRows),modelRows=row;else,modelRows(end+1)=row;end %#ok<AGROW>
    columnNames={};
    if cfg.execute,p=load(fullfile(modelDir,'SPM.mat'),'SPM');columnNames=p.SPM.xX.name;end
    if cfg.execute
        p=load(fullfile(modelDir,'model_contrasts.mat'));catalog=p.contrasts;
        stats=psy.glm_contrast_table(catalog,modelDir,true);
    else
        % 以虚拟列构建语义目录，不将尚不存在的beta/统计图标为已估计。
        fakeNames=semanticColumns(c);fakeX=zeros(0,numel(fakeNames));
        catalog=psy.glm_model_contrasts(fakeNames,c,fakeX,0);
        stats=psy.glm_contrast_table(catalog,modelDir,false);
    end
    for j=1:numel(catalog)
        source=catalog(j).sourceContrast;target=0;
        if source>0,target=model.targetUnits(source);end
        betaPath='';
        if target>0&&cfg.execute
            label='target';
            if strcmp(cfg.fit.strategy,'joint'),label=char(plan.units.model_label(target));end
            idx=find(strcmp(columnNames,sprintf('Sn(1) %s*bf(1)',label)));
            if numel(idx)~=1,error('psy:GLMColumn','Target canonical beta mapping is ambiguous');end
            betaPath=fullfile(modelDir,sprintf('beta_%04d.nii',idx));
        end
        row=struct('model',model.id,'contrast',catalog(j).name,'statistic',catalog(j).stat, ...
            'target_unit_index',target,'canonical_beta',betaPath, ...
            'contrast_path',char(stats.effect_path(j)), ...
            't_path',char(stats.stat_path(j)), ...
            'estimated',cfg.execute);
        if strcmp(catalog(j).stat,'F'),row.t_path='';end
        row.statistic_path=char(stats.stat_path(j));
        if isempty(outputRows),outputRows=row;else,outputRows(end+1)=row;end %#ok<AGROW>
    end
    writetable(struct2table(modelRows,'AsArray',true),fullfile(out,'model_status.tsv'),'FileType','text','Delimiter','\t');
    writetable(struct2table(outputRows,'AsArray',true),fullfile(out,'model_outputs.tsv'),'FileType','text','Delimiter','\t');
end

status='framework_prepared_not_estimated';marker='GLM_FRAMEWORK_PREPARED.mat';
if cfg.execute,status='framework_models_estimated';marker='GLM_FRAMEWORK_COMPLETE.mat';end
summary=struct('schemaVersion',1,'status',status,'estimateUnit',cfg.model.unit, ...
    'expression',cfg.events.expression,'hrf',cfg.hrf.type,'strategy',cfg.fit.strategy, ...
    'lssGrouping',cfg.fit.lssGrouping,'level',cfg.level,'engine',cfg.engine, ...
    'pmodEnabled',cfg.pmod.enabled, ...
    'nEvents',plan.nEvents,'nUnits',plan.nUnits,'nTargets',plan.nTargets, ...
    'nModels',plan.nModels,'nFrames',numel(v),'trSeconds',tr, ...
    'scientificValidation','engineering execution only; event semantics, anatomy, residuals and multiplicity require study-specific review');
f=fopen(fullfile(out,'summary.json'),'w');
if f<0,error('psy:GLMOutput','Cannot write summary JSON');end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(summary,PrettyPrint=true));clear cleanup;
save(fullfile(out,marker),'summary','modelRows','run','cfg');
end

function columns=semanticColumns(cfg)
labels=cfg.conditions;
if cfg.pmod.enabled
    for m=reshape(cfg.pmod.modulators,1,[])
        for power=1:m.poly,labels{end+1}=sprintf('%sx%s^%d',m.condition,m.name,power);end %#ok<AGROW>
    end
end
n=1;if strcmp(cfg.hrf.type,'fir'),n=cfg.hrf.fir.nBins;end
columns={};
for k=1:numel(labels)
    for b=1:n,columns{end+1}=sprintf('Sn(1) %s*bf(%d)',labels{k},b);end %#ok<AGROW>
end
end
