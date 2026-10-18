function summary=run_prepare_inputs(cfg)
%RUN_PREPARE_INPUTS 通用清单适配：不包含HCP规则，不重采样，不修改源影像。
setup_function;if nargin<1,cfg=prepare_inputs_config;end
if ~ismember(cfg.mode,{'roi','voxels'})||~isscalar(cfg.requireCommonFeatures)||~ismember(cfg.requireCommonFeatures,[false true]),error('cog:PrepareOptions','roi/voxels and logical common-feature policy required');end
t=cog.read_runs(cfg.manifestFile);
for k=1:height(t)
    if t.temporal_state(k)~="unfiltered_unregressed"&&strlength(t.confounds(k))>0,error('cog:TemporalState','Previously regressed input cannot receive new confounds implicitly');end
    if ~endsWith(lower(t.bold(k)),'.nii')||~endsWith(lower(t.mask(k)),'.nii')||~endsWith(lower(t.roi_file(k)),'.nii'),error('cog:Format','Explicit uncompressed NIfTI paths required');end
end
summary=struct('status','preflight','nRuns',height(t),'execute',cfg.execute);if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use a new preparation directory');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');prepared=table;referenceIds=strings(0,1);referenceSpace=[];
for k=1:height(t)
    [y,space]=cog.load_bold(t.bold(k),t.mask(k),t.tr_seconds(k),cfg.maxMatrixGiB);conf=[];if strlength(t.confounds(k))>0,c=cog.read_tsv(t.confounds(k));conf=str2double(string(table2cell(c)));end
    [y,processing]=cog.clean_timeseries(y,t.tr_seconds(k),conf,cfg.clean);
    if strcmp(cfg.mode,'roi'),[y,roiInfo]=cog.roi_extract(y,space,t.roi_file(k),cfg.roiMinVoxels);featureIds="roi_"+string(roiInfo.label);else,featureIds=string(space.indices);roiInfo=[];end
    if cfg.requireCommonFeatures
        if k==1,referenceIds=featureIds(:);referenceSpace=space.reference;elseif ~isequal(referenceIds,featureIds(:)),error('cog:PrepareFeatures','Different output identities; supply explicit compatible masks/ROI labels or disable common-feature check for separate analyses');end
        if strcmp(cfg.mode,'voxels'),cog.check_grid(space.reference,referenceSpace);end
    end
    data=struct('y',y,'trSeconds',t.tr_seconds(k),'featureIds',featureIds(:),'roiNames',featureIds(:),'frameIndices',(1:size(y,1))','processing',processing,'sourceTemporalState',t.temporal_state(k),'sourceBold',t.bold(k),'roiInfo',roiInfo);
    if strcmp(cfg.mode,'voxels'),data.space=space;end
    parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);file=fullfile(out,'input.mat');save(file,'data','-v7.3');prepared=[prepared;table(t.subject(k),t.session(k),t.run(k),string(file),'VariableNames',{'subject','session','run','data_file'})]; %#ok<AGROW>
end
writetable(prepared,fullfile(cfg.outputRoot,'prepared_runs.tsv'),'FileType','text','Delimiter','\t');summary.status='complete';summary.manifestFile=fullfile(cfg.outputRoot,'prepared_runs.tsv');save(fullfile(cfg.outputRoot,'PREPARE_INPUTS_COMPLETE.mat'),'summary');
end
