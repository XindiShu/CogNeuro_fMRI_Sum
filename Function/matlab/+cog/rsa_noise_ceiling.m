function result=rsa_noise_ceiling(rdms,subjectIds,conditionIds,modelRDMs,modelNames,o)
%RSA_NOISE_CEILING 固定条件的Pearson距离相关天花板；按原被试身份排除bootstrap副本。
[nc,nc2,ns]=size(rdms);subjects=string(subjectIds(:));conditions=string(conditionIds(:));if ~isnumeric(rdms)||~isreal(rdms)||nc~=nc2||nc<3||ns<3||any(~isfinite(rdms),'all')||numel(subjects)~=ns||numel(unique(subjects))~=ns||numel(conditions)~=nc||numel(unique(conditions))~=nc||any(ismissing(subjects)|subjects=="")||any(ismissing(conditions)|conditions==""),error('cog:CeilingInput','>=3 complete conditions and >=3 independent subject RDMs with exact identities required');end
if ~isscalar(o.nBootstrap)||~isfinite(o.nBootstrap)||o.nBootstrap<0||o.nBootstrap~=fix(o.nBootstrap)||~isscalar(o.alpha)||~isfinite(o.alpha)||o.alpha<=0||o.alpha>=1||strlength(string(o.designNote))==0,error('cog:CeilingOptions','Bootstrap/alpha and independent-unit design note required');end
ix=find(triu(true(nc),1));v=zeros(numel(ix),ns);for s=1:ns,a=rdms(:,:,s);checkRdm(a);v(:,s)=a(ix);end;v=normalize(v);nm=size(modelRDMs,3);if isempty(modelRDMs),nm=0;end;names=string(modelNames(:));if nm~=numel(names)||numel(unique(names))~=nm||any(ismissing(names)|names==""),error('cog:CeilingModel','Unique matching model names required');end
m=zeros(numel(ix),nm);for j=1:nm,a=modelRDMs(:,:,j);if ~isequal(size(a),[nc nc]),error('cog:CeilingModel','Model condition order/dimensions must match');end;checkRdm(a);m(:,j)=a(ix);end;if nm>0,m=normalize(m);end
[estimate,perSubject]=scores(v,subjects,m);draws=nan(o.nBootstrap,2+nm);state=rng;cleanup=onCleanup(@()rng(state));rng(o.seed);
for b=1:o.nBootstrap,rows=randi(ns,ns,1);draws(b,:)=scores(v(:,rows),subjects(rows),m);end
ci=nan(2,2+nm);valid=sum(isfinite(draws),1);for j=1:2+nm,a=draws(isfinite(draws(:,j)),j);if numel(a)>=max(2,ceil(.8*o.nBootstrap)),ci(:,j)=prctile(a,[100*o.alpha/2 100*(1-o.alpha/2)]);end,end
result=struct('lower',estimate(1),'upper',estimate(2),'modelMeanScores',estimate(3:end),'perSubject',perSubject,'modelNames',names,'subjectIds',subjects,'conditionIds',conditions,'metric','pearson','bootstrapEstimates',draws,'confidenceInterval',ci,'bootstrapValidCount',valid,'options',o,'note','RDM vectors centered/L2-normalized separately before group pooling. Upper includes target subject; lower excludes all copies of original target subject, including within a bootstrap. Conditions fixed; unit bootstrap is marginal descriptive uncertainty, not distance-wise/condition bootstrap, model selection test or exact population bound. Negative crossnobis distances/correlations retained. No Spearman ceiling or covariance-weighted RDM comparison.');
end
function checkRdm(a)
if any(~isfinite(a),'all')||~isreal(a)||norm(a-a','fro')>1e-8||any(diag(a)~=0),error('cog:CeilingInput','Symmetric finite zero-diagonal RDM required');end
end
function v=normalize(v)
v=v-mean(v,1);den=sqrt(sum(v.^2,1));if any(den==0),error('cog:CeilingConstant','Constant distance vector has undefined correlation');end;v=v./den;
end
function [estimate,individual]=scores(v,subjects,m)
ns=size(v,2);upper=nan(ns,1);lower=upper;models=v'*m;pooled=mean(v,2);den=norm(pooled);if den>eps,upper=v'*(pooled/den);end
for s=1:ns,use=subjects~=subjects(s);if any(use),pool=mean(v(:,use),2);if norm(pool)>eps,lower(s)=v(:,s)'*(pool/norm(pool));end,end,end
estimate=[mean(lower) mean(upper) mean(models,1)];individual=struct('lower',lower,'upper',upper,'modelScores',models);
end
