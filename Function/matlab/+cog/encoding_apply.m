function [prediction,parts,nuisance]=encoding_apply(model,spaces,covariates)
%ENCODING_APPLY 冻结训练参数；parts仅为线性分量，不是独有解释方差。
if ~isequal(cellfun(@(a)size(a,2),spaces),model.spaceSizes)||size(covariates,2)~=model.nCovariates,error('cog:EncodingApply','Feature-space/covariate columns mismatch');end
x=horzcat(spaces{:});design=[ones(size(x,1),1) double(covariates)];if any(~isfinite(x),'all')||any(~isfinite(design),'all'),error('cog:EncodingApply','Finite aligned values required');end
a=x-design*model.betaX;a=(a(:,model.valid)-model.mean(model.valid))./model.scale(model.valid);nuisance=design*model.betaY;prediction=a*model.weights+nuisance;parts=zeros(size(x,1),size(prediction,2),numel(spaces));bands=model.featureBands(model.valid);
for g=1:numel(spaces),use=bands==g;parts(:,:,g)=a(:,use)*model.weights(use,:);end
end
