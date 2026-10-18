function report=confounds_batch(cfg)
%CONFOUNDS_BATCH 多被试/session/run。输入影像须已经配准且使用未平滑数据。
if ~isfile(fullfile(cfg.spmPath,'spm.m')), error('psy:SPMPath','Set cfg.spmPath'); end
addpath(cfg.spmPath);
o=detectImportOptions(cfg.manifestFile,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','run','bold','wm','csf','motion','alignment'};
if ~all(ismember(required,o.VariableNames)), error('psy:ConfoundColumns','Missing required columns'); end
o.DataLines=[2 Inf]; o.ConsecutiveDelimitersRule='split'; o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string'); t=readtable(cfg.manifestFile,o); t=fillmissing(t,'constant',"");
if isempty(t), error('psy:NoRuns','Empty confounds manifest'); end
keys=strings(height(t),1);
for i=1:height(t)
    for name={'subject','session','run'}
        v=char(t.(name{1})(i)); if strcmp(name{1},'session') && isempty(v), continue; end
        if isempty(regexp(v,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')), error('psy:UnsafeID','Invalid ID'); end
    end
    keys(i)=lower(t.subject(i)+"/"+t.session(i)+"/"+t.run(i));
end
if numel(unique(keys))~=numel(keys), error('psy:DuplicateRun','Duplicate confound run'); end
selected=true(height(t),1);
if ~isempty(cfg.subjects), selected=selected & ismember(t.subject,cfg.subjects); end
if ~isempty(cfg.runNames), selected=selected & ismember(t.run,cfg.runNames); end
t=t(selected,:); if isempty(t), error('psy:NoRuns','No selected runs'); end
if isfolder(cfg.outputRoot), error('psy:ConfoundsExists','Choose a new output root'); end
mkdir(cfg.outputRoot); save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
base=fileparts(char(java.io.File(cfg.manifestFile).getCanonicalPath()));
report=struct([]);
for i=1:height(t)
    r=struct('subject',char(t.subject(i)),'session',char(t.session(i)),'name',char(t.run(i)));
    out=psy.run_output_dir(cfg.outputRoot,r);
    row=struct('subject',r.subject,'session',r.session,'run',r.name,'status','failed','message','','output',out);
    try
        if t.alignment(i)~="world_aligned", error('psy:Alignment','Explicit world_aligned declaration required'); end
        for name={'bold','wm','csf','motion'}
            p=char(t.(name{1})(i)); if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
            p=char(java.io.File(p).getCanonicalPath());
            if ~isfile(p), error('psy:ConfoundInput','Missing %s: %s',name{1},p); end
            r.(name{1})=p;
        end
        summary=psy.extract_confounds(r,cfg,out);
        row.status='confounds_extracted_not_regressed';
        row.message=sprintf('%d frames, WM %d / CSF %d voxels',summary.nVolumes,summary.wmVoxels,summary.csfVoxels);
    catch exception
        row.message=exception.message;
    end
    if isempty(report), report=row; else, report(end+1)=row; end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    fprintf('%s/%s/%s: %s %s\n',r.subject,r.session,r.name,row.status,row.message);
    if strcmp(row.status,'failed') && ~cfg.continueOnError, error('psy:ConfoundFailed','%s',row.message); end
end
end
