function [T,theta,details]=pcm_individual_cv(Y,model,part,cond,S,o,fitScale)
%PCM_INDIVIDUAL_CV 原生逐训练折拟合+显式观测协方差条件评分；不改旧PCM源码。
ns=numel(Y);T=struct('SN',(1:ns)','likelihood',zeros(ns,1));theta=cell(ns,1);details=cell(ns,1);
for s=1:ns
    y=Y{s};p=part{s};c=cond{s};parts=unique(p);n=size(y,1);nc=size(model.Gc,1);z=full(sparse((1:n)',c,1,n,nc));b=full(sparse((1:n)',p,1,n,max(p)));folds=cell(numel(parts),1);theta{s}=cell(numel(parts),1);
    for k=1:numel(parts)
        test=p==parts(k);train=~test;[~,~,trainParts]=unique(p(train));[native,th,g]=pcm_fitModelIndivid({y(train,:)},{model},{trainParts},{c(train)},'S',{S{s}(train,train)},'runEffect',o.runEffect,'fitScale',fitScale,'maxIteration',o.maxIterations,'verbose',0);
        scale=1;if isfield(native,'scale'),scale=native.scale(1);end
        V=z*(g{1}(:,:,1)*scale)*z'+native.noise(1)*S{s};xa=zeros(nnz(train),0);xt=zeros(nnz(test),0);
        if strcmp(o.runEffect,'random'),V=V+native.run(1)*(b*b');else,xa=b(train,:);xa=xa(:,any(xa,1));xt=b(test,:);xt=xt(:,any(xt,1));end
        [value,prediction]=cog.gaussian_predictive_score(y(train,:),y(test,:),V(train,train),V(test,train),V(test,test),xa,xt);T.likelihood(s)=T.likelihood(s)+value;theta{s}{k}=th;folds{k}=struct('partition',parts(k),'trainRows',find(train),'testRows',find(test),'nativeFit',native,'prediction',prediction);
    end
    details{s}=folds;
end
end
