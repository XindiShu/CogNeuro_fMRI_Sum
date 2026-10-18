function projected=srm_apply(model,series)
%SRM_APPLY 对已知被试应用冻结映射；新被试需独立对齐训练段，当前不自动拟合。
if ~iscell(series)||numel(series)~=numel(model.weights),error('cog:SRMApply','Same ordered fitted subjects required');end
projected=cell(size(series));for s=1:numel(series),x=double(series{s});if size(x,2)~=size(model.weights{s},1)||any(~isfinite(x),'all'),error('cog:SRMApply','Subject feature order/count/value mismatch');end;x=x-model.trainingMean{s};if model.options.scaleFeatures,x=x./model.trainingScale{s};end;projected{s}=x*model.weights{s};end
end
