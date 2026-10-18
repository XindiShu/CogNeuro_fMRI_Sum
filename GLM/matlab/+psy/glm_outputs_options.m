function cfg=glm_outputs_options(cfg)
%GLM_OUTPUTS_OPTIONS 只读后处理的独立配置；不向估计入口加入额外字段。
check(cfg,{'mode','spmPath','outputRoot','results','betas','roi'});
check(cfg.results,{'manifestFile','correction','alpha','tail','minClusterVoxels','connectivity','backgroundFile','plot','writeVoxelTable','roiManifestFile'});
check(cfg.betas,{'manifestFile','writeMatrix','maxMatrixGiB','roiManifestFile'});check(cfg.roi,{'emptyPolicy','minVoxels'});
cfg.mode=choice(cfg.mode,{'results','betas','both'});cfg.results.correction=choice(cfg.results.correction,{'none','fwe','fdr'});
cfg.results.tail=choice(cfg.results.tail,{'positive','negative','two_sided'});cfg.roi.emptyPolicy=choice(cfg.roi.emptyPolicy,{'nan','error'});
for v={cfg.results.plot,cfg.results.writeVoxelTable,cfg.betas.writeMatrix}
    if ~islogical(v{1})||~isscalar(v{1}),error('psy:GLMOutputsConfig','Flags must be logical scalar');end
end
number(cfg.results.alpha,0,.5,false);number(cfg.betas.maxMatrixGiB,0,Inf,false);
integer(cfg.results.minClusterVoxels,0);integer(cfg.roi.minVoxels,1);
if ~isscalar(cfg.results.connectivity)||~ismember(cfg.results.connectivity,[6 18 26]),error('psy:GLMOutputsConfig','Connectivity must be 6,18,26');end
cfg.outputRoot=psy.glm_absolute_path(cfg.outputRoot);cfg.spmPath=psy.glm_absolute_path(cfg.spmPath);
if ~isfile(fullfile(cfg.spmPath,'spm.m')),error('psy:SPMPath','Set SPM installation directory');end
end
function check(s,fields)
if ~isstruct(s)||~isscalar(s)||~all(isfield(s,fields))||any(~ismember(fieldnames(s),fields)),error('psy:GLMOutputsConfig','Use current glm_outputs_config');end
end
function v=choice(v,allowed)
if ~isscalar(string(v))||~ismember(string(v),string(allowed)),error('psy:GLMOutputsConfig','Unknown option');end
v=char(v);
end
function number(v,lo,hi,inclusive)
if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||(~inclusive&&(v<=lo||v>=hi)),error('psy:GLMOutputsConfig','Invalid positive numeric limit');end
end
function integer(v,minimum)
if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||v<minimum||fix(v)~=v,error('psy:GLMOutputsConfig','Invalid integer limit');end
end
