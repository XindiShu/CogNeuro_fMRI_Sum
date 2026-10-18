function result=decode(x,target,groups,o)
%DECODE 留一显式分组交叉验证；缩放/零方差剔除仅从训练折学习。
% 分类使用MATLAB diagLinear LDA；回归使用固定lambda ridge，不做样本内筛选。
if ~isnumeric(x)||~ismatrix(x)||isempty(x)||any(~isfinite(x),'all')||~isreal(x),error('cog:Decode','Finite real samples x features required');end
groups=string(groups(:));target=target(:);n=size(x,1);
if numel(groups)~=n||numel(target)~=n||any(ismissing(groups)|strlength(groups)==0),error('cog:Decode','Targets and explicit groups must match rows');end
folds=unique(groups,'stable');if numel(folds)<2,error('cog:CV','Need >=2 independent CV groups');end
if ~ismember(o.task,{'classification','regression'}),error('cog:Decode','Unknown task');end
if strcmp(o.task,'regression')&&(~isnumeric(target)||any(~isfinite(target))||~isscalar(o.lambda)||~isfinite(o.lambda)||o.lambda<=0),error('cog:Decode','Finite numeric target and lambda>0 required');end
if strcmp(o.task,'classification')
    target=string(target);if any(ismissing(target)|strlength(target)==0),error('cog:Decode','Missing classes');end
    classes=unique(target,'stable');if numel(classes)<2,error('cog:Decode','Need >=2 classes');end;prediction=strings(n,1);
else,prediction=nan(n,1);classes=strings(0,1);end
models=cell(numel(folds),1);
for k=1:numel(folds)
    test=groups==folds(k);train=~test;mu=mean(double(x(train,:)),1);sd=std(double(x(train,:)),0,1);valid=sd>eps(max(abs(x(train,:)),[],1))*10;
    if ~any(valid),error('cog:Constant','No training-variable features');end
    a=(double(x(train,valid))-mu(valid))./sd(valid);b=(double(x(test,valid))-mu(valid))./sd(valid);
    if strcmp(o.task,'classification')
        if ~all(ismember(classes,unique(target(train))))||any(arrayfun(@(c)nnz(target(train)==c)<2,classes)),error('cog:CVClasses','Every training fold needs >=2 examples of each class');end
        model=fitcdiscr(a,target(train),'DiscrimType','diagLinear','Prior','uniform');prediction(test)=string(predict(model,b));
        payload=struct('classNames',string(model.ClassNames),'means',model.Mu,'sigma',model.Sigma,'prior',model.Prior);
    else
        center=mean(target(train));z=double(target(train))-center;
        if size(a,2)>size(a,1),weights=a'*((a*a'+o.lambda*eye(size(a,1)))\z);else,weights=(a'*a+o.lambda*eye(size(a,2)))\(a'*z);end
        prediction(test)=b*weights+center;payload=struct('weights',weights,'intercept',center,'lambda',o.lambda);
    end
    models{k}=struct('heldOutGroup',folds(k),'nTrain',nnz(train),'nTest',nnz(test),'featureMask',valid,'trainingMean',mu,'trainingScale',sd,'model',payload);
end
result=struct('task',o.task,'target',target,'prediction',prediction,'groups',groups,'folds',{models},'classes',classes);
if strcmp(o.task,'classification')
    cm=zeros(numel(classes));for a=1:numel(classes),for b=1:numel(classes),cm(a,b)=nnz(target==classes(a)&prediction==classes(b));end,end
    result.confusion=cm;result.accuracy=mean(target==prediction);result.balancedAccuracy=mean(diag(cm)./sum(cm,2));
else
    result.mae=mean(abs(prediction-target));result.rSquared=1-sum((prediction-target).^2)/sum((target-mean(target)).^2);
    result.correlation=corr(prediction,double(target));
end
result.note='Out-of-group prediction with fixed model settings; no automatic significance claim. CV groups must reflect subject/session/run/family dependencies appropriate to the question.';
end
