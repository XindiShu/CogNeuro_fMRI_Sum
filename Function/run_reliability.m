function result=run_reliability(cfg)
%RUN_RELIABILITY 显式完整平衡矩阵的ICC或项目分半。
setup_function;if nargin<1,cfg=reliability_config;end;s=load(cfg.dataFile,'data');d=s.data;if ~isfield(d,'featureIds')||numel(d.featureIds)~=size(d.y,3)||numel(unique(string(d.featureIds)))~=numel(d.featureIds),error('cog:ReliabilityInput','Unique feature identity required');end
o=cfg.options;if ~cfg.execute,o.nBootstrap=0;end
if strcmp(cfg.method,'icc'),result=cog.icc(d.y,d.unitIds,d.occasionIds,o);elseif strcmp(cfg.method,'split_half'),if ~cfg.execute,o.nSplits=1;end;result=cog.split_half(d.y,d.unitIds,d.itemIds,o);else,error('cog:ReliabilityInput','Unknown method');end
if ~cfg.execute,result=struct('status','preflight');return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New reliability output root required');end;mkdir(cfg.outputRoot);featureIds=d.featureIds;save(fullfile(cfg.outputRoot,'reliability.mat'),'result','featureIds','cfg','-v7.3');
end
