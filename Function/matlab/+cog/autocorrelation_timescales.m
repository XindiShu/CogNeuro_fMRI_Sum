function result=autocorrelation_timescales(y,trSeconds,frameIndices,o)
%AUTOCORRELATION_TIMESCALES 有偏归一化ACF、首正瓣面积、正瓣log-linear近似；不跨缺帧。
[nt,nf]=size(y);frames=double(frameIndices(:));if numel(frames)~=nt||any(~isfinite(frames))||any(diff(frames)~=1),error('cog:TimescaleContinuity','Explicit continuous frame indices required; do not concatenate gaps');end
if ~isnumeric(y)||~isreal(y)||any(~isfinite(y),'all')||nt<6||~isscalar(trSeconds)||~isfinite(trSeconds)||trSeconds<=0||~isscalar(o.maxLagSeconds)||~isfinite(o.maxLagSeconds)||o.maxLagSeconds<=0||~isscalar(o.expFitMaxLagSeconds)||~isfinite(o.expFitMaxLagSeconds)||o.expFitMaxLagSeconds<=0,error('cog:TimescaleOptions','Finite time series and explicit positive seconds settings required');end
maxLag=min(nt-2,floor(o.maxLagSeconds/trSeconds));if maxLag<3,error('cog:TimescaleCoverage','Need at least three positive lag samples');end
lag=(0:maxLag)'*trSeconds;acf=nan(maxLag+1,nf);area=nan(1,nf);iat=area;zeroTime=area;tau=area;r2=area;nFit=zeros(1,nf);rightCensored=false(1,nf);valid=false(1,nf);
for f=1:nf
    x=double(y(:,f))-mean(y(:,f));denom=sum(x.^2);if denom==0,continue;end;valid(f)=true;
    for l=0:maxLag,acf(l+1,f)=sum(x(1:nt-l).*x(1+l:nt))/denom;end
    first=find(acf(2:end,f)<=0,1)+1;
    if isempty(first),last=maxLag+1;rightCensored(f)=true;t=lag;v=acf(:,f);
    else,last=first-1;fraction=acf(last,f)/(acf(last,f)-acf(first,f));zeroTime(f)=lag(last)+fraction*trSeconds;t=[lag(1:last);zeroTime(f)];v=[acf(1:last,f);0];end
    area(f)=trapz(t,v);iat(f)=trSeconds*(1+2*sum(acf(2:last,f)));fit=find(lag>0&lag<=o.expFitMaxLagSeconds&((1:numel(lag))'<=last)&acf(:,f)>0);nFit(f)=numel(fit);
    if numel(fit)>=3,a=[ones(numel(fit),1) lag(fit)];z=log(acf(fit,f));b=a\z;if b(2)<0,tau(f)=-1/b(2);r2(f)=1-sum((z-a*b).^2)/sum((z-mean(z)).^2);end,end
end
result=struct('lagSeconds',lag,'acfBiasedNormalized',acf,'positiveAreaSeconds',area,'positiveIatSeconds',iat,'firstNonpositiveInterpolatedSeconds',zeroTime,'positiveAreaRightCensored',rightCensored,'exponentialApproxTauSeconds',tau,'exponentialLogFitRSquared',r2,'exponentialFitPoints',nFit,'validNonconstantFeature',valid,'options',o,'note','ACF uses common lag0 sum-of-squares denominator; positive area includes lag0 and linear zero interpolation. IAT uses positive sampled lags only. Exponential tau fits log positive ACF (not a neuronal deconvolution model). Filtering/motion/record length shape all quantities; no biological intrinsic-timescale or confidence claim.');
end
