function result=dcm_model_probabilities(dcMs)
%DCM_MODEL_PROBABILITIES 同一数据不同网络模型的固定效应后验；均匀先验。
if ~iscell(dcMs)||numel(dcMs)<2,error('cog:DCMCompare','Cell of >=2 estimated models required');end
f=zeros(numel(dcMs),1);reference=dcMs{1};for k=1:numel(dcMs)
    cog.dcm_check(dcMs{k});d=dcMs{k};
    if ~isequal(d.Y.y,reference.Y.y)||~isequal(d.U.u,reference.U.u)||~isequal(d.Y.name,reference.Y.name)||d.Y.dt~=reference.Y.dt,error('cog:DCMCompare','Model evidence comparison requires the same data/inputs/scaling/node order');end
    f(k)=d.F;
end
p=exp(f-max(f));p=p/sum(p);result=struct('freeEnergies',f,'posteriorModelProbability',p,'logBayesFactorsVsFirst',f-f(1),'note','Uniform model priors, fixed-effect within-dataset comparison. Not group random-effects model selection or a causal intervention result.');
end
