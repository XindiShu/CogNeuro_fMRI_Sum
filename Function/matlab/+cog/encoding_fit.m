function model=encoding_fit(spaces,y,covariates,lambdas)
%ENCODING_FIT 多输出banded L2；只从训练数据估计混杂/均值/尺度。
x=horzcat(spaces{:});y=double(y);design=[ones(size(x,1),1) double(covariates)];sizes=cellfun(@(a)size(a,2),spaces);bands=repelem(1:numel(spaces),sizes);penalty=lambdas(bands);
if size(y,1)~=size(x,1)||any(~isfinite(x),'all')||any(~isfinite(y),'all')||any(~isfinite(design),'all')||rank(design)~=size(design,2)||size(x,1)<=size(design,2)+2||any(~isfinite(penalty)|penalty<=0),error('cog:EncodingFit','Finite aligned data, estimable nuisance and positive per-space penalties required');end
betaX=design\x;betaY=design\y;a=x-design*betaX;z=y-design*betaY;mu=mean(a,1);sd=std(a,0,1);valid=sd>10*eps(max(1,max(abs(x),[],1)));a=(a(:,valid)-mu(valid))./sd(valid);p=penalty(valid);
if size(a,2)>size(a,1),scaled=a./sqrt(p);weights=(scaled'*((scaled*scaled'+eye(size(a,1)))\z))./sqrt(p(:));else,weights=(a'*a+diag(p))\(a'*z);end
model=struct('betaX',betaX,'betaY',betaY,'mean',mu,'scale',sd,'valid',valid,'weights',weights,'spaceSizes',sizes,'featureBands',bands,'lambdaPerSpace',lambdas,'nCovariates',size(covariates,2));
end
