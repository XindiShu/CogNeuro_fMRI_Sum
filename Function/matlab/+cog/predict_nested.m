function result=predict_nested(x,y,groups,covariates,exchangeBlocks,o,execute)
%PREDICT_NESTED 外层留一组，内部留一训练组；所有步骤重新估计。
if nargin<7,execute=true;end
x=double(x);y=double(y(:));groups=string(groups(:));exchangeBlocks=string(exchangeBlocks(:));n=size(x,1);covariates=double(covariates);folds=unique(groups,'stable');
if ~ismatrix(x)||~isreal(x)||~isreal(y)||~isreal(covariates)||isempty(x)||numel(y)~=n||numel(groups)~=n||numel(exchangeBlocks)~=n||size(covariates,1)~=n||any(~isfinite(x),'all')||any(~isfinite(y))||std(y)==0||any(~isfinite(covariates),'all')||any(ismissing(groups)|groups==""|ismissing(exchangeBlocks)|exchangeBlocks=="")||numel(folds)<6,error('cog:PredictionInput','Finite aligned subject data and >=6 independent CV groups required for this nested implementation');end
if strcmp(o.method,'ridge'),grid=o.lambdaGrid;valid=grid>0;elseif strcmp(o.method,'cpm'),grid=o.cpmPGrid;valid=grid>0&grid<1;else,error('cog:PredictionInput','Method must be ridge or cpm');end
if isempty(grid)||~isvector(grid)||any(~isfinite(grid)|~valid)||numel(unique(grid))~=numel(grid)||~isscalar(o.nPermutations)||~isfinite(o.nPermutations)||o.nPermutations<0||o.nPermutations~=fix(o.nPermutations),error('cog:PredictionInput','Invalid unique tuning grid/permutation count');end
if o.nPermutations>0&&(size(covariates,2)>0||numel(folds)~=n||strlength(string(o.exchangeabilityJustification))==0),error('cog:PredictionPermutation','Direct target permutation supports independent unique groups, no covariates, and explicit justification only');end
% 预先检查全部内外训练的协变量可估计性，不跑到后面才忽略坏折。
for a=1:numel(folds),for b=1:numel(folds),if a==b,continue;end;use=groups~=folds(a)&groups~=folds(b);d=[ones(nnz(use),1) covariates(use,:)];if rank(d)~=size(d,2)||nnz(use)<=size(d,2)+2,error('cog:PredictionDesign','An inner-fold nuisance design is not estimable');end,end,end
result=struct('status','preflight','nSamples',n,'nGroups',numel(folds),'options',o);if ~execute,return;end
[prediction,nuisancePrediction,models]=evaluate(x,y,groups,covariates,o.method,grid);
observed=corr(prediction,y);residualTarget=y-nuisancePrediction;residualPrediction=prediction-nuisancePrediction;null=nan(o.nPermutations,1);old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
for p=1:o.nPermutations
    yp=y;blocks=unique(exchangeBlocks,'stable');for b=1:numel(blocks),ii=find(exchangeBlocks==blocks(b));yp(ii)=y(ii(randperm(numel(ii))));end
    pp=evaluate(x,yp,groups,covariates,o.method,grid);null(p)=corr(pp,yp);
end
pValue=[];if o.nPermutations>0,if ~isfinite(observed)||any(~isfinite(null)),error('cog:PredictionPermutation','Nonfinite observed/null correlation; do not compute p from invalid draws');end;pValue=(1+nnz(null>=observed))/(1+o.nPermutations);end
result.status='complete';result.prediction=prediction;result.target=y;result.groups=groups;result.models=models;result.correlation=observed;result.rSquared=1-sum((prediction-y).^2)/sum((y-mean(y)).^2);result.mae=mean(abs(prediction-y));result.nuisanceOnlyPrediction=nuisancePrediction;result.residualCorrelation=corr(residualPrediction,residualTarget);result.nullCorrelation=null;result.pHigherCorrelation=pValue;result.note='Nested out-of-group predictions; nuisance contribution is added back to full-target prediction. Residual score uses outer-training nuisance fits. No automatic scientific adequacy or coefficient-causality claim.';
end
function [prediction,nuisancePrediction,models]=evaluate(x,y,groups,covariates,method,grid)
folds=unique(groups,'stable');prediction=nan(size(y));nuisancePrediction=prediction;models=cell(numel(folds),1);
for a=1:numel(folds)
    test=groups==folds(a);train=~test;inner=unique(groups(train),'stable');loss=zeros(numel(grid),1);
    for p=1:numel(grid)
        pred=nan(nnz(train),1);trainIds=find(train);
        for b=1:numel(inner),fit=train&groups~=inner(b);validate=train&groups==inner(b);model=cog.prediction_fit(x(fit,:),y(fit),covariates(fit,:),method,grid(p));pred(groups(trainIds)==inner(b))=cog.prediction_apply(model,x(validate,:),covariates(validate,:));end
        loss(p)=mean((pred-y(train)).^2);
    end
    [~,best]=min(loss);model=cog.prediction_fit(x(train,:),y(train),covariates(train,:),method,grid(best));[prediction(test),nuisancePrediction(test)]=cog.prediction_apply(model,x(test,:),covariates(test,:));models{a}=struct('heldOutGroup',folds(a),'trainingRowIds',find(train),'testRowIds',find(test),'innerMse',loss,'selectedParameter',grid(best),'model',model);
end
end
