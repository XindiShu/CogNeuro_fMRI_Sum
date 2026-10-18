function result=icc(y,unitIds,occasionIds,o)
%ICC 完整平衡单因素/双因素ANOVA六种ICC；负值保留，独立单位bootstrap。
[n,k,p]=size(y);units=string(unitIds(:));occasions=string(occasionIds(:));if ~isnumeric(y)||~isreal(y)||n<3||k<2||any(~isfinite(y),'all')||numel(units)~=n||numel(unique(units))~=n||numel(occasions)~=k||numel(unique(occasions))~=k||any(ismissing(units)|units=="")||any(ismissing(occasions)|occasions==""),error('cog:ICCInput','Balanced finite units x occasions x features with >=3 unique units and >=2 occasions required');end
if ~isscalar(o.nBootstrap)||~isfinite(o.nBootstrap)||o.nBootstrap<0||o.nBootstrap~=fix(o.nBootstrap)||~isscalar(o.alpha)||~isfinite(o.alpha)||o.alpha<=0||o.alpha>=1||strlength(string(o.designNote))==0,error('cog:ICCOptions','Explicit design note and bootstrap/alpha required');end
[values,ms]=calculate(double(y));names={'ICC11','ICC1k','ICC21','ICC2k','ICC31','ICC3k'};result=struct('values',values,'metricNames',{names},'meanSquares',ms,'unitIds',units,'occasionIds',occasions,'options',o,'confidenceInterval',nan(2,6,p),'bootstrapValidCount',zeros(6,p));
if o.nBootstrap>0
    state=rng;cleanup=onCleanup(@()rng(state));rng(o.seed);draws=nan(o.nBootstrap,6,p);for b=1:o.nBootstrap,draws(b,:,:)=reshape(calculate(double(y(randi(n,n,1),:,:))),1,6,p);end
    for f=1:p,for m=1:6,a=draws(:,m,f);a=a(isfinite(a));result.bootstrapValidCount(m,f)=numel(a);if numel(a)>=max(2,ceil(.8*o.nBootstrap)),result.confidenceInterval(:,m,f)=prctile(a,[100*o.alpha/2 100*(1-o.alpha/2)]);end,end,end
end
result.note='Shrout-Fleiss balanced ANOVA point definitions: ICC1 one-way, ICC2 absolute agreement two-way random, ICC3 consistency two-way mixed; 1 single and k average measurement. Interpret random/fixed raters from design, not formula alone. Negative ICC retained; zero denominators -> NaN. Optional row percentile bootstrap is marginal/descriptive, no F-test/BCa/feature multiplicity or missing-data mixed model.';
end
function [v,ms]=calculate(y)
[n,k,p]=size(y);v=nan(6,p);ms=nan(4,p);
for f=1:p
    a=y(:,:,f);row=mean(a,2);col=mean(a,1);grand=mean(a,'all');r=k*sum((row-grand).^2)/(n-1);c=n*sum((col-grand).^2)/(k-1);e=sum((a-row-col+grand).^2,'all')/((n-1)*(k-1));w=sum((a-row).^2,'all')/(n*(k-1));ms(:,f)=[r;c;e;w];num=[r-w;r-w;r-e;r-e;r-e;r-e];den=[r+(k-1)*w;r;r+(k-1)*e+k*(c-e)/n;r+(c-e)/n;r+(k-1)*e;r];ok=den~=0;v(ok,f)=num(ok)./den(ok);
end
end
