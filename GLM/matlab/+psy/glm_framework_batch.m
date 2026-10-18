function report=glm_framework_batch(cfg)
%GLM_FRAMEWORK_BATCH 通用run/被试/组调度；数据发现与统计计算分离。
cfg=psy.glm_framework_options(cfg);
if ~isfile(fullfile(cfg.spmPath,'spm.m')),error('psy:SPMPath','Set SPM path');end
if strcmp(cfg.level,'group'),report=psy.glm_group_batch(cfg);return;end
o=detectImportOptions(cfg.manifestFile,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','run','bold','events','confounds','temporal_state'};
if ~all(ismember(required,o.VariableNames)),error('psy:GLMColumns','Missing manifest columns');end
if any(~ismember(o.VariableNames,[required {'mask'}]))
    error('psy:GLMColumns','Unknown manifest columns; supported optional column is mask');
end
o.DataLines=[2 Inf];o.ConsecutiveDelimitersRule='split';o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string');t=fillmissing(readtable(cfg.manifestFile,o),'constant',"");
if isempty(t),error('psy:NoRuns','Empty manifest');end
keys=strings(height(t),1);
for k=1:height(t)
    for field={'subject','session','run'}
        id=char(t.(field{1})(k));
        if strcmp(field{1},'session')&&isempty(id),continue;end
        if isempty(regexp(id,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('psy:UnsafeID','Invalid subject/session/run ID');end
    end
    keys(k)=lower(t.subject(k)+"/"+t.session(k)+"/"+t.run(k));
end
if numel(unique(keys))~=height(t),error('psy:DuplicateRun','Duplicate run');end
if isfolder(cfg.outputRoot)||isfile(cfg.outputRoot),error('psy:GLMExists','Choose a new output root');end
addpath(cfg.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
cfg.outputRoot=char(java.io.File(cfg.outputRoot).getCanonicalPath());
base=fileparts(char(java.io.File(cfg.manifestFile).getCanonicalPath()));
mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
report=struct([]);
if strcmp(cfg.level,'subject')
    report=subjectBatch(t,cfg,base);return;
end
for k=1:height(t)
    run=struct('subject',char(t.subject(k)),'session',char(t.session(k)),'name',char(t.run(k)), ...
        'temporal_state',char(t.temporal_state(k)),'mask',cfg.explicitMask);
    row=struct('subject',run.subject,'session',run.session,'run',run.name, ...
        'status','failed','nEvents',NaN,'nUnits',NaN,'nModels',NaN,'message','');
    try
        for field={'bold','events','confounds'}
            p=char(t.(field{1})(k));
            if isempty(p),error('psy:GLMInput','Empty %s path',field{1});end
            run.(field{1})=resolve(p,base);
        end
        if ismember('mask',t.Properties.VariableNames)&&strlength(t.mask(k))>0
            run.mask=resolve(char(t.mask(k)),base);
        end
        summary=psy.glm_framework_run(run,cfg,psy.run_output_dir(cfg.outputRoot,run));
        row.status=summary.status;row.nEvents=summary.nEvents;row.nUnits=summary.nUnits;row.nModels=summary.nModels;
    catch ex
        row.message=ex.message;
    end
    if isempty(report),report=row;else,report(end+1)=row;end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    if strcmp(row.status,'failed')&&~cfg.continueOnError,error('psy:GLMFailed','%s',row.message);end
end
end

function report=subjectBatch(t,cfg,base)
keys=lower(t.subject+"/"+t.session);
if cfg.subject.combineSessions,keys=lower(t.subject);end
groups=unique(keys,'stable');report=struct([]);effects=table;
for k=1:numel(groups)
    rows=find(keys==groups(k));runs=struct([]);
    row=struct('subject',char(t.subject(rows(1))),'session',char(t.session(rows(1))), ...
        'run','combined','status','failed','nEvents',NaN,'nUnits',NaN,'nModels',NaN,'message','');
    if cfg.subject.combineSessions,row.session='';end
    try
        for j=1:numel(rows)
            i=rows(j);r=struct('subject',char(t.subject(i)),'session',char(t.session(i)), ...
                'name',char(t.run(i)),'temporal_state',char(t.temporal_state(i)),'mask',cfg.explicitMask);
            for field={'bold','events','confounds'}
                p=char(t.(field{1})(i));if isempty(p),error('psy:GLMInput','Empty path');end
                r.(field{1})=resolve(p,base);
            end
            if ismember('mask',t.Properties.VariableNames)&&strlength(t.mask(i))>0,r.mask=resolve(char(t.mask(i)),base);end
            if isempty(runs),runs=r;else,runs(end+1)=r;end %#ok<AGROW>
        end
        out=fullfile(cfg.outputRoot,['sub-' row.subject]);
        if ~isempty(row.session),out=fullfile(out,['ses-' row.session]);end
        out=fullfile(out,'combined');
        if strcmp(cfg.engine,'glmsingle')
            summary=psy.glmsingle_run(runs,cfg,out);
        else
            summary=psy.glm_subject_run(runs,cfg,out);
        end
        row.status=summary.status;row.nEvents=summary.nEvents;row.nUnits=summary.nUnits;row.nModels=summary.nModels;
        if cfg.execute&&strcmp(cfg.engine,'spm_classical')
            e=readtable(fullfile(out,'subject_contrasts.tsv'),'FileType','text','Delimiter','\t','TextType','string');
            if isempty(effects),effects=e;else,effects=[effects;e];end %#ok<AGROW>
        end
    catch ex
        row.message=ex.message;
    end
    if isempty(report),report=row;else,report(end+1)=row;end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    if strcmp(row.status,'failed')&&~cfg.continueOnError,error('psy:GLMFailed','%s',row.message);end
end
% 只有所有被试均成功时才发布可直接送入二级的总清单，避免静默缩小样本。
if cfg.execute&&strcmp(cfg.engine,'spm_classical')&&~any(strcmp({report.status},'failed'))
    writetable(effects,fullfile(cfg.outputRoot,'subject_contrasts.tsv'),'FileType','text','Delimiter','\t');
end
end

function p=resolve(p,base)
if ~java.io.File(p).isAbsolute(),p=fullfile(base,p);end
p=char(java.io.File(p).getCanonicalPath());
if ~isfile(p),error('psy:GLMInput','Missing input: %s',p);end
end
