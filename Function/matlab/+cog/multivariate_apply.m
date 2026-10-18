function result=multivariate_apply(model,x,y,covariates)
%MULTIVARIATE_APPLY 冻结训练参数；CCA/PLS-C为双块评分，PLS-R才直接预测Y。
x=double(x);design=[ones(size(x,1),1) double(covariates)];if ~isreal(x)||~isreal(y)||~isreal(covariates)||size(x,2)~=numel(model.validX)||size(design,2)~=size(model.betaX,1)||any(~isfinite(x),'all')||any(~isfinite(design),'all'),error('cog:MultivariateApply','Feature/covariate shape or values mismatch');end
xa=x-design*model.betaX;xa=(xa(:,model.validX)-model.meanX(model.validX))./model.scaleX(model.validX);result=struct('Xscores',xa*model.xWeights(model.validX,:),'Yscores',[],'predictionY',[]);
if ~isempty(y)
    if size(y,1)~=size(x,1)||size(y,2)~=numel(model.validY)||any(~isfinite(y),'all'),error('cog:MultivariateApply','Y shape/value mismatch');end
    ya=double(y)-design*model.betaY;ya=(ya(:,model.validY)-model.meanY(model.validY))./model.scaleY(model.validY);if ~strcmp(model.method,'pls_regression'),result.Yscores=ya*model.yWeights(model.validY,:);end
end
if strcmp(model.method,'pls_regression'),pred=[ones(size(x,1),1) xa]*model.regressionBeta;result.predictionY=design*model.betaY;result.predictionY(:,model.validY)=result.predictionY(:,model.validY)+pred.*model.scaleY(model.validY)+model.meanY(model.validY);end
end
