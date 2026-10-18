function result=run_rsa_ceiling(cfg)
%RUN_RSA_CEILING 条件顺序显式的数据/模型RDM，固定Pearson度量。
setup_function;if nargin<1,cfg=rsa_ceiling_config;end;s=load(cfg.dataFile,'data');d=s.data;if ~isfield(d,'modelRDMs'),d.modelRDMs=[];d.modelNames=strings(0,1);end;o=cfg.options;if ~cfg.execute,o.nBootstrap=0;end
result=cog.rsa_noise_ceiling(d.rdms,d.subjectIds,d.conditionIds,d.modelRDMs,d.modelNames,o);if ~cfg.execute,result=struct('status','preflight');return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New ceiling output root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'rsa_ceiling.mat'),'result','cfg','-v7.3');
end
