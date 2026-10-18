function [prediction,nuisancePrediction]=prediction_apply(model,x,covariates)
%PREDICTION_APPLY 只应用训练折参数，不重新估计尺度/协变量/边掩膜。
if ~isreal(x)||~isreal(covariates)||size(x,2)~=model.nFeatures||size(covariates,1)~=size(x,1)||size(covariates,2)~=model.nCovariates||any(~isfinite(x),'all')||any(~isfinite(covariates),'all'),error('cog:PredictionApply','Feature/covariate shape or values mismatch');end
design=[ones(size(x,1),1) double(covariates)];a=double(x)-design*model.betaX;a=(a(:,model.validFeatures)-model.mean(model.validFeatures))./model.scale(model.validFeatures);nuisancePrediction=design*model.betaY;
if strcmp(model.method,'ridge'),residual=a*model.weights;else,scores=[sum(a(:,model.positiveMask),2) sum(a(:,model.negativeMask),2)];j=model.scoreColumns;d=[ones(size(x,1),1) (scores(:,j)-model.scoreMean(j))./model.scoreScale(j)];residual=d*model.weights;end
prediction=nuisancePrediction+residual;
end
