function report=run_glmsingle_demo(cfg,demo)
%RUN_GLMSINGLE_DEMO 已预处理数据的显式近似示例；配置在config/glmsingle_demo_config.m。
oldPath=path;restorePath=onCleanup(@()path(oldPath));
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
if nargin==0,[cfg,demo]=glmsingle_demo_config;elseif nargin~=2,error('psy:GLMsingleDemo','Supply both cfg and demo, or neither');end
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.engine,'glmsingle')||~strcmp(cfg.level,'subject')||~strcmp(cfg.model.unit,'event')|| ...
        ~strcmp(cfg.events.expression,'fixed')||~strcmp(cfg.glmsingle.identityColumn,'trial_type')|| ...
        ~strcmp(cfg.glmsingle.onsetMode,'nearest')
    error('psy:GLMsingleDemo','Use the explicit condition-repeat, fixed-duration, nearest-TR demo profile');
end
if ~isstruct(demo)||~isscalar(demo)||~isequal(fieldnames(demo),{'maxVoxelsPerSubject'})|| ...
        ~isnumeric(demo.maxVoxelsPerSubject)||~isreal(demo.maxVoxelsPerSubject)|| ...
        ~isscalar(demo.maxVoxelsPerSubject)||~isfinite(demo.maxVoxelsPerSubject)|| ...
        demo.maxVoxelsPerSubject<0||fix(demo.maxVoxelsPerSubject)~=demo.maxVoxelsPerSubject
    error('psy:GLMsingleDemo','maxVoxelsPerSubject must be a nonnegative integer; 0 means all');
end
addpath(cfg.spmPath);
out=char(java.io.File(cfg.outputRoot).getCanonicalPath());
if isfile(out)||isfolder(out),error('psy:GLMExists','Choose a new demo output root');end
manifest=char(java.io.File(cfg.manifestFile).getCanonicalPath());
o=detectImportOptions(manifest,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','run','bold','events','confounds','temporal_state'};
if ~all(ismember(required,o.VariableNames))||any(~ismember(o.VariableNames,[required {'mask'}]))
    error('psy:GLMColumns','Use the standard GLM run manifest with optional mask');
end
o.DataLines=[2 Inf];o.ConsecutiveDelimitersRule='split';o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string');t=fillmissing(readtable(manifest,o),'constant',"");
if isempty(t),error('psy:NoRuns','Empty manifest');end
if ~ismember('mask',t.Properties.VariableNames),t.mask=repmat(string(cfg.explicitMask),height(t),1);end
for i=1:height(t)
    for key={'subject','session','run'}
        id=char(t.(key{1})(i));if strcmp(key{1},'session')&&isempty(id),continue;end
        if isempty(regexp(id,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('psy:UnsafeID','Invalid manifest ID');end
    end
    for key={'bold','events','confounds','mask'}
        p=char(t.(key{1})(i));if isempty(p)&&strcmp(key{1},'mask'),p=cfg.explicitMask;end
        if isempty(p),error('psy:GLMInput','Demo requires BOLD/events/confounds and an explicit mask');end
        if ~java.io.File(p).isAbsolute(),p=fullfile(fileparts(manifest),p);end
        p=char(java.io.File(p).getCanonicalPath());
        if ~isfile(p),error('psy:GLMInput','Missing input: %s',p);end
        t.(key{1})(i)=string(p);
    end
end
keys=lower(t.subject+"/"+t.session+"/"+t.run);
if numel(unique(keys))~=height(t),error('psy:DuplicateRun','Duplicate manifest run');end
source=t;inputFiles=unique([string(manifest);t.bold;t.events;t.confounds;t.mask],'stable');
before=hashFiles(inputFiles);mkdir(out);
writetable(before,fullfile(out,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');
save(fullfile(out,'demo_configuration.mat'),'cfg','demo','source');
try
    groupKeys=lower(t.subject+"/"+t.session);if cfg.subject.combineSessions,groupKeys=lower(t.subject);end
    groups=unique(groupKeys,'stable');maskAudit=struct([]);eventAudit=table;
    inputDir=fullfile(out,'prepared');mkdir(inputDir);
    for g=1:numel(groups)
        rows=find(groupKeys==groups(g));mask=[];reference=[];
        for j=1:numel(rows)
            i=rows(j);v=spm_vol(char(t.bold(i)));m=spm_vol(char(t.mask(i)));
            if isempty(reference),reference=v(1);mask=true(reference.dim);end
            if ~isscalar(m)||~isequal(m.dim,reference.dim)||max(abs(m.mat-reference.mat),[],'all')>1e-5|| ...
                    ~isequal(v(1).dim,reference.dim)||max(abs(v(1).mat-reference.mat),[],'all')>1e-5
                error('psy:GLMGrid','Subject masks/BOLD must share geometry');
            end
            values=spm_read_vols(m);
            if any(~isfinite(values(:))|values(:)<0),error('psy:GLMsingleMask','Mask must be finite and nonnegative');end
            mask=mask&values>0;
            h=niftiinfo(char(t.bold(i)));tr=h.PixelDimensions(4);
            switch lower(h.TimeUnits)
                case 'second'
                case 'millisecond',tr=tr/1000;
                case 'microsecond',tr=tr/1e6;
                otherwise,error('psy:TimeUnits','Unknown BOLD time unit');
            end
            e=psy.read_events_tsv(char(t.events(i)),numel(v)*tr);n=height(e.table);
            grid=round(e.onsetSeconds/tr)*tr;lastFrame=(numel(v)-1)*tr;
            audio=repmat("not_supplied",n,1);
            if ismember('stimulus_id',e.table.Properties.VariableNames),audio=string(e.table.stimulus_id);end
            included=lastFrame-grid>=cfg.glmsingle.minEndBufferSeconds-1e-6;
            preparedIndex=zeros(n,1);preparedIndex(included)=(1:nnz(included))';
            reason=repmat("",n,1);reason(~included)="insufficient onset-to-last-frame buffer for demo HRF estimation";
            a=table(repmat(t.subject(i),n,1),repmat(t.session(i),n,1),repmat(t.run(i),n,1),(1:n)', ...
                audio,string(e.table.trial_type),e.onsetSeconds,e.durationSeconds, ...
                repmat(cfg.events.fixedDurationSeconds,n,1),grid,grid-e.onsetSeconds, ...
                repmat(numel(v)*tr,n,1),lastFrame-grid, ...
                max(0,e.onsetSeconds+e.durationSeconds-numel(v)*tr), ...
                max(0,grid+cfg.events.fixedDurationSeconds-numel(v)*tr),included,preparedIndex,reason, ...
                'VariableNames',{'subject','session','run','source_event_index','source_stimulus_id','cv_identity', ...
                'original_onset_seconds','original_duration_seconds','modeled_duration_seconds','grid_onset_seconds', ...
                'onset_error_seconds','acquisition_end_seconds','seconds_to_last_frame_from_grid_onset', ...
                'original_event_overrun_seconds','modeled_event_overrun_seconds','included_in_demo', ...
                'prepared_event_index','exclusion_reason'});
            if isempty(eventAudit),eventAudit=a;else,eventAudit=[eventAudit;a];end %#ok<AGROW>
            if ~any(included),error('psy:GLMsingleDemo','Tail rule excludes every event in a run');end
            preparedEvents=e.table(included,:);preparedEvents.original_event_index=find(included);
            eventFile=fullfile(inputDir,sprintf('run_%03d_demo_events.tsv',i));
            writetable(preparedEvents,eventFile,'FileType','text','Delimiter','\t');t.events(i)=string(eventFile);
        end
        candidates=find(mask);count=numel(candidates);
        if count==0,error('psy:GLMsingleMask','Empty subject coverage intersection');end
        limit=demo.maxVoxelsPerSubject;
        if limit>0&&count>limit,candidates=candidates(round(linspace(1,count,limit)));end
        mask(:)=false;mask(candidates)=true;
        maskFile=fullfile(inputDir,sprintf('group_%03d_demo_mask.nii',g));
        header=struct('fname',maskFile,'dim',reference.dim,'mat',reference.mat,'dt',[2 0], ...
            'pinfo',[1;0;0],'descrip','Engineering demo: deterministic coverage-mask voxel sample');
        spm_write_vol(header,double(mask));t.mask(rows)=string(maskFile);
        row=struct('group',char(groups(g)),'coverageVoxels',count,'demoVoxels',numel(candidates),'mask',maskFile);
        if isempty(maskAudit),maskAudit=row;else,maskAudit(g)=row;end
    end
    writetable(eventAudit,fullfile(out,'demo_event_audit.tsv'),'FileType','text','Delimiter','\t');
    writetable(struct2table(maskAudit),fullfile(out,'demo_mask_audit.tsv'),'FileType','text','Delimiter','\t');
    preparedCfg=cfg;preparedCfg.manifestFile=fullfile(inputDir,'runs.tsv');preparedCfg.outputRoot=fullfile(out,'models');
    writetable(t,preparedCfg.manifestFile,'FileType','text','Delimiter','\t');
    assumptions=struct('purpose','engineering_demo_only_not_research_inference', ...
        'identity','trial_type is the CV repeat identity; each source event retains a separate beta', ...
        'eventUnit','one source EV row, including its task/response period; not a word-level trial', ...
        'durationModel','one common fixed duration; source durations retained, no equivalence claim', ...
        'fixedDurationSeconds',cfg.events.fixedDurationSeconds, ...
        'timing','nearest TR; source zero point and BOLD unchanged; no interpolation or padding', ...
        'maxAbsoluteOnsetErrorSeconds',max(abs(eventAudit.onset_error_seconds)), ...
        'tail','events with insufficient onset-to-last-frame buffer explicitly excluded in a new event table; BOLD unchanged; excluded task activity is unmodeled', ...
        'minimumOnsetToLastFrameSeconds',cfg.glmsingle.minEndBufferSeconds, ...
        'nExcludedEvents',nnz(~eventAudit.included_in_demo), ...
        'maskSelection','deterministic uniform selection in linear mask index; not an anatomical ROI or whole-brain result', ...
        'maxVoxelsPerSubject',demo.maxVoxelsPerSubject, ...
        'noisePool','explicit R2 threshold, possibly including task-responsive voxels; CV chooses PC count', ...
        'noiseR2Threshold',cfg.glmsingle.noiseR2Threshold,'pcR2Threshold',cfg.glmsingle.pcR2Threshold);
    writeJson(fullfile(out,'demo_assumptions.json'),assumptions);
    report=psy.glm_batch(preparedCfg);
    if cfg.execute&&~all(strcmp({report.status},'glmsingle_models_estimated'))
        error('psy:GLMsingleDemo','Not all requested subjects completed');
    end
    if ~cfg.execute&&~all(strcmp({report.status},'glmsingle_prepared_not_estimated'))
        error('psy:GLMsingleDemo','Not all requested subjects passed preparation');
    end
    eventAudit.beta_index=NaN(height(eventAudit),1);
    for g=1:numel(groups)
        rows=find(groupKeys==groups(g));folder=fullfile(preparedCfg.outputRoot,['sub-' char(t.subject(rows(1)))]);
        if ~cfg.subject.combineSessions&&strlength(t.session(rows(1)))>0,folder=fullfile(folder,['ses-' char(t.session(rows(1)))]);end
        mapping=readtable(fullfile(folder,'combined','event_mapping.tsv'),'FileType','text','Delimiter','\t');
        for k=1:height(mapping)
            i=rows(mapping.run_index(k));selected=eventAudit.subject==t.subject(i)&eventAudit.session==t.session(i)& ...
                eventAudit.run==t.run(i)&eventAudit.prepared_event_index==mapping.source_event_index(k);
            if nnz(selected)~=1,error('psy:GLMsingleDemo','Cannot restore original event identity');end
            eventAudit.beta_index(selected)=mapping.beta_index(k);
        end
    end
    assert(all(isfinite(eventAudit.beta_index(eventAudit.included_in_demo))),'psy:GLMsingleDemo','Incomplete demo beta mapping');
    writetable(eventAudit,fullfile(out,'demo_event_audit.tsv'),'FileType','text','Delimiter','\t');
    after=hashFiles(inputFiles);
    writetable(after,fullfile(out,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');
    assert(isequal(before,after),'psy:GLMsingleInputChanged','Source inputs changed');
    summary=struct('purpose',assumptions.purpose,'estimated',cfg.execute,'nSubjects',numel(report), ...
        'nRuns',height(t),'nSourceEvents',height(eventAudit),'nModeledEvents',nnz(eventAudit.included_in_demo), ...
        'nExcludedEvents',nnz(~eventAudit.included_in_demo),'inputHashesUnchanged',height(before), ...
        'assumptionsFile',fullfile(out,'demo_assumptions.json'),'modelsRoot',preparedCfg.outputRoot);
    writeJson(fullfile(out,'demo_summary.json'),summary);
    marker='GLMSINGLE_DEMO_PREPARED.mat';if cfg.execute,marker='GLMSINGLE_DEMO_COMPLETE.mat';end
    save(fullfile(out,marker),'report','cfg','preparedCfg','demo','summary','maskAudit');
catch ex
    errorReport=getReport(ex,'extended','hyperlinks','off');save(fullfile(out,'GLMSINGLE_DEMO_FAILED.mat'),'errorReport');
    after=hashFiles(inputFiles);writetable(after,fullfile(out,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');
    rethrow(ex);
end
disp(struct2table(report,'AsArray',true));clear restorePath;
end
function t=hashFiles(files)
bytes=zeros(numel(files),1);sha256=strings(numel(files),1);
for k=1:numel(files),entry=dir(char(files(k)));bytes(k)=entry.bytes;sha256(k)=psy.file_sha256(char(files(k)));end
t=table(files,bytes,sha256,'VariableNames',{'path','bytes','sha256'});
end
function writeJson(file,value)
f=fopen(file,'w');if f<0,error('psy:GLMOutput','Cannot write JSON');end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value,PrettyPrint=true));clear cleanup;
end
