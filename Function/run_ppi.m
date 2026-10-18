function summary=run_ppi(cfg)
%RUN_PPI SPM神经层PPI/gPPI；私有模型和VOI，原模型仅供读取。
setup_function;if nargin<1,cfg=ppi_config;end
if ~isfile(cfg.spmMat)||~isfile(cfg.seedMask),error('cog:PPI','SPM model and seed mask required');end
loaded=load(cfg.spmMat,'SPM');SPM=loaded.SPM;source=fileparts(cfg.spmMat);s=cfg.sessionIndex;
if ~isscalar(s)||s~=fix(s)||s<1||s>numel(SPM.Sess)||~isfield(SPM.xX,'W')||~isfield(SPM,'Vbeta'),error('cog:PPI','Estimated model and valid session required');end
if ~ismember(cfg.mode,{'ppi','gppi'})||~ismember(cfg.serialCorrelation,{'FAST','AR(1)'})||~isscalar(cfg.highpassSeconds)||~isfinite(cfg.highpassSeconds)||cfg.highpassSeconds<=0,error('cog:PPI','Invalid settings');end
idx=cfg.conditionIndices;if isempty(idx),idx=1:numel(SPM.Sess(s).U);end
if isempty(idx)||any(idx<1|idx~=fix(idx)|idx>numel(SPM.Sess(s).U))||numel(unique(idx))~=numel(idx),error('cog:PPI','Invalid condition selection');end
if strcmp(cfg.mode,'ppi')&&(numel(cfg.psychologicalWeights)~=numel(idx)||any(~isfinite(cfg.psychologicalWeights))||~any(cfg.psychologicalWeights)),error('cog:PPI','Explicit psychological contrast required');end
seed=spm_vol(cfg.seedMask);cog.check_grid(seed,SPM.xY.VY(1));d=spm_read_vols(seed);if any(~isfinite(d(:))|d(:)<0)||~any(d(:)>0),error('cog:PPI','Invalid seed');end
summary=struct('execute',cfg.execute,'mode',cfg.mode,'sessionIndex',s,'nConditions',numel(idx),'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use a new output directory');end
mkdir(cfg.outputRoot);private=fullfile(cfg.outputRoot,'private_source');mkdir(private);modelDir=fullfile(cfg.outputRoot,'interaction_model');mkdir(modelDir);
old=pwd;cleanup=onCleanup(@()cd(old)); %#ok<NASGU>
for name={'Vbeta','VResMS','VM'}
    if isfield(SPM,name{1}),for k=1:numel(SPM.(name{1})),SPM.(name{1})(k).fname=cog.resolve_path(SPM.(name{1})(k).fname,source);end,end
end
for k=1:numel(SPM.xY.VY),SPM.xY.VY(k).fname=cog.resolve_path(SPM.xY.VY(k).fname,source);end
SPM.swd=private;SPM.pwd=private;cd(private);
targetMask=SPM.VM.fname;
if ~isempty(cfg.analysisMask)
    target=spm_vol(cfg.analysisMask);cog.check_grid(target,SPM.VM);a=spm_read_vols(target);original=spm_read_vols(SPM.VM);
    if any(~isfinite(a(:))|a(:)<0)||~any(a(:)>0)||any(a(:)>0&original(:)<=0),error('cog:PPIMask','Analysis mask must be a nonempty original mask subset');end
    targetMask=cfg.analysisMask;
end
task=[];for k=1:numel(SPM.Sess(s).Fc),task=[task SPM.Sess(s).col(SPM.Sess(s).Fc(k).i)];end %#ok<AGROW>
task=unique(task);if isempty(task),error('cog:PPI','No task effects for VOI adjustment');end
c=zeros(size(SPM.xX.X,2),numel(task));for k=1:numel(task),c(task(k),k)=1;end
SPM.xCon=spm_FcUtil('Set','effects_of_interest','F','c',c,SPM.xX.xKXs);SPM=spm_contrasts(SPM,1);save(fullfile(private,'SPM.mat'),'SPM');
job={};job{1}.spm.util.voi.spmmat={fullfile(private,'SPM.mat')};job{1}.spm.util.voi.adjust=1;job{1}.spm.util.voi.session=s;job{1}.spm.util.voi.name='seed';
job{1}.spm.util.voi.roi{1}.mask.image={cfg.seedMask};job{1}.spm.util.voi.roi{1}.mask.threshold=.5;job{1}.spm.util.voi.expression='i1';
spm_jobman('initcfg');spm_jobman('run',job);voi=load(fullfile(private,sprintf('VOI_seed_%d.mat',s)),'xY');
if strcmp(cfg.mode,'ppi'),groups={[idx(:),ones(numel(idx),1),cfg.psychologicalWeights(:)]};
else,groups=cell(numel(idx),1);for k=1:numel(idx),groups{k}=[idx(k),1,1];end,end
ppi=cell(numel(groups),1);for k=1:numel(groups),ppi{k}=spm_peb_ppi(SPM,'ppi',voi.xY,groups{k},sprintf('interaction_%03d',k),0);end
reg=[];names={};for k=1:numel(ppi),reg=[reg ppi{k}.ppi];names{end+1}=sprintf('PPI_%03d',k);end %#ok<AGROW>
nInteraction=size(reg,2);for k=1:numel(ppi),reg=[reg ppi{k}.P];names{end+1}=sprintf('PSY_%03d',k);end %#ok<AGROW>
reg=[reg ppi{1}.Y];names{end+1}='seed_BOLD';
if isfield(SPM.Sess(s),'C')&&~isempty(SPM.Sess(s).C.C),reg=[reg SPM.Sess(s).C.C];names=[names SPM.Sess(s).C.name(:)'];end
if any(~isfinite(reg),'all')||rank([reg ones(size(reg,1),1)])<size(reg,2)+1,error('cog:PPIRank','Interaction model is nonfinite/rank deficient');end
rows=SPM.Sess(s).row;scans=cell(numel(rows),1);for k=1:numel(rows),h=SPM.xY.VY(rows(k));scans{k}=sprintf('%s,%d',h.fname,h.n(1));end
job={};spec.dir={modelDir};spec.timing=struct('units','secs','RT',SPM.xY.RT,'fmri_t',SPM.xBF.T,'fmri_t0',SPM.xBF.T0);
spec.sess.scans=scans;spec.sess.cond=struct('name',{},'onset',{},'duration',{},'tmod',{},'pmod',{},'orth',{});
for k=1:size(reg,2),spec.sess.regress(k)=struct('name',names{k},'val',reg(:,k));end
spec.sess.multi={''};spec.sess.multi_reg={''};spec.sess.hpf=cfg.highpassSeconds;spec.fact=struct('name',{},'levels',{});spec.bases.hrf.derivs=[0 0];spec.volt=1;spec.global='None';spec.mthresh=-Inf;spec.mask={targetMask};spec.cvi=cfg.serialCorrelation;job{1}.spm.stats.fmri_spec=spec;
if cfg.estimate
    job{2}.spm.stats.fmri_est.spmmat={fullfile(modelDir,'SPM.mat')};job{2}.spm.stats.fmri_est.method.Classical=1;job{2}.spm.stats.fmri_est.write_residuals=0;
    job{3}.spm.stats.con.spmmat={fullfile(modelDir,'SPM.mat')};job{3}.spm.stats.con.delete=0;
    for k=1:nInteraction,w=zeros(1,size(reg,2));w(k)=1;job{3}.spm.stats.con.consess{k}.tcon=struct('name',names{k},'weights',w,'sessrep','none');end
end
save(fullfile(cfg.outputRoot,'ppi_job.mat'),'job','cfg','ppi','reg','names');spm_jobman('run',job);
summary.status='prepared';if cfg.estimate,summary.status='estimated';end
summary.nInteractions=nInteraction;summary.backend='SPM spm_peb_ppi neural deconvolution';summary.sourceModel=cfg.spmMat;
if cfg.estimate,summary.qc=cog.verify_spm_model(fullfile(modelDir,'SPM.mat'));end
cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);if cfg.estimate,save(fullfile(cfg.outputRoot,'PPI_COMPLETE.mat'),'summary');end
end
