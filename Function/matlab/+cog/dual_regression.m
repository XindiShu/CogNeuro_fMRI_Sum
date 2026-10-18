function result=dual_regression(y,maps,normalizeStage2)
%DUAL_REGRESSION 联合空间回归→联合时间回归；不做阈值化双回归或群体检验。
if ~ismatrix(y)||~ismatrix(maps)||size(y,2)~=size(maps,1)||any(~isfinite(y),'all')||any(~isfinite(maps),'all')||~isreal(y)||~isreal(maps),error('cog:DualRegression','Finite time x feature and feature x component matrices required');end
[nt,nv]=size(y);k=size(maps,2);spatial=[ones(nv,1) maps];if k<1||rank(spatial)~=k+1||nt<=k+2,error('cog:DualRegression','Independent nonconstant maps and sufficient frames required');end
y=y-mean(y,1);b=spatial\y';tc=b(2:end,:)';tc=tc-mean(tc,1);if any(std(tc,0,1)<=eps),error('cog:DualRegression','Constant stage1 timecourse');end
regressors=tc;if normalizeStage2,regressors=tc./std(tc,0,1);end
design=[ones(nt,1) regressors];if rank(design)~=k+1,error('cog:DualRegression','Stage2 time design must be full rank');end
b=design\y;residual=y-design*b;result=struct('timecourses',tc,'stage2Regressors',regressors,'subjectMaps',b(2:end,:)','residualVariance',sum(residual.^2,1)/(nt-k-1),'fnc',cog.fc(tc,'pearson'),'stage2TimecourseVarianceNormalized',logical(normalizeStage2));
end
