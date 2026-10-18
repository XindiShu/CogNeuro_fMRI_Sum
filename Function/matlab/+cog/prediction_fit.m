function model=prediction_fit(x,y,covariates,method,parameter)
%PREDICTION_FIT 所有混杂回归/尺度/边筛选仅在此训练数据估计。
x=double(x);y=double(y(:));covariates=double(covariates);design=[ones(size(x,1),1) covariates];
if ~ismatrix(x)||~isreal(x)||~isreal(y)||~isreal(covariates)||numel(y)~=size(x,1)||size(covariates,1)~=size(x,1)||any(~isfinite(x),'all')||any(~isfinite(y))||any(~isfinite(covariates),'all')||rank(design)~=size(design,2)||size(x,1)<=size(design,2)+2,error('cog:PredictionFit','Finite training data and estimable full-rank nuisance design required');end
betaX=design\x;betaY=design\y;a=x-design*betaX;z=y-design*betaY;sd=std(a,0,1);valid=sd>10*eps(max(1,max(abs(x),[],1)));mu=mean(a,1);a=(a(:,valid)-mu(valid))./sd(valid);
model=struct('method',method,'parameter',parameter,'nFeatures',size(x,2),'nCovariates',size(covariates,2),'betaX',betaX,'betaY',betaY,'mean',mu,'scale',sd,'validFeatures',valid,'weights',[],'positiveMask',false(1,size(a,2)),'negativeMask',false(1,size(a,2)),'scoreColumns',[],'scoreMean',[],'scoreScale',[]);
switch method
    case 'ridge'
        if ~isscalar(parameter)||~isfinite(parameter)||parameter<=0,error('cog:PredictionFit','Positive ridge lambda required');end
        if size(a,2)>size(a,1),model.weights=a'*((a*a'+parameter*eye(size(a,1)))\z);else,model.weights=(a'*a+parameter*eye(size(a,2)))\(a'*z);end
    case 'cpm'
        if ~isscalar(parameter)||~isfinite(parameter)||parameter<=0||parameter>=1,error('cog:PredictionFit','CPM p threshold must be in (0,1)');end
        if std(z)>eps&&~isempty(a),r=corr(a,z);df=size(a,1)-size(design,2)-1;p=2*tcdf(-abs(r.*sqrt(df./max(eps,1-r.^2))),df);model.positiveMask=(r'>0&p'<parameter);model.negativeMask=(r'<0&p'<parameter);end
        scores=[sum(a(:,model.positiveMask),2) sum(a(:,model.negativeMask),2)];model.scoreMean=mean(scores,1);model.scoreScale=std(scores,0,1);columns=find(model.scoreScale>eps);d=ones(size(a,1),1);keep=[];
        for k=columns,b=(scores(:,k)-model.scoreMean(k))/model.scoreScale(k);if rank([d b])>size(d,2),d=[d b];keep(end+1)=k;end,end %#ok<AGROW>
        model.scoreColumns=keep;model.weights=d\z;
    otherwise,error('cog:PredictionFit','Unknown method');
end
end
