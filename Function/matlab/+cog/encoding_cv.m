function result=encoding_cv(spaces,y,runIds,frameIndices,groups,covariates,o,execute)
%ENCODING_CV 多输出每列内折选参数；单候选固定，不借测试输出调参。
if nargin<8,execute=true;end
n=size(y,1);groups=string(groups(:));runIds=string(runIds(:));frameIndices=double(frameIndices(:));
if ~ismember(o.sampleKind,{'event_estimates','continuous'})||~ismember(o.method,{'ridge','banded_ridge'})||(~strcmp(o.sampleKind,'continuous')&&any(o.lagsFrames~=0))||isempty(y)||numel(groups)~=n||numel(runIds)~=n||size(covariates,1)~=n||~isreal(covariates)||any(~isfinite(covariates),'all')||any(ismissing(groups)|groups=="")||~isreal(y)||any(~isfinite(y),'all')||~isscalar(o.purgeFrames)||~isfinite(o.purgeFrames)||o.purgeFrames<0||o.purgeFrames~=fix(o.purgeFrames),error('cog:EncodingInput','Explicit aligned targets/groups, sample kind, lag and purge settings required');end
[lagged,keep,sources]=cog.lag_features(spaces,runIds,frameIndices,o.lagsFrames);x=cellfun(@(a)a(keep,:),lagged,'UniformOutput',false);yy=double(y(keep,:));g=groups(keep);runs=runIds(keep);frames=frameIndices(keep);c=double(covariates(keep,:));folds=unique(g,'stable');ng=numel(spaces);candidates=double(o.lambdaCandidates);
if ~ismatrix(candidates)||isempty(candidates)||any(~isfinite(candidates)|candidates<=0,'all')||strcmp(o.method,'ridge')&&size(candidates,2)~=1||strcmp(o.method,'banded_ridge')&&size(candidates,2)~=ng,error('cog:EncodingOptions','Positive candidate rows; ridge one column, banded one per feature space');end
if strcmp(o.method,'ridge'),candidates=repmat(candidates,1,ng);end
if numel(folds)<2||size(candidates,1)>1&&numel(folds)<3,error('cog:EncodingGroups','Need >=2 CV groups; multiple candidate tuning requires >=3');end
result=struct('status','preflight','validRows',keep,'sourceRows',sources,'nValidRows',nnz(keep),'nGroups',numel(folds),'options',o);if ~execute,return;end
prediction=nan(size(yy));nuisance=prediction;parts=nan(size(yy,1),size(yy,2),ng);models=cell(numel(folds),1);radius=o.purgeFrames+max(o.lagsFrames);
for f=1:numel(folds)
    test=g==folds(f);train=purge(~test,test,runs,frames,radius);loss=zeros(size(candidates,1),size(yy,2));
    if size(candidates,1)>1
        inner=unique(g(train),'stable');if numel(inner)<2,error('cog:EncodingGroups','Purging removed an inner CV group');end
        for p=1:size(candidates,1)
            pred=nan(size(yy));for b=1:numel(inner),validation=train&g==inner(b);fit=purge(train&~validation,validation,runs,frames,radius);model=cog.encoding_fit(slice(x,fit),yy(fit,:),c(fit,:),candidates(p,:));pred(validation,:)=cog.encoding_apply(model,slice(x,validation),c(validation,:));end
            loss(p,:)=mean((pred(train,:)-yy(train,:)).^2,1);
        end
    end
    [~,best]=min(loss,[],1);payload=cell(size(candidates,1),1);
    for p=unique(best)
        targets=best==p;model=cog.encoding_fit(slice(x,train),yy(train,targets),c(train,:),candidates(p,:));[pr,components,np]=cog.encoding_apply(model,slice(x,test),c(test,:));prediction(test,targets)=pr;nuisance(test,targets)=np;parts(test,targets,:)=components;payload{p}=struct('targetColumns',find(targets),'model',model);
    end
    models{f}=struct('heldOutGroup',folds(f),'trainingValidRowIds',find(train),'testValidRowIds',find(test),'innerMse',loss,'selectedCandidatePerTarget',best,'models',{payload});
end
r=nan(1,size(yy,2));r2=r;for v=1:size(yy,2),if std(yy(:,v))>eps,r2(v)=1-sum((prediction(:,v)-yy(:,v)).^2)/sum((yy(:,v)-mean(yy(:,v))).^2);if std(prediction(:,v))>eps,r(v)=corr(prediction(:,v),yy(:,v));end,end,end
out=nan(size(y));out(keep,:)=prediction;result.status='complete';result.prediction=out;result.nuisancePredictionValidRows=nuisance;result.featureSpacePredictionsValidRows=parts;result.correlation=r;result.rSquared=r2;result.models=models;result.note='Out-of-group multivariate encoding, target-specific nested MSE candidate selection or one prespecified candidate. Parts are additive predictions, not unique variance. Constant-target/prediction correlations remain NaN; no significance claim.';
end
function out=slice(x,rows)
out=cellfun(@(a)a(rows,:),x,'UniformOutput',false);
end
function train=purge(train,test,runs,frames,radius)
if radius<=0,return;end
for k=unique(runs(test),'stable')',ii=find(train&runs==k);t=frames(test&runs==k);if isempty(ii)||isempty(t),continue;end;near=rangesearch(double(t),double(frames(ii)),radius);train(ii(~cellfun(@isempty,near)))=false;end
end
