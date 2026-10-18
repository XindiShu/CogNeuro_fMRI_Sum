function report=glm_batch(cfg)
%GLM_BATCH 可组合框架入口；没有model分支的旧配置仍按独立run执行。
if isfield(cfg,'model')
    report=psy.glm_framework_batch(cfg);
    return;
end
if ~isfile(fullfile(cfg.spmPath,'spm.m')), error('psy:SPMPath','Set SPM path'); end
addpath(cfg.spmPath); spm('defaults','fmri'); spm_jobman('initcfg');
o=detectImportOptions(cfg.manifestFile,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','run','bold','events','confounds','temporal_state'};
if ~all(ismember(required,o.VariableNames)), error('psy:GLMColumns','Missing manifest columns'); end
o.DataLines=[2 Inf]; o.ConsecutiveDelimitersRule='split'; o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string'); t=fillmissing(readtable(cfg.manifestFile,o),'constant',"");
keys=strings(height(t),1);
for i=1:height(t)
    for field={'subject','session','run'}
        a=char(t.(field{1})(i)); if strcmp(field{1},'session')&&isempty(a), continue; end
        if isempty(regexp(a,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')), error('psy:UnsafeID','Invalid ID'); end
    end
    keys(i)=lower(t.subject(i)+"/"+t.session(i)+"/"+t.run(i));
end
if isempty(t), error('psy:NoRuns','Empty manifest'); end
if numel(unique(keys))~=numel(keys), error('psy:DuplicateRun','Duplicate run'); end
if isfolder(cfg.outputRoot), error('psy:GLMExists','Choose new output root'); end
mkdir(cfg.outputRoot); base=fileparts(char(java.io.File(cfg.manifestFile).getCanonicalPath())); report=struct([]);
for i=1:height(t)
    r=struct('subject',char(t.subject(i)),'session',char(t.session(i)),'name',char(t.run(i)),'temporal_state',char(t.temporal_state(i)));
    row=struct('subject',r.subject,'session',r.session,'run',r.name,'status','failed','message','');
    try
        for field={'bold','events','confounds'}
            p=char(t.(field{1})(i)); if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
            p=char(java.io.File(p).getCanonicalPath()); if ~isfile(p), error('psy:GLMInput','Missing %s',p); end
            r.(field{1})=p;
        end
        row.status=psy.glm_run(r,cfg,psy.run_output_dir(cfg.outputRoot,r));
    catch ex
        row.message=ex.message;
    end
    if isempty(report), report=row; else, report(end+1)=row; end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    if strcmp(row.status,'failed')&&~cfg.continueOnError, error('psy:GLMFailed','%s',row.message); end
end
end
