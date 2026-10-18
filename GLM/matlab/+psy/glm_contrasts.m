function weights=glm_contrasts(columnNames,conditions,requested,x,minDF,nRuns,basis)
%GLM_CONTRASTS 按 SPM 列名映射 canonical HRF 对比；检查高通后可估性。
if size(requested,2)~=numel(conditions)||any(~isfinite(requested),'all')||any(all(requested==0,2))
    error('psy:GLMContrast','Finite nonzero contrast rows must match condition count');
end
if nargin<6,nRuns=1;end
if nargin<7,basis=1;end
weights=zeros(size(requested,1),size(x,2));
for session=1:nRuns
for k=1:numel(conditions)
    idx=find(strcmp(columnNames,sprintf('Sn(%d) %s*bf(%d)',session,conditions{k},basis)));
    if numel(idx)~=1, error('psy:GLMColumn','Missing/ambiguous SPM condition column'); end
    weights(:,idx)=requested(:,k)/nRuns;
end
end
% 0行且minDF=0专用于准备阶段的列名映射；实际SPM设计始终执行以下数值检查。
if size(x,1)==0&&minDF==0,return;end
if size(x,1)-rank(x)<minDF, error('psy:GLMDF','Insufficient residual dimensions after highpass'); end
projector=pinv(x)*x;
if norm(weights-weights*projector,'fro')>1e-7*max(1,norm(weights,'fro'))
    error('psy:GLMEstimability','Requested contrast not estimable');
end
end
