function result=cogneuro_preprocess_handoff(job)
%COGNEURO_PREPROCESS_HANDOFF 从真实完成记录交接GLM；不猜文件前缀、不回归影像。
validateJob(job);
previousPath=path;previousDirectory=pwd;
restore=onCleanup(@()restoreEnvironment(previousPath,previousDirectory)); %#ok<NASGU>
toolkit=absolutePath(job.toolkit_root,true);spmRoot=absolutePath(job.spm_root,true);
output=absolutePath(job.output_root,false);sourceFile=absolutePath(job.preprocessing_result_file,true);
if isfolder(output)||isfile(output),error('cogneuro:HandoffExists','Choose a new handoff output directory');end
if within(output,toolkit)||within(output,spmRoot)
    error('cogneuro:HandoffOutput','Handoff output must be outside toolkit/SPM installations');
end
addpath(fullfile(toolkit,'matlab'),'-begin');addpath(spmRoot,'-begin');
for name={'spm','spm_vol','spm_read_vols'}
    verifyLoaded(name{1},fullfile(spmRoot,[name{1} '.m']));
end
for name={'motion_regressors','read_events_tsv','file_sha256'}
    verifyLoaded(['psy.' name{1}],fullfile(toolkit,'matlab','+psy',[name{1} '.m']));
end
source=jsondecode(fileread(sourceFile));
if ~isstruct(source)||~isscalar(source)||~all(isfield(source,{'schema_version','route','status','runs','output_files'}))|| ...
        ~isequal(source.schema_version,1)||~strcmp(source.route,'preprocess')||~strcmp(source.status,'complete')|| ...
        ~isstruct(source.runs)||numel(source.runs)~=numel(job.expected_runs)
    error('cogneuro:HandoffSource','Expected a complete preprocessing adapter result with matching run count');
end
recordedOutputs=pathList(source.output_files);
for k=1:numel(recordedOutputs),requireFile(recordedOutputs{k});end
sourceKeys=strings(numel(source.runs),1);expectedKeys=sourceKeys;
for k=1:numel(source.runs)
    sourceKeys(k)=runKey(source.runs(k));expectedKeys(k)=runKey(job.expected_runs(k));
end
if numel(unique(lower(sourceKeys)))~=numel(sourceKeys)||numel(unique(lower(expectedKeys)))~=numel(expectedKeys)|| ...
        ~isequal(sort(sourceKeys),sort(expectedKeys))
    error('cogneuro:HandoffIdentity','Preprocessing and confirmed run identities must match exactly without duplicates');
end
checked=cell(1,numel(job.expected_runs));
for k=1:numel(job.expected_runs)
    expected=job.expected_runs(k);record=source.runs(sourceKeys==expectedKeys(k));
    checked{k}=checkRun(record,expected,job.options.bold_source,output,recordedOutputs);
end
% 先核查所有来源，再在新目录中写交接文件；失败证据保留，不覆盖完成的预处理结果。
mkdir(output);runs=struct([]);provenance=struct([]);outputFiles={};
for k=1:numel(checked)
    item=checked{k};folder=runDirectory(output,item);
    mkdir(folder);events=fullfile(folder,'events.tsv');confounds=fullfile(folder,'confounds.tsv');
    [ok,message]=copyfile(item.source_events,events);
    if ~ok,error('cogneuro:HandoffWrite','Cannot copy verified events: %s',message);end
    writetable(item.confound_table,confounds,'FileType','text','Delimiter','\t');
    row=struct('subject',item.subject,'session',item.session,'run',item.run, ...
        'bold',item.bold,'events',events,'confounds',confounds,'mask',item.mask, ...
        'temporal_state','unfiltered_unregressed','tr_seconds',item.tr_seconds,'n_frames',item.n_frames, ...
        'source_completion',item.source_completion,'source_completion_status',item.source_completion_status, ...
        'event_shift_already_applied_seconds',item.dummy.eventShiftSeconds, ...
        'negative_onset_count',item.negative_onset_count,'event_end_overrun_seconds',item.event_end_overrun_seconds, ...
        'fd_radius_mm',item.fd_radius_mm);
    if isempty(runs),runs=row;else,runs(end+1)=row;end %#ok<AGROW>
    audit=rmfield(item,{'confound_table'});audit.events_output=events;audit.confounds_output=confounds;
    audit.events_output_sha256=psy.file_sha256(events);audit.confounds_output_sha256=psy.file_sha256(confounds);
    if isempty(provenance),provenance=audit;else,provenance(end+1)=audit;end %#ok<AGROW>
    outputFiles=[outputFiles,{events,confounds}]; %#ok<AGROW>
end
manifest=fullfile(output,'runs.tsv');t=struct2table(runs,'AsArray',true);
t=t(:,{'subject','session','run','bold','events','confounds','temporal_state','mask'});
writetable(t,manifest,'FileType','text','Delimiter','\t');
provenanceFile=fullfile(output,'handoff_provenance.json');
audit=struct('schema_version',1,'source_result_file',sourceFile,'source_result_sha256',psy.file_sha256(sourceFile), ...
    'bold_source',char(job.options.bold_source),'include_tissue_means',false, ...
    'temporal_processing','none; no rows removed, no temporal filtering or nuisance regression', ...
    'runs',provenance,'manifest_sha256',psy.file_sha256(manifest));
writeJson(provenanceFile,audit);outputFiles=[outputFiles,{manifest,provenanceFile}];
result=struct('schema_version',1,'route','handoff','mode','execute','status','complete', ...
    'manifest_file',manifest,'output_root',output,'runs',runs,'output_files',{outputFiles}, ...
    'provenance_file',provenanceFile,'scientific_qc_passed',false, ...
    'limitations',{{'Only native completion records and listed outputs are handed off; no filenames are inferred from prefixes.', ...
        'Motion regressors contain 24 native motion columns and FD; WM/CSF tissue means are not implemented in this pilot.', ...
        'Mask grid agreement and finite masked data do not establish anatomical alignment or suitable brain coverage.', ...
        'Adjusted events are copied without another time shift; negative onsets and reported end overruns are preserved.', ...
        'This step does not estimate a GLM, filter images, regress nuisance signals or approve scientific model quality.'}});
end

function item=checkRun(record,expected,selection,output,recordedOutputs)
fields={'subject','session','run','output_path','completion_marker','retained_frames','tr_seconds', ...
    'realigned_bold','normalized_bold','smoothed_bold','motion_file','adjusted_events','plan_file'};
if ~all(isfield(record,fields)),error('cogneuro:HandoffSource','Incomplete preprocessing run record');end
out=absolutePath(record.output_path,true);marker=absolutePath(record.completion_marker,true);
if ~isfolder(out)||~samePath(marker,fullfile(out,'COMPLETE.mat'))||within(output,out)
    error('cogneuro:HandoffSource','Native completion marker must belong to the recorded run; handoff output must be separate');
end
complete=load(marker,'status','requiredOutputs');
if ~all(isfield(complete,{'status','requiredOutputs'}))|| ...
        ~any(startsWith(string(complete.status),["realigned_","segmented_","spatial_pipeline_"]))
    error('cogneuro:HandoffIncomplete','Native run does not have an eligible completed preprocessing status');
end
required=pathList(complete.requiredOutputs);
for k=1:numel(required),requireFile(required{k});end
inputFile=fullfile(out,'input_info.mat');requireFile(inputFile);
native=load(inputFile,'run','cfg','info','plan');
if ~all(isfield(native,{'run','cfg','info','plan'}))||~all(isfield(native.run,{'subject','session','name','events'}))|| ...
        ~strcmp(runKey(struct('subject',native.run.subject,'session',native.run.session,'run',native.run.name)),runKey(expected))|| ...
        ~isfield(native.cfg,'fdRadiusMm')||~isfield(native.cfg,'execute')||~isequal(native.cfg.execute,true)|| ...
        ~positiveScalar(native.cfg.fdRadiusMm)||~all(isfield(native.info,{'nVolumes','trSeconds'}))|| ...
        ~isfield(native.plan,'dummy')
    error('cogneuro:HandoffInputInfo','Completed input_info must identify the run, executed configuration, original events and dummy plan');
end
planFile=absolutePath(record.plan_file,true);assertListed(planFile,required,'plan');
if ~samePath(planFile,fullfile(out,'preprocessing_plan.json'))
    error('cogneuro:HandoffPlan','Use the native plan listed by the completion marker');
end
plan=jsondecode(fileread(planFile));
if ~isfield(plan,'dummy'),error('cogneuro:HandoffPlan','Missing recorded dummy plan');end
dummy=checkDummy(plan.dummy,native.plan.dummy,native.info,record,expected);
switch char(selection)
    case 'realigned',bold=record.realigned_bold;
    case 'normalized_unsmoothed',bold=record.normalized_bold;
    case 'smoothed',bold=record.smoothed_bold;
    otherwise,error('cogneuro:HandoffSelection','Unsupported BOLD source');
end
bold=absolutePath(bold,true);motion=absolutePath(record.motion_file,true);events=absolutePath(record.adjusted_events,true);
assertListed(bold,required,'selected BOLD');assertListed(motion,required,'motion');
assertListed(marker,recordedOutputs,'completion marker');
if ~within(bold,out)||~within(motion,out)||~within(events,out)&&dummy.count>0
    error('cogneuro:HandoffSource','Selected processing outputs must belong to their completed run');
end
if dummy.count>0,assertListed(events,required,'adjusted events');end
originalEvents=absolutePath(native.run.events,true);
if dummy.count==0&&~samePath(events,originalEvents)
    error('cogneuro:HandoffEvents','Without dummy removal, use the original native staged event TSV');
end
original=psy.read_events_tsv(originalEvents,dummy.originalVolumes*dummy.trSeconds);
adjusted=psy.read_events_tsv(events,dummy.retainedDurationSeconds);
if ~isequal(original.table.Properties.VariableNames,adjusted.table.Properties.VariableNames)|| ...
        height(original.table)~=height(adjusted.table)
    error('cogneuro:HandoffEventShift','Dummy adjustment changed event rows or columns');
end
shifted=original.onsetSeconds-dummy.eventShiftSeconds;
if any(abs(adjusted.onsetSeconds-shifted)>1e-9*max(1,max(abs(shifted))))
    error('cogneuro:HandoffEventShift','Adjusted onsets do not match the single recorded dummy shift');
end
columns=setdiff(original.table.Properties.VariableNames,{'onset'},'stable');
if ~isequaln(original.table(:,columns),adjusted.table(:,columns))
    error('cogneuro:HandoffEventShift','Dummy adjustment changed non-onset event values');
end
mask=absolutePath(expected.mask,true);images=checkImages(bold,mask,dummy.retainedVolumes,dummy.trSeconds);
rp=readmatrix(motion,'FileType','text');
if size(rp,1)~=dummy.retainedVolumes,error('cogneuro:HandoffMotion','Motion row count differs from retained BOLD frames');end
[values,names,fd]=psy.motion_regressors(rp,native.cfg.fdRadiusMm);
confounds=array2table([values,fd],'VariableNames',[names,{'framewise_displacement'}]);
sources={marker,inputFile,planFile,bold,motion,events,originalEvents,mask};hashes=cell(size(sources));
for k=1:numel(sources),hashes{k}=psy.file_sha256(sources{k});end
item=struct('subject',char(expected.subject),'session',char(expected.session),'run',char(expected.run), ...
    'bold',bold,'mask',mask,'source_events',events,'source_original_events',originalEvents, ...
    'source_motion',motion,'source_completion',marker,'source_completion_status',char(complete.status), ...
    'source_plan',planFile,'source_input_info',inputFile,'tr_seconds',dummy.trSeconds, ...
    'n_frames',dummy.retainedVolumes,'dummy',dummy,'fd_radius_mm',native.cfg.fdRadiusMm, ...
    'confound_table',confounds,'negative_onset_count',adjusted.negativeOnsetCount, ...
    'event_end_overrun_seconds',adjusted.endOverrunSeconds,'masked_voxels',images.masked_voxels, ...
    'source_files',{sources},'source_sha256',{hashes});
end

function dummy=checkDummy(dummy,stored,info,record,expected)
fields={'count','originalVolumes','retainedVolumes','trSeconds','discardedSeconds', ...
    'eventReference','eventShiftSeconds','retainedDurationSeconds'};
if ~isstruct(dummy)||~isscalar(dummy)||~all(isfield(dummy,fields))||~isstruct(stored)||~all(isfield(stored,fields))
    error('cogneuro:HandoffPlan','Incomplete dummy provenance');
end
for k=1:numel(fields)
    name=fields{k};
    if strcmp(name,'eventReference')
        if ~strcmp(dummy.(name),stored.(name)),error('cogneuro:HandoffPlan','Stored and published dummy provenance differ');end
    elseif ~finiteScalar(dummy.(name))||~finiteScalar(stored.(name))||abs(dummy.(name)-stored.(name))>1e-9*max(1,abs(dummy.(name)))
        error('cogneuro:HandoffPlan','Stored and published dummy provenance differ');
    end
end
if ~positiveScalar(dummy.trSeconds)||dummy.count<0||fix(dummy.count)~=dummy.count|| ...
        dummy.originalVolumes<3||fix(dummy.originalVolumes)~=dummy.originalVolumes||dummy.retainedVolumes<3|| ...
        fix(dummy.retainedVolumes)~=dummy.retainedVolumes||dummy.originalVolumes-dummy.count~=dummy.retainedVolumes|| ...
        ~finiteScalar(info.nVolumes)||info.nVolumes~=dummy.originalVolumes||~positiveScalar(info.trSeconds)|| ...
        ~positiveScalar(record.tr_seconds)||~positiveScalar(expected.tr_seconds)|| ...
        ~finiteScalar(record.retained_frames)||record.retained_frames~=dummy.retainedVolumes
    error('cogneuro:HandoffPlan','Frame count/TR facts disagree with completed dummy provenance; GLM needs at least three frames');
end
tr=dummy.trSeconds;
if any(abs([info.trSeconds,record.tr_seconds,expected.tr_seconds]-tr)>1e-6*max(1,tr))|| ...
        abs(dummy.discardedSeconds-dummy.count*tr)>1e-9*max(1,dummy.count*tr)|| ...
        abs(dummy.retainedDurationSeconds-dummy.retainedVolumes*tr)>1e-9*max(1,dummy.retainedVolumes*tr)
    error('cogneuro:HandoffPlan','TR/duration facts disagree with completed dummy provenance');
end
if ~textChoice(dummy.eventReference,{'unspecified','original_first_volume','retained_first_volume'})|| ...
        dummy.count>0&&strcmp(dummy.eventReference,'unspecified')
    error('cogneuro:HandoffPlan','Ambiguous completed event time reference');
end
expectedShift=0;if dummy.count>0&&strcmp(dummy.eventReference,'original_first_volume'),expectedShift=dummy.count*tr;end
if abs(dummy.eventShiftSeconds-expectedShift)>1e-9*max(1,expectedShift)
    error('cogneuro:HandoffPlan','Recorded event shift is inconsistent with dummy count and time reference');
end
end

function result=checkImages(bold,mask,nFrames,tr)
if ~endsWith(lower(bold),'.nii')||~endsWith(lower(mask),'.nii')
    error('cogneuro:HandoffImage','Use completed uncompressed NIfTI BOLD and staged 3-D mask');
end
volumes=spm_vol(bold);h=niftiinfo(bold);mv=spm_vol(mask);
if numel(volumes)~=nFrames||numel(h.PixelDimensions)<4,error('cogneuro:HandoffFrames','Selected BOLD frame count differs from completed dummy plan');end
actualTR=h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond',actualTR=actualTR/1000;
    case 'microsecond',actualTR=actualTR/1e6;
    otherwise,error('cogneuro:HandoffTR','NIfTI time units must be known');
end
if ~positiveScalar(actualTR)||abs(actualTR-tr)>1e-6*max(1,tr),error('cogneuro:HandoffTR','Selected BOLD TR differs from completed plan');end
reference=volumes(1);
if ~isscalar(mv)||~sameGrid(reference,mv)||rank(reference.mat)<4
    error('cogneuro:HandoffMask','Explicit mask dimensions/affine must match selected BOLD');
end
maskValues=spm_read_vols(mv);
if any(~isfinite(maskValues(:))|maskValues(:)<0)||~any(maskValues(:)>0)
    error('cogneuro:HandoffMask','Explicit mask must be finite, nonnegative and nonempty');
end
inside=maskValues>0;clear maskValues;
for k=1:numel(volumes)
    if ~sameGrid(reference,volumes(k)),error('cogneuro:HandoffGrid','Selected BOLD frames have inconsistent grids');end
    values=spm_read_vols(volumes(k));
    if any(~isfinite(values(inside))),error('cogneuro:HandoffNonfinite','Selected BOLD contains nonfinite values inside the explicit mask');end
end
result=struct('masked_voxels',nnz(inside));
end

function same=sameGrid(a,b)
same=isequal(a.dim,b.dim)&&isequal(size(a.mat),[4 4])&&isequal(size(b.mat),[4 4])&& ...
    all(isfinite(a.mat),'all')&&all(isfinite(b.mat),'all')&&max(abs(a.mat-b.mat),[],'all')<=1e-5;
end

function validateJob(j)
fields={'schema_version','route','mode','toolkit_root','spm_root','output_root','preprocessing_result_file','options','expected_runs'};
if ~isstruct(j)||~isscalar(j)||~all(isfield(j,fields))||~isequal(j.schema_version,1)|| ...
        ~textChoice(j.route,{'handoff'})||~textChoice(j.mode,{'execute'})
    error('cogneuro:HandoffJob','Invalid handoff job schema/route/mode');
end
if ~isstruct(j.options)||~isscalar(j.options)||~all(isfield(j.options,{'bold_source','include_tissue_means'}))|| ...
        any(~ismember(fieldnames(j.options),{'bold_source','include_tissue_means'}))|| ...
        ~textChoice(j.options.bold_source,{'realigned','normalized_unsmoothed','smoothed'})
    error('cogneuro:HandoffOptions','Choose an explicitly recorded realigned/normalized_unsmoothed/smoothed BOLD source');
end
if ~islogical(j.options.include_tissue_means)||~isscalar(j.options.include_tissue_means)||j.options.include_tissue_means
    error('cogneuro:HandoffTissue','Pilot handoff supports include_tissue_means=false only; do not invent WM/CSF regressors');
end
if ~isstruct(j.expected_runs)||isempty(j.expected_runs)||~all(isfield(j.expected_runs,{'subject','session','run','tr_seconds','mask'}))
    error('cogneuro:HandoffJob','Confirmed run identities, TRs and staged explicit masks are required');
end
end

function paths=pathList(values)
if ~(iscell(values)||ischar(values)||isstring(values))||isempty(values)
    error('cogneuro:HandoffSource','Expected nonempty native path list');
end
if ischar(values),paths={values};else,paths=cellstr(string(values(:)));end
for k=1:numel(paths),paths{k}=absolutePath(paths{k},true);end
end

function assertListed(file,paths,role)
if ~any(cellfun(@(p)samePath(file,p),paths)),error('cogneuro:HandoffSource','%s is not listed in the actual completion outputs',role);end
end

function key=runKey(r)
if ~isstruct(r)||~all(isfield(r,{'subject','session','run'})),error('cogneuro:HandoffIdentity','Missing run identity');end
for name={'subject','session','run'}
    value=string(r.(name{1}));
    if ~isscalar(value)||ismissing(value)||(strlength(value)==0&&~strcmp(name{1},'session'))|| ...
            (strlength(value)>0&&isempty(regexp(char(value),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')))
        error('cogneuro:HandoffIdentity','Invalid subject/session/run identity');
    end
end
key=string(r.subject)+"/"+string(r.session)+"/"+string(r.run);
end

function folder=runDirectory(root,r)
folder=fullfile(root,['sub-' r.subject]);if ~isempty(r.session),folder=fullfile(folder,['ses-' r.session]);end
folder=fullfile(folder,r.run);
end

function p=absolutePath(p,mustExist)
if ~(ischar(p)||isstring(p))||~isscalar(string(p))||ismissing(string(p))||strlength(string(p))==0|| ...
        ~java.io.File(char(p)).isAbsolute()
    error('cogneuro:HandoffPath','Expected an explicit absolute path');
end
p=char(java.io.File(char(p)).getCanonicalPath());
if mustExist&&~isfile(p)&&~isfolder(p),error('cogneuro:HandoffMissing','Missing source: %s',p);end
end

function requireFile(p)
if ~isfile(p),error('cogneuro:HandoffMissing','Missing required completed output: %s',p);end
end

function same=samePath(a,b)
same=strcmpi(char(java.io.File(a).getCanonicalPath()),char(java.io.File(b).getCanonicalPath()));
end

function inside=within(p,root)
p=lower(char(java.io.File(p).getCanonicalPath()));root=lower(char(java.io.File(root).getCanonicalPath()));
inside=strcmp(p,root)||startsWith(p,[root filesep]);
end

function verifyLoaded(name,expected)
found=which(name);
if isempty(found)||~isfile(expected)||~samePath(found,expected)
    error('cogneuro:HandoffDependency','%s must resolve to selected toolkit/SPM: %s',name,expected);
end
end

function ok=finiteScalar(x)
ok=isnumeric(x)&&isreal(x)&&isscalar(x)&&isfinite(x);
end

function ok=positiveScalar(x)
ok=finiteScalar(x)&&x>0;
end

function ok=textChoice(x,choices)
ok=(ischar(x)||isstring(x))&&isscalar(string(x))&&~ismissing(string(x))&&ismember(string(x),string(choices));
end

function writeJson(file,value)
if isfile(file),error('cogneuro:HandoffExists','Refuse to overwrite an existing output');end
[f,message]=fopen(file,'w','n','UTF-8');if f<0,error('cogneuro:HandoffWrite','%s',message);end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value,PrettyPrint=true)); %#ok<NASGU>
end

function restoreEnvironment(previousPath,previousDirectory)
path(previousPath);cd(previousDirectory);
end
