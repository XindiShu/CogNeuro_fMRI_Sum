function result=run_encoding(cfg)
%RUN_ENCODING 单个声明好的编码数据集；多个被试独立调用新输出，不合并身份。
setup_function;if nargin<1,cfg=encoding_config;end
s=load(cfg.dataFile,'data');d=s.data;if ~all(isfield(d,{'featureSpaces','featureIds','targetIds','y','runIds','frameIndices','cvGroups','featureSpaceNames'})),error('cog:EncodingInput','Named feature spaces/columns/targets, run/frame and CV group identities required');end
names=string(d.featureSpaceNames(:));if numel(names)~=numel(d.featureSpaces)||numel(unique(names))~=numel(names)||any(ismissing(names)|names==""),error('cog:EncodingInput','Unique feature-space names required');end
if ~iscell(d.featureIds)||numel(d.featureIds)~=numel(d.featureSpaces),error('cog:EncodingInput','One feature-ID vector per space required');end
featureIds=d.featureIds;for k=1:numel(featureIds),ids=string(featureIds{k}(:));if numel(ids)~=size(d.featureSpaces{k},2)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids==""),error('cog:EncodingInput','Unique ordered feature IDs required');end;featureIds{k}=ids;end
targetIds=string(d.targetIds(:));if numel(targetIds)~=size(d.y,2)||numel(unique(targetIds))~=numel(targetIds)||any(ismissing(targetIds)|targetIds==""),error('cog:EncodingInput','Unique ordered brain target IDs required');end
if strcmp(cfg.options.sampleKind,'continuous')&&(~isfield(d,'trSeconds')||~isscalar(d.trSeconds)||~isfinite(d.trSeconds)||d.trSeconds<=0),error('cog:EncodingInput','Continuous encoding requires explicit common TR in seconds');end
c=zeros(size(d.y,1),0);if isfield(d,'covariates'),c=d.covariates;end
result=cog.encoding_cv(d.featureSpaces,d.y,d.runIds,d.frameIndices,d.cvGroups,c,cfg.options,false);if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New encoding result root required');end
result=cog.encoding_cv(d.featureSpaces,d.y,d.runIds,d.frameIndices,d.cvGroups,c,cfg.options,true);mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'encoding.mat'),'result','cfg','names','featureIds','targetIds','-v7.3');save(fullfile(cfg.outputRoot,'ENCODING_COMPLETE.mat'),'result');
end
