function model=pattern_fit(x,y,featureIds,o)
%PATTERN_FIT 训练样本独立学习列筛选/均值/尺度；固定diagLDA/ridge/二分类svm/logistic。
ids=string(featureIds(:));if ~isnumeric(x)||~ismatrix(x)||~isreal(x)||size(x,1)<4||any(~isfinite(x),'all')||numel(ids)~=size(x,2)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids==""),error('cog:PatternInput','Finite samples x features and unique feature IDs required');end
y=y(:);if numel(y)~=size(x,1)||~ismember(o.estimator,{'diaglda','ridge','svm','logistic'}),error('cog:PatternInput','Supported fixed estimator and matching target required');end
mu=mean(double(x),1);sd=std(double(x),0,1);valid=sd>eps(max(abs(x),[],1))*10;if ~any(valid),error('cog:PatternInput','No variable training feature');end;a=(double(x(:,valid))-mu(valid))./sd(valid);
model=struct('featureIds',ids,'featureMask',valid,'trainingMean',mu,'trainingScale',sd,'estimator',o.estimator,'options',o);
if ~strcmp(o.estimator,'ridge')
    y=string(y);classes=unique(y);if numel(classes)<2||any(ismissing(y)|y=="")||any(arrayfun(@(c)nnz(y==c)<2,classes)),error('cog:PatternTarget','At least2 training examples per class required');end
    if strcmp(o.estimator,'diaglda'),model.native=compact(fitcdiscr(a,y,'DiscrimType','diagLinear','Prior','uniform'));
    else
        if numel(classes)~=2||~isscalar(o.lambda)||~isfinite(o.lambda)||o.lambda<=0,error('cog:PatternTarget','Binary native linear classifier and lambda>0 required');end
        weights=zeros(size(y));for k=1:2,weights(y==classes(k))=numel(y)/(2*nnz(y==classes(k)));end
        if strcmp(o.estimator,'svm'),solver='dual';else,solver='lbfgs';end
        model.native=fitclinear(a,y,'Learner',o.estimator,'Regularization','ridge','Lambda',o.lambda,'Solver',solver,'Weights',weights,'ClassNames',classes);model.trainingWeights=weights;
    end;model.classes=classes;
else
    if ~isnumeric(y)||any(~isfinite(y))||~isscalar(o.lambda)||~isfinite(o.lambda)||o.lambda<=0,error('cog:PatternTarget','Finite regression y and lambda>0 required');end
    model.trainingTargetMean=mean(double(y));z=double(y)-model.trainingTargetMean;if size(a,2)>size(a,1),model.weights=a'*((a*a'+o.lambda*eye(size(a,1)))\z);else,model.weights=(a'*a+o.lambda*eye(size(a,2)))\(a'*z);end
end
end
