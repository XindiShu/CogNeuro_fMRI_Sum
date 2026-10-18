function status=glm_run(run,cfg,out,model)
%GLM_RUN SPM一级计算层；每个run独立session，跨run对比等权平均。
if isfield(cfg,'engine')&&~strcmp(cfg.engine,'spm_classical'),error('psy:GLMEngine','Use glmsingle_run for the GLMsingle engine');end
previousDirectory=pwd;restoreDirectory=onCleanup(@()cd(previousDirectory));
out=char(java.io.File(out).getCanonicalPath());
if isfolder(out)||isfile(out),error('psy:GLMExists','Choose a new model directory');end
if ~ismember(cfg.serialCorrelation,{'FAST','AR(1)'})||~isscalar(cfg.highpassSeconds)||~isfinite(cfg.highpassSeconds)||cfg.highpassSeconds<=0
    error('psy:GLMConfig','Invalid serial model or highpass');
end
if ~isnumeric(cfg.maskThreshold)||~isscalar(cfg.maskThreshold)||~isfinite(cfg.maskThreshold)||cfg.maskThreshold<0||cfg.maskThreshold>1
    error('psy:GLMConfig','maskThreshold must be in [0,1]');
end
if cfg.microtimeResolution<1||fix(cfg.microtimeResolution)~=cfg.microtimeResolution||cfg.microtimeOnset<1||cfg.microtimeOnset>cfg.microtimeResolution||fix(cfg.microtimeOnset)~=cfg.microtimeOnset
    error('psy:GLMConfig','Invalid microtime resolution/onset');
end
if numel(cfg.contrastNames)~=size(cfg.contrastWeights,1),error('psy:GLMContrast','One name per contrast required');end
bases=struct('hrf',struct('derivs',[0 0]));
if isfield(cfg,'hrf')
    if isfield(cfg.hrf,'fir'),bases=psy.glm_basis(cfg.hrf.type,cfg.hrf.fir);else,bases=psy.glm_basis(cfg.hrf.type);end
end
s=struct;s.dir={out};design=cell(1,numel(run));masks={};nFrames=zeros(1,numel(run));
for session=1:numel(run)
    r=run(session);
    if ~strcmp(r.temporal_state,'unfiltered_unregressed'),error('psy:GLMState','Do not use pre-regressed/filtered residual images');end
    v=spm_vol(r.bold);h=niftiinfo(r.bold);n=numel(v);
    if numel(h.PixelDimensions)<4,error('psy:GLMTR','A 4-D BOLD with time spacing is required');end
    tr=h.PixelDimensions(4);
    switch lower(h.TimeUnits)
        case 'second'
        case 'millisecond',tr=tr/1000;
        case 'microsecond',tr=tr/1e6;
        otherwise,error('psy:TimeUnits','Unknown time units');
    end
    if ~isfinite(tr)||tr<=0||n<3,error('psy:GLMTR','Invalid series/TR');end
    if session==1,reference=v(1);referenceTR=tr;end
    if abs(tr-referenceTR)>1e-6,error('psy:GLMTR','SPM multi-session model requires the same TR');end
    if isfield(bases,'fir')
        ticks=bases.fir.length/bases.fir.order/(tr/cfg.microtimeResolution);
        if ticks<1||abs(ticks-round(ticks))>1e-6*max(1,ticks)
            error('psy:GLMFIRGrid','FIR bin width must be an integer multiple of TR/microtimeResolution; no silent rounding');
        end
    end
    for k=1:n
        if ~isequal(v(k).dim,reference.dim)||max(abs(v(k).mat-reference.mat),[],'all')>1e-5
            error('psy:GLMGrid','All frames/runs must share geometry; no automatic resampling');
        end
    end
    if nargin<4
        conditions=psy.glm_events(r.events,n*tr,cfg.conditions);
    else
        conditions=model(session).conditions;
    end
    design{session}=psy.confound_design(r.confounds,cfg.design);
    d=design{session};if d.nFrames~=n,error('psy:GLMLength','Confounds/BOLD length mismatch');end
    maskFile='';if isfield(cfg,'explicitMask'),maskFile=cfg.explicitMask;end
    if isfield(r,'mask')&&~isempty(r.mask),maskFile=r.mask;end
    if ~isempty(maskFile)
        mv=spm_vol(maskFile);
        if ~isscalar(mv)||~isequal(mv.dim,reference.dim)||max(abs(mv.mat-reference.mat),[],'all')>1e-5
            error('psy:GLMMask','Explicit mask must match BOLD geometry; no automatic resampling');
        end
        values=spm_read_vols(mv);
        if any(~isfinite(values(:))|values(:)<0)||~any(values(:)>0),error('psy:GLMMask','Mask must be finite, nonnegative and nonempty');end
        masks{end+1,1}=maskFile; %#ok<AGROW>
    end
    scans=arrayfun(@(k)sprintf('%s,%d',r.bold,k),(1:n)','UniformOutput',false);
    sess=struct('scans',{scans},'cond',conditions,'multi',{{''}}, ...
        'regress',struct('name',{},'val',{}),'multi_reg',{{''}},'hpf',cfg.highpassSeconds);
    for k=2:size(d.matrix,2) % SPM每session自带截距，不重复传入。
        sess.regress(k-1)=struct('name',d.names{k},'val',d.matrix(:,k));
    end
    s.sess(session)=sess;nFrames(session)=n;
end
if isempty(masks),masks={''};else,masks=unique(masks,'stable');end
s.timing=struct('units','secs','RT',referenceTR,'fmri_t',cfg.microtimeResolution,'fmri_t0',cfg.microtimeOnset);
s.fact=struct('name',{},'levels',{});s.bases=bases;s.volt=1;
s.global='None';s.mthresh=cfg.maskThreshold;s.mask=masks;s.cvi=cfg.serialCorrelation;
mkdir(out);b={};b{1}.spm.stats.fmri_spec=s;save(fullfile(out,'specification.mat'),'b','run','cfg','design');
status='glm_prepared_not_estimated';if ~cfg.execute,return;end
psy.spm_step(b,fullfile(out,'01_specify.mat'));
p=load(fullfile(out,'SPM.mat'));SPM=p.SPM;x=spm_filter(SPM.xX.K,SPM.xX.X);
filterRank=psy.glm_highpass_rank(SPM.xX.K);
% 每个run先单独检查自由度和可估性，防止其他run掩盖局部不足。
for j=1:numel(run)
    rows=SPM.Sess(j).row;cols=[SPM.Sess(j).col SPM.xX.iB(j)];
    localNames=strrep(SPM.xX.name(cols),sprintf('Sn(%d) ',j),'Sn(1) ');
    psy.glm_model_contrasts(localNames,cfg,x(rows,cols), ...
        cfg.minResidualDF+rank(SPM.xX.K(j).X0));
end
contrasts=psy.glm_model_contrasts(SPM.xX.name,cfg,x, ...
    cfg.minResidualDF*numel(run)+filterRank,numel(run));
weights=vertcat(contrasts(strcmp({contrasts.stat},'T')).weights);
audit=struct('nFrames',sum(nFrames),'framesPerRun',nFrames,'nRuns',numel(run), ...
    'runWeights',ones(1,numel(run))/numel(run),'filteredDesignRank',rank(x), ...
    'filterRank',filterRank,'remainingDimensions',sum(nFrames)-rank(x)-filterRank,'columns',{SPM.xX.name});
save(fullfile(out,'design_audit.mat'),'audit','weights','contrasts');
save(fullfile(out,'model_contrasts.mat'),'contrasts');
contrastTable=psy.glm_contrast_table(contrasts,out,false);
writetable(contrastTable,fullfile(out,'contrast_mapping.tsv'),'FileType','text','Delimiter','\t');
if isfield(bases,'fir')
    bin=(1:bases.fir.order)';width=size(SPM.xBF.bf,1)/bases.fir.order*SPM.xBF.dt;
    start_seconds=(bin-1)*width;end_seconds=bin*width;
    writetable(table(bin,start_seconds,end_seconds),fullfile(out,'fir_time_bins.tsv'),'FileType','text','Delimiter','\t');
end
if nargin>=4,psy.glm_diagnostics(out,cfg,false);end
b={};b{1}.spm.stats.fmri_est.spmmat={fullfile(out,'SPM.mat')};
b{1}.spm.stats.fmri_est.write_residuals=0;b{1}.spm.stats.fmri_est.method.Classical=1;
psy.spm_step(b,fullfile(out,'02_estimate.mat'));
b={};b{1}.spm.stats.con.spmmat={fullfile(out,'SPM.mat')};
for k=1:numel(contrasts)
    field='tcon';if strcmp(contrasts(k).stat,'F'),field='fcon';end
    b{1}.spm.stats.con.consess{k}.(field)=struct('name',contrasts(k).name,'weights',contrasts(k).weights,'sessrep','none');
end
b{1}.spm.stats.con.delete=0;psy.spm_step(b,fullfile(out,'03_contrasts.mat'));
p=load(fullfile(out,'SPM.mat'),'SPM');
if numel(p.SPM.xCon)~=numel(contrasts)||~isequal({p.SPM.xCon.name},{contrasts.name})||~isequal({p.SPM.xCon.STAT},{contrasts.stat})
    error('psy:GLMContrast','SPM did not produce exactly the requested T/F contrast catalog');
end
status='run_glm_estimated_spatial_limitations_unchanged';qc=psy.verify_glm(out);
if nargin>=4,psy.glm_diagnostics(out,cfg,true);end
contrastTable=psy.glm_contrast_table(contrasts,out,true);
writetable(contrastTable,fullfile(out,'contrast_mapping.tsv'),'FileType','text','Delimiter','\t');
save(fullfile(out,'COMPLETE.mat'),'status','run','cfg','weights','qc');
end
