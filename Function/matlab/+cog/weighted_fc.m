function result=weighted_fc(y,weights,confounds)
%WEIGHTED_FC 非负显式时间权重的WLS残差相关；不从事件暗自生成权重。
if nargin<3||isempty(confounds),confounds=zeros(size(y,1),0);end
weights=double(weights(:));n=size(y,1);
if ~isnumeric(y)||~ismatrix(y)||any(~isfinite(y),'all')||numel(weights)~=n||any(~isfinite(weights)|weights<0)||nnz(weights)>n||nnz(weights)<4||size(confounds,1)~=n||any(~isfinite(confounds),'all'),error('cog:WeightedFC','Invalid matrix/weights/confounds');end
weights=weights/sum(weights);x=[ones(n,1) double(confounds)];a=x.*sqrt(weights);b=double(y).*sqrt(weights);
if rank(a)<size(a,2)||nnz(weights)-size(a,2)<3,error('cog:WeightedFC','Rank deficient/insufficient weighted observations');end
res=double(y)-x*(a\b);s=res'*(weights.*res);scale=sqrt(diag(s));if any(scale<=eps),error('cog:Constant','Constant weighted residual');end
r=s./(scale*scale');r=max(-1,min(1,r));z=atanh(r);z(1:size(r,1)+1:end)=NaN;
result=struct('correlation',r,'fisherZ',z,'nPositiveWeights',nnz(weights),'effectiveWeightCount',1/sum(weights.^2),'nConfounds',size(confounds,2),'note','WLS residual correlation. Effective weight count is descriptive, not autocorrelation-adjusted inferential df.');
end
