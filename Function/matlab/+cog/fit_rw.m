function result=fit_rw(choice,reward,blocks,o)
%FIT_RW 两参数有界多起点最大似然；无层级贝叶斯/参数显著性推断。
lower=[o.alphaBounds(1) o.betaBounds(1)];upper=[o.alphaBounds(2) o.betaBounds(2)];
if numel(o.alphaBounds)~=2||numel(o.betaBounds)~=2||any(~isfinite([lower upper]))||any(lower>=upper)||lower(1)<0||upper(1)>1||lower(2)<0||~isscalar(o.nStarts)||~isfinite(o.nStarts)||o.nStarts<1||o.nStarts~=fix(o.nStarts)||~isscalar(o.maxIterations)||~isfinite(o.maxIterations)||o.maxIterations<1||o.maxIterations~=fix(o.maxIterations),error('cog:RWFit','Valid bounds/start counts/iteration limit required');end
cog.rw_softmax(choice,reward,blocks,(lower+upper)/2,o);old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
options=optimoptions('fmincon','Display','off','Algorithm','interior-point','MaxIterations',o.maxIterations,'MaxFunctionEvaluations',max(200,20*o.maxIterations));fits=cell(o.nStarts,1);best=Inf;
for k=1:o.nStarts
    x0=lower+rand(1,2).*(upper-lower);[parameter,value,exitflag,output]=fmincon(@(p)cog.rw_softmax(choice,reward,blocks,p,o),x0,[],[],[],[],lower,upper,[],options);fits{k}=struct('start',x0,'parameter',parameter,'negativeLogLikelihood',value,'exitflag',exitflag,'output',output);
    if isfinite(value)&&value<best,best=value;selected=k;end
end
if ~isfinite(best),error('cog:RWFit','No finite fit');end
parameter=fits{selected}.parameter;[~,latent]=cog.rw_softmax(choice,reward,blocks,parameter,o);n=numel(choice);result=struct('alpha',parameter(1),'inverseTemperature',parameter(2),'negativeLogLikelihood',best,'aic',2*best+4,'bic',2*best+2*log(n),'latent',latent,'fits',{fits},'selectedStart',selected,'options',o,'convergenceAssessed',false,'note','Chosen-action RW with block-boundary resets, softmax and fixed lapse; parameter fit is descriptive. Identifiability, recovery, feedback semantics and out-of-sample model comparison need their own design.');
end
