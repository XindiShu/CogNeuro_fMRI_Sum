function model=multivariate_fit(x,y,covariates,method,o)
%MULTIVARIATE_FIT 训练折内混杂/尺度；PLS-C、CCA与原生PLS回归定义分开。
x=double(x);y=double(y);n=size(x,1);design=[ones(n,1) double(covariates)];k=o.nComponents;
if ~ismatrix(x)||~ismatrix(y)||size(y,1)~=n||size(covariates,1)~=n||~isreal(x)||~isreal(y)||~isreal(covariates)||any(~isfinite(x),'all')||any(~isfinite(y),'all')||any(~isfinite(design),'all')||rank(design)~=size(design,2)||n<=size(design,2)||~isscalar(k)||~isfinite(k)||k<1||k~=fix(k),error('cog:MultivariateInput','Finite aligned data, estimable nuisance and positive component count required');end
bx=design\x;by=design\y;xa=x-design*bx;ya=y-design*by;mx=mean(xa,1);my=mean(ya,1);sx=std(xa,0,1);sy=std(ya,0,1);vx=sx>10*eps(max(1,max(abs(x),[],1)));vy=sy>10*eps(max(1,max(abs(y),[],1)));if ~any(vx)||~any(vy),error('cog:MultivariateConstant','No training-variable features in one block');end
if ~o.scaleFeatures,sx(vx)=1;sy(vy)=1;end
xa=(xa(:,vx)-mx(vx))./sx(vx);ya=(ya(:,vy)-my(vy))./sy(vy);if rank(xa)<k||~strcmp(method,'pls_regression')&&rank(ya)<k,error('cog:MultivariateRank','Component count exceeds training observable rank');end
df=n-1;cxx=xa'*xa/df;cyy=ya'*ya/df;cxy=xa'*ya/df;beta=[];native=[];statistics=[];
switch method
    case 'pls_covariance'
        [wx,d,wy]=svd(cxy,'econ');wx=wx(:,1:k);wy=wy(:,1:k);statistics=diag(d);statistics=statistics(1:k);xs=xa*wx;ys=ya*wy;kind='singular value of cross-covariance after declared nuisance/scaling';
    case 'cca'
        if ~isscalar(o.lambdaX)||~isfinite(o.lambdaX)||o.lambdaX<0||~isscalar(o.lambdaY)||~isfinite(o.lambdaY)||o.lambdaY<0,error('cog:CCAOptions','Prespecified nonnegative covariance ridge values required');end
        [lx,fx]=chol(cxx+o.lambdaX*eye(size(cxx)),'lower');[ly,fy]=chol(cyy+o.lambdaY*eye(size(cyy)),'lower');if fx||fy,error('cog:CCARank','Classical covariance not positive definite; reduce training features or specify positive regularization');end
        [u,d,v]=svd(lx\cxy/ly','econ');wx=lx'\u(:,1:k);wy=ly'\v(:,1:k);statistics=diag(d);statistics=statistics(1:k);xs=xa*wx;ys=ya*wy;kind='regularized covariance-normalized canonical singular value';
    case 'pls_regression'
        [xl,yl,xs,ys,beta,pct,~,stats]=plsregress(xa,ya,k);wx=stats.W;wy=yl;if norm(xa*wx-xs,'fro')>1e-7*max(1,norm(xs,'fro')),error('cog:PLSNative','Native score weights do not match documented XS=X0*W contract');end
        native=struct('Xloadings',xl,'Yloadings',yl,'explainedVarianceFractionPreprocessed',pct);statistics=pct(2,:)';kind='in-sample fraction of preprocessed Y variance per PLS component';
    otherwise,error('cog:MultivariateMethod','Unsupported association/prediction method');
end
if ~strcmp(method,'pls_regression'),for j=1:k,[~,i]=max(abs(wx(:,j)));if wx(i,j)<0,wx(:,j)=-wx(:,j);wy(:,j)=-wy(:,j);xs(:,j)=-xs(:,j);ys(:,j)=-ys(:,j);end,end,end
xweights=zeros(size(x,2),k);yweights=zeros(size(y,2),k);xweights(vx,:)=wx;yweights(vy,:)=wy;scoreR=nan(1,k);for j=1:k,if std(xs(:,j))>eps&&std(ys(:,j))>eps,scoreR(j)=corr(xs(:,j),ys(:,j));end,end
model=struct('method',method,'betaX',bx,'betaY',by,'meanX',mx,'meanY',my,'scaleX',sx,'scaleY',sy,'validX',vx,'validY',vy,'xWeights',xweights,'yWeights',yweights,'Xscores',xs,'Yscores',ys,'statistics',statistics(:)','statisticDefinition',kind,'trainingScoreCorrelations',scoreR,'regressionBeta',beta,'native',native,'options',o);
end
