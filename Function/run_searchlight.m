function summary=run_searchlight(cfg)
%RUN_SEARCHLIGHT 各被试/session独立运行；所有中心球用同一物理空间/共享置换。
setup_function;if nargin<1,cfg=searchlight_config;end
t=cog.read_tsv(cfg.catalogFile,[{'estimate_id','subject','session','run','condition','image_path','volume_index','mask_path',cfg.targetColumn},cfg.partitionColumns,cfg.exchangeabilityColumns]);
if ~isempty(cfg.sourceId),if ~ismember('source_id',t.Properties.VariableNames),error('cog:BetaSource','source_id missing');end;t=t(t.source_id==string(cfg.sourceId),:);end
if isempty(t)||(ismember('source_id',t.Properties.VariableNames)&&numel(unique(t.source_id))>1),error('cog:BetaSource','Select one nonempty estimation source');end
summary=struct('execute',cfg.execute,'nEstimates',height(t),'records',{{}});if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New searchlight result root required');end;mkdir(cfg.outputRoot);
for f={'image_path','mask_path'},for k=1:height(t),t.(f{1})(k)=string(cog.resolve_path(t.(f{1})(k),fileparts(cfg.catalogFile)));end,end
selected=fullfile(cfg.outputRoot,'selected_catalog.tsv');writetable(t,selected,'FileType','text','Delimiter','\t');
units=t.subject+"/"+t.session;allUnits=unique(units,'stable');save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg');
for u=1:numel(allUnits)
    use=units==allUnits(u);meta=t(use,:);out=fullfile(cfg.outputRoot,sprintf('unit_%03d',u));mkdir(out);unitCatalog=fullfile(out,'selected_catalog.tsv');writetable(meta,unitCatalog,'FileType','text','Delimiter','\t');
    [x,meta,space]=cog.load_betas(unitCatalog,cfg.maxMatrixGiB);world=space.reference.mat*[space.ijk';ones(1,size(space.ijk,1))];xyz=world(1:3,:)';centers=(1:size(x,2))';
    if ~isempty(cfg.centerMaskFile)
        v=spm_vol(cfg.centerMaskFile);if ~isscalar(v),error('cog:Centers','3D center mask required');end;cog.check_grid(v,space.reference);m=spm_read_vols(v);if any(~isfinite(m),'all')||any(m<0,'all'),error('cog:Centers','Finite nonnegative center mask required');end;centers=find(m(space.indices)>0);
    end
    part=strings(height(meta),1);blocks=part;for k=1:numel(cfg.partitionColumns),part=part+"/"+meta.(cfg.partitionColumns{k});end;for k=1:numel(cfg.exchangeabilityColumns),blocks=blocks+"/"+meta.(cfg.exchangeabilityColumns{k});end
    target=meta.(cfg.targetColumn);if strcmp(cfg.options.mode,'rsa'),target=meta.condition;elseif strcmp(cfg.options.decode.task,'regression'),target=str2double(target);end
    result=cog.searchlight(x,xyz,centers,target,part,blocks,cfg.options);save(fullfile(out,'searchlight.mat'),'result','meta','space');
    for name={'score','nFeatures','pUncorrected','pFweMax'}
        values=result.(name{1});if isempty(values),continue;end;a=nan(1,size(x,2));a(centers)=values;cog.write_map(fullfile(out,[name{1} '.nii']),a,space,['Searchlight ' name{1}]);
    end
    summary.records{end+1}=struct('unit',allUnits(u),'nCenters',numel(centers),'nValid',nnz(result.valid),'inferenceEligible',result.inferenceEligible);
end
cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'SEARCHLIGHT_COMPLETE.mat'),'summary');
end
