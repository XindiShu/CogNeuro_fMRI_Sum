function qc=dcm_check(DCM)
%DCM_CHECK 后验/证据工程检查；有限数值不代表识别性或收敛合格。
if ~all(isfield(DCM,{'Ep','Cp','F','M'}))||~isscalar(DCM.F)||~isfinite(DCM.F)||any(~isfinite(spm_vec(DCM.Ep)))||any(~isfinite(DCM.Cp),'all')||~isequal(size(DCM.Cp),[numel(spm_vec(DCM.Ep)) numel(spm_vec(DCM.Ep))])
    error('cog:DCMPosterior','Missing/nonfinite/incompatible posterior or evidence');
end
c=full(DCM.Cp);if norm(c-c','fro')>1e-6*max(1,norm(c,'fro'))||min(eig((c+c')/2))< -1e-7*max(1,norm(c,'fro')),error('cog:DCMPosterior','Posterior covariance is not symmetric positive semidefinite');end
qc=struct('status','finite_posterior','freeEnergy',DCM.F,'nRegions',DCM.n,'nFrames',DCM.v,'nParameters',size(c,1),'convergenceAssessed',false,'explainedVariancePercent',[]);
if isfield(DCM,'R')&&isequal(size(DCM.R),size(DCM.Y.y))
    if any(~isfinite(DCM.R),'all'),error('cog:DCMPosterior','Nonfinite residual');end
    qc.explainedVariancePercent=100*(1-var(DCM.R,0,1)./var(DCM.Y.y,0,1));
end
end
