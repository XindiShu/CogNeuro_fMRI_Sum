function result=ordered_events(y,o,frozen)
%ORDERED_EVENTS 顺序单链同方差Gaussian事件；固定首/末事件，显式EM或冻结模式对齐。
if nargin<3,frozen=[];end
y=double(y);[nt,nf]=size(y);k=o.nEvents;if ~ismatrix(y)||~isreal(y)||any(~isfinite(y),'all')||nf<1||~isscalar(k)||k<2||k~=fix(k)||nt<2*k||~isscalar(o.maxIterations)||o.maxIterations<1||o.maxIterations~=fix(o.maxIterations)||~isscalar(o.minVariance)||o.minVariance<=0||~isscalar(o.tolerance)||o.tolerance<=0,error('cog:EventInput','Finite patterns and valid event/variance/iteration settings required');end
stay=(nt-k)/(nt-1);advance=(k-1)/(nt-1);logP=diag(repmat(log(stay),k,1))+diag(repmat(log(advance),k-1,1),1);allowed=logical(eye(k)+diag(ones(k-1,1),1));logP(~allowed)=-Inf;logPriorEnd=gammaln(nt)-gammaln(k)-gammaln(nt-k+1)+(nt-k)*log(stay)+(k-1)*log(advance);
if isempty(frozen)
    initial=min(k,ceil((1:nt)'*k/nt));patterns=zeros(k,nf);for j=1:k,patterns(j,:)=mean(y(initial==j,:),1);end;variance=max(o.minVariance,var(y,0,'all'));history=[];
    for iteration=1:o.maxIterations
        [gamma,ll]=infer(y,patterns,variance,logP,logPriorEnd);history(end+1)=ll; %#ok<AGROW>
        counts=sum(gamma,1)';patterns=(gamma'*y)./counts;distance=zeros(nt,k);for j=1:k,distance(:,j)=sum((y-patterns(j,:)).^2,2);end;variance=max(o.minVariance,sum(gamma.*distance,'all')/(nt*nf));
        if iteration>1&&abs(history(end)-history(end-1))<=o.tolerance*max(1,abs(history(end-1))),break;end
    end
else
    patterns=frozen.patterns;variance=frozen.variance;history=[];if ~isequal(size(patterns),[k nf]),error('cog:EventInput','Frozen event pattern dimensions mismatch');end
end
[gamma,ll,emission]=infer(y,patterns,variance,logP,logPriorEnd);history(end+1)=ll;delta=-inf(nt,k);back=zeros(nt,k);delta(1,1)=emission(1,1);
for t=2:nt,for j=1:k,[value,i]=max(delta(t-1,:)+logP(:,j)');delta(t,j)=value+emission(t,j);back(t,j)=i;end,end
labels=zeros(nt,1);labels(nt)=k;for t=nt:-1:2,labels(t-1)=back(t,labels(t));end
result=struct('patterns',patterns,'variance',variance,'posterior',gamma,'labels',labels,'boundaryBeforeRows',find(diff(labels)>0)+1,'conditionalLogLikelihood',ll,'logLikelihoodHistory',history,'options',o,'frozenPatternApplication',~isempty(frozen),'note','Ordered Gaussian event model, self/next only, starts1/endsK. Conditional endpoint prior is uniform over K-1 ordered transition locations. Plug-in patterns/variance; no BrainIAK annealing/split-merge/multi-chain equivalence or optimal-K/neural-boundary inference claim.');
end
function [gamma,ll,emission]=infer(y,patterns,variance,logP,prior)
[nt,nf]=size(y);k=size(patterns,1);emission=zeros(nt,k);for j=1:k,emission(:,j)=-.5*nf*log(2*pi*variance)-sum((y-patterns(j,:)).^2,2)/(2*variance);end
forward=-inf(nt,k);forward(1,1)=emission(1,1);for t=2:nt,for j=1:k,forward(t,j)=emission(t,j)+lse(forward(t-1,:)+logP(:,j)');end,end
backward=-inf(nt,k);backward(nt,k)=0;for t=nt-1:-1:1,for j=1:k,backward(t,j)=lse(logP(j,:)+emission(t+1,:)+backward(t+1,:));end,end
evidence=forward(nt,k);gamma=exp(forward+backward-evidence);gamma=gamma./sum(gamma,2);ll=evidence-prior;if ~isfinite(ll)||any(~isfinite(gamma),'all'),error('cog:EventPosterior','Nonfinite event posterior');end
end
function value=lse(a)
m=max(a);if isinf(m)&&m<0,value=-Inf;else,value=m+log(sum(exp(a-m)));end
end
