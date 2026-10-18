function results=beta_series(beta,meta,minTrials,estimator)
%BETA_SERIES 每subject/session/run/condition分别相关，不跨run盲目混合。
if nargin<3,minTrials=4;end;if nargin<4,estimator='pearson';end
fields={'subject','session','run','condition','estimate_id'};
if ~all(ismember(fields,meta.Properties.VariableNames))||height(meta)~=size(beta,1)||numel(unique(string(meta.estimate_id)))~=height(meta)||any(~isfinite(beta),'all')
    error('cog:BetaSeries','Unique trial metadata must match finite rows');
end
if ~isscalar(minTrials)||minTrials<3||minTrials~=fix(minTrials),error('cog:BetaSeries','minTrials integer >=3 required');end
if ismember('estimate_unit',meta.Properties.VariableNames)&&any(~ismember(string(meta.estimate_unit),["trial","event","item","trial_phase"]))
    error('cog:BetaUnit','Beta-series requires declared comparable trial/item estimates');
end
key=string(meta.subject)+"/"+string(meta.session)+"/"+string(meta.run)+"/"+string(meta.condition);groups=unique(key,'stable');results=cell(numel(groups),1);
for k=1:numel(groups)
    use=key==groups(k);r=struct('key',groups(k),'nTrials',nnz(use),'estimateIds',string(meta.estimate_id(use)),'status','insufficient_trials','fc',[]);
    for field={'source_id','method','variant','units','estimate_unit'}
        if ismember(field{1},meta.Properties.VariableNames)&&numel(unique(string(meta.(field{1})(use))))>1,error('cog:BetaSource','Select one compatible source/estimation unit per run; no duplicated LSA/LSS samples');end
    end
    if nnz(use)>=minTrials,r.fc=cog.fc(beta(use,:),estimator);r.status='complete';end
    results{k}=r;
end
end
