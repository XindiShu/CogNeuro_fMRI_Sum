function result=run_multivariate(cfg)
%RUN_MULTIVARIATE 保存特征/单位身份；三种关联/预测和中介有各自定义。
setup_function;if nargin<1,cfg=multivariate_config;end
s=load(cfg.dataFile,'data');d=s.data;if ~all(isfield(d,{'X','Y','sampleIds','independentUnitIds','XfeatureIds','YfeatureIds'})),error('cog:MultivariateData','Explicit X/Y, sample/unit and feature identities required');end
n=size(d.X,1);samples=string(d.sampleIds(:));units=string(d.independentUnitIds(:));xf=string(d.XfeatureIds(:));yf=string(d.YfeatureIds(:));if size(d.Y,1)~=n||numel(samples)~=n||numel(unique(samples))~=n||numel(units)~=n||any(ismissing(samples)|samples==""|ismissing(units)|units=="")||numel(xf)~=size(d.X,2)||numel(yf)~=size(d.Y,2)||numel(unique(xf))~=numel(xf)||numel(unique(yf))~=numel(yf)||any(ismissing(xf)|xf=="")||any(ismissing(yf)|yf==""),error('cog:MultivariateData','Aligned unique sample and feature identities required');end
c=zeros(n,0);if isfield(d,'covariates'),c=d.covariates;end
if strcmp(cfg.method,'mediation')
    a=cfg.mediation.predictorColumn;b=cfg.mediation.outcomeColumn;if ~isfield(d,'M')||numel(d.M)~=n||~isscalar(a)||a<1||a>size(d.X,2)||a~=fix(a)||~isscalar(b)||b<1||b>size(d.Y,2)||b~=fix(b)||cfg.options.nPermutations>0||cfg.options.crossValidate,error('cog:MediationData','One explicit mediator, valid chosen columns, no association permutation/CV settings required');end
    o=cfg.options;if ~cfg.execute,o.nBootstrap=0;end;result=cog.mediation(d.X(:,a),d.M,d.Y(:,b),c,units,o);
else
    if ~ismember(cfg.method,{'pls_covariance','cca','pls_regression'}),error('cog:MultivariateMethod','Unsupported method');end
    blocks=repmat("all",n,1);if isfield(d,'exchangeBlocks'),blocks=d.exchangeBlocks;end;groups=strings(0,1);if isfield(d,'cvGroups'),groups=d.cvGroups;end
    if ~cfg.execute,result=cog.multivariate_fit(d.X,d.Y,c,cfg.method,cfg.options);return;end
    if isfolder(cfg.outputRoot),error('cog:Exists','New multivariate result root required');end
    result=cog.multivariate_analysis(d.X,d.Y,c,units,blocks,groups,cfg.method,cfg.options);
end
if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New multivariate result root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'multivariate.mat'),'result','cfg','samples','units','xf','yf','-v7.3');save(fullfile(cfg.outputRoot,'MULTIVARIATE_COMPLETE.mat'),'cfg');
end
