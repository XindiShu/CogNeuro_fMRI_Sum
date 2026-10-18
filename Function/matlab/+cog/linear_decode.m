function result=linear_decode(x,y,groups,featureIds,o)
%LINEAR_DECODE 固定L2的二分类线性模型，所有尺度仅来自训练组。
y=string(y(:));groups=string(groups(:));n=size(x,1);classes=unique(y);if numel(y)~=n||numel(groups)~=n||any(ismissing(y)|y=="")||any(ismissing(groups)|groups=="")||numel(classes)~=2||~ismember(o.estimator,{'svm','logistic'})||strlength(string(o.dependencyNote))==0,error('cog:LinearDecodeInput','Binary labels, explicit groups and dependency note required');end
folds=unique(groups,'stable');if numel(folds)<2,error('cog:LinearDecodeInput','At least2 CV groups required');end
state=rng;cleanup=onCleanup(@()rng(state));rng(o.seed);prediction=strings(n,1);scores=nan(n,2);models=cell(numel(folds),1);
for k=1:numel(folds)
    test=groups==folds(k);model=cog.pattern_fit(x(~test,:),y(~test),featureIds,o);r=cog.pattern_apply(model,x(test,:),featureIds);if ~isequal(model.classes,classes),error('cog:LinearDecodeClasses','Both classes required in every source fold');end
    prediction(test)=r.prediction;[~,order]=ismember(classes,r.scoreClassNames);scores(test,:)=r.score(:,order);models{k}=struct('heldOutGroup',folds(k),'model',model);
end
cm=zeros(2);for a=1:2,for b=1:2,cm(a,b)=nnz(y==classes(a)&prediction==classes(b));end,end
result=struct('target',y,'prediction',prediction,'scores',scores,'classes',classes,'groups',groups,'folds',{models},'confusion',cm,'accuracy',mean(prediction==y),'balancedAccuracy',mean(diag(cm)./sum(cm,2)),'options',o,'note','Native binary linear SVM/logistic with fixed ridge penalty and class-balanced source weights; score columns follow classes, SVM scores are not calibrated probabilities. Training-only preprocessing; CV groups and upstream independence remain caller responsibility, no tuning/permutation inference.');
end
