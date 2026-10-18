function result=intersubject(series,o)
%INTERSUBJECT LOO ISC、方向ISFC及其对称化；共享循环移位零模型，非群体推断。
if ~iscell(series)||numel(series)<2,error('cog:ISCInput','At least two aligned subjects required');end
[nt,nf]=size(series{1});ns=numel(series);data=zeros(nt,nf,ns);
for s=1:ns,x=double(series{s});if ~isequal(size(x),[nt nf])||~isreal(x)||any(~isfinite(x),'all')||nt<8||any(std(x,0,1)<=eps),error('cog:ISCInput','Finite nonconstant common time x feature matrices required');end;if o.standardizeSubjects,x=(x-mean(x,1))./std(x,0,1);end;data(:,:,s)=x;end
wantISFC=true;if isfield(o,'computeISFC'),wantISFC=o.computeISFC;end
[isc,directional,symmetric]=calculate(data,wantISFC);summaryI=summarize(isc);summaryF=[];nullI=nan(o.nSurrogates,nf);nullF=[];if wantISFC,summaryF=summarize(symmetric);nullF=nan(o.nSurrogates,nf,nf);end
if ~isscalar(o.nSurrogates)||~isfinite(o.nSurrogates)||o.nSurrogates<0||o.nSurrogates~=fix(o.nSurrogates)||~isscalar(o.minShiftFrames)||o.minShiftFrames<1||o.minShiftFrames~=fix(o.minShiftFrames)||2*o.minShiftFrames>nt,error('cog:ISCOptions','Invalid shift repetitions/exclusion radius');end
old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
for p=1:o.nSurrogates
    shifted=data;for s=1:ns,shift=randi([o.minShiftFrames nt-o.minShiftFrames]);shifted(:,:,s)=circshift(data(:,:,s),shift,1);end
    [a,~,b]=calculate(shifted,wantISFC);nullI(p,:)=summarize(a);if wantISFC,nullF(p,:,:)=summarize(b);end
end
result=struct('iscPerSubject',isc,'isfcDirectionalPerSubject',directional,'isfcSymmetricPerSubject',symmetric,'iscFisherMean',summaryI,'isfcFisherMean',summaryF,'nullIsc',nullI,'nullIsfc',nullF,'iscP',[],'iscPFwe',[],'isfcP',[],'isfcPFwe',[],'options',o);
if o.nSurrogates>0
    maximumI=max(abs(nullI),[],2);result.iscP=(1+sum(abs(nullI)>=abs(summaryI),1))/(o.nSurrogates+1);result.iscPFwe=(1+sum(maximumI>=abs(summaryI),1))/(o.nSurrogates+1);
    if wantISFC,upper=triu(true(nf));nullEdges=reshape(nullF,o.nSurrogates,nf*nf);maximumF=max(abs(nullEdges(:,upper(:))),[],2);result.isfcP=reshape((1+sum(abs(nullEdges)>=abs(summaryF(:)'),1))/(o.nSurrogates+1),nf,nf);result.isfcPFwe=reshape((1+sum(maximumF>=abs(summaryF(:)'),1))/(o.nSurrogates+1),nf,nf);end
end
result.note='Mean Fisher-z then tanh across dependent leave-one-out subjects; subject estimates are not independent tests. Two-sided circular-shift Monte Carlo, max family separately ISC features or ISFC upper-triangle including diagonal; periodic/stationary assumptions and shared-stimulus alignment are supplied, not established. Not population random-effects inference.';
end
function [isc,directional,symmetric]=calculate(x,wantISFC)
[~,nf,ns]=size(x);isc=zeros(1,nf,ns);directional=[];symmetric=[];if wantISFC,directional=zeros(nf,nf,ns);symmetric=directional;end
for s=1:ns
    other=mean(x(:,:,setdiff(1:ns,s)),3);if any(std(other,0,1)<=eps),error('cog:ISCReference','Leave-one-out reference has constant feature');end
    if wantISFC,r=corr(x(:,:,s),other);isc(1,:,s)=diag(r)';directional(:,:,s)=r;symmetric(:,:,s)=(r+r')/2;
    else,a=x(:,:,s)-mean(x(:,:,s),1);b=other-mean(other,1);isc(1,:,s)=sum(a.*b,1)./sqrt(sum(a.^2,1).*sum(b.^2,1));end
end
end
function r=summarize(x)
r=tanh(mean(atanh(max(-1+eps,min(1-eps,x))),3));
end
