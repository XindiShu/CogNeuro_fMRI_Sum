function audit=glmsingle_design_check(plan,confounds,cfg)
%GLMSINGLE_DESIGN_CHECK 原生每个候选HRF的单事件列，联合多项式/混杂检查可估性。
hrfs=getcanonicalhrf(plan.stimdurSeconds,plan.trSeconds)';
if strcmp(cfg.hrf.type,'library'),hrfs=getcanonicalhrflibrary(plan.stimdurSeconds,plan.trSeconds)';end
audit=struct([]);
for r=1:numel(plan.design)
    n=size(plan.design{r},1);degree=cfg.glmsingle.maxPolyDegree;
    if isempty(degree),degree=round(n*plan.trSeconds/60/2);end
    if degree>=n,error('psy:GLMsingleDF','Polynomial degree is too large');end
    polynomial=constructpolynomialmatrix(n,0:degree);nuisance=[polynomial confounds{r}];
    selected=plan.mapping.run_index==r;frames=plan.mapping.frame_index(selected);
    stimulus=zeros(n,numel(frames));stimulus(sub2ind(size(stimulus),frames,(1:numel(frames))'))=1;
    ranks=zeros(1,size(hrfs,2));
    for h=1:size(hrfs,2)
        task=conv2(stimulus,hrfs(:,h));task=task(1:n,:);
        full=[task nuisance];ranks(h)=rank(full);
        if ranks(h)-rank(nuisance)~=numel(frames)||n-ranks(h)<cfg.minResidualDF
            error('psy:GLMsingleDF','Run %d has nonestimable trials/insufficient residual dimensions for candidate HRF %d',r,h);
        end
    end
    if cfg.glmsingle.wantDenoise&&n-max(ranks)-cfg.glmsingle.maxPCs<cfg.minResidualDF
        error('psy:GLMsingleDF','Run %d has insufficient dimensions for requested maximum PC count',r);
    end
    row=struct('runIndex',r,'nFrames',n,'nTrials',numel(frames),'polynomialDegree',degree, ...
        'nuisanceRank',rank(nuisance),'candidateHrfRanks',ranks,'minimumResidualDimensions',n-max(ranks));
    if isempty(audit),audit=row;else,audit(r)=row;end
end
end
