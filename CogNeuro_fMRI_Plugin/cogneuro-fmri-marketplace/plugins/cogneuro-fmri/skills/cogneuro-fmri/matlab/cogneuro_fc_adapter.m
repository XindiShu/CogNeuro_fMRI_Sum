function result = cogneuro_fc_adapter(job)
%COGNEURO_FC_ADAPTER 对所选分析方法包进行只读深预检或独立静态FC执行。
% job中的路径均为绝对路径；清单/影像工作副本由外部事务层准备。
% 参数单位：TR为秒，bandHz为Hz，max_matrix_gib为double矩阵GiB上限。
% 本适配器不修改工具包配置、原始输入或已有输出；不自动判断解剖配准质量。
% 当前执行试点仅接收声明为unfiltered_unregressed的时序，避免重复清理。

validateJob(job);
toolkitRoot = canonical(job.toolkit_root);
spmRoot = canonical(job.spm_root);
manifestFile = canonical(job.manifest_file);
outputRoot = canonical(job.output_root);
if isfile(outputRoot) || isfolder(outputRoot)
    error('cogneuro:OutputExists','Use a new, absent output_root: %s',outputRoot);
end
if inside(outputRoot,toolkitRoot) || inside(outputRoot,spmRoot)
    error('cogneuro:OutputLocation','output_root cannot be inside a toolkit or SPM installation');
end

oldPath = path;
pathCleanup = onCleanup(@()path(oldPath)); %#ok<NASGU>
% 仅加入明确选定的三个工具包目录和SPM根目录；不递归加入其他包。
addpath(toolkitRoot,fullfile(toolkitRoot,'matlab'),fullfile(toolkitRoot,'config'),'-begin');
addpath(spmRoot,'-begin');
sources = checkSources(toolkitRoot,spmRoot);
runs = cog.read_runs(manifestFile);
validateRuns(runs,job,outputRoot);
o = job.options;
cleanOptions = o.cleaning;
details = struct([]);
for k = 1:height(runs)
    row = runs(k,:);
    % 以下使用生产入口的同一读入、两次联合投影、ROI提取和FC估计函数。
    [y,space] = cog.load_bold(row.bold,row.mask,row.tr_seconds,o.max_matrix_gib);
    confounds = [];
    if strlength(row.confounds)>0
        confoundTable = cog.read_tsv(row.confounds);
        confounds = str2double(string(table2cell(confoundTable)));
    end
    noBand = cleanOptions; noBand.bandHz = [];
    [~,baseInfo] = cog.clean_timeseries(y,row.tr_seconds,confounds,noBand);
    [clean,cleanInfo] = cog.clean_timeseries(y,row.tr_seconds,confounds,cleanOptions);
    [roi,roiInfo] = cog.roi_extract(clean,space,row.roi_file,o.roi_min_voxels);
    fc = cog.fc(roi,char(o.fc_measure));
    % 常数原信号经联合投影可能只剩浮点舍入噪声；以原ROI强度尺度补查。
    % 10*eps是数值保护阈值，不是生物信号筛选阈值或科学效应量阈值。
    [rawRoi,~] = cog.roi_extract(y,space,row.roi_file,o.roi_min_voxels);
    roiResidualStd = std(roi,0,1);
    roiRoundoffThreshold = 10*eps(max(abs(rawRoi),[],1));
    if any(roiResidualStd<=roiRoundoffThreshold)
        error('cog:Constant','ROI residual is constant or at original-signal roundoff scale');
    end
    if any(~isfinite(fc.correlation),'all')
        error('cogneuro:FCNonfinite','The selected estimator produced nonfinite correlations');
    end
    item = struct('subject',char(row.subject),'session',char(row.session), ...
        'run',char(row.run),'tr_seconds',row.tr_seconds, ...
        'n_frames',size(y,1),'n_voxels',size(y,2),'n_rois',size(roi,2), ...
        'projection_rank',cleanInfo.projectionRank, ...
        'residual_dimensions',cleanInfo.residualDimensions, ...
        'matrix_gib',space.matrixGiB,'temporal_state',char(row.temporal_state), ...
        'smoothing_fwhm_mm',row.smoothing_fwhm_mm, ...
        'cleaning',cleanInfo,'unfiltered_projection',baseInfo, ...
        'roi_residual_std',roiResidualStd,'roi_roundoff_threshold',roiRoundoffThreshold, ...
        'roi_coverage',table2struct(roiInfo));
    if isempty(details)
        details = item;
    else
        details(end+1,1) = item; %#ok<AGROW>
    end
    clear y clean roi rawRoi confounds fc
end
result = struct('schema_version',1,'route','fc','mode',char(job.mode), ...
    'status','preflight_passed','n_runs',height(runs),'runs',details, ...
    'loaded_sources',sources,'output_files',{{}}, ...
    'checks',struct('manifest',true,'expected_run_identity',true, ...
    'grid_and_tr',true,'masked_bold_finite',true,'joint_projection',true, ...
    'roi_coverage',true,'estimator_evaluable',true, ...
    'residual_numerical_variance',true,'output_absent',true), ...
    'limitations',{{ ...
    'Same voxel grid does not prove anatomical alignment; visual QC remains required.', ...
    'Declared processing history and scientific suitability are not inferred from image values.', ...
    'Residual dimensions are algebraic dimensions, not statistical effective degrees of freedom.', ...
    'The matrix GiB limit is not a bound on peak MATLAB process memory.', ...
    'Successful FC estimation does not establish inference validity or neural causality.'}});
if strcmp(job.mode,'preflight')
    % 只读预检：不建立output_root，不写图像/时序/相关矩阵或完成标记。
    return
end

cfg = function_config;
cfg.manifestFile = manifestFile; % 清单路径：仅使用本次事务的私有副本。
cfg.outputRoot = outputRoot; % 输出路径：每次尝试必须使用尚不存在的新目录。
cfg.spmPath = spmRoot; % SPM路径：显式选定且通过实际加载来源核查。
cfg.execute = true;
cfg.methods = {'static_fc'};
cfg.continueOnError = false;
cfg.maxMatrixGiB = o.max_matrix_gib; % GiB：限制读入double矩阵大小，不代表峰值内存。
cfg.roiMinVoxels = o.roi_min_voxels; % 正整数：每个ROI与有效掩膜交集的最少体素数。
cfg.clean = cleanOptions;
cfg.fc.estimator = char(o.fc_measure);
cfg.fc.seedColumns = []; % 默认只计算ROI矩阵；本适配器不隐式增加seed-to-voxel路线。
summary = run_function(cfg);
checkSources(toolkitRoot,spmRoot);
result.output_files = verifyExecution(outputRoot,runs,details,summary);
result.status = 'complete';
result.summary = summary;
end

function validateJob(job)
if ~isstruct(job) || ~isscalar(job)
    error('cogneuro:Job','Job must be a scalar structure');
end
required = {'schema_version','route','mode','toolkit_root','spm_root', ...
    'manifest_file','output_root','options'};
if ~all(isfield(job,required)) || ~isequal(job.schema_version,1) || ...
        ~textScalar(job.route) || ~strcmp(job.route,'fc') || ...
        ~textScalar(job.mode) || ~ismember(string(job.mode),["preflight","execute"])
    error('cogneuro:Job','Expected schema_version=1, route=fc and preflight/execute mode');
end
if ~isfield(job,'expected_runs')
    error('cogneuro:RunIdentity','expected_runs must enumerate every approved manifest row');
end
for key = {'toolkit_root','spm_root','manifest_file','output_root'}
    value = job.(key{1});
    if ~textScalar(value) || ~absolutePath(char(value))
        error('cogneuro:Path','%s must be an absolute path',key{1});
    end
end
if ~isfolder(job.toolkit_root) || ~isfolder(job.spm_root) || ~isfile(job.manifest_file)
    error('cogneuro:Path','Selected toolkit/SPM folders and manifest must exist');
end
o = job.options;
keys = {'cleaning','fc_measure','max_matrix_gib','roi_min_voxels'};
if ~isstruct(o) || ~isscalar(o) || ~all(isfield(o,keys))
    error('cogneuro:Options','All FC options must be explicit');
end
if ~textScalar(o.fc_measure) || ~ismember(string(o.fc_measure),["pearson","spearman","partial"]) || ...
        ~positiveScalar(o.max_matrix_gib) || ~positiveInteger(o.roi_min_voxels)
    error('cogneuro:Options','Invalid FC measure, matrix budget or ROI voxel threshold');
end
c = o.cleaning;
if ~isstruct(c) || ~isscalar(c) || ...
        ~all(isfield(c,{'detrend','bandHz','minResidualDimensions'})) || ...
        ~islogical(c.detrend) || ~isscalar(c.detrend) || ...
        ~positiveInteger(c.minResidualDimensions)
    error('cogneuro:Options','Explicit logical detrend and positive residual dimensions required');
end
band = c.bandHz;
if ~isnumeric(band) || ~isreal(band) || ...
        (~isempty(band) && (~isvector(band) || numel(band)~=2 || ...
        any(~isfinite(band)) || band(1)<0 || band(2)<=band(1)))
    error('cogneuro:Options','bandHz must be [] or a finite increasing [low high] Hz pair');
end
end

function validateRuns(runs,job,outputRoot)
for k = 1:height(runs)
    row = runs(k,:);
    % 试点约束：无论当前选项是否含混杂/频带，已有清理历史均不能再次投影。
    if row.temporal_state~="unfiltered_unregressed"
        error('cogneuro:TemporalState','FC pilot requires unfiltered_unregressed input; do not clean previously processed time series again');
    end
    for key = {'bold','mask','roi_file'}
        file = row.(key{1});
        if ~endsWith(lower(file),'.nii') || ~isfile(file)
            error('cog:Format','Existing uncompressed .nii BOLD, mask and ROI files required');
        end
    end
    for key = {'bold','mask','roi_file','confounds'}
        file = row.(key{1});
        if strlength(file)>0 && inside(canonical(file),outputRoot)
            error('cogneuro:OutputLocation','An input cannot be inside output_root');
        end
    end
end
expected = job.expected_runs;
if ~isstruct(expected) || numel(expected)~=height(runs) || ...
        ~all(isfield(expected,{'subject','session','run','tr_seconds'}))
    error('cogneuro:RunIdentity','expected_runs must enumerate every manifest row');
end
for k = 1:height(runs)
    e = expected(k);
    if ~textScalar(e.subject) || ~textScalar(e.session) || ~textScalar(e.run) || ...
            ~strcmp(e.subject,runs.subject(k)) || ~strcmp(e.session,runs.session(k)) || ...
            ~strcmp(e.run,runs.run(k)) || ~positiveScalar(e.tr_seconds) || ...
            abs(e.tr_seconds-runs.tr_seconds(k))>1e-9
        error('cogneuro:RunIdentity','Manifest identity/TR differs from approved job row %d',k);
    end
end
end

function files = verifyExecution(root,runs,details,summary)
if ~isstruct(summary) || ~all(isfield(summary,{'nRuns','completed','failed'})) || ...
        summary.nRuns~=height(runs) || summary.failed~=0 || summary.completed~=height(runs)
    error('cogneuro:Completion','Actual run_function summary does not confirm every run');
end
files = {fullfile(root,'configuration.mat'),fullfile(root,'summary.json'), ...
    fullfile(root,'BATCH_COMPLETE.mat')};
requireFiles(files);
batch = load(fullfile(root,'BATCH_COMPLETE.mat'),'summary');
if ~isfield(batch,'summary') || batch.summary.failed~=0 || ...
        batch.summary.completed~=height(runs) || batch.summary.nRuns~=height(runs)
    error('cogneuro:Completion','BATCH_COMPLETE does not confirm every expected run');
end
for k = 1:height(runs)
    row = runs(k,:);
    parts = {char(row.subject)};
    if strlength(row.session)>0, parts{end+1} = char(row.session); end %#ok<AGROW>
    parts{end+1} = char(row.run);
    out = fullfile(root,parts{:});
    names = {'COMPLETE.mat','summary.json','roi_coverage.tsv', ...
        'roi_timeseries.mat','static_fc.mat','fc_r.tsv'};
    perRun = cellfun(@(name)fullfile(out,name),names,'UniformOutput',false);
    requireFiles(perRun);
    done = load(fullfile(out,'COMPLETE.mat'),'record');
    if ~isfield(done,'record') || ~all(isfield(done.record, ...
            {'status','subject','session','run','nFrames','nVoxels','methods'})) || ...
            ~strcmp(done.record.status,'complete') || ...
            ~strcmp(done.record.subject,row.subject) || ~strcmp(done.record.session,row.session) || ...
            ~strcmp(done.record.run,row.run) || done.record.nFrames~=details(k).n_frames || ...
            done.record.nVoxels~=details(k).n_voxels || ~isequal(done.record.methods,{'static_fc'})
        error('cogneuro:Completion','Run completion marker does not match expected identity/shape');
    end
    saved = load(fullfile(out,'static_fc.mat'),'fc','roiInfo');
    if ~all(isfield(saved,{'fc','roiInfo'})) || ...
            ~isequal(size(saved.fc.correlation),[details(k).n_rois details(k).n_rois]) || ...
            any(~isfinite(saved.fc.correlation),'all') || ...
            ~isequal(table2struct(saved.roiInfo),details(k).roi_coverage)
        error('cogneuro:Completion','Saved FC result or ROI identities disagree with preflight');
    end
    files = [files perRun]; %#ok<AGROW>
end
end

function requireFiles(files)
for k = 1:numel(files)
    item = dir(files{k});
    if isempty(item) || item.isdir || item.bytes==0
        error('cogneuro:Completion','Required output is missing or empty: %s',files{k});
    end
end
end

function sources = checkSources(toolkitRoot,spmRoot)
names = {'run_function','setup_function','function_config','cog.read_runs', ...
    'cog.read_tsv','cog.resolve_path','cog.check_grid','cog.load_bold', ...
    'cog.clean_timeseries','cog.roi_extract','cog.fc','cog.write_json', ...
    'spm','spm_vol','spm_read_vols','nifti','file_array'};
sources = repmat(struct('name','','path','','origin',''),numel(names),1);
for k = 1:numel(names)
    file = which(names{k});
    if k<=12, selected = toolkitRoot; origin = 'function_toolkit';
    else, selected = spmRoot; origin = 'spm'; end
    if isempty(file) || ~isfile(file) || ~inside(canonical(file),selected)
        error('cogneuro:SourceMismatch','%s must resolve inside selected %s; resolved: %s', ...
            names{k},origin,file);
    end
    sources(k) = struct('name',names{k},'path',canonical(file),'origin',origin);
end
end

function yes = textScalar(value)
yes = (ischar(value) && (isrow(value) || isempty(value))) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value));
end

function yes = positiveScalar(value)
yes = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value>0;
end

function yes = positiveInteger(value)
yes = positiveScalar(value) && value==fix(value);
end

function yes = absolutePath(value)
if ispc
    yes = ~isempty(regexp(value,'^[A-Za-z]:[\\/]|^\\\\','once'));
else
    yes = startsWith(value,'/');
end
end

function value = canonical(value)
value = char(java.io.File(char(value)).getCanonicalPath());
end

function yes = inside(file,root)
file = strrep(char(file),'\','/'); root = strrep(char(root),'\','/');
while numel(root)>1 && root(end)=='/', root(end)=[]; end
if ispc, file=lower(file); root=lower(root); end
yes = strcmp(file,root) || startsWith(file,[root '/']);
end
