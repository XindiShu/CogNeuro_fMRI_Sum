function result=nbs_onesample(matrices,independentUnitIds,o)
%NBS_ONESAMPLE 一样本或预先相减的配对差值；整单位符号翻转的最大连通成分校正。
[n,n2,ns]=size(matrices);ids=string(independentUnitIds(:));
if ~isnumeric(matrices)||~isreal(matrices)||n~=n2||n<2||ns<3||any(~isfinite(matrices),'all')||numel(ids)~=ns||numel(unique(ids))~=ns||any(ismissing(ids)|ids==""),error('cog:NBSInput','Finite nodes x nodes x >=3 independent units with unique IDs required');end
for s=1:ns,if norm(matrices(:,:,s)-matrices(:,:,s)','fro')>1e-8,error('cog:NBSInput','Symmetric undirected matrices required');end,end
if ~isscalar(o.threshold)||~isfinite(o.threshold)||o.threshold<=0||~ismember(o.tail,{'positive','negative','both'})||~ismember(o.componentStatistic,{'extent','excess_mass'})||~isscalar(o.exactMaxUnits)||o.exactMaxUnits<0||o.exactMaxUnits>16||o.exactMaxUnits~=fix(o.exactMaxUnits)||~isscalar(o.nPermutations)||o.nPermutations<1||o.nPermutations~=fix(o.nPermutations)||strlength(string(o.exchangeabilityNote))==0,error('cog:NBSOptions','Valid prespecified threshold/tail/statistic/permutations and exchangeability justification required');end
ix=find(triu(true(n),1));[i,j]=ind2sub([n n],ix);x=reshape(double(matrices),n*n,ns);x=x(ix,:)';if any(std(x,0,1)==0&mean(x,1)~=0),error('cog:NBSDegenerate','Nonzero constant edge has undefined finite t; change input/mask explicitly');end
observed=tStatistic(x);components=findComponents(observed,i,j,n,o);exact=ns<=o.exactMaxUnits;
state=rng;cleanup=onCleanup(@()rng(state));rng(o.seed);if exact,np=2^ns;else,np=o.nPermutations;end;maximum=zeros(np,1);
for p=1:np
    if exact,signs=2*double(bitget(uint32(p-1),1:ns))'-1;else,signs=2*(rand(ns,1)>.5)-1;end
    c=findComponents(tStatistic(x.*signs),i,j,n,o);if ~isempty(c),maximum(p)=max([c.statistic]);end
end
for k=1:numel(components),if exact,components(k).pFwe=mean(maximum>=components(k).statistic-1e-12);else,components(k).pFwe=(1+nnz(maximum>=components(k).statistic-1e-12))/(np+1);end,end
t=zeros(n);t(ix)=observed;t=t+t';result=struct('t',t,'df',ns-1,'components',components,'nullMaximum',maximum,'exactEnumeration',exact,'nSignPatterns',np,'independentUnitIds',ids,'options',o,'note','Independent row-wise sign symmetry under zero null is required. Paired input must already be within-unit differences. Both tails use separate signed components but shared maximum. Component-level FWE across all edges/components/tails for one prespecified threshold/statistic; not edge p-values, causal networks, GLM/group comparison, family blocks or threshold-free NBS. Exact includes observed; MC uses plus-one.');
end
function t=tStatistic(x)
n=size(x,1);mu=mean(x,1);sd=std(x,0,1);t=zeros(size(mu));ok=sd>0;t(ok)=mu(ok)./(sd(ok)/sqrt(n));t(~ok&mu~=0)=sign(mu(~ok&mu~=0))*Inf;
end
function components=findComponents(t,i,j,n,o)
components=struct('nodes',{},'edgeIndices',{},'edgePairs',{},'sign',{},'statistic',{},'pFwe',{});tails=1;if strcmp(o.tail,'negative'),tails=-1;elseif strcmp(o.tail,'both'),tails=[1 -1];end
for sg=tails
    active=sg*t>o.threshold;if ~any(active),continue;end;a=sparse([i(active);j(active)],[j(active);i(active)],true,n,n);labels=conncomp(graph(a,'upper'));used=unique(labels([i(active);j(active)]));
    for label=used(:)'
        edges=find(active(:)&labels(i)'==label&labels(j)'==label);if isempty(edges),continue;end;if strcmp(o.componentStatistic,'extent'),stat=numel(edges);else,stat=sum(sg*t(edges)-o.threshold);end
        components(end+1)=struct('nodes',find(labels==label),'edgeIndices',edges,'edgePairs',[i(edges) j(edges)],'sign',sg,'statistic',stat,'pFwe',NaN); %#ok<AGROW>
    end
end
end
