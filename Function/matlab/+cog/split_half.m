function result=split_half(y,unitIds,itemIds,o)
%SPLIT_HALF 同一项目分半用于所有单位，半测均值之间的跨单位相关及SB修正。
[n,k,p]=size(y);units=string(unitIds(:));items=string(itemIds(:));if ~isnumeric(y)||~isreal(y)||n<3||k<4||any(~isfinite(y),'all')||numel(units)~=n||numel(unique(units))~=n||numel(items)~=k||numel(unique(items))~=k||any(ismissing(units)|units=="")||any(ismissing(items)|items==""),error('cog:SplitInput','Complete matched item matrix with >=3 units/>=4 unique items required');end
if ~ismember(o.splitPolicy,{'odd_even','random_balanced'})||~isscalar(o.nSplits)||~isfinite(o.nSplits)||o.nSplits<1||o.nSplits~=fix(o.nSplits)||strlength(string(o.designNote))==0,error('cog:SplitOptions','Explicit matched item design and split options required');end
ns=o.nSplits;if strcmp(o.splitPolicy,'odd_even'),ns=1;end;state=rng;cleanup=onCleanup(@()rng(state));rng(o.seed);r=nan(ns,p);sb=r;left=cell(ns,1);right=left;
for s=1:ns
    if strcmp(o.splitPolicy,'odd_even'),a=1:2:k;b=2:2:k;else,order=randperm(k);a=order(1:floor(k/2));b=order(floor(k/2)+1:end);end;left{s}=a;right{s}=b;
    for f=1:p,x=mean(y(:,a,f),2);z=mean(y(:,b,f),2);if std(x)>0&&std(z)>0,r(s,f)=corr(x,z);if 1+r(s,f)~=0,sb(s,f)=2*r(s,f)/(1+r(s,f));end,end,end
end
result=struct('correlation',r,'spearmanBrown',sb,'leftItems',{left},'rightItems',{right},'unitIds',units,'itemIds',items,'options',o,'note','Across-unit Pearson correlation of half-item means, with 2r/(1+r) parallel-half correction. Negative values retained, undefined variance/denominator -> NaN. Random splits share items and units: split distribution is not independent replicates, population CI or test-retest evidence. No automatic item random-effects/generalizability inference.');
end
