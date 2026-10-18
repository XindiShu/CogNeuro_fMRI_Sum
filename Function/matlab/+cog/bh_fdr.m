function [q,keep]=bh_fdr(p,alpha)
%BH_FDR 每次输入数组构成一个检验族；NaN保留，不以零替代。
if nargin<2,alpha=.05;end
if ~isnumeric(p)||any(isinf(p),'all')||any(p(~isnan(p))<0|p(~isnan(p))>1)||~isscalar(alpha)||alpha<=0||alpha>=1,error('cog:FDR','Invalid p or alpha');end
q=nan(size(p));valid=find(~isnan(p));[a,order]=sort(p(valid));n=numel(a);
if n>0,b=a(:).*n./(1:n)';b=flipud(cummin(flipud(b)));q(valid(order))=min(b,1);end
keep=q<=alpha;
end
