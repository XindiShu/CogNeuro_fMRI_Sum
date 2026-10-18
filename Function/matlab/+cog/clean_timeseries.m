function [residual,info]=clean_timeseries(y,tr,confounds,o)
%CLEAN_TIMESERIES 截距/趋势/混杂/频率基联合投影；不删帧不插值。
if ~isnumeric(y)||~ismatrix(y)||size(y,1)<4||isempty(y)||any(~isfinite(y),'all')||~isreal(y),error('cog:Data','Finite real [time x feature] required');end
n=size(y,1);if isempty(confounds),confounds=zeros(n,0);end
if ~isnumeric(confounds)||size(confounds,1)~=n||any(~isfinite(confounds),'all'),error('cog:Confounds','Finite confounds must match all frames');end
if ~isscalar(tr)||~isfinite(tr)||tr<=0,error('cog:TR','Positive TR seconds required');end
x=[ones(n,1),double(confounds)];if o.detrend,x=[x linspace(-1,1,n)'];end
band=o.bandHz;
if ~isempty(band)
    if numel(band)~=2||any(~isfinite(band))||band(1)<0||band(2)<=band(1)||band(2)>1/(2*tr),error('cog:Band','Invalid frequency band');end
    frequency=(0:n-1)/(2*n*tr);reject=find(frequency<band(1)|frequency>band(2));reject(reject==1)=[];
    basis=sqrt(2/n)*cos(pi*((0:n-1)'+.5)*(reject-1)/n);x=[x basis];
end
[u,s,~]=svd(x,'econ');s=diag(s);rankX=nnz(s>max(size(x))*eps(max(s)));q=u(:,1:rankX);
if n-rankX<o.minResidualDimensions,error('cog:ResidualDimensions','Too few residual dimensions');end
residual=double(y)-q*(q'*double(y));
info=struct('nFrames',n,'nConfounds',size(confounds,2),'projectionRank',rankX,'residualDimensions',n-rankX,'bandHz',band,'detrend',logical(o.detrend),'framesDeleted',0,'maxResidualProjection',max(abs(q'*residual),[],'all'));
end
