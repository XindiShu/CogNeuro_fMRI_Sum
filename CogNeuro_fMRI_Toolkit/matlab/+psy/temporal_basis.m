function model=temporal_basis(x,tr,cfg)
%TEMPORAL_BASIS 把混杂项和带外 DCT-II 基一次联合正交化。
% 频率 k/(2*N*TR)，不是 Butterworth/FFT 滤波器；无工具箱 dct 依赖。
if ~isnumeric(x)||~ismatrix(x)||size(x,1)<3||any(~isfinite(x),'all')
    error('psy:TemporalDesign','Need finite N x P design');
end
if ~(isscalar(tr)&&isfinite(tr)&&tr>0), error('psy:TemporalTR','TR must be positive seconds'); end
n=size(x,1); nyquist=1/(2*tr); lo=cfg.highpassHz; hi=cfg.lowpassHz;
if ~(isnumeric(lo)&&isscalar(lo)&&isfinite(lo)&&lo>=0&&lo<nyquist)
    error('psy:TemporalBand','Invalid highpass frequency');
end
if ~isempty(hi) && ~(isnumeric(hi)&&isscalar(hi)&&isfinite(hi)&&hi>lo&&hi<nyquist)
    error('psy:TemporalBand','Require highpass < lowpass < Nyquist, or empty lowpass');
end
f=(1:n-1)/(2*n*tr); rejected=f<lo;
if ~isempty(hi), rejected=rejected|f>hi; end
k=find(rejected); d=sqrt(2/n)*cos(pi*((0:n-1)'+.5)*k/n);
a=[ones(n,1)/sqrt(n),x,d]; norms=sqrt(sum(a.^2,1)); a=a(:,norms>0)./norms(norms>0);
[u,s,~]=svd(a,'econ'); singular=diag(s); tol=max(size(a))*eps(max(singular)); rankX=sum(singular>tol);
minimum=cfg.minResidualDF;
if ~(isscalar(minimum)&&isfinite(minimum)&&minimum>=1&&fix(minimum)==minimum), error('psy:TemporalDF','Invalid minimum residual dimension'); end
if n-rankX<minimum, error('psy:TemporalDF','Joint model leaves only %d residual dimensions',n-rankX); end
model=struct('Q',u(:,1:rankX),'rank',rankX,'remainingDF',n-rankX, ...
    'nFrames',n,'trSeconds',tr,'rejectedDctIndices',k,'rejectedDctHz',f(k), ...
    'highpassHz',lo,'lowpassHz',hi,'method','joint_nuisance_and_DCT_projection');
end
