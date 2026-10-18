function result=fc(y,estimator)
%FC 列为ROI；相关与偏相关不代表神经因果。无效/常数列显式拒绝。
if nargin<2,estimator='pearson';end
if ~isnumeric(y)||~ismatrix(y)||size(y,1)<4||size(y,2)<1||any(~isfinite(y),'all')||~isreal(y),error('cog:FC','Finite real matrix required');end
y=double(y);if any(std(y,0,1)<=eps(max(abs(y),[],1))*10),error('cog:Constant','Constant/near constant feature');end
switch estimator
    case 'pearson',r=corr(y);
    case 'spearman',r=corr(y,'Type','Spearman');
    case 'partial'
        s=cov(y);if rcond(s)<1e-10,error('cog:Singular','Partial correlation covariance is singular/ill-conditioned');end
        p=s\eye(size(s));r=-p./sqrt(diag(p)*diag(p)');r(1:size(r,1)+1:end)=1;
    otherwise,error('cog:FC','Unknown estimator');
end
r=max(-1,min(1,r));z=atanh(r);z(1:size(r,1)+1:end)=NaN;
result=struct('correlation',r,'fisherZ',z,'estimator',estimator,'nObservations',size(y,1),'note','No p-values: temporal autocorrelation and nuisance projection require appropriate inference. Diagonal Fisher-z is NaN.');
end
