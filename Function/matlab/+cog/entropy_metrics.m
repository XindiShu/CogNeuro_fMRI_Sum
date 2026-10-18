function result=entropy_metrics(y,o)
%ENTROPY_METRICS SampEn(nats)、排列熵(bits/归一化)、幅度直方图熵(bits)定义分开。
[nt,nf]=size(y);m=o.sampleM;delay=o.delayFrames;order=o.permutationOrder;
if ~isnumeric(y)||~ismatrix(y)||~isreal(y)||any(~isfinite(y),'all')||~isscalar(m)||~isfinite(m)||m<1||m~=fix(m)||~isscalar(delay)||~isfinite(delay)||delay<1||delay~=fix(delay)||~isscalar(order)||order<2||order>7||order~=fix(order)||~isscalar(o.toleranceFraction)||~isfinite(o.toleranceFraction)||o.toleranceFraction<=0||~ismember(o.tiePolicy,{'omit','stable'})||~isscalar(o.histogramBins)||o.histogramBins<2||o.histogramBins~=fix(o.histogramBins),error('cog:EntropyOptions','Finite continuous series and valid distinct entropy settings required');end
n=nt-m*delay;if n<5||n*(n-1)/2>o.maxComparisons||nt-(order-1)*delay<5,error('cog:EntropyCoverage','Insufficient/excessive embedding pair coverage');end
samp=nan(1,nf);countM=zeros(1,nf);countNext=countM;tolerance=countM;permutation=nan(1,nf);histogram=nan(1,nf);nValid=zeros(1,nf);nTies=nValid;histEdges=cell(1,nf);
for f=1:nf
    x=double(y(:,f));r=o.toleranceFraction*std(x);tolerance(f)=r;indices=(1:n)'+(0:m)*delay;embedded=x(indices);b=nnz(pdist(embedded(:,1:m),'chebychev')<=r);a=nnz(pdist(embedded,'chebychev')<=r);countM(f)=b;countNext(f)=a;if b>0,if a==0,samp(f)=Inf;else,samp(f)=-log(a/b);end,end
    count=zeros(factorial(order),1);ix=(1:nt-(order-1)*delay)'+(0:order-1)*delay;v=x(ix);
    for t=1:size(v,1)
        values=v(t,:);if numel(unique(values))<order,nTies(f)=nTies(f)+1;if strcmp(o.tiePolicy,'omit'),continue;end,end
        [~,permutationIndices]=sortrows([values(:) (1:order)'],[1 2]);code=1;for j=1:order-1,code=code+sum(permutationIndices(j+1:end)<permutationIndices(j))*factorial(order-j);end;count(code)=count(code)+1;
    end
    nValid(f)=sum(count);if nValid(f)>0,p=count(count>0)/nValid(f);permutation(f)=-sum(p.*log2(p));end
    if max(x)==min(x),histogram(f)=0;histEdges{f}=[min(x) max(x)];else,edges=linspace(min(x),max(x),o.histogramBins+1);counts=histcounts(x,edges);p=counts(counts>0)/sum(counts);histogram(f)=-sum(p.*log2(p));histEdges{f}=edges;end
end
result=struct('sampleEntropyNats',samp,'sampleMatchesM',countM,'sampleMatchesNext',countNext,'sampleToleranceAbsolute',tolerance,'sampleTemplateCount',n,'permutationEntropyBits',permutation,'permutationEntropyNormalized',permutation/log2(factorial(order)),'permutationValidWindows',nValid,'permutationTiedWindows',nTies,'histogramEntropyBits',histogram,'histogramEdges',{histEdges},'options',o,'note','SampEn uses equal m/m+1 template origins, unordered non-self Chebyshev pairs, inclusive tolerance; B0 -> NaN, A0 with B>0 -> Inf. Permutation ties handled explicitly. Histogram entropy is amplitude bin diversity, not temporal complexity. No sample/algorithm convention equivalence or neuronal entropy claim.');
end
