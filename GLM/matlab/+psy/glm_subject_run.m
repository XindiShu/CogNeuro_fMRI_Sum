function summary=glm_subject_run(runs,cfg,out)
%GLM_SUBJECT_RUN 同被试多run条件GLM；支持pmod/FIR，各run匹配效应等权平均。
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.engine,'spm_classical'),error('psy:GLMEngine','Use glmsingle_run for the GLMsingle engine');end
if ~strcmp(cfg.level,'subject')||isempty(runs),error('psy:GLMLevel','Subject level and nonempty runs required');end
if numel(unique(lower(string({runs.subject}))))~=1,error('psy:GLMSubject','Cannot combine different subjects');end
if ~cfg.subject.combineSessions&&numel(unique(lower(string({runs.session}))))~=1
    error('psy:GLMSubject','Different sessions require combineSessions=true');
end
keys=lower(string({runs.session})+"/"+string({runs.name}));
boldPaths=arrayfun(@(r)string(char(java.io.File(r.bold).getCanonicalPath())),runs);
if numel(unique(keys))~=numel(runs)||numel(unique(lower(boldPaths)))~=numel(runs)
    error('psy:DuplicateRun','Duplicate run identity or BOLD input');
end
out=char(java.io.File(out).getCanonicalPath());
if isfolder(out)||isfile(out),error('psy:GLMExists','Choose a new subject directory');end
plans=cell(1,numel(runs));models=struct([]);nEvents=0;counts=zeros(numel(runs),1);tr=counts;
for k=1:numel(runs)
    h=niftiinfo(runs(k).bold);v=spm_vol(runs(k).bold);
    if numel(h.PixelDimensions)<4,error('psy:GLMTR','4-D BOLD required');end
    tr(k)=h.PixelDimensions(4);
    switch lower(h.TimeUnits)
        case 'second'
        case 'millisecond',tr(k)=tr(k)/1000;
        case 'microsecond',tr(k)=tr(k)/1e6;
        otherwise,error('psy:TimeUnits','Unknown time units');
    end
    counts(k)=numel(v);plans{k}=psy.glm_framework_plan(runs(k).events,counts(k)*tr(k),cfg);
    nEvents=nEvents+plans{k}.nEvents;
    if isempty(models),models=plans{k}.models;else,models(k)=plans{k}.models;end
end
% 计算层负责所有run的几何/TR/混杂与时间状态检查；失败不生成完成标记。
modelDir=fullfile(out,'model');psy.glm_run(runs,cfg,modelDir,models);
save(fullfile(out,'subject_plan.mat'),'plans','runs','cfg');
for k=1:numel(runs)
    prefix=sprintf('run_%03d',k);
    writetable(plans{k}.mapping,fullfile(out,[prefix '_event_mapping.tsv']),'FileType','text','Delimiter','\t');
    if ~isempty(plans{k}.pmodAudit),writetable(plans{k}.pmodAudit,fullfile(out,[prefix '_pmod_values.tsv']),'FileType','text','Delimiter','\t');end
end
runIndex=(1:numel(runs))';subject=string({runs.subject})';session=string({runs.session})';run=string({runs.name})';
bold=string({runs.bold})';events=string({runs.events})';confounds=string({runs.confounds})';
run_weight=ones(numel(runs),1)/numel(runs);
inputs=table(runIndex,subject,session,run,bold,events,confounds,counts,tr,run_weight);
writetable(inputs,fullfile(out,'run_mapping.tsv'),'FileType','text','Delimiter','\t');
status='subject_prepared_not_estimated';marker='GLM_SUBJECT_PREPARED.mat';
if cfg.execute
    p=load(fullfile(modelDir,'model_contrasts.mat'));catalog=p.contrasts;
    eligible=find(strcmp({catalog.stat},'T')); % F/ESS没有可送入单样本组模块的有符号效应图。
    subject=repmat(string(runs(1).subject),numel(eligible),1);
    session=repmat(string(runs(1).session),numel(subject),1);
    if cfg.subject.combineSessions,session(:)="";end
    contrast=string({catalog(eligible).name})';contrast_image=strings(numel(subject),1);
    mask=repmat(string(fullfile(modelDir,'mask.nii')),numel(subject),1);
    for k=1:numel(subject),contrast_image(k)=string(fullfile(modelDir,sprintf('con_%04d.nii',eligible(k))));end
    effects=table(subject,session,contrast,contrast_image,mask);
    writetable(effects,fullfile(out,'subject_contrasts.tsv'),'FileType','text','Delimiter','\t');
    status='subject_models_estimated';marker='GLM_SUBJECT_COMPLETE.mat';
end
summary=struct('status',status,'nEvents',nEvents,'nUnits',numel(cfg.conditions)*numel(runs), ...
    'nModels',1,'nRuns',numel(runs),'nFrames',sum(counts),'runWeights',run_weight', ...
    'hrf',cfg.hrf.type,'pmodEnabled',cfg.pmod.enabled, ...
    'aggregation','arithmetic mean of matched run-specific task contrasts; not inverse-variance pooling');
save(fullfile(out,marker),'summary','cfg','runs');
f=fopen(fullfile(out,'summary.json'),'w');cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s',jsonencode(summary,PrettyPrint=true));clear cleanup;
end
