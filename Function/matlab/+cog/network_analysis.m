function result=network_analysis(w,o,bctPath)
%NETWORK_ANALYSIS 调用原生BCT社区/参与系数/二值保度重接，正边按确定性密度阈值。
base=struct('negativePolicy',o.negativePolicy,'threshold',0);checked=cog.graph_metrics(w,base);w=checked.adjacency;n=size(w,1);
if ~isvector(o.densities)||isempty(o.densities)||any(~isfinite(o.densities)|o.densities<=0|o.densities>1)||any(diff(o.densities)<=0)||~isscalar(o.gamma)||~isfinite(o.gamma)||o.gamma<=0||~validInteger(o.communityRepeats,1)||~validInteger(o.nNull,0)||~validInteger(o.rewireIterations,1),error('cog:NetworkOptions','Valid increasing densities/gamma/integer repeats required');end
oldPath=path;cleanupPath=onCleanup(@()path(oldPath));addpath(bctPath);names={'community_louvain','participation_coef','randmio_und'};for k=1:numel(names),if ~strcmpi(strrep(fileparts(which(names{k})),'\','/'),strrep(char(bctPath),'\','/')),error('cog:BCT','BCT native functions must resolve in declared directory');end,end
state=rng;cleanupRng=onCleanup(@()rng(state));rng(o.seed);indices=find(triu(w>0,1));[~,order]=sortrows([-w(indices) indices],[1 2]);indices=indices(order);levels=cell(numel(o.densities),1);
for d=1:numel(o.densities)
    keep=min(floor(o.densities(d)*n*(n-1)/2+1e-12),numel(indices));if keep<1,error('cog:NetworkDensity','A selected density retains zero positive edges');end
    a=zeros(n);a(indices(1:keep))=w(indices(1:keep));a=a+a';partitions=zeros(n,o.communityRepeats);q=zeros(o.communityRepeats,1);agreement=zeros(n);
    for r=1:o.communityRepeats,[partitions(:,r),q(r)]=community_louvain(a,o.gamma,[],'modularity');agreement=agreement+(partitions(:,r)==partitions(:,r)');end
    [bestQ,best]=max(q);community=partitions(:,best);weighted=cog.graph_metrics(a,struct('negativePolicy','reject','threshold',0));binary=cog.graph_metrics(double(a>0),struct('negativePolicy','reject','threshold',0));
    rewires=zeros(o.nNull,1);nullClustering=nan(o.nNull,1);nullPath=nullClustering;nullEfficiency=nullClustering;nullConnected=false(o.nNull,1);nullDegree=zeros(n,o.nNull);canRewire=hasDisjointEdges(a>0);
    for r=1:o.nNull
        if canRewire,[b,rewires(r)]=randmio_und(double(a>0),o.rewireIterations);else,b=double(a>0);end
        if any(sum(b,2)~=binary.degree)||~isequal(b,b')||any(diag(b)),error('cog:BCTInvariant','Native rewiring broke simple undirected degree invariant');end
        g=cog.graph_metrics(b,struct('negativePolicy','reject','threshold',0));nullDegree(:,r)=g.degree;nullClustering(r)=mean(g.binaryClustering);nullPath(r)=g.meanFinitePathLength;nullEfficiency(r)=g.globalEfficiency;nullConnected(r)=g.nDisconnectedPairs==0;
    end
    sigma=NaN;normalC=NaN;normalL=NaN;
    if o.nNull>0&&all(rewires>0)&&binary.nDisconnectedPairs==0&&all(nullConnected)&&mean(nullClustering)>0
        normalC=mean(binary.binaryClustering)/mean(nullClustering);normalL=binary.meanFinitePathLength/mean(nullPath);sigma=normalC/normalL;
    end
    levels{d}=struct('requestedDensity',o.densities(d),'actualDensity',weighted.density,'weighted',weighted,'binary',binary,'community',community,'modularity',bestQ,'allModularity',q,'allPartitions',partitions,'coassignment',agreement/o.communityRepeats,'weightedParticipation',participation_coef(a,community),'nullSuccessfulRewires',rewires,'nullDegree',nullDegree,'nullMeanClustering',nullClustering,'nullMeanFinitePath',nullPath,'nullEfficiency',nullEfficiency,'nullConnected',nullConnected,'binaryNormalizedClustering',normalC,'binaryNormalizedPath',normalL,'binarySmallWorldSigma',sigma);
end
result=struct('levels',{levels},'nNegativeEdgesDropped',checked.nNegativeEdgesDropped,'options',o,'nativeBctDirectory',bctPath,'note','Positive undirected weights; tied edge ranks use linear index, no threshold search inference. Best Louvain restart is not guaranteed global optimum; coassignment is descriptive, not consensus clustering. Nulls preserve binary degree, not strength/connectivity/spatial wiring; sigma only for connected observed/all successfully rewired connected nulls. Small or dense graphs may not mix.');
end
function yes=validInteger(x,low)
yes=isscalar(x)&&isfinite(x)&&x==fix(x)&&x>=low;
end
function yes=hasDisjointEdges(a)
[i,j]=find(triu(a,1));yes=false;for k=1:numel(i),if any(i~=i(k)&i~=j(k)&j~=i(k)&j~=j(k)),yes=true;return;end,end
end
