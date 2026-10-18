function [lagged,valid,sourceRows]=lag_features(spaces,runIds,frameIndices,lags)
%LAG_FEATURES y(t)由X(t-lag)预测；按实际帧号/连续段匹配，不借用相邻run。
runIds=string(runIds(:));frameIndices=double(frameIndices(:));n=numel(runIds);lags=double(lags(:)');
if ~iscell(spaces)||isempty(spaces)||numel(frameIndices)~=n||any(ismissing(runIds)|runIds=="")||any(~isfinite(frameIndices)|frameIndices<1|frameIndices~=fix(frameIndices))||isempty(lags)||any(~isfinite(lags)|lags<0|lags~=fix(lags))||numel(unique(lags))~=numel(lags),error('cog:EncodingLags','Explicit run IDs, actual integer frame IDs and unique causal lags required');end
sourceRows=zeros(n,numel(lags));valid=true(n,1);runs=unique(runIds,'stable');
for k=1:numel(runs)
    ii=find(runIds==runs(k));f=frameIndices(ii);if any(diff(f)<=0),error('cog:EncodingLags','Frames must strictly increase within run');end
    cuts=[1;find(diff(f)~=1)+1;numel(ii)+1];for s=1:numel(cuts)-1,jj=ii(cuts(s):cuts(s+1)-1);for l=1:numel(lags),[has,where]=ismember(frameIndices(jj)-lags(l),frameIndices(jj));sourceRows(jj(has),l)=jj(where(has));valid(jj(~has))=false;end,end
end
lagged=cell(size(spaces));for g=1:numel(spaces),x=double(spaces{g});if ~ismatrix(x)||size(x,1)~=n||isempty(x)||~isreal(x)||any(~isfinite(x),'all'),error('cog:EncodingLags','Finite aligned feature-space matrices required');end;a=nan(n,size(x,2)*numel(lags));for l=1:numel(lags),has=sourceRows(:,l)>0;a(has,(l-1)*size(x,2)+(1:size(x,2)))=x(sourceRows(has,l),:);end;lagged{g}=a;end
end
