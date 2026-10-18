function result=network_summary(r,networkLabels)
%NETWORK_SUMMARY 每个网络对的边均值；对角不计，分别输出r均值与z均值。
if size(r,1)~=size(r,2)||any(~isfinite(r),'all')||norm(r-r','fro')>1e-8||any(abs(r)>1,'all'),error('cog:Network','Finite symmetric correlation matrix required');end
networkLabels=string(networkLabels(:));if numel(networkLabels)~=size(r,1)||any(ismissing(networkLabels)|networkLabels==""),error('cog:Network','Network label per ROI required');end
labels=unique(networkLabels,'stable');n=numel(labels);meanR=nan(n);meanZ=nan(n);counts=zeros(n);
for a=1:n,for b=a:n
    use=(networkLabels==labels(a))*(networkLabels==labels(b))';if a==b,use=triu(use,1);end
    values=r(logical(use));counts(a,b)=numel(values);counts(b,a)=counts(a,b);
    if ~isempty(values),meanR(a,b)=mean(values);meanZ(a,b)=mean(atanh(values));meanR(b,a)=meanR(a,b);meanZ(b,a)=meanZ(a,b);end
end,end
result=struct('labels',labels,'meanR',meanR,'meanFisherZ',meanZ,'nEdges',counts,'note','Exact +/-1 off-diagonal correlations yield infinite Fisher z; no automatic clipping. Descriptive edge summary, not independent-edge inference.');
end
