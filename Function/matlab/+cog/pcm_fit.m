function result=pcm_fit(datasets,conditionLabels,models,o,execute)
%PCM_FIT 显式噪声/条件映射→原生PCM，不把CV评分转成Bayesian模型概率。
if nargin<5,execute=true;end
labels=string(conditionLabels(:));nc=numel(labels);ns=numel(datasets);
if isempty(which('pcm_fitModelIndivid'))||~iscell(datasets)||ns<1||~iscell(models)||isempty(models)||nc<2||numel(unique(labels))~=nc||any(ismissing(labels)|labels=="")||~ismember(o.mode,{'individual','group','individual_cv','group_cv'})||~ismember(o.runEffect,{'fixed','random'})||~isscalar(o.maxIterations)||~isfinite(o.maxIterations)||o.maxIterations<1||o.maxIterations~=fix(o.maxIterations),error('cog:PCMInput','Official PCM backend, explicit datasets/models/condition order and valid options required');end
if strcmp(o.mode,'group')&&ns<2||strcmp(o.mode,'group_cv')&&ns<3,error('cog:PCMSubjects','Group fit needs >=2, group CV >=3 independent subjects in this wrapper');end
if ~(ischar(o.fitScale)&&strcmp(o.fitScale,'auto'))&&(~(isnumeric(o.fitScale)||islogical(o.fitScale))||~isscalar(o.fitScale)||~ismember(o.fitScale,[0 1])),error('cog:PCMOptions','fitScale must be auto or logical scalar');end
Y=cell(ns,1);S=Y;part=Y;cond=Y;notes=Y;Ghat=Y;SigmaHat=Y;
for s=1:ns
    d=datasets{s};if ~all(isfield(d,{'y','condition','partition','rowNoiseCovariance','noiseNote','spatialNoiseState'})),error('cog:PCMNoise','Data must declare observation covariance, noise provenance and spatial noise state');end
    y=double(d.y);p=string(d.partition(:));c=string(d.condition(:));n=size(y,1);if ~ismatrix(y)||~isreal(y)||size(y,2)<2||numel(p)~=n||numel(c)~=n||any(~isfinite(y),'all')||any(ismissing(p)|p==""|ismissing(c)|c=="")||strlength(string(d.noiseNote))==0,error('cog:PCMInput','Finite observation x features and explicit nonempty labels/noise note required');end
    parts=unique(p,'stable');if numel(parts)<2,error('cog:PCMPartitions','At least two partitions needed');end
    if strcmp(o.mode,'individual_cv')&&numel(parts)<3,error('cog:PCMPartitions','Individual CV requires >=3 partitions so training retains >=2');end
    [has,cid]=ismember(c,labels);if ~all(has)||numel(unique(cid))~=nc,error('cog:PCMConditions','Dataset conditions must exactly match declared model labels');end
    [~,pid]=ismember(p,parts);counts=accumarray([cid pid],1,[nc numel(parts)]);if any(counts==0,'all'),error('cog:PCMConditions','Every partition must contain every condition');end
    cov=double(d.rowNoiseCovariance);checkPsd(cov,n,true);S{s}=cov;
    if isfield(d,'featureNoiseCovariance')&&~isempty(d.featureNoiseCovariance),a=double(d.featureNoiseCovariance);checkPsd(a,size(y,2),true);y=y/chol(a,'lower')';
    elseif strcmp(d.spatialNoiseState,'already_whitened')
        % 调用者声明的白化；不从同一批模式暗自估计空间噪声。
    elseif ~(o.allowEngineeringNoise&&strcmp(d.spatialNoiseState,'unwhitened_engineering')),error('cog:PCMNoise','Provide feature noise covariance or explicit already-whitened declaration; engineering bypass is opt-in');end
    Y{s}=y;cond{s}=cid;part{s}=pid;notes{s}=d.noiseNote;
end
checked=cell(size(models));names=strings(numel(models),1);q=eye(nc)-ones(nc)/nc;
for m=1:numel(models)
    model=models{m};if ~all(isfield(model,{'name','type','Gc'}))||~ismember(model.type,{'fixed','component'}),error('cog:PCMModel','Named fixed/component Gc models required');end
    names(m)=string(model.name);g=double(model.Gc);if size(g,1)~=nc||size(g,2)~=nc||ndims(g)>3||isempty(g),error('cog:PCMModel','Gc must match explicit condition order');end
    for k=1:size(g,3),checkPsd(g(:,:,k),nc,false);end
    if strcmp(model.type,'fixed'),if size(g,3)~=1,error('cog:PCMModel','Fixed model has exactly one G');end;model.numGparams=0;
    else
        model.numGparams=size(g,3);basis=reshape(g,nc*nc,[]);if strcmp(o.runEffect,'fixed'),for k=1:size(g,3),basis(:,k)=reshape(q*g(:,:,k)*q,nc*nc,1);end,end
        if rank(basis)<model.numGparams,error('cog:PCMIdentifiability','Component matrices are linearly dependent after declared fixed-effect projection');end
    end
    model.Gc=g;model.theta0=zeros(model.numGparams,1);checked{m}=model; % 模型参数初值固定，避免group-CV使用全被试Ghat初始化。
end
if numel(unique(names))~=numel(names)||any(ismissing(names)|names==""),error('cog:PCMModel','Unique model names required');end
result=struct('status','preflight','nSubjects',ns,'conditionLabels',labels,'modelNames',names,'options',o);if ~execute,return;end
for s=1:ns,[Ghat{s},SigmaHat{s}]=pcm_estGCrossval(Y{s},part{s},cond{s},'removeMean',strcmp(o.runEffect,'fixed'));end
fits=cell(numel(models),1);likelihood=nan(ns,numel(models));
for m=1:numel(models)
    model=checked(m);if ischar(o.fitScale)&&strcmp(o.fitScale,'auto'),fitScale=strcmp(model{1}.type,'fixed')||startsWith(o.mode,'group');else,fitScale=o.fitScale;if ~isscalar(fitScale)||~ismember(fitScale,[0 1]),error('cog:PCMOptions','fitScale must be auto or logical scalar');end,end
    args={'runEffect',o.runEffect,'S',S,'verbose',0};
    switch o.mode
        case 'individual',[T,theta,Gpred,INFO]=pcm_fitModelIndivid(Y,model,part,cond,args{:},'fitScale',fitScale,'maxIteration',o.maxIterations);
        case 'group',[T,theta,Gpred]=pcm_fitModelGroup(Y,model,part,cond,args{:},'fitScale',fitScale,'MaxIteration',o.maxIterations);INFO=[];
        case 'individual_cv'
            [T,theta,INFO]=cog.pcm_individual_cv(Y,model{1},part,cond,S,o,fitScale);Gpred=[];
        case 'group_cv'
            if strcmp(model{1}.type,'fixed')
                T=pcm_fitModelGroupCrossval(Y,model,part,cond,args{:},'fitScale',fitScale,'MaxIteration',o.maxIterations);theta={zeros(0,ns)};Gpred={repmat(model{1}.Gc,1,1,ns)};
            else,[T,theta,Gpred]=pcm_fitModelGroupCrossval(Y,model,part,cond,args{:},'fitScale',fitScale,'MaxIteration',o.maxIterations);end;INFO=[];
    end
    if ~isfield(T,'likelihood')||~isequal(size(T.likelihood),[ns 1])||any(~isfinite(T.likelihood),'all'),error('cog:PCMFit','Nonfinite or malformed native likelihood');end
    likelihood(:,m)=T.likelihood;fits{m}=struct('T',T,'theta',{theta},'Gpred',{Gpred},'detail',INFO,'fitScale',fitScale);
end
result.status='complete';result.fits=fits;result.likelihood=likelihood;result.deltaLogLikelihoodVsFirst=likelihood-likelihood(:,1);result.Gcrossval=Ghat;result.SigmaCrossval=SigmaHat;result.noiseNotes=notes;result.models=checked;result.convergenceAssessed=false;result.backend=which('pcm_fitModelIndivid');result.note='Marginal likelihood or native held-out predictive score according to mode. Compare same observations/features/noise assumptions; no automatic Bayes posterior, parameter significance or adequate convergence claim. Gcrossval diagnostic assumes the native estimator weighting, not a general row-covariance correction.';
end
function checkPsd(a,n,strict)
if ~isnumeric(a)||~isreal(a)||~isequal(size(a),[n n])||any(~isfinite(a),'all')||norm(a-a','fro')>1e-8*max(1,norm(a,'fro')),error('cog:PCMCovariance','Finite symmetric covariance/G matrix required');end
if strict,[~,flag]=chol(a);if flag,error('cog:PCMCovariance','Noise covariance must be positive definite');end
elseif min(eig((a+a')/2))< -1e-8*max(1,norm(a,'fro')),error('cog:PCMCovariance','Model G must be positive semidefinite');end
end
