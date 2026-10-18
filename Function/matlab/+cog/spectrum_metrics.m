function result=spectrum_metrics(y,tr,band)
%SPECTRUM_METRICS 未补零FFT的单边振幅；ALFF=带内均值，fALFF=带内和/全正频和。
% 输入应已去趋势/混杂但未带通；不在此重复投影或删除帧。
if ~isnumeric(y)||~ismatrix(y)||size(y,1)<4||isempty(y)||~isreal(y)||any(~isfinite(y),'all'),error('cog:Spectrum','Invalid time series');end
if ~isscalar(tr)||~isfinite(tr)||tr<=0||numel(band)~=2||any(~isfinite(band))||band(1)<0||band(2)<=band(1)||band(2)>1/(2*tr),error('cog:Band','Invalid TR/band');end
n=size(y,1);a=abs(fft(double(y)-mean(double(y),1),[],1))/n;
idx=2:floor(n/2)+1;f=(idx-1)/(n*tr);a=2*a(idx,:);if mod(n,2)==0,a(end,:)=a(end,:)/2;end
use=f>=band(1)-eps&f<=band(2)+eps;if ~any(use),error('cog:FrequencyResolution','No Fourier bins inside requested band');end
alff=mean(a(use,:),1);den=sum(a,1);falff=sum(a(use,:),1)./den;falff(den==0)=NaN;
result=struct('alff',alff,'falff',falff,'frequencyHz',f,'bandHz',band,'nBandBins',nnz(use),'nFFT',n, ...
    'definition','Unpadded FFT; one-sided amplitude abs(FFT)/N, double non-DC/non-Nyquist bins; ALFF band mean; fALFF band sum divided by all positive-frequency amplitude sum (not power).', ...
    'note','Absolute ALFF depends on this explicit normalization; not promised numerically identical to padded FFT implementations.');
end
