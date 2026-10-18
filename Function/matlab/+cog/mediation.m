function result=mediation(x,m,y,covariates,units,o)
%MEDIATION 线性无交互的a/b/c'/ab与单位bootstrap；相关不建立因果识别。
x=double(x(:));m=double(m(:));y=double(y(:));units=string(units(:));n=numel(x);if numel(m)~=n||numel(y)~=n||numel(units)~=n||size(covariates,1)~=n||any(~isfinite([x m y covariates]),'all')||~isreal([x m y covariates])||any(ismissing(units)|units=="")||~isscalar(o.nBootstrap)||o.nBootstrap<0||o.nBootstrap~=fix(o.nBootstrap)||~isscalar(o.alpha)||o.alpha<=0||o.alpha>=1,error('cog:MediationInput','Finite paired vectors/covariates/independent units and bootstrap settings required');end
result=fitPaths(x,m,y,covariates);result.nSamples=n;result.nIndependentUnits=numel(unique(units));result.bootstrapEffects=[];result.percentileCi=[];result.bootstrapRejectedDraws=0;result.inferenceEligible=false;
if o.nBootstrap>0
    if result.residualDfOutcome<1||numel(unique(units))<2||strlength(string(o.exchangeabilityJustification))==0,error('cog:MediationBootstrap','Residual df>0, >=2 units and explicit resampling justification required');end
    old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed);samples=zeros(o.nBootstrap,5);accepted=0;attempt=0; %#ok<NASGU>
    while accepted<o.nBootstrap&&attempt<20*o.nBootstrap
        attempt=attempt+1;ii=cog.bootstrap_unit_rows(units);try,b=fitPaths(x(ii),m(ii),y(ii),covariates(ii,:));catch e,if strcmp(e.identifier,'cog:MediationRank'),continue;else,rethrow(e);end,end
        accepted=accepted+1;samples(accepted,:)=[b.a b.b b.direct b.indirect b.total];
    end
    if accepted<o.nBootstrap,error('cog:MediationBootstrap','Too many rank-deficient bootstrap draws');end
    result.bootstrapEffects=samples;result.percentileCi=prctile(samples,[o.alpha/2 1-o.alpha/2]*100,1);result.bootstrapRejectedDraws=attempt-accepted;result.inferenceEligible=strcmp(o.inferenceScope,'assumed_exchangeable');
end
result.options=o;result.note='Linear no-interaction path estimates with the same covariates. Direct/indirect associations are not causal mediation identification; no unmeasured-confounding, sequential-ignorability or temporal-causality assumptions established. Percentile intervals condition on valid full-rank unit-resampled fits; no BCa or automatic multiple comparison.';
end
function result=fitPaths(x,m,y,c)
aDesign=[ones(numel(x),1) double(c) x];bDesign=[aDesign m];if rank(aDesign)~=size(aDesign,2)||rank(bDesign)~=size(bDesign,2)||numel(x)<size(bDesign,2),error('cog:MediationRank','Path designs must be full rank; no unidentified pseudoinverse');end
a=aDesign\m;b=bDesign\y;total=aDesign\y;result=struct('a',a(end),'b',b(end),'direct',b(end-1),'indirect',a(end)*b(end),'total',total(end),'residualDfMediator',numel(x)-size(aDesign,2),'residualDfOutcome',numel(x)-size(bDesign,2),'mediatorResidual',m-aDesign*a,'outcomeResidual',y-bDesign*b);
end
