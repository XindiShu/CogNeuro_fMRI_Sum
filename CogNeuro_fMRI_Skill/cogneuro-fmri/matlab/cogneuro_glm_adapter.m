function result=cogneuro_glm_adapter(job)
%COGNEURO_GLM_ADAPTER 显式确认后的 run 级 canonical SPM GLM 试点适配器。
% 仅读取输入；设计预检只写 work_root，正式估计只写新建的 output_root。
% 不把工程预检或计算完成解释为实验设计、配准或科研结论已经验收。
validateJob(job);
previousPath=path;previousDirectory=pwd;
restore=onCleanup(@()restoreEnvironment(previousPath,previousDirectory)); %#ok<NASGU>
toolkit=absolutePath(job.toolkit_root,true);spmRoot=absolutePath(job.spm_root,true);
work=absolutePath(job.work_root,false);output=absolutePath(job.output_root,false);
manifest=absolutePath(job.manifest_file,true);
assertFresh(work,'work_root');assertFresh(output,'output_root');
if overlaps(work,output)||within(work,toolkit)||within(output,toolkit)||within(work,spmRoot)||within(output,spmRoot)
    error('cogneuro:GLMOutput','Work/output roots must be separate and outside toolkit/SPM installations');
end
addpath(fullfile(toolkit,'matlab'),'-begin');
addpath(fullfile(toolkit,'config'),'-begin');addpath(spmRoot,'-begin');
verifyLoaded('spm',fullfile(spmRoot,'spm.m'));
for name={'spm_jobman','spm_vol','spm_read_vols','spm_filter'}
    verifyLoaded(name{1},fullfile(spmRoot,[name{1} '.m']));
end
verifyLoaded('glm_config',fullfile(toolkit,'config','glm_config.m'));
verifyLoaded('design_config',fullfile(toolkit,'config','design_config.m'));
dependencies={'glm_batch','glm_framework_run','glm_framework_options','glm_framework_plan', ...
    'confound_design','glm_model_contrasts','glm_highpass_rank','glm_diagnostics','verify_glm','spm_step','run_output_dir'};
for k=1:numel(dependencies)
    verifyLoaded(['psy.' dependencies{k}],fullfile(toolkit,'matlab','+psy',[dependencies{k} '.m']));
end
cfg=configuration(job,toolkit,spmRoot,manifest,output);
runs=readRuns(manifest,job.expected_runs,work,output);
spm('defaults','fmri');spm_jobman('initcfg');
metrics=struct([]);
for k=1:numel(runs)
    % [约束] 每帧按显式掩膜逐体素检查；不自动配准或发明脑掩膜。
    checked=checkImages(runs(k),job.options.max_matrix_gib);
    if abs(checked.tr_seconds-runs(k).expected_tr_seconds)>1e-6*max(1,checked.tr_seconds)
        error('cogneuro:GLMTR','BOLD TR differs from the confirmed per-run TR');
    end
    % 先读取列/FD元数据，在原生函数分配 spike 矩阵和做 SVD 之前拒绝超预算设计。
    [confoundTable,nuisanceColumns]=previewConfounds(runs(k).confounds,cfg.design,checked.n_frames);
    % [单位/约束] GiB=2^30 字节；保守上界包括尚未剔除的常量混杂列，不是峰值内存保证。
    columns=numel(cfg.conditions)+nuisanceColumns;
    designGiB=8*(8*checked.n_frames*columns+4*columns^2+checked.n_frames^2)/2^30;
    if designGiB>job.options.max_matrix_gib
        error('cogneuro:GLMMemory','Conservative design-array estimate %.3g GiB exceeds confirmed budget',designGiB);
    end
    nuisances=psy.confound_design(confoundTable,cfg.design);
    p=psy.glm_framework_plan(runs(k).events,checked.n_frames*checked.tr_seconds,cfg);
    checked.design_array_estimate_gib=designGiB;
    checked.n_events=p.nEvents;checked.negative_onset_count=p.negativeOnsetCount;
    checked.event_end_overrun_seconds=p.modeledEndOverrunSeconds;
    checked.dropped_constant_confound_columns=nuisances.droppedConstantColumns;
    checked.dependent_confound_column_count=nuisances.dependentColumnCount;
    if isempty(metrics),metrics=checked;else,metrics(end+1)=checked;end %#ok<AGROW>
end
% 所有输入预检通过后才建立私有设计目录；保留失败证据，绝不清理已有结果。
mkdir(work);
for k=1:numel(runs)
    out=psy.run_output_dir(work,runs(k));
    summary=psy.glm_framework_run(runs(k),cfg,out);
    if ~strcmp(summary.status,'framework_prepared_not_estimated')
        error('cogneuro:GLMPreflight','Unexpected toolkit preparation state');
    end
    modelDir=fullfile(out,'models','joint');
    specification=load(fullfile(modelDir,'specification.mat'),'b');
    psy.spm_step(specification.b,fullfile(modelDir,'preflight_specify.mat'));
    loaded=load(fullfile(modelDir,'SPM.mat'),'SPM');SPM=loaded.SPM;
    filtered=spm_filter(SPM.xX.K,SPM.xX.X);
    highpassRank=psy.glm_highpass_rank(SPM.xX.K);
    contrasts=psy.glm_model_contrasts(SPM.xX.name,cfg,filtered,cfg.minResidualDF+highpassRank);
    if isfield(SPM,'Vbeta')&&~isempty(SPM.Vbeta)
        error('cogneuro:GLMPreflight','Design-only preflight unexpectedly contains estimated betas');
    end
    metrics(k).filtered_design_rank=rank(filtered);
    metrics(k).highpass_basis_rank=highpassRank;
    metrics(k).remaining_dimensions=size(filtered,1)-rank(filtered)-highpassRank;
    metrics(k).n_design_columns=size(filtered,2);
    metrics(k).dependent_design_column_count=size(filtered,2)-rank(filtered);
    metrics(k).contrast_names={contrasts.name};
    metrics(k).contrast_estimability_checked=true;
    metrics(k).design_path=modelDir;metrics(k).status='preflight_passed';
    metrics(k).output_path='';metrics(k).completion_marker='';metrics(k).qc_path='';
    psy.glm_diagnostics(modelDir,cfg,false);
    audit=metrics(k); %#ok<NASGU>
    save(fullfile(modelDir,'cogneuro_preflight_audit.mat'),'audit','contrasts');
end
result=struct('schema_version',1,'route','glm','mode',char(job.mode), ...
    'status','preflight_passed','toolkit_root',toolkit,'spm_root',spmRoot, ...
    'work_root',work,'output_root',output,'runs',metrics, ...
    'policy',struct('level','run','engine','spm_classical','unit','condition', ...
        'fit','joint','hrf','canonical','event_expression','duration', ...
        'pmod_enabled',false,'qc_plot',false,'max_residual_voxels',32), ...
    'limitations',{{'Preflight specifies the real SPM design without image estimation; it does not prove fit, residual behavior, anatomy or scientific validity.', ...
        'Every BOLD frame is checked for finite values inside the supplied explicit mask; outside-mask values are not reviewed.', ...
        'Explicit-mask grid equality and finite data do not establish anatomical alignment or appropriate brain coverage.', ...
        'Remaining dimensions are algebraic after highpass projection, not SPM effective residual degrees of freedom.', ...
        'Run models are independent; no subject combination, group inference, pmod, FIR, LSA, LSS or GLMsingle is executed.', ...
        'Memory estimates limit checked arrays and are not a guarantee of MATLAB/SPM peak memory.'}});
result.output_files={};
if strcmp(job.mode,'preflight'),return;end
% [约束] 原生入口执行估计；继续使用新目录，不覆盖预检或用户已有结果。
cfg.execute=true;report=psy.glm_batch(cfg);
if numel(report)~=numel(runs)||any(~strcmp({report.status},'framework_models_estimated'))
    error('cogneuro:GLMIncomplete','Toolkit report does not confirm every requested run');
end
for k=1:numel(runs)
    runOut=psy.run_output_dir(output,runs(k));modelDir=fullfile(runOut,'models','joint');
    marker=fullfile(runOut,'GLM_FRAMEWORK_COMPLETE.mat');
    modelMarker=fullfile(modelDir,'COMPLETE.mat');
    requiredFiles={marker,modelMarker,fullfile(modelDir,'SPM.mat'),fullfile(modelDir,'glm_qc.json'), ...
        fullfile(modelDir,'model_diagnostics.json'),fullfile(runOut,'model_outputs.tsv'), ...
        fullfile(runOut,'model_status.tsv'),fullfile(runOut,'summary.json')};
    requireFiles(requiredFiles);
    complete=load(marker,'summary');modelComplete=load(modelMarker,'status','qc');
    if ~strcmp(complete.summary.status,'framework_models_estimated')|| ...
            ~strcmp(modelComplete.status,'run_glm_estimated_spatial_limitations_unchanged')|| ...
            complete.summary.nFrames~=metrics(k).n_frames||complete.summary.nModels~=1|| ...
            modelComplete.qc.nContrasts~=numel(cfg.contrastNames)|| ...
            ~isequal(modelComplete.qc.contrastNames,cfg.contrastNames)
        error('cogneuro:GLMIncomplete','Completion metadata differs from the requested run/model');
    end
    loaded=load(fullfile(modelDir,'SPM.mat'),'SPM');
    if ~isfield(loaded.SPM,'xCon')||numel(loaded.SPM.xCon)~=numel(cfg.contrastNames)|| ...
            ~isequal({loaded.SPM.xCon.name},cfg.contrastNames)|| ...
            ~all(strcmp({loaded.SPM.xCon.STAT},'T'))
        error('cogneuro:GLMIncomplete','Estimated contrast catalog differs from confirmation');
    end
    expectedMaps={fullfile(modelDir,'mask.nii'),fullfile(modelDir,'ResMS.nii')};
    for b=1:numel(loaded.SPM.Vbeta)
        expectedMaps{end+1}=fullfile(modelDir,sprintf('beta_%04d.nii',b)); %#ok<AGROW>
    end
    for c=1:numel(cfg.contrastNames)
        expectedMaps(end+1:end+2)={fullfile(modelDir,sprintf('con_%04d.nii',c)), ...
            fullfile(modelDir,sprintf('spmT_%04d.nii',c))}; %#ok<AGROW>
    end
    requireFiles(expectedMaps);
    result.output_files=[result.output_files requiredFiles expectedMaps];
    result.runs(k).status='complete';result.runs(k).output_path=runOut;
    result.runs(k).completion_marker=marker;result.runs(k).qc_path=fullfile(modelDir,'glm_qc.json');
end
result.status='complete';
end

function [t,columns]=previewConfounds(file,cfg,nFrames)
%PREVIEWCONFOUNDS 只读表格和选择元数据；此处不构造 spike/正交基或执行 SVD。
t=readtable(file,'FileType','text','Delimiter','\t');
if height(t)~=nFrames,error('cogneuro:GLMLength','Confounds/BOLD frame counts differ');end
base={'trans_x','trans_y','trans_z','rot_x','rot_y','rot_z'};
switch cfg.motionModel
    case 'none',names={};
    case '6',names=base;
    case '24',names=[base,strcat(base,'_derivative1'),strcat(base,'_power2'),strcat(base,'_derivative1_power2')];
    otherwise,error('psy:DesignMotion','Choose none, 6 or 24');
end
if cfg.includeTissueMeans,names=[names,{'white_matter','csf'}];end
if ~all(ismember(names,t.Properties.VariableNames))
    error('psy:DesignColumns','Missing selected confound columns');
end
spikes=0;
if cfg.addSpikes
    if ~ismember('framewise_displacement',t.Properties.VariableNames)
        error('psy:DesignColumns','FD column required for spikes');
    end
    fd=t.framewise_displacement;
    if ~isnumeric(fd)||any(~isfinite(fd)|fd<0)
        error('psy:DesignFD','FD must be finite nonnegative');
    end
    spikes=nnz(fd>cfg.fdThresholdMm); % [约束] 与原生算法一致，严格大于阈值；不扩展邻帧。
end
columns=1+numel(names)+double(cfg.linearTrend)+spikes; % 截距始终保留；不预先剔除常量列。
end

function cfg=configuration(job,toolkit,spmRoot,manifest,output)
% [配置] 官方 glm_config 只读入内存；不改写任何已定稿工具包配置。
cfg=glm_config;g=job.options.glm;c=g.confounds;
cfg.manifestFile=manifest;cfg.outputRoot=output;cfg.spmPath=spmRoot;cfg.execute=false;
cfg.conditions=reshape(cellstr(string(job.options.conditions)),1,[]);
cfg.contrastNames=reshape({job.options.contrasts.name},1,[]);
cfg.contrastWeights=zeros(numel(job.options.contrasts),numel(cfg.conditions));
for k=1:numel(job.options.contrasts)
    cfg.contrastNames{k}=char(cfg.contrastNames{k});
    cfg.contrastWeights(k,:)=reshape(job.options.contrasts(k).weights,1,[]);
end
cfg.model=struct('unit','condition','targetConditions',{{}});
cfg.events=struct('expression','duration','fixedDurationSeconds',1);
cfg.hrf.type='canonical';cfg.pmod=struct('enabled',false, ...
    'modulators',struct('condition',{},'column',{},'name',{},'poly',{}), ...
    'center','within_condition','scale','none','orthogonalize',false);
cfg.fit=struct('strategy','joint','lssGrouping','condition');
cfg.level='run';cfg.engine='spm_classical';cfg.subject.combineSessions=false;
cfg.explicitMask='';cfg.qc=struct('plot',false,'maxResidualVoxels',32);
cfg.highpassSeconds=g.highpass_seconds;cfg.serialCorrelation=char(g.serial_correlation);
cfg.microtimeResolution=g.microtime_resolution;cfg.microtimeOnset=g.microtime_onset;
cfg.maskThreshold=g.mask_threshold;cfg.minResidualDF=g.min_residual_df;
cfg.continueOnError=false;
cfg.design=struct('motionModel',char(c.motion_model),'includeTissueMeans',c.include_tissue_means, ...
    'linearTrend',c.linear_trend,'addSpikes',c.add_spikes,'fdThresholdMm',c.fd_threshold_mm, ...
    'minResidualDF',c.min_residual_df);
cfg.glmsingle.path=fullfile(toolkit,'external','glmsingle');
cfg=psy.glm_framework_options(cfg);
end

function runs=readRuns(manifest,expected,work,output)
o=detectImportOptions(manifest,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','run','bold','events','confounds','temporal_state','mask'};
if ~all(ismember(required,o.VariableNames))||any(~ismember(o.VariableNames,required))
    error('cogneuro:GLMManifest','Pilot manifest requires exactly subject/session/run/bold/events/confounds/temporal_state/mask');
end
o.DataLines=[2 Inf];o.ConsecutiveDelimitersRule='split';o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string');t=fillmissing(readtable(manifest,o),'constant',"");
if isempty(t)||height(t)~=numel(expected),error('cogneuro:GLMRuns','Manifest and confirmed run counts differ');end
runs=struct([]);keys=strings(height(t),1);expectedKeys=strings(numel(expected),1);
for k=1:numel(expected)
    expectedKeys(k)=runKey(expected(k).subject,expected(k).session,expected(k).run);
end
if numel(unique(expectedKeys))~=numel(expectedKeys),error('cogneuro:GLMRuns','Duplicate confirmed run identity');end
for k=1:height(t)
    keys(k)=runKey(t.subject(k),t.session(k),t.run(k));
    match=find(expectedKeys==keys(k));
    if numel(match)~=1,error('cogneuro:GLMRuns','Manifest identity differs from confirmed runs');end
    if ~strcmp(t.temporal_state(k),'unfiltered_unregressed')
        error('cogneuro:GLMState','Pilot requires confirmed unfiltered_unregressed BOLD');
    end
    r=struct('subject',char(t.subject(k)),'session',char(t.session(k)),'name',char(t.run(k)), ...
        'temporal_state','unfiltered_unregressed','expected_tr_seconds',expected(match).tr_seconds);
    for field={'bold','events','confounds','mask'}
        p=absolutePath(char(t.(field{1})(k)),true);
        if isfolder(p)||within(p,work)||within(p,output),error('cogneuro:GLMInput','Input must be a file outside fresh work/output roots');end
        r.(field{1})=p;
    end
    if isempty(runs),runs=r;else,runs(end+1)=r;end %#ok<AGROW>
end
if numel(unique(keys))~=numel(keys),error('cogneuro:GLMRuns','Duplicate manifest run identity');end
end

function result=checkImages(r,budget)
if ~endsWith(lower(r.bold),'.nii')||~endsWith(lower(r.mask),'.nii')
    error('cogneuro:GLMInput','Stage uncompressed .nii BOLD and explicit mask before calling the adapter');
end
volumes=spm_vol(r.bold);h=niftiinfo(r.bold);maskVolume=spm_vol(r.mask);
if numel(volumes)<3||numel(h.PixelDimensions)<4,error('cogneuro:GLMTR','A 4-D BOLD with at least three frames is required');end
tr=h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond',tr=tr/1000;
    case 'microsecond',tr=tr/1e6;
    otherwise,error('cogneuro:GLMTR','BOLD time units must be known');
end
positive(tr,'TR');reference=volumes(1);
if numel(reference.dim)~=3||any(~isfinite(reference.dim)|reference.dim<1)|| ...
        ~isequal(size(reference.mat),[4 4])||any(~isfinite(reference.mat),'all')|| ...
        rank(reference.mat)<4
    error('cogneuro:GLMGrid','Invalid BOLD dimensions or affine');
end
% [单位/约束] 同时保留掩膜、当前 double 帧和临时数组的保守估计；按帧读取。
frameGiB=32*prod(double(reference.dim))/2^30;
if frameGiB>budget,error('cogneuro:GLMMemory','Single-frame check estimate exceeds confirmed GiB budget');end
if ~isscalar(maskVolume)||~sameGrid(reference,maskVolume)
    error('cogneuro:GLMMask','Explicit mask and BOLD must have identical dimensions and affine');
end
maskValues=spm_read_vols(maskVolume);
if any(~isfinite(maskValues(:))|maskValues(:)<0)||~any(maskValues(:)>0)
    error('cogneuro:GLMMask','Explicit mask must be finite, nonnegative and nonempty');
end
mask=maskValues>0;clear maskValues;
for k=1:numel(volumes)
    if ~sameGrid(reference,volumes(k)),error('cogneuro:GLMGrid','BOLD frame grids differ');end
    values=spm_read_vols(volumes(k));
    if any(~isfinite(values(mask))),error('cogneuro:GLMNonfinite','Nonfinite BOLD value inside explicit mask at frame %d',k);end
end
result=struct('subject',r.subject,'session',r.session,'run',r.name,'n_frames',numel(volumes), ...
    'tr_seconds',tr,'dimensions',reference.dim,'masked_voxels',nnz(mask), ...
    'masked_bold_all_frames_finite',true,'grid_checked_all_frames',true, ...
    'frame_array_estimate_gib',frameGiB);
end

function same=sameGrid(a,b)
same=isequal(a.dim,b.dim)&&isequal(size(b.mat),[4 4])&&all(isfinite(b.mat),'all')&& ...
    max(abs(a.mat-b.mat),[],'all')<=1e-5;
end

function validateJob(j)
required={'schema_version','route','mode','toolkit_root','spm_root','manifest_file','output_root','work_root','options','expected_runs'};
if ~isstruct(j)||~isscalar(j)||~all(isfield(j,required))||~isequal(j.schema_version,1)|| ...
        ~textChoice(j.route,{'glm'})||~textChoice(j.mode,{'preflight','execute'})
    error('cogneuro:GLMJob','Invalid schema_version/route/mode or missing job fields');
end
o=j.options;fields={'conditions','contrasts','glm','max_matrix_gib'};
if ~isstruct(o)||~isscalar(o)||~all(isfield(o,fields))||any(~ismember(fieldnames(o),fields))
    error('cogneuro:GLMOptions','Unknown or missing GLM options');
end
positive(o.max_matrix_gib,'max_matrix_gib');
conditions=string(o.conditions(:));
if isempty(conditions)||numel(unique(conditions))~=numel(conditions)|| ...
        any(ismissing(conditions))||any(cellfun(@isempty,regexp(cellstr(conditions),'^[A-Za-z][A-Za-z0-9_]*$','once')))
    error('cogneuro:GLMOptions','Conditions must be unique letter-led simple labels');
end
if ~isstruct(o.contrasts)||isempty(o.contrasts)||~all(isfield(o.contrasts,{'name','weights'}))|| ...
        any(~ismember(fieldnames(o.contrasts),{'name','weights'}))
    error('cogneuro:GLMOptions','contrasts must contain name and weights');
end
names=strings(numel(o.contrasts),1);
for k=1:numel(o.contrasts)
    names(k)=string(o.contrasts(k).name);w=o.contrasts(k).weights;
    if ~isscalar(names(k))||ismissing(names(k))||strlength(strtrim(names(k)))==0|| ...
            ~isempty(regexp(char(names(k)),'[\x00-\x1f]','once'))|| ...
            ~isnumeric(w)||~isreal(w)||~isvector(w)||numel(w)~=numel(conditions)||any(~isfinite(w))||all(w==0)
        error('cogneuro:GLMOptions','Each contrast needs a nonempty name and finite nonzero weights matching conditions');
    end
end
if numel(unique(names))~=numel(names),error('cogneuro:GLMOptions','Duplicate contrast names');end
g=o.glm;fields={'highpass_seconds','microtime_resolution','microtime_onset','serial_correlation', ...
    'hrf','min_residual_df','mask_threshold','confounds'};
exactFields(g,fields,'glm');positive(g.highpass_seconds,'highpass_seconds');
positiveInteger(g.microtime_resolution,'microtime_resolution');positiveInteger(g.microtime_onset,'microtime_onset');
positiveInteger(g.min_residual_df,'min_residual_df');
if g.microtime_onset>g.microtime_resolution||~textChoice(g.serial_correlation,{'AR(1)','FAST'})|| ...
        ~textChoice(g.hrf,{'canonical'})||~finiteScalar(g.mask_threshold)||g.mask_threshold<0||g.mask_threshold>1
    error('cogneuro:GLMOptions','Invalid microtime/serial/HRF/mask option');
end
c=g.confounds;exactFields(c,{'motion_model','include_tissue_means','linear_trend','add_spikes','fd_threshold_mm','min_residual_df'},'confounds');
if ~textChoice(c.motion_model,{'none','6','24'})||~finiteScalar(c.fd_threshold_mm)||c.fd_threshold_mm<0
    error('cogneuro:GLMOptions','Invalid motion model or FD threshold');
end
for f={'include_tissue_means','linear_trend','add_spikes'}
    if ~islogical(c.(f{1}))||~isscalar(c.(f{1})),error('cogneuro:GLMOptions','Confound switches must be logical scalars');end
end
positiveInteger(c.min_residual_df,'confounds.min_residual_df');
if ~isstruct(j.expected_runs)||isempty(j.expected_runs)||~all(isfield(j.expected_runs,{'subject','session','run','tr_seconds'}))
    error('cogneuro:GLMRuns','Confirmed per-run identity/TR facts required');
end
for k=1:numel(j.expected_runs)
    positive(j.expected_runs(k).tr_seconds,'expected TR');
end
end

function exactFields(s,fields,label)
if ~isstruct(s)||~isscalar(s)||~all(isfield(s,fields))||any(~ismember(fieldnames(s),fields))
    error('cogneuro:GLMOptions','Unknown/missing %s options',label);
end
end

function positive(x,label)
if ~finiteScalar(x)||x<=0,error('cogneuro:GLMOptions','%s must be a positive finite number',label);end
end

function positiveInteger(x,label)
positive(x,label);if fix(x)~=x,error('cogneuro:GLMOptions','%s must be an integer',label);end
end

function ok=finiteScalar(x)
ok=isnumeric(x)&&isreal(x)&&isscalar(x)&&isfinite(x);
end

function ok=textChoice(x,choices)
ok=(ischar(x)||isstring(x))&&isscalar(string(x))&&~ismissing(string(x))&&ismember(string(x),string(choices));
end

function key=runKey(subject,session,run)
ids={subject,session,run};
for k=1:3
    id=string(ids{k});
    if ~isscalar(id)||ismissing(id)||(k~=2&&strlength(id)==0)|| ...
            (strlength(id)>0&&isempty(regexp(char(id),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')))
        error('cogneuro:GLMRuns','Invalid subject/session/run identity');
    end
end
key=lower(string(subject)+"/"+string(session)+"/"+string(run));
end

function p=absolutePath(p,mustExist)
if ~(ischar(p)||isstring(p))||~isscalar(string(p))||ismissing(string(p))|| ...
        strlength(string(p))==0||~java.io.File(char(p)).isAbsolute()
    error('cogneuro:GLMPath','All job and manifest paths must be explicit absolute paths');
end
p=char(java.io.File(char(p)).getCanonicalPath());
if mustExist&&~isfile(p)&&~isfolder(p),error('cogneuro:GLMPath','Missing path: %s',p);end
end

function assertFresh(p,label)
if isfile(p)||isfolder(p),error('cogneuro:GLMFresh','%s must not already exist',label);end
end

function inside=within(p,root)
p=lower(char(java.io.File(p).getCanonicalPath()));root=lower(char(java.io.File(root).getCanonicalPath()));
inside=strcmp(p,root)||startsWith(p,[root filesep]);
end

function overlap=overlaps(a,b)
overlap=within(a,b)||within(b,a);
end

function verifyLoaded(name,expected)
found=which(name);
if isempty(found)||~isfile(expected)||~strcmpi(char(java.io.File(found).getCanonicalPath()),char(java.io.File(expected).getCanonicalPath()))
    error('cogneuro:GLMSource','%s must resolve to selected dependency: %s',name,expected);
end
end

function requireFiles(files)
for k=1:numel(files)
    if ~isfile(files{k}),error('cogneuro:GLMIncomplete','Missing completed output: %s',files{k});end
end
end

function restoreEnvironment(previousPath,previousDirectory)
path(previousPath);cd(previousDirectory);
end
