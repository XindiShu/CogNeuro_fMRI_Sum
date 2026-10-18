function result=group_summary(y,subjectIds,alpha)
%GROUP_SUMMARY 独立被试一采样t、均值CI、Cohen dz及BH-FDR；不将run当独立人。
if nargin<3,alpha=.05;end
subjectIds=string(subjectIds(:));n=size(y,1);
if ~isnumeric(y)||~ismatrix(y)||isempty(y)||n<3||numel(subjectIds)~=n||numel(unique(subjectIds))~=n||any(ismissing(subjectIds)|subjectIds=="")||any(~isfinite(y),'all')
    error('cog:Group','Finite independent-subject rows, unique IDs and n>=3 required');
end
if ~isscalar(alpha)||~isfinite(alpha)||alpha<=0||alpha>=1,error('cog:Group','Invalid alpha');end
[~,p,ci,s]=ttest(double(y),0,'Alpha',alpha);[q,keep]=cog.bh_fdr(p,alpha);sd=std(double(y),0,1);
result=struct('nSubjects',n,'subjectIds',subjectIds,'mean',mean(double(y),1),'standardDeviation',sd,'meanConfidenceInterval',ci,'t',s.tstat,'df',s.df,'p',p,'q',q,'significant',keep,'cohenDz',mean(double(y),1)./sd,'alpha',alpha, ...
    'note','One-sample independent-subject inference only. Each column is one feature in the supplied FDR family. Paired analysis can use per-subject differences; regression/repeated-measures/permutation are separate pending interfaces. n>=3 is an engineering guard, not a sample-size recommendation.');
end
