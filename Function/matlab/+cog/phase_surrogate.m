function surrogate=phase_surrogate(y)
%PHASE_SURROGATE 同频率所有节点乘同一相位；精确保留离散auto/cross spectrum。
if ~isnumeric(y)||~ismatrix(y)||~isreal(y)||size(y,1)<4||any(~isfinite(y),'all'),error('cog:PhaseSurrogate','Finite real continuous multivariate segment >=4 frames required');end
n=size(y,1);f=fft(double(y),[],1);positive=2:floor((n+1)/2);phase=exp(2*pi*1i*rand(numel(positive),1));f(positive,:)=f(positive,:).*phase;f(n-positive+2,:)=conj(f(positive,:));surrogate=real(ifft(f,[],1));
end
