function summary=run_dcm_group(cfg)
%RUN_DCM_GROUP 以独立被试为行；不将多个run或模型当成额外被试。
setup_function;if nargin<1,cfg=dcm_group_config;end
t=cog.read_tsv(cfg.manifestFile,[{'subject','dcm_file'},cfg.covariateColumns]);base=fileparts(cfg.manifestFile);
if height(t)<3||numel(unique(t.subject))~=height(t)||any(t.subject==""),error('cog:DCMGroup','Need >=3 unique subject rows; not a scientific sample-size recommendation');end
x=ones(height(t),1);for k=1:numel(cfg.covariateColumns),a=str2double(t.(cfg.covariateColumns{k}));if any(~isfinite(a)),error('cog:DCMGroup','Finite covariates required');end;x=[x a-mean(a)];end %#ok<AGROW>
if rank(x)<size(x,2)||size(x,1)<=size(x,2)||isempty(cfg.fields)||~iscellstr(cfg.fields)||~isscalar(cfg.maxIterations)||~isfinite(cfg.maxIterations)||cfg.maxIterations<1||cfg.maxIterations~=fix(cfg.maxIterations),error('cog:DCMGroup','Invalid/full-rank group design or options');end
if ~isempty(cfg.modelMasks)&&(~ismatrix(cfg.modelMasks)||~isreal(cfg.modelMasks)||any(~isfinite(cfg.modelMasks),'all')||any(cfg.modelMasks~=0&cfg.modelMasks~=1,'all')),error('cog:DCMGroup','Binary candidate-model matrix required');end
GCM=cell(height(t),1);for k=1:height(t)
    t.dcm_file(k)=string(cog.resolve_path(t.dcm_file(k),base));s=load(t.dcm_file(k),'DCM');GCM{k}=s.DCM;cog.dcm_check(GCM{k});
    if ~all(isfield(GCM{k}.Ep,cfg.fields)),error('cog:DCMGroup','Requested parameter field missing');end
    if k>1&&(~isequal(GCM{k}.a,GCM{1}.a)||~isequal(GCM{k}.b,GCM{1}.b)||~isequal(GCM{k}.c,GCM{1}.c)||~isequal(GCM{k}.Y.name,GCM{1}.Y.name)||~isequal(size(GCM{k}.Cp),size(GCM{1}.Cp))),error('cog:DCMGroup','Nodes/order/model masks must agree across independent subjects');end
end
if numel(unique(lower(t.dcm_file)))~=height(t),error('cog:DCMGroup','Same fitted file cannot represent multiple subjects');end
summary=struct('execute',cfg.execute,'nSubjects',height(t),'nRegressors',size(x,2),'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use new group output directory');end;mkdir(cfg.outputRoot);old=pwd;cleanup=onCleanup(@()cd(old));cd(cfg.outputRoot); %#ok<NASGU>
M=struct('X',x,'Xnames',{{'intercept',cfg.covariateColumns{:}}},'Q','single','maxit',cfg.maxIterations);
[PEB,empiricalDCMs]=spm_dcm_peb(GCM,M,cfg.fields);if ~isfinite(PEB.F)||any(~isfinite(PEB.Ep),'all')||any(~isfinite(PEB.Cp),'all'),error('cog:DCMGroup','Nonfinite PEB posterior');end
save(fullfile(cfg.outputRoot,'PEB.mat'),'PEB','empiricalDCMs','cfg','t','x');summary.status='estimated';summary.freeEnergy=PEB.F;
if cfg.reduceAndAverage
    if isempty(cfg.modelMasks),[BMA,BMR]=spm_dcm_peb_bmc(PEB);else
        if size(cfg.modelMasks,2)~=numel(PEB.Pnames),error('cog:DCMGroup','Candidate columns must match PEB.Pnames');end
        [BMA,BMR]=spm_dcm_peb_bmc(PEB,logical(cfg.modelMasks));
    end
    if any(~isfinite(BMA.Ep),'all')||any(~isfinite(BMA.Cp),'all'),error('cog:DCMGroup','Nonfinite BMA posterior');end
    save(fullfile(cfg.outputRoot,'BMA_BMR.mat'),'BMA','BMR');summary.reductionAndAverage=true;
else,summary.reductionAndAverage=false;end
cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'DCM_GROUP_COMPLETE.mat'),'summary');
end
