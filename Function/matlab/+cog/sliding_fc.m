function result=sliding_fc(y,trSeconds,frameIndices,o,execute)
%SLIDING_FC 一run；缺帧在frameIndices显式保留，不跨间断开窗或造连续性。
if nargin<5,execute=true;end
[nt,n]=size(y);frameIndices=double(frameIndices(:));
if ~isnumeric(y)||~ismatrix(y)||~isreal(y)||n<2||any(~isfinite(y),'all')||numel(frameIndices)~=nt||any(~isfinite(frameIndices)|frameIndices<1|frameIndices~=fix(frameIndices))||any(diff(frameIndices)<=0)||~isscalar(trSeconds)||~isfinite(trSeconds)||trSeconds<=0,error('cog:DynamicFC','Finite time x nodes, true ascending integer acquisition frame IDs, and seconds TR required');end
if isempty(o.windowSeconds)||~isvector(o.windowSeconds)||any(~isfinite(o.windowSeconds)|o.windowSeconds<=0)||~isscalar(o.stepSeconds)||~isfinite(o.stepSeconds)||o.stepSeconds<=0||~ismember(o.taper,{'rectangular','gaussian'})||~isscalar(o.gaussianSigmaFraction)||~isfinite(o.gaussianSigmaFraction)||o.gaussianSigmaFraction<=0||~isscalar(o.minWindows)||~isfinite(o.minWindows)||o.minWindows<3||o.minWindows~=fix(o.minWindows)||~isscalar(o.nSurrogates)||~isfinite(o.nSurrogates)||o.nSurrogates<0||o.nSurrogates~=fix(o.nSurrogates),error('cog:DynamicFC','Invalid window/taper/null options');end
lengths=round(o.windowSeconds/trSeconds);step=max(1,round(o.stepSeconds/trSeconds));if any(lengths<8)||numel(unique(lengths))~=numel(lengths),error('cog:DynamicFC','Distinct actual windows of >=8 frames required');end
cuts=[1;find(diff(frameIndices)~=1)+1;nt+1];segments=[cuts(1:end-1) cuts(2:end)-1];edgeMask=triu(true(n),1);[edgeRow,edgeColumn]=find(edgeMask);e=nnz(edgeMask);windows=cell(numel(lengths),1);validLength=false(numel(lengths),1);
for k=1:numel(lengths)
    starts=[];for s=1:size(segments,1),starts=[starts segments(s,1):step:(segments(s,2)-lengths(k)+1)];end %#ok<AGROW>
    nf=lengths(k);w=ones(nf,1);if strcmp(o.taper,'gaussian'),w=exp(-.5*(((1:nf)'-(nf+1)/2)/(o.gaussianSigmaFraction*nf)).^2);end;w=w/sum(w);ends=starts+nf-1;
    windows{k}=struct('requestedSeconds',o.windowSeconds(k),'actualDurationSeconds',nf*trSeconds,'stepFrames',step,'actualStepSeconds',step*trSeconds,'startRows',starts,'endRows',ends,'startFrameIndices',frameIndices(starts),'endFrameIndices',frameIndices(ends),'centerTimeSeconds',(frameIndices(starts)+frameIndices(ends)-2)*trSeconds/2,'weights',w,'effectiveWeightCount',1/sum(w.^2),'nWindows',numel(starts),'status','insufficient_windows','correlation',[],'fisherZ',[],'edgeSdR',[],'pUncorrected',[],'pFweEdgesAndLengths',[]);validLength(k)=numel(starts)>=o.minWindows;
end
if ~any(validLength),error('cog:DynamicCoverage','No window length has sufficient within-segment windows');end
result=struct('status','preflight','segmentsRows',segments,'frameIndices',frameIndices,'edgeNodes',[edgeRow edgeColumn],'windows',{windows},'options',o,'nullEdgeSdR',[],'nullMaximum',[]);if ~execute,return;end
observed=nan(numel(lengths),e);
for k=find(validLength)'
    [r,z,sd]=windowScores(y,windows{k},edgeMask);windows{k}.correlation=r;windows{k}.fisherZ=z;windows{k}.edgeSdR=sd;windows{k}.status='complete';observed(k,:)=sd;
end
null=nan(o.nSurrogates,numel(lengths),e);nullMaximum=nan(o.nSurrogates,1);old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
for b=1:o.nSurrogates
    surrogate=y;for s=1:size(segments,1),ii=segments(s,1):segments(s,2);if numel(ii)>=4,surrogate(ii,:)=cog.phase_surrogate(y(ii,:));end,end
    for k=find(validLength)',[~,~,sd]=windowScores(surrogate,windows{k},edgeMask);null(b,k,:)=sd;end
    a=reshape(null(b,validLength,:),[],1);nullMaximum(b)=max(a);
end
if o.nSurrogates>0
    for k=find(validLength)',a=reshape(null(:,k,:),o.nSurrogates,e);windows{k}.pUncorrected=(1+sum(a>=observed(k,:),1))/(1+o.nSurrogates);windows{k}.pFweEdgesAndLengths=(1+sum(nullMaximum>=observed(k,:),1))/(1+o.nSurrogates);end
end
result.status='complete';result.windows=windows;result.nullEdgeSdR=null;result.nullMaximum=nullMaximum;result.note='Within-run/continuous-segment windows. Across-window SD of Pearson r, no independent-window t-test. Shared multivariate phase surrogates preserve discrete power/cross spectra per segment under periodic linear stationary null assumptions; not amplitude ranks or all nonlinear features. Max family contains all requested valid lengths and undirected edges for this run only.';
end
function [r,z,variability]=windowScores(y,window,edgeMask)
n=size(y,2);r=zeros(n,n,window.nWindows);z=r;values=zeros(window.nWindows,nnz(edgeMask));for k=1:window.nWindows,a=cog.weighted_fc(y(window.startRows(k):window.endRows(k),:),window.weights,[]);r(:,:,k)=a.correlation;z(:,:,k)=a.fisherZ;values(k,:)=a.correlation(edgeMask);end
variability=std(values,0,1);if any(~isfinite(variability)),error('cog:DynamicFC','Nonfinite window variability');end
end
