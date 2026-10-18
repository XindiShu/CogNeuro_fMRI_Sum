function result=cogneuro_preprocess_adapter(job)
%COGNEURO_PREPROCESS_ADAPTER 基于官方配置的原始NIfTI/SPM空间预处理试点。
% 只在内存覆盖已批准科学参数；官方toolkit_config.m及源输入保持不变。
% 预检仅写新work_root；正式计算仅写另一个新output_root，禁止复用/覆盖。
validateJob(job);
oldPath=path;oldDirectory=pwd;
restore=onCleanup(@()restoreEnvironment(oldPath,oldDirectory)); %#ok<NASGU>
toolkit=absolute(job.toolkit_root,true);spmRoot=absolute(job.spm_root,true);
manifest=absolute(job.manifest_file,true);work=absolute(job.work_root,false);
output=absolute(job.output_root,false);
assertFresh(work);assertFresh(output);
if overlap(work,output)||within(work,toolkit)||within(output,toolkit)|| ...
        within(work,spmRoot)||within(output,spmRoot)
    error('cogneuro:PreprocessOutput','Work/output roots must be separate and outside installations');
end
addpath(fullfile(toolkit,'matlab'),fullfile(toolkit,'config'),'-begin');addpath(spmRoot,'-begin');
sources=checkSources(toolkit,spmRoot);
configFile=fullfile(toolkit,'config','toolkit_config.m');
approvedHash=lower(char(job.options.preprocessing.toolkit_config_sha256));
if ~strcmp(psy.file_sha256(configFile),approvedHash)
    error('cogneuro:PreprocessConfigHash','Official toolkit_config.m differs from its approved SHA256');
end
cfg=toolkit_config;
cfg=applyOverrides(cfg,job.options.preprocessing.overrides);
checkPilotConfiguration(cfg);
% 系统参数由事务层控制；科学路线不在此被暗中改为另一种算法。
cfg.inputMode='manifest';cfg.inputStage='raw';cfg.manifestFile=manifest;
cfg.spmPath=spmRoot;cfg.outputRoot=output;cfg.execute=false;
cfg.stopAfter=char(job.options.preprocessing.stop_after);
cfg.subjects={};cfg.runNames={};cfg.continueOnError=false;cfg.resume=false;
psy.validate_preprocess_config(cfg);
runs=psy.read_manifest(cfg);
validateRuns(runs,job.expected_runs,work,output);
details=struct([]);plans=cell(1,numel(runs));
for k=1:numel(runs)
    checked=checkImages(runs(k),job.expected_runs(k).tr_seconds,job.options.max_matrix_gib);
    info=psy.inspect_run(runs(k));
    plan=psy.preprocess_plan(runs(k),info,cfg);plan.dummy=psy.dummy_plan(runs(k),info,cfg);
    if ismember(cfg.stopAfter,{'segment','smooth'}),plan.segment=psy.segment_plan(runs(k),cfg);end
    plans{k}=plan;
    item=struct('subject',runs(k).subject,'session',runs(k).session,'run',runs(k).name, ...
        'output_path','','completion_marker','','retained_frames',plan.dummy.retainedVolumes, ...
        'tr_seconds',info.trSeconds,'realigned_bold','','normalized_bold','','smoothed_bold','', ...
        'motion_file','','adjusted_events','','plan_file','', ...
        'input_frames',checked.n_frames,'checked_array_gib',checked.array_gib, ...
        'planned_steps',{plannedSteps(plan,cfg)},'executed_steps',{{}});
    if plan.dummy.count==0,item.adjusted_events=runs(k).events;end
    if isempty(details),details=item;else,details(end+1)=item;end %#ok<AGROW>
end
% 原生execute=false会保存输入检查，但不会运行STC/Realign/Segment等处理。
preflightCfg=cfg;preflightCfg.outputRoot=work;
preflightReport=psy.preprocess_batch(preflightCfg);
verifyReport(preflightReport,runs,'validated_inputs');
for k=1:numel(runs)
    header=fullfile(psy.run_output_dir(fullfile(work,'input_checks'),runs(k)),'header.mat');
    requireFiles({header});details(k).plan_file=header;
    saved=load(header,'info');
    if saved.info.nVolumes~=details(k).input_frames|| ...
            saved.info.preprocessPlan.dummy.retainedVolumes~=details(k).retained_frames|| ...
            abs(saved.info.trSeconds-details(k).tr_seconds)>1e-6
        error('cogneuro:PreprocessPlan','Native preflight differs from the checked input/plan');
    end
end
result=struct('schema_version',1,'route','preprocess','mode',char(job.mode), ...
    'status','preflight_passed','n_runs',numel(runs),'toolkit_root',toolkit,'spm_root',spmRoot, ...
    'work_root',work,'output_root',output,'runs',details,'loaded_sources',sources, ...
    'resolved_preprocessing_config',jsonSafe(cfg),'toolkit_config_sha256',approvedHash, ...
    'output_files',{filesUnder(work)},'preflight_output_files',{filesUnder(work)}, ...
    'scientific_qc_passed',false, ...
    'validation_scope',struct('raw_bold_all_frames_finite',true,'raw_t1_3d_finite',true, ...
        'native_input_and_acquisition_planning',true,'anatomical_alignment_proven',false, ...
        'susceptibility_correction_performed',false,'gradient_distortion_correction_performed',false), ...
    'limitations',{{ ...
        'Pilot requires raw uncompressed NIfTI BOLD and a real T1 for every row, including realign-only, as required by the installed native manifest reader.', ...
        'Pilot uses SPM segmentation normalisation and no susceptibility correction; DICOM, CAT, group normalisation, extra anatomy, atlases, reuse and weighting are excluded.', ...
        'Finite data and completion markers do not prove anatomical alignment, local distortion correction, brain coverage or scientific acceptance.', ...
        'Segmentation/normalisation/smoothing delegate to the toolkit; this skill does not add a full-chain real-data validation claim.', ...
        'Array GiB estimates are conservative checked-array budgets, not guarantees of MATLAB/SPM peak memory.', ...
        'qc.maxResliceNonfiniteFraction does not control raw/no-SDC reslicing; its native finite-copy branch is inactive here.', ...
        'No temporal nuisance regression, connectivity, GLM or handoff is executed by this adapter.'}});
if strcmp(job.mode,'execute')
    cfg.execute=true;
    report=psy.preprocess_batch(cfg);
    expectedStatus=stageStatus(cfg.stopAfter);verifyReport(report,runs,expectedStatus);
    for k=1:numel(runs)
        out=psy.run_output_dir(output,runs(k));
        result.runs(k)=verifyCompleted(out,runs(k),details(k),plans{k},cfg);
    end
    result.status='complete';result.report=report;
    result.resolved_preprocessing_config=jsonSafe(cfg);
    result.output_files=filesUnder(output);
end
checkSources(toolkit,spmRoot);
if ~strcmp(psy.file_sha256(configFile),approvedHash)
    error('cogneuro:PreprocessConfigHash','Official configuration changed during this attempt');
end
end

function validateJob(job)
required={'schema_version','route','mode','toolkit_root','spm_root','manifest_file', ...
    'work_root','output_root','options','expected_runs'};
if ~isstruct(job)||~isscalar(job)||~all(isfield(job,required))|| ...
        ~isequal(job.schema_version,1)||~text(job.route)||~strcmp(job.route,'preprocess')|| ...
        ~text(job.mode)||~ismember(string(job.mode),["preflight","execute"])
    error('cogneuro:PreprocessJob','Expected schema 1 preprocess job and preflight/execute mode');
end
if ~isstruct(job.options)||~isscalar(job.options)|| ...
        ~all(isfield(job.options,{'preprocessing','max_matrix_gib'}))|| ...
        ~positive(job.options.max_matrix_gib)
    error('cogneuro:PreprocessOptions','Explicit positive max_matrix_gib and preprocessing options required');
end
p=job.options.preprocessing;
if ~isstruct(p)||~isscalar(p)||~all(isfield(p,{'stop_after','toolkit_config_sha256','overrides'}))|| ...
        ~text(p.stop_after)||~ismember(string(p.stop_after),["realign","segment","smooth"])|| ...
        ~text(p.toolkit_config_sha256)||isempty(regexp(char(p.toolkit_config_sha256),'^[a-fA-F0-9]{64}$','once'))
    error('cogneuro:PreprocessOptions','Explicit stop_after, official configuration SHA256 and overrides required');
end
if ~isstruct(job.expected_runs)||isempty(job.expected_runs)|| ...
        ~all(isfield(job.expected_runs,{'subject','session','run','tr_seconds'}))
    error('cogneuro:PreprocessIdentity','Expected every approved subject/session/run and TR');
end
end

function cfg=applyOverrides(cfg,overrides)
% 科学参数白名单：单位/约束仍由官方各options/plan/validate函数检查。
allowed={'sliceTiming.enabled','sliceTiming.seconds','sliceTiming.referenceSeconds', ...
    'sliceTiming.mode','sliceTiming.acquisitionTimeSeconds','sliceTiming.reference','sliceTiming.microtimeResolution', ...
    'realign.quality','realign.separationMm','realign.smoothingFwhmMm','realign.registerToMean', ...
    'realign.estimateInterpolation','realign.writeInterpolation','realign.wrap','realign.mask', ...
    'segment.backend','segment.biasRegularisation','segment.biasFwhmMm', ...
    'segment.gaussians','segment.affineRegistration','segment.mrf','segment.cleanup', ...
    'segment.warpRegularisation','segment.warpSamplingMm','segment.deformationFields', ...
    'segment.saveBias','segment.smoothnessMm','segment.nativeOutputs','segment.warpedOutputs', ...
    'coreg.costFunction','coreg.separationMm','coreg.smoothingFwhmMm','coreg.tolerance', ...
    'sdc.method','normalise.method','normalise.interpolation','voxelSizeMm','boundingBoxMm', ...
    'smoothingFwhmMm','smooth.dataType','smooth.implicitMasking','smooth.prefix', ...
    'qc.enabled','qc.maskFraction','qc.maxResliceNonfiniteFraction','fdRadiusMm','fdFlagMm'};
if isempty(overrides),return;end
if ~isstruct(overrides)||~all(isfield(overrides,{'path','value'}))
    error('cogneuro:PreprocessOverride','Overrides must be an array of {path,value} records');
end
seen={};
for k=1:numel(overrides)
    key=overrides(k).path;
    if ~text(key)||~ismember(char(key),allowed)||ismember(char(key),seen)
        error('cogneuro:PreprocessOverride','Unknown, forbidden or repeated scientific override path');
    end
    key=char(key);seen{end+1}=key;value=overrides(k).value; %#ok<AGROW>
    if strcmp(key,'segment.biasFwhmMm')&&text(value)&&strcmp(value,'Inf'),value=Inf;end
    if isnumeric(value)&&isvector(value)&&~strcmp(key,'boundingBoxMm'),value=value(:)';end
    if ismember(key,{'segment.nativeOutputs','segment.warpedOutputs'})
        if isstring(value),value=cellstr(value);end
        if iscell(value),value=reshape(value,1,[]);end
    end
    parts=strsplit(key,'.');
    if numel(parts)==1,cfg.(parts{1})=value;
    else,cfg.(parts{1}).(parts{2})=value;end
end
end

function checkPilotConfiguration(cfg)
% 不将用户选定的其他算法/额外输入静默关闭；不支持的设置须重新审阅。
if ~strcmp(cfg.sdc.method,'none')||~strcmp(cfg.segment.backend,'spm')|| ...
        ~strcmp(cfg.normalise.method,'segmentation')||~strcmp(cfg.distortionCorrection,'not_applied')|| ...
        cfg.dicom.enabled||cfg.atlas.enabled||~isempty(cfg.atlas.manifestFile)|| ...
        ~isempty(cfg.segment.channelsFile)||~strcmp(cfg.segment.channelAlignment,'require_aligned')|| ...
        cfg.segment.inputVolume~=1|| ...
        (~isempty(cfg.realign.weightImage)&&~strcmpi(cfg.realign.weightImage,'none'))
    error('cogneuro:PreprocessPilot','Unsupported official/overridden configuration; pilot requires SPM, segmentation normalisation, no SDC/DICOM/extra anatomy/atlas/weighting');
end
if ~positive(cfg.fdRadiusMm)||~positive(cfg.fdFlagMm)|| ...
        ~flag(cfg.qc.enabled)|| ...
        ~positive(cfg.qc.maskFraction)||cfg.qc.maskFraction>=1|| ...
        ~positive(cfg.qc.maxResliceNonfiniteFraction)||cfg.qc.maxResliceNonfiniteFraction>=1
    error('cogneuro:PreprocessOptions','FD parameters must be positive and QC fractions strictly in (0,1)');
end
% 原生浅预检部分字段仅检查数值范围；补齐SPM菜单实际要求的数组形状。
if ~positive(cfg.realign.separationMm)|| ...
        ~isnumeric(cfg.realign.smoothingFwhmMm)||~isreal(cfg.realign.smoothingFwhmMm)|| ...
        ~isscalar(cfg.realign.smoothingFwhmMm)||~isfinite(cfg.realign.smoothingFwhmMm)|| ...
        cfg.realign.smoothingFwhmMm<0||~isscalar(cfg.realign.estimateInterpolation)|| ...
        ~isnumeric(cfg.coreg.smoothingFwhmMm)||~isreal(cfg.coreg.smoothingFwhmMm)|| ...
        ~isequal(size(cfg.coreg.smoothingFwhmMm),[1 2])|| ...
        any(~isfinite(cfg.coreg.smoothingFwhmMm))||any(cfg.coreg.smoothingFwhmMm<0)
    error('cogneuro:PreprocessOptions','SPM Realign separation/FWHM/interpolation must be scalar; Coreg FWHM must have two finite nonnegative entries');
end
end

function validateRuns(runs,expected,work,output)
if numel(runs)~=numel(expected),error('cogneuro:PreprocessIdentity','Manifest count differs from approved runs');end
for k=1:numel(runs)
    r=runs(k);e=expected(k);
    if ~text(e.subject)||~text(e.session)||~text(e.run)||~positive(e.tr_seconds)|| ...
            ~strcmp(r.subject,e.subject)||~strcmp(r.session,e.session)||~strcmp(r.name,e.run)
        error('cogneuro:PreprocessIdentity','Approved identity differs at manifest row %d',k);
    end
    if ~strcmp(r.inputStage,'raw')||(~isempty(r.sdcMethod)&&~strcmp(r.sdcMethod,'none'))|| ...
            ~isempty(r.anatomyChannels)||~isempty(r.atlases)||~isempty(r.anatomyReuseDir)|| ...
            ~isempty(r.fieldmaps)||~isempty(r.fieldmapEpi)|| ...
            (~isempty(r.realignWeightImage)&&~strcmpi(r.realignWeightImage,'none'))
        error('cogneuro:PreprocessPilot','Unsupported per-run input stage or SDC/anatomy/atlas/weight/reuse declaration');
    end
    for key={'bold','t1'}
        file=r.(key{1});
        if isempty(file)||~endsWith(lower(file),'.nii')||~isfile(file)
            error('cogneuro:PreprocessInput','Every row requires staged uncompressed .nii BOLD and real T1');
        end
    end
    for key={'bold','t1','events','metadata','sbref','provenance'}
        file=r.(key{1});
        if ~isempty(file)&&(within(absolute(file,true),work)||within(absolute(file,true),output))
            error('cogneuro:PreprocessOutput','An input cannot be inside work/output roots');
        end
    end
end
end

function checked=checkImages(run,expectedTR,budget)
h=niftiinfo(run.bold);t=niftiinfo(run.t1);
if numel(h.ImageSize)~=4||h.ImageSize(4)<2||numel(t.ImageSize)~=3|| ...
        ~strcmpi(h.SpaceUnits,'millimeter')||~strcmpi(t.SpaceUnits,'millimeter')
    error('cogneuro:PreprocessShape','Pilot requires >=2-frame 4D BOLD and a 3D T1 in millimeters');
end
tr=h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond',tr=tr/1000;
    case 'microsecond',tr=tr/1e6;
    otherwise,error('cogneuro:PreprocessTR','Unknown raw BOLD time units');
end
if ~positive(tr)||abs(tr-expectedTR)>1e-6*max(1,expectedTR)
    error('cogneuro:PreprocessTR','Raw BOLD TR differs from approved seconds');
end
arrayGiB=8*(prod(double(h.ImageSize))+prod(double(t.ImageSize)))/2^30;
if arrayGiB>budget,error('cogneuro:PreprocessMemory','Checked raw arrays %.4g GiB exceed approved budget',arrayGiB);end
volumes=spm_vol(run.bold);
if numel(volumes)~=h.ImageSize(4),error('cogneuro:PreprocessShape','SPM/header frame counts disagree');end
for k=1:numel(volumes)
    checkVolume(volumes(k));
    values=spm_read_vols(volumes(k));
    if any(~isfinite(values),'all'),error('cogneuro:PreprocessNonfinite','Raw BOLD contains nonfinite values at frame %d',k);end
end
v=spm_vol(run.t1);if ~isscalar(v),error('cogneuro:PreprocessShape','T1 must be 3D');end
checkVolume(v);values=spm_read_vols(v);
if any(~isfinite(values),'all'),error('cogneuro:PreprocessNonfinite','Raw T1 contains nonfinite values');end
checked=struct('n_frames',numel(volumes),'array_gib',arrayGiB);
end

function checkVolume(v)
if any(~isfinite(v.mat),'all')||abs(det(v.mat(1:3,1:3)))<eps||any(v.dim<1)
    error('cogneuro:PreprocessGeometry','Invalid NIfTI affine or spatial dimensions');
end
end

function item=verifyCompleted(out,run,item,plan,cfg)
marker=fullfile(out,'COMPLETE.mat');infoFile=fullfile(out,'input_info.mat');
planFile=fullfile(out,'preprocessing_plan.json');realignJob=fullfile(out,'02_realign.mat');
requireFiles({marker,infoFile,planFile,realignJob});done=load(marker);saved=load(infoFile);
if ~all(isfield(done,{'requiredOutputs','status','signature'}))|| ...
        ~strcmp(done.status,stageStatus(cfg.stopAfter))||~iscell(done.requiredOutputs)|| ...
        ~all(isfield(saved,{'run','info','cfg','plan'}))|| ...
        ~strcmp(saved.run.subject,run.subject)||~strcmp(saved.run.session,run.session)|| ...
        ~strcmp(saved.run.name,run.name)||~samePath(saved.run.bold,run.bold)|| ...
        ~samePath(saved.run.t1,run.t1)||saved.info.nVolumes~=item.input_frames|| ...
        abs(saved.info.trSeconds-item.tr_seconds)>1e-6|| ...
        saved.plan.dummy.retainedVolumes~=item.retained_frames|| ...
        ~strcmp(saved.cfg.stopAfter,cfg.stopAfter)||~saved.cfg.execute||saved.cfg.resume|| ...
        saved.cfg.continueOnError||~strcmp(saved.plan.sdc.method,'none')|| ...
        ~strcmp(saved.cfg.inputStage,'raw')||~samePath(saved.cfg.manifestFile,cfg.manifestFile)|| ...
        ~samePath(saved.cfg.outputRoot,cfg.outputRoot)||~isequaln(saved.plan,plan)
    error('cogneuro:PreprocessCompletion','Native completion/input metadata do not match approved run/plan');
end
required=cellfun(@(f)absolute(f,true),done.requiredOutputs,'UniformOutput',false);
requireFiles(required);
if any(~cellfun(@(f)within(f,out),required))
    error('cogneuro:PreprocessCompletion','Required derivative points outside its private run output');
end
batch=load(realignJob,'matlabbatch');
try
    realign=batch.matlabbatch{1}.spm.spatial.realign.estwrite;
    scans=realign.data{1};prefix=realign.roptions.prefix;
catch
    error('cogneuro:PreprocessCompletion','Expected actual Realign Estimate/Write job not found');
end
if ~iscell(scans)||numel(scans)~=item.retained_frames||~text(prefix)||isempty(prefix)
    error('cogneuro:PreprocessCompletion','Realign job frame count/prefix mismatch');
end
inputs=cellfun(@(f)regexprep(char(f),',\d+$',''),scans,'UniformOutput',false);
if numel(unique(inputs))~=1,error('cogneuro:PreprocessCompletion','Realign job mixes BOLD sources');end
[folder,stem,ext]=fileparts(inputs{1});
item.realigned_bold=absolute(fullfile(folder,[char(prefix) stem ext]),true);
item.motion_file=absolute(fullfile(folder,['rp_' stem '.txt']),true);
requireMembers({item.realigned_bold,item.motion_file,planFile},required);
checkDerivative(item.realigned_bold,item.retained_frames,item.tr_seconds);
motion=readmatrix(item.motion_file,'FileType','text');
if ~isequal(size(motion),[item.retained_frames 6])||any(~isfinite(motion),'all')
    error('cogneuro:PreprocessCompletion','Motion file is not retained-frame-by-six finite SPM parameters');
end
if strcmp(cfg.stopAfter,'smooth')
    sm=fullfile(out,'SMOOTHING_COMPLETE.mat');requireMembers({sm},required);
    smooth=load(sm,'record');r=smooth.record;
    if ~all(isfield(r,{'input','output','nVolumes','trSeconds'}))|| ...
            r.nVolumes~=item.retained_frames||abs(r.trSeconds-item.tr_seconds)>1e-6
        error('cogneuro:PreprocessCompletion','Smoothing completion metadata differs from run');
    end
    item.normalized_bold=absolute(r.input,true);item.smoothed_bold=absolute(r.output,true);
    requireMembers({item.normalized_bold,item.smoothed_bold},required);
    checkDerivative(item.normalized_bold,item.retained_frames,item.tr_seconds);
    checkDerivative(item.smoothed_bold,item.retained_frames,item.tr_seconds);
elseif strcmp(cfg.stopAfter,'segment')
    requireMembers({fullfile(out,'SEGMENT_COMPLETE.mat')},required);
end
if plan.dummy.count>0&&~isempty(run.events)
    eventPath=fullfile(out,'dummy_trim','events_retained_first_volume.tsv');
    requireMembers({eventPath},required);item.adjusted_events=eventPath;
else
    item.adjusted_events=run.events;
end
item.output_path=out;item.completion_marker=marker;item.plan_file=planFile;
item.executed_steps=item.planned_steps;
end

function checkDerivative(file,frames,tr)
v=spm_vol(file);n=nifti(file);
if numel(v)~=frames||~isfield(n.timing,'tspace')||abs(n.timing.tspace-tr)>1e-6*max(1,tr)
    error('cogneuro:PreprocessCompletion','Derivative frame count or TR differs from retained input');
end
end

function requireMembers(files,required)
requireFiles(files);
for k=1:numel(files)
    if ~any(cellfun(@(p)samePath(absolute(files{k},true),p),required))
        error('cogneuro:PreprocessCompletion','Derivative is absent from native COMPLETE.requiredOutputs');
    end
end
end

function verifyReport(report,runs,status)
if numel(report)~=numel(runs)||any(~strcmp({report.status},status))
    error('cogneuro:PreprocessCompletion','Native report does not confirm every requested run/stage');
end
for k=1:numel(runs)
    if ~strcmp(report(k).subject,runs(k).subject)||~strcmp(report(k).session,runs(k).session)|| ...
            ~strcmp(report(k).run,runs(k).name)
        error('cogneuro:PreprocessIdentity','Native report identity mismatch');
    end
end
end

function steps=plannedSteps(plan,cfg)
steps={};if plan.dummy.count>0,steps{end+1}='discard_dummy_working_copy';end
if plan.slice.enabled,steps{end+1}='slice_timing';end
steps=[steps {'realign_estimate_write','motion_qc'}];
if cfg.qc.enabled,steps{end+1}='timeseries_qc';end
if ismember(cfg.stopAfter,{'segment','smooth'}),steps{end+1}='spm_segment';end
if strcmp(cfg.stopAfter,'smooth'),steps=[steps {'coregister_estimate','normalise_write','smooth'}];end
end

function value=stageStatus(stage)
switch stage
    case 'realign',value='realigned_without_distortion_correction';
    case 'segment',value='segmented_without_distortion_correction';
    case 'smooth',value='spatial_pipeline_without_distortion_correction';
end
end

function sources=checkSources(toolkit,spmRoot)
names={'preprocess_batch','validate_preprocess_config','read_manifest','inspect_run','inspect_contract', ...
    'preprocess_plan','slice_timing_plan','dummy_plan','segment_plan','segment_options','atlas_options', ...
    'normalise_options','smooth_options','process_run','stage_image','trim_dummy_bold','write_dummy_events', ...
    'spm_motion_step','motion_qc','timeseries_qc','spatial_steps','segment_run','spm_segment_batch', ...
    'smooth_run','smooth_record','spm_step','run_output_dir','file_sha256','segment_output_flags','deformation_field_flags', ...
    'stage_anatomy','realign_weight_plan','sdc_spm_options','has_dicom_sources','read_events_tsv'};
sources=struct([]);
allNames=[{'toolkit_config'} cellfun(@(n)['psy.' n],names,'UniformOutput',false) ...
    {'spm','spm_jobman','spm_vol','spm_read_vols','nifti','file_array'}];
for k=1:numel(allNames)
    name=allNames{k};file=which(name);
    if k==1,expected=fullfile(toolkit,'config','toolkit_config.m');root=toolkit;
    elseif k<=numel(names)+1,expected=fullfile(toolkit,'matlab','+psy',[names{k-1} '.m']);root=toolkit;
    else,expected='';root=spmRoot;end
    if isempty(file)||~isfile(file)||~within(absolute(file,true),root)|| ...
            (~isempty(expected)&&~samePath(absolute(file,true),absolute(expected,true)))
        error('cogneuro:PreprocessSource','%s does not resolve to the selected toolkit/SPM',name);
    end
    entry=struct('name',name,'path',absolute(file,true));
    if isempty(sources),sources=entry;else,sources(end+1)=entry;end %#ok<AGROW>
end
end

function files=filesUnder(folder)
listing=dir(fullfile(folder,'**','*'));listing=listing(~[listing.isdir]);
files=arrayfun(@(d)fullfile(d.folder,d.name),listing,'UniformOutput',false);
files=reshape(files,1,[]);
end

function requireFiles(files)
for k=1:numel(files)
    d=dir(files{k});if isempty(d)||d.isdir||d.bytes==0,error('cogneuro:PreprocessMissing','Missing/empty file: %s',files{k});end
end
end

function value=jsonSafe(value)
if isstruct(value)
    for k=1:numel(value)
        fields=fieldnames(value);
        for j=1:numel(fields),value(k).(fields{j})=jsonSafe(value(k).(fields{j}));end
    end
elseif iscell(value)
    for k=1:numel(value),value{k}=jsonSafe(value{k});end
elseif isnumeric(value)&&any(~isfinite(value),'all')
    cells=num2cell(value);
    for k=1:numel(cells)
        if isinf(cells{k})&&cells{k}>0,cells{k}='Inf';
        elseif isinf(cells{k}),cells{k}='-Inf';
        elseif isnan(cells{k}),cells{k}='NaN';end
    end
    if isscalar(value),value=cells{1};else,value=cells;end
end
end

function value=absolute(value,mustExist)
if ~text(value)||isempty(value)||~java.io.File(char(value)).isAbsolute()
    error('cogneuro:PreprocessPath','Absolute paths are required');
end
value=char(java.io.File(char(value)).getCanonicalPath());
if mustExist&&~isfile(value)&&~isfolder(value),error('cogneuro:PreprocessPath','Path does not exist: %s',value);end
end
function assertFresh(folder)
if isfile(folder)||isfolder(folder),error('cogneuro:PreprocessOutput','Use a new absent work/output root');end
end
function yes=within(file,root)
file=strrep(char(file),'\','/');root=strrep(char(root),'\','/');
while numel(root)>1&&root(end)=='/',root(end)=[];end
if ispc,file=lower(file);root=lower(root);end
yes=strcmp(file,root)||startsWith(file,[root '/']);
end
function yes=samePath(a,b)
if ispc,yes=strcmpi(a,b);else,yes=strcmp(a,b);end
end
function yes=overlap(a,b)
yes=within(a,b)||within(b,a);
end
function yes=text(value)
yes=(ischar(value)&&(isrow(value)||isempty(value)))|| ...
    (isstring(value)&&isscalar(value)&&~ismissing(value));
end
function yes=positive(value)
yes=isnumeric(value)&&isreal(value)&&isscalar(value)&&isfinite(value)&&value>0;
end
function yes=flag(value)
yes=isscalar(value)&&(islogical(value)||(isnumeric(value)&&isreal(value)&&isfinite(value)&&ismember(value,[0 1])));
end
function restoreEnvironment(oldPath,oldDirectory)
path(oldPath);if isfolder(oldDirectory),cd(oldDirectory);end
end
