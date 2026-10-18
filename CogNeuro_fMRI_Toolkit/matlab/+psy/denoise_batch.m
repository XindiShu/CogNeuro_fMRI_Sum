function report=denoise_batch(cfg)
%DENOISE_BATCH 显式逐 run 清单，支持不同 TR，不根据文件名猜测任务类型。
if ~isfile(fullfile(cfg.spmPath,'spm.m')), error('psy:SPMPath','Set SPM path'); end
addpath(cfg.spmPath);
o=detectImportOptions(cfg.manifestFile,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','run','bold','confounds','purpose','temporal_state'};
if ~all(ismember(required,o.VariableNames)), error('psy:DenoiseColumns','Missing manifest columns'); end
o.DataLines=[2 Inf]; o.ConsecutiveDelimitersRule='split'; o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string'); t=readtable(cfg.manifestFile,o); t=fillmissing(t,'constant',"");
keys=strings(height(t),1);
for i=1:height(t)
    for field={'subject','session','run'}
        value=char(t.(field{1})(i)); if strcmp(field{1},'session')&&isempty(value), continue; end
        if isempty(regexp(value,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')), error('psy:UnsafeID','Invalid ID'); end
    end
    keys(i)=lower(t.subject(i)+"/"+t.session(i)+"/"+t.run(i));
end
if numel(unique(keys))~=numel(keys), error('psy:DuplicateRun','Duplicate run'); end
selected=true(height(t),1);
if ~isempty(cfg.subjects), selected=selected&ismember(t.subject,cfg.subjects); end
if ~isempty(cfg.runNames), selected=selected&ismember(t.run,cfg.runNames); end
t=t(selected,:); if isempty(t), error('psy:NoRuns','No selected runs'); end
if isfolder(cfg.outputRoot), error('psy:DenoiseExists','Choose a new output root'); end
mkdir(cfg.outputRoot); save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
base=fileparts(char(java.io.File(cfg.manifestFile).getCanonicalPath())); report=struct([]);
for i=1:height(t)
    r=struct('subject',char(t.subject(i)),'session',char(t.session(i)),'name',char(t.run(i)), ...
        'purpose',char(t.purpose(i)),'temporal_state',char(t.temporal_state(i)));
    row=struct('subject',r.subject,'session',r.session,'run',r.name,'status','failed','message','');
    try
        for field={'bold','confounds'}
            p=char(t.(field{1})(i)); if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
            p=char(java.io.File(p).getCanonicalPath());
            if ~isfile(p), error('psy:DenoiseInput','Missing %s',p); end
            r.(field{1})=p;
        end
        s=psy.denoise_run(r,cfg,psy.run_output_dir(cfg.outputRoot,r));
        row.status=s.status; row.message=sprintf('%d frames; joint rank %d; residual dimensions %d',s.nFrames,s.rank,s.remainingDF);
    catch ex
        row.message=ex.message;
    end
    if isempty(report), report=row; else, report(end+1)=row; end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    fprintf('%s/%s/%s: %s %s\n',r.subject,r.session,r.name,row.status,row.message);
    if strcmp(row.status,'failed')&&~cfg.continueOnError, error('psy:DenoiseFailed','%s',row.message); end
end
end
