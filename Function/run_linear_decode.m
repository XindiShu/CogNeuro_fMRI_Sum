function result=run_linear_decode(cfg)
%RUN_LINEAR_DECODE 显式矩阵/样本身份和CV组的线性分类器。
setup_function;if nargin<1,cfg=linear_decode_config;end;s=load(cfg.dataFile,'data');d=s.data;ids=string(d.sampleIds(:));if numel(ids)~=size(d.X,1)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids==""),error('cog:LinearDecodeInput','Unique sample IDs required');end
if ~cfg.execute,result=struct('status','preflight','nSamples',numel(ids));return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New linear decode output root required');end;result=cog.linear_decode(d.X,d.Y,d.cvGroups,d.featureIds,cfg.options);result.sampleIds=ids;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'linear_decode.mat'),'result','cfg','-v7.3');
end
