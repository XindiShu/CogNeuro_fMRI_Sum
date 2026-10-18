function result=graph_metrics(w,o)
%GRAPH_METRICS 无向正权网络；负边策略、绝对阈值明确，断连距离为Inf。
if ~isnumeric(w)||~ismatrix(w)||size(w,1)~=size(w,2)||size(w,1)<2||any(~isfinite(w),'all')||norm(w-w','fro')>1e-8,error('cog:Graph','Finite symmetric square matrix required');end
if ~ismember(o.negativePolicy,{'reject','drop'})||~isscalar(o.threshold)||~isfinite(o.threshold)||o.threshold<0,error('cog:Graph','Invalid policy/threshold');end
n=size(w,1);w=double(w);w(1:n+1:end)=0;negative=nnz(triu(w<0,1));
if negative>0&&strcmp(o.negativePolicy,'reject'),error('cog:NegativeEdges','Negative edges require explicit handling');end
w(w<0)=0;w(w<o.threshold)=0;a=w>0;degree=sum(a,2);strength=sum(w,2);tri=diag(double(a)^3)/2;
clustering=zeros(n,1);valid=degree>=2;clustering(valid)=2*tri(valid)./(degree(valid).*(degree(valid)-1));
d=inf(n);d(a)=1./w(a);d(1:n+1:end)=0;for k=1:n,d=min(d,d(:,k)+d(k,:));end
invD=1./d;invD(1:n+1:end)=0;eff=sum(invD,'all')/(n*(n-1));finitePaths=d(~eye(n)&isfinite(d));
if isempty(finitePaths),pathLength=NaN;else,pathLength=mean(finitePaths);end
result=struct('adjacency',w,'degree',degree,'strength',strength,'binaryClustering',clustering,'weightedShortestPaths',d,'globalEfficiency',eff, ...
    'meanFinitePathLength',pathLength,'density',nnz(a)/(n*(n-1)),'nNegativeEdgesDropped',negative,'nDisconnectedPairs',nnz(triu(isinf(d),1)), ...
    'threshold',o.threshold,'negativePolicy',o.negativePolicy,'note','Positive undirected graph; distance=1/weight; clustering is binary. Finite-path mean is not a disconnected-graph characteristic path length. No small-world/null-network claim.');
end
