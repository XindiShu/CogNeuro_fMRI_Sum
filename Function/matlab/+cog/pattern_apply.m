function result=pattern_apply(model,x,featureIds)
%PATTERN_APPLY 目标域禁止重学尺度/均值/筛选，不接收目标标签。
if ~isequal(string(featureIds(:)),model.featureIds)||~isnumeric(x)||~isreal(x)||~ismatrix(x)||size(x,2)~=numel(model.featureIds)||any(~isfinite(x),'all'),error('cog:PatternApply','Finite target matrix with exact frozen feature identity/order required');end
a=(double(x(:,model.featureMask))-model.trainingMean(model.featureMask))./model.trainingScale(model.featureMask);
if ~strcmp(model.estimator,'ridge'),[pred,score]=predict(model.native,a);result=struct('prediction',string(pred),'score',score,'scoreClassNames',string(model.native.ClassNames));else,result=struct('prediction',a*model.weights+model.trainingTargetMean);end
end
