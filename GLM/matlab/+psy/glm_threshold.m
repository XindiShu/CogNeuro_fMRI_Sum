function [keep,p,q,u,meta]=glm_threshold(values,stat,df,resels,opt)
%GLM_THRESHOLD 单一对比、完整模型搜索域上的体素推断；不做簇水平校正。
values=double(values(:));stat=char(stat);df=double(df(:)');
if isempty(values)||any(~isfinite(values))||~ismember(stat,{'T','F'})||numel(df)~=2||any(~isfinite(df)|df<=0)
    error('psy:GLMInference','Finite statistics and valid T/F degrees of freedom required');
end
tails=1;
if strcmp(stat,'F')
    if ~strcmp(opt.tail,'positive')||any(values< -1e-6),error('psy:GLMInference','F supports upper tail only and must be nonnegative');end
    z=max(values,0);scaled=df(1)*z;denominator=df(2)+scaled;
    p=betainc(df(2)./denominator,df(2)/2,df(1)/2);
    nearZero=scaled<=df(2);p(nearZero)=betainc(scaled(nearZero)./denominator(nearZero),df(1)/2,df(2)/2,'upper');
else
    z=values;
    if strcmp(opt.tail,'negative'),z=-z;end
    if strcmp(opt.tail,'two_sided'),z=abs(values);tails=2;end
    % 直接用双精度不完全beta函数算尾概率，避免stock spm_Tcdf的近似误差。
    upper=.5*betainc(df(2)./(df(2)+z.^2),df(2)/2,.5);
    nearZero=abs(z)<1;upper(nearZero)=.5-.5*betainc(z(nearZero).^2./(df(2)+z(nearZero).^2),.5,df(2)/2);
    upper(z<0)=1-upper(z<0);p=min(1,tails*upper);
end
q=spm_P_FDR(p);
switch opt.correction
    case 'none'
        u=spm_u(opt.alpha/tails,df,stat);keep=p<=opt.alpha;
    case 'fdr'
        keep=q<=opt.alpha;u=Inf;if any(keep),u=min(z(keep));end
    case 'fwe'
        if numel(resels)~=4||any(~isfinite(resels))||~any(resels>0),error('psy:GLMInference','FWE needs valid model resels; no automatic fallback');end
        u=spm_uc(opt.alpha/tails,df,stat,double(resels(:)'),1,numel(values));
        if ~isscalar(u)||isnan(u),error('psy:GLMInference','Invalid SPM FWE threshold');end
        keep=z>u;
    otherwise
        error('psy:GLMInference','Unknown voxel correction');
end
meta=struct('statistic',stat,'degreesOfFreedom',df,'voxelCorrection',opt.correction, ...
    'alpha',opt.alpha,'tail',opt.tail,'tailCount',tails,'searchVoxels',numel(values), ...
    'statisticThreshold',u,'infiniteThreshold',isinf(u),'nPassingVoxelThreshold',nnz(keep), ...
    'family','one contrast over all model-mask voxels; no correction across contrasts/models/ROIs', ...
    'fweMethod','SPM spm_uc: random-field threshold with native Bonferroni comparison; two-sided alpha/2 per tail');
end
