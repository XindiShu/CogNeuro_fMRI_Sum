function result=multivariate_analysis(x,y,covariates,units,exchangeBlocks,groups,method,o)
%MULTIVARIATE_ANALYSIS 关联统计重拟合置换/单位bootstrap，与冻结留组验证分开。
n=size(x,1);units=string(units(:));exchangeBlocks=string(exchangeBlocks(:));groups=string(groups(:));
if numel(units)~=n||numel(exchangeBlocks)~=n||any(ismissing(units)|units==""|ismissing(exchangeBlocks)|exchangeBlocks=="")||~isscalar(o.nPermutations)||~isfinite(o.nPermutations)||o.nPermutations<0||o.nPermutations~=fix(o.nPermutations)||~isscalar(o.nBootstrap)||~isfinite(o.nBootstrap)||o.nBootstrap<0||o.nBootstrap~=fix(o.nBootstrap)||~isscalar(o.alpha)||o.alpha<=0||o.alpha>=1||~ismember(o.inferenceScope,{'engineering','assumed_exchangeable'}),error('cog:MultivariateOptions','Explicit independent units/exchange blocks and valid resampling settings required');end
if (o.nPermutations>0||o.nBootstrap>0)&&strlength(string(o.exchangeabilityJustification))==0,error('cog:MultivariateResampling','Explicit exchangeability/unit-resampling justification required');end
if o.nPermutations>0&&(size(covariates,2)>0||numel(unique(units))~=n),error('cog:MultivariatePermutation','Direct Y permutation supports unique independent rows and no covariates; correlated units/residual permutation not implemented');end
if strcmp(method,'pls_regression')&&(o.nPermutations>0||o.nBootstrap>0),error('cog:PLSRegressionInference','This PLS regression branch provides frozen CV prediction, not association-statistic permutation/loading CI');end
model=cog.multivariate_fit(x,y,covariates,method,o);k=o.nComponents;result=struct('model',model,'nullStatistics',[],'pComponent',[],'pFweComponents',[],'bootstrapXWeights',[],'bootstrapYWeights',[],'xWeightPercentileCi',[],'yWeightPercentileCi',[],'bootstrapRejectedDraws',0,'cv',[],'inferenceEligible',false);
old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
if o.nPermutations>0
    null=zeros(o.nPermutations,k);blocks=unique(exchangeBlocks,'stable');for p=1:o.nPermutations,indices=(1:n)';for b=1:numel(blocks),ii=find(exchangeBlocks==blocks(b));indices(ii)=ii(randperm(numel(ii)));end;fit=cog.multivariate_fit(x,y(indices,:),covariates,method,o);null(p,:)=fit.statistics;end
    result.nullStatistics=null;result.pComponent=(1+sum(null>=model.statistics,1))/(o.nPermutations+1);result.pFweComponents=(1+sum(max(null,[],2)>=model.statistics,1))/(o.nPermutations+1);result.inferenceEligible=strcmp(o.inferenceScope,'assumed_exchangeable');
end
if o.nBootstrap>0
    bx=zeros(o.nBootstrap,size(x,2),k);by=zeros(o.nBootstrap,size(y,2),k);accepted=0;attempt=0;
    while accepted<o.nBootstrap&&attempt<20*o.nBootstrap
        attempt=attempt+1;rows=cog.bootstrap_unit_rows(units);
        try,b=cog.multivariate_fit(x(rows,:),y(rows,:),covariates(rows,:),method,o);catch e,if ismember(e.identifier,{'cog:MultivariateConstant','cog:MultivariateRank','cog:MultivariateInput','cog:CCARank'}),continue;else,rethrow(e);end,end
        for j=1:k,if model.xWeights(:,j)'*b.xWeights(:,j)<0,b.xWeights(:,j)=-b.xWeights(:,j);b.yWeights(:,j)=-b.yWeights(:,j);end,end
        accepted=accepted+1;bx(accepted,:,:)=b.xWeights;by(accepted,:,:)=b.yWeights;
    end
    if accepted<o.nBootstrap,error('cog:MultivariateBootstrap','Too many invalid bootstrap fits');end
    result.bootstrapXWeights=bx;result.bootstrapYWeights=by;result.xWeightPercentileCi=prctile(bx,[o.alpha/2 1-o.alpha/2]*100,1);result.yWeightPercentileCi=prctile(by,[o.alpha/2 1-o.alpha/2]*100,1);result.bootstrapRejectedDraws=attempt-accepted;
end
if o.crossValidate
    if numel(groups)~=n||any(ismissing(groups)|groups=="")||numel(unique(groups))<2,error('cog:MultivariateCV','Explicit >=2 CV groups required');end
    for u=unique(units,'stable')',if numel(unique(groups(units==u)))~=1,error('cog:MultivariateCV','Every independent unit must stay in one outer group');end,end
    folds=unique(groups,'stable');models=cell(numel(folds),1);prediction=nan(size(y));products=nan(n,k);
    for f=1:numel(folds)
        test=groups==folds(f);train=~test;fit=cog.multivariate_fit(x(train,:),y(train,:),covariates(train,:),method,o);applied=cog.multivariate_apply(fit,x(test,:),y(test,:),covariates(test,:));models{f}=struct('heldOutGroup',folds(f),'trainingRows',find(train),'testRows',find(test),'model',fit);
        if strcmp(method,'pls_regression'),prediction(test,:)=applied.predictionY;
        else,scale=std(fit.Xscores,0,1).*std(fit.Yscores,0,1);scale(scale<=eps)=NaN;products(test,:)=applied.Xscores.*applied.Yscores./scale;end
    end
    cv=struct('models',{models},'predictionY',[],'rSquared',[],'correlation',[],'standardizedScoreProducts',[],'meanStandardizedScoreProduct',[],'nScorablePairs',[]);
    if strcmp(method,'pls_regression')
        cv.predictionY=prediction;cv.rSquared=nan(1,size(y,2));cv.correlation=cv.rSquared;for j=1:size(y,2),if std(y(:,j))>eps,cv.rSquared(j)=1-sum((prediction(:,j)-y(:,j)).^2)/sum((y(:,j)-mean(y(:,j))).^2);if std(prediction(:,j))>eps,cv.correlation(j)=corr(prediction(:,j),y(:,j));end,end,end
    else,cv.standardizedScoreProducts=products;cv.meanStandardizedScoreProduct=mean(products,1,'omitnan');cv.nScorablePairs=sum(isfinite(products),1);end
    result.cv=cv;
end
result.options=o;result.note='PLS-C covariance, CCA association, PLS-R prediction are distinct. Permutation refits marginal preprocessing/model with fixed hyperparameters; bootstrap pairs X/Y by declared independent units and sign-aligns component weights only. No automatic matching of degenerate components, latent dimension/ridge selection, population adequacy or causality claim. Frozen score-product CV is invariant to joint sign flips; it is not a prediction of Y.';
end
