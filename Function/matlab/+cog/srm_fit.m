function model=srm_fit(series,o)
%SRM_FIT 确定性正交SRM：min Σ||X_s-S*W_s'||²，W_s'*W_s=I。
if ~iscell(series)||numel(series)<2,error('cog:SRMInput','Aligned multiple subjects required');end
nt=size(series{1},1);k=o.nFeatures;if ~isscalar(k)||~isfinite(k)||k<1||k~=fix(k)||~isscalar(o.maxIterations)||o.maxIterations<1||o.maxIterations~=fix(o.maxIterations)||~isscalar(o.tolerance)||o.tolerance<=0,error('cog:SRMOptions','Invalid shared rank/optimization options');end
x=cell(size(series));mu=x;sd=x;weights=x;
for s=1:numel(series),a=double(series{s});if size(a,1)~=nt||size(a,2)<k||nt<=k+1||any(~isfinite(a),'all')||~isreal(a),error('cog:SRMInput','Finite aligned time matrices with sufficient feature/time rank required');end;mu{s}=mean(a,1);sd{s}=std(a,0,1);if any(sd{s}<=eps),error('cog:SRMInput','Constant subject feature');end;a=a-mu{s};if o.scaleFeatures,a=a./sd{s};end;x{s}=a;end
[u,d,~]=svd(x{1},'econ');if d(k,k)<=eps(d(1,1))*max(size(x{1})),error('cog:SRMInput','Requested shared rank exceeds training rank');end;shared=u(:,1:k)*d(1:k,1:k);objective=[];
for iteration=1:o.maxIterations
    projected=zeros(nt,k);for s=1:numel(x),[u,~,v]=svd(x{s}'*shared,'econ');weights{s}=u*v';projected=projected+x{s}*weights{s};end;shared=projected/numel(x);value=0;for s=1:numel(x),value=value+sum((x{s}-shared*weights{s}').^2,'all');end;objective(end+1)=value; %#ok<AGROW>
    if iteration>1&&abs(objective(end)-objective(end-1))<=o.tolerance*max(1,objective(end-1)),break;end
end
model=struct('weights',{weights},'sharedResponse',shared,'trainingMean',{mu},'trainingScale',{sd},'objective',objective,'options',o,'note','Deterministic orthogonal least-squares SRM, not probabilistic BrainIAK SRM. Train-only centering/scaling and fitted subject maps; no automatic feature-rank selection or independent predictive validity claim.');
end
