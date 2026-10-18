function result=rsa(x,condition,partition,o)
%RSA 显式条件/独立分区；相关、欧氏和给定噪声协方差的crossnobis。
if ~isnumeric(x)||~ismatrix(x)||isempty(x)||any(~isfinite(x),'all')||~isreal(x),error('cog:RSA','Finite real pattern matrix required');end
condition=string(condition(:));partition=string(partition(:));
if numel(condition)~=size(x,1)||numel(partition)~=size(x,1)||any(ismissing(condition)|condition=="")||any(ismissing(partition)|partition==""),error('cog:RSA','Explicit condition/partition per estimate required');end
labels=unique(condition,'stable');parts=unique(partition,'stable');nc=numel(labels);np=numel(parts);nf=size(x,2);
if nc<2,error('cog:RSA','Need >=2 conditions');end
patterns=nan(nc,nf,np);counts=zeros(nc,np);
for p=1:np,for c=1:nc,use=partition==parts(p)&condition==labels(c);counts(c,p)=nnz(use);if any(use),patterns(c,:,p)=mean(double(x(use,:)),1);end,end,end
if any(counts==0,'all'),error('cog:RSAComplete','Every partition must contain every condition; no implicit missing-cell imputation');end
rdm=zeros(nc);meanPatterns=mean(patterns,3);
switch o.metric
    case 'correlation'
        if any(std(meanPatterns,0,2)==0),error('cog:Constant','Constant spatial pattern');end
        rdm=1-corr(meanPatterns');
    case 'euclidean'
        for a=1:nc,for b=a+1:nc,rdm(a,b)=sqrt(sum((meanPatterns(a,:)-meanPatterns(b,:)).^2));rdm(b,a)=rdm(a,b);end,end
    case 'crossnobis'
        if np<2,error('cog:RSAPartitions','Crossnobis requires >=2 independent partitions');end
        if ~isfield(o,'noiseCovariance')||~isequal(size(o.noiseCovariance),[nf nf])||any(~isfinite(o.noiseCovariance),'all')||norm(o.noiseCovariance-o.noiseCovariance','fro')>1e-8,error('cog:RSANoise','Explicit symmetric feature noise covariance required');end
        [l,flag]=chol(o.noiseCovariance,'lower');if flag~=0,error('cog:RSANoise','Positive definite noise covariance required');end
        for p=1:np,patterns(:,:,p)=patterns(:,:,p)/l';end
        for a=1:nc,for b=a+1:nc
            d=reshape(patterns(a,:,:)-patterns(b,:,:),nf,np)';cross=d*d';rdm(a,b)=(sum(cross,'all')-trace(cross))/(np*(np-1)*nf);rdm(b,a)=rdm(a,b);
        end,end
    otherwise,error('cog:RSA','Unknown distance metric');
end
rdm(1:nc+1:end)=0;result=struct('rdm',rdm,'labels',labels,'partitions',parts,'counts',counts,'metric',o.metric,'nFeatures',nf,'modelFits',[]);
if isfield(o,'modelRDMs')&&~isempty(o.modelRDMs)
    if ~isfield(o,'modelLabels')||~isequal(string(o.modelLabels(:)),labels),error('cog:RSAModelLabels','Model labels must exactly match returned label order');end
    model=o.modelRDMs;if size(model,1)~=nc||size(model,2)~=nc||any(~isfinite(model),'all'),error('cog:RSAModel','Invalid model RDM dimensions/values');end
    select=tril(true(nc),-1);scores=nan(size(model,3),1);
    for k=1:size(model,3)
        m=model(:,:,k);if norm(m-m','fro')>1e-8||any(diag(m)~=0),error('cog:RSAModel','Symmetric zero-diagonal model RDM required');end
        scores(k)=corr(rdm(select),m(select),'Type','Spearman');
    end
    result.modelFits=scores;
end
result.note='RDM/model scores only; pairwise distances are dependent. Crossnobis can be negative; do not truncate. Noise covariance provenance is the caller responsibility.';
end
