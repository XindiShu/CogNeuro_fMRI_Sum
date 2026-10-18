function result=searchlight(x,xyz,centerIds,target,partitions,exchangeBlocks,o)
%SEARCHLIGHT 球邻域共享置换索引，单侧最大统计量FWE；不作群体推断。
if ~isnumeric(x)||~ismatrix(x)||~isreal(x)||any(~isfinite(x),'all')||~isequal(size(xyz),[size(x,2) 3])||any(~isfinite(xyz),'all'),error('cog:Searchlight','Finite samples x features and feature x 3 physical coordinates required');end
centerIds=centerIds(:);n=size(x,1);partitions=string(partitions(:));exchangeBlocks=string(exchangeBlocks(:));target=target(:);
if isempty(centerIds)||numel(unique(centerIds))~=numel(centerIds)||any(centerIds<1|centerIds>size(x,2)|centerIds~=fix(centerIds))||numel(target)~=n||numel(partitions)~=n||numel(exchangeBlocks)~=n||any(ismissing(partitions)|partitions==""|ismissing(exchangeBlocks)|exchangeBlocks==""),error('cog:Searchlight','Explicit unique centers, row targets and nonempty partition/exchangeability blocks required');end
if ~ismember(o.mode,{'decode','rsa'})||~isscalar(o.radiusMm)||~isfinite(o.radiusMm)||o.radiusMm<=0||~isscalar(o.minFeatures)||~isfinite(o.minFeatures)||o.minFeatures<2||o.minFeatures~=fix(o.minFeatures)||~isscalar(o.nPermutations)||~isfinite(o.nPermutations)||o.nPermutations<0||o.nPermutations~=fix(o.nPermutations),error('cog:Searchlight','Invalid mode/radius/coverage/permutation count');end
if o.nPermutations>0&&(~ismember(o.permutationScope,{'engineering','assumed_exchangeable'})||strlength(string(o.exchangeabilityJustification))==0),error('cog:Exchangeability','Explicit permutation scope and justification required');end
if strcmp(o.mode,'rsa')&&(~ismember(o.rsaScore,{'mean_distance','model_spearman'})||(o.nPermutations>0&&strcmp(o.rsaScore,'mean_distance'))),error('cog:SearchlightRSA','Mean distance is label-invariant and cannot use label permutations');end
neighbors=rangesearch(double(xyz),double(xyz(centerIds,:)),o.radiusMm);count=cellfun(@numel,neighbors)';valid=count>=o.minFeatures;score=nan(1,numel(centerIds));
for c=find(valid),score(c)=measure(x(:,neighbors{c}),target,partitions,o,neighbors{c});end
valid=valid&isfinite(score);if ~any(valid),error('cog:Searchlight','No finite adequately covered centers');end
nullMax=nan(o.nPermutations,1);uncorrected=zeros(size(score));corrected=uncorrected;old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
if strcmp(o.mode,'rsa')&&strcmp(o.rsaScore,'model_spearman')
    labels=unique(string(target),'stable');if numel(labels)<3||size(o.rsa.modelRDMs,3)~=1,error('cog:SearchlightRSA','Model Spearman requires >=3 conditions and one model');end
end
for p=1:o.nPermutations
    permTarget=target;op=o;
    if strcmp(o.mode,'decode')
        blocks=unique(exchangeBlocks,'stable');for b=1:numel(blocks),ii=find(exchangeBlocks==blocks(b));permTarget(ii)=target(ii(randperm(numel(ii))));end
    else
        order=randperm(numel(labels));op.rsa.modelRDMs=o.rsa.modelRDMs(order,order);
    end
    null=nan(size(score));for c=find(valid),null(c)=measure(x(:,neighbors{c}),permTarget,partitions,op,neighbors{c});end
    if any(~isfinite(null(valid))),error('cog:SearchlightNull','Permutation returned nonfinite statistic at an observed-valid center');end
    nullMax(p)=max(null(valid));uncorrected(valid)=uncorrected(valid)+(null(valid)>=score(valid));corrected(valid)=corrected(valid)+(nullMax(p)>=score(valid));
end
pRaw=[];pFwe=[];if o.nPermutations>0,pRaw=nan(size(score));pFwe=pRaw;pRaw(valid)=(1+uncorrected(valid))/(1+o.nPermutations);pFwe(valid)=(1+corrected(valid))/(1+o.nPermutations);end
result=struct('centerIds',centerIds,'score',score,'nFeatures',count,'valid',valid,'pUncorrected',pRaw,'pFweMax',pFwe,'nullMaximum',nullMax,'options',o,'inferenceEligible',o.nPermutations>0&&strcmp(o.permutationScope,'assumed_exchangeable'),'note','One-sided higher-score Monte Carlo p=(1+exceedances)/(B+1); same row/item permutations across centers. FWE family is only the requested valid centers within this one analysis unit; caller exchangeability assumed, not verified. No population inference.');
end
function score=measure(x,target,partitions,o,features)
if strcmp(o.mode,'decode')
    try,d=cog.decode(x,target,partitions,o.decode);catch e,if strcmp(e.identifier,'cog:Constant'),score=NaN;return;else,rethrow(e);end,end
    if strcmp(o.decode.task,'classification'),score=d.balancedAccuracy;else,score=d.correlation;end
else
    rOptions=o.rsa;if strcmp(rOptions.metric,'crossnobis'),rOptions.noiseCovariance=rOptions.noiseCovariance(features,features);end
    try,r=cog.rsa(x,target,partitions,rOptions);catch e,if strcmp(e.identifier,'cog:Constant'),score=NaN;return;else,rethrow(e);end,end
    if strcmp(o.rsaScore,'model_spearman'),if numel(r.labels)<3||numel(r.modelFits)~=1,error('cog:SearchlightRSA','One model and >=3 conditions required');end;score=r.modelFits;else,score=mean(r.rdm(tril(true(numel(r.labels)),-1)));end
end
end
