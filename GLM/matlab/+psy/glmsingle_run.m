function summary=glmsingle_run(runs,cfg,out)
%GLMSINGLE_RUN 固定版本官方GLMsingle；掩膜内原时序，禁止静默改设计或降级。
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.engine,'glmsingle')||isempty(runs),error('psy:GLMsingleConfig','GLMsingle and nonempty runs required');end
oldPath=path;oldDirectory=pwd;oldRng=rng;
restore=onCleanup(@()restoreState(oldPath,oldDirectory,oldRng));
out=char(java.io.File(out).getCanonicalPath());
if isfolder(out)||isfile(out),error('psy:GLMExists','Choose a new GLMsingle output directory');end
if numel(unique(lower(string({runs.subject}))))~=1,error('psy:GLMSubject','Different subjects cannot be one GLMsingle dataset');end
if ~cfg.subject.combineSessions&&numel(unique(string({runs.session})))~=1,error('psy:GLMSubject','Different sessions require combineSessions=true');end
keys=lower(string({runs.session})+"/"+string({runs.name}));
boldPaths=arrayfun(@(r)string(char(java.io.File(r.bold).getCanonicalPath())),runs);
if numel(unique(keys))~=numel(runs)||numel(unique(lower(boldPaths)))~=numel(runs),error('psy:DuplicateRun','Repeated run identity/BOLD file');end
volumes=cell(1,numel(runs));nFrames=zeros(1,numel(runs));trs=nFrames;mask=[];reference=[];confounds=cell(size(volumes));
inputs=struct([]);
for r=1:numel(runs)
    run=runs(r);if ~strcmp(run.temporal_state,'unfiltered_unregressed'),error('psy:GLMState','GLMsingle requires unfiltered/unregressed input');end
    v=spm_vol(run.bold);h=niftiinfo(run.bold);
    if numel(h.PixelDimensions)<4,error('psy:GLMTR','4-D BOLD required');end
    tr=h.PixelDimensions(4);
    switch lower(h.TimeUnits)
        case 'second'
        case 'millisecond',tr=tr/1000;
        case 'microsecond',tr=tr/1e6;
        otherwise,error('psy:TimeUnits','Unknown BOLD time unit');
    end
    if ~isfinite(tr)||tr<=0||numel(v)<3,error('psy:GLMTR','Invalid TR/frame count');end
    if isempty(reference),reference=v(1);mask=true(reference.dim);end
    if r>1&&abs(tr-trs(1))>1e-6,error('psy:GLMTR','GLMsingle requires common TR');end
    for f=1:numel(v),checkGrid(v(f),reference);end
    maskFile=cfg.explicitMask;if isfield(run,'mask')&&~isempty(run.mask),maskFile=run.mask;end
    if isempty(maskFile),error('psy:GLMsingleMask','Provide an explicit coverage/analysis mask for every run');end
    mv=spm_vol(maskFile);checkGrid(mv,reference);m=spm_read_vols(mv);
    if any(~isfinite(m(:))|m(:)<0)||~any(m(:)>0),error('psy:GLMsingleMask','Invalid analysis mask');end
    mask=mask&m>0;
    d=psy.confound_design(run.confounds,cfg.design);
    if d.nFrames~=numel(v),error('psy:GLMLength','Confounds/BOLD frame mismatch');end
    confounds{r}=d.matrix(:,2:end);volumes{r}=v;nFrames(r)=numel(v);trs(r)=tr;
    for role={'bold','events','confounds','mask'}
        file=maskFile;if ~strcmp(role{1},'mask'),file=run.(role{1});end
        entry=dir(file);row=struct('run_index',r,'role',role{1},'path',file,'bytes',entry.bytes);
        if isempty(inputs),inputs=row;else,inputs(end+1)=row;end %#ok<AGROW>
    end
end
if ~any(mask(:)),error('psy:GLMsingleMask','Empty mask intersection');end
plan=psy.glmsingle_plan({runs.events},nFrames,trs(1),cfg);
inputGiB=nnz(mask)*sum(nFrames)*4/2^30;
if inputGiB>cfg.glmsingle.maxInputGiB,plan.issues(end+1)="masked input data exceed maxInputGiB";plan.ready=false;end
mkdir(out);save(fullfile(out,'preflight.mat'),'plan','cfg','runs','nFrames','trs','inputGiB');
writetable(plan.mapping,fullfile(out,'event_mapping.tsv'),'FileType','text','Delimiter','\t');
writetable(plan.identities,fullfile(out,'identity_mapping.tsv'),'FileType','text','Delimiter','\t');
writetable(struct2table(inputs),fullfile(out,'input_files.tsv'),'FileType','text','Delimiter','\t');
summary=struct('status','glmsingle_prepared_not_estimated','ready',plan.ready,'issues',plan.issues, ...
    'nEvents',plan.nEvents,'nUnits',plan.nEvents,'nModels',2+double(cfg.glmsingle.wantDenoise)+double(cfg.glmsingle.wantRidge), ...
    'nRuns',numel(runs),'nFrames',sum(nFrames),'nIdentities',plan.nIdentities, ...
    'repeatedAcrossRuns',plan.repeatedAcrossRuns,'sharedIdentitiesPerFold',plan.sharedIdentitiesPerFold, ...
    'inputGiB',inputGiB,'maskedVoxels',nnz(mask),'temporalModel','native run-wise polynomials; no SPM FAST/AR/highpass');
if ~plan.ready
    summary.status='glmsingle_blocked_not_estimated';writeJson(fullfile(out,'summary.json'),summary);
    save(fullfile(out,'GLMSINGLE_BLOCKED.mat'),'summary');
    if cfg.execute,error('psy:GLMsingleNotReady','%s',strjoin(plan.issues,'; '));end
    return;
end
dependency=psy.glmsingle_dependency(cfg.glmsingle.path);
designAudit=psy.glmsingle_design_check(plan,confounds,cfg);
save(fullfile(out,'design_audit.mat'),'designAudit','dependency');
if ~cfg.execute
    writeJson(fullfile(out,'summary.json'),summary);save(fullfile(out,'GLMSINGLE_PREPARED.mat'),'summary');return;
end
if cfg.glmsingle.wantDenoise&&(isempty(cfg.glmsingle.noiseR2Threshold)||isempty(cfg.glmsingle.pcR2Threshold))&&exist('fitgmdist','file')~=2
    error('psy:GLMsingleDependency','Automatic R2 thresholds require Statistics and Machine Learning Toolbox fitgmdist');
end
data=cell(size(volumes));
for r=1:numel(runs)
    data{r}=zeros(nnz(mask),nFrames(r),'single');zeroCount=zeros(nnz(mask),1);
    for f=1:nFrames(r)
        frame=spm_read_vols(volumes{r}(f));values=frame(mask);
        if any(~isfinite(values)),error('psy:GLMsingleData','Nonfinite values inside explicit coverage mask');end
        data{r}(:,f)=single(values);zeroCount=zeroCount+(values==0);
    end
    if any(zeroCount>0),error('psy:GLMsingleData','Zero-coded/partial coverage inside mask; provide a verified full-coverage mask');end
end
globalMean=zeros(nnz(mask),1);
for r=1:numel(data),globalMean=globalMean+sum(data{r},2,'double');end
globalMean=globalMean/sum(nFrames);
if any(~isfinite(globalMean)|globalMean<=0),error('psy:GLMsingleData','Positive preserved baseline required; do not supply centered residuals');end
g=cfg.glmsingle;
opt=struct('wantlibrary',double(strcmp(cfg.hrf.type,'library')),'wantglmdenoise',double(g.wantDenoise), ...
    'wantfracridge',double(g.wantRidge),'wantfileoutputs',[0 0 0 0], ...
    'wantmemoryoutputs',[1 1 double(g.wantDenoise) double(g.wantRidge)], ...
    'chunknum',g.chunkVoxels,'extraregressors',{confounds},'wantpercentbold',double(g.wantPercentBold), ...
    'numpcstotry',g.maxPCs,'fracs',g.fracs,'pcstop',1.05,'brainR2',g.noiseR2Threshold, ...
    'pcR2cutoff',g.pcR2Threshold,'wantlss',0,'xvalscheme',{num2cell(1:numel(runs))});
opt.maxpolydeg=[designAudit.polynomialDegree];
[~,~,sessionIndex]=unique(string({runs.session}),'stable');opt.sessionindicator=sessionIndex;
save(fullfile(out,'native_call.mat'),'opt','cfg','dependency');rng(g.randomSeed,'twister');
% NaN输出目录 + 全关闭原生文件写入，绕开官方函数清空既有输出目录的行为。
[results,resultsdesign]=GLMestimatesingletrial(plan.design,data,plan.stimdurSeconds,plan.trSeconds,NaN,opt);
clear data;
if resultsdesign.opt.wantglmdenoise~=double(g.wantDenoise)||resultsdesign.opt.wantfracridge~=double(g.wantRidge)|| ...
        ~isequal(double(resultsdesign.stimorder(:)),double(plan.mapping.identity_index))|| ...
        ~isequal(double(resultsdesign.numtrialrun(:)),double(accumarray(plan.mapping.run_index,1)))
    error('psy:GLMsingleNativeMismatch','Native model flags/event mapping changed; no completion marker');
end
for r=1:numel(runs)
    if ~isequal(resultsdesign.design{r},plan.design{r}),error('psy:GLMsingleNativeMismatch','Native design was changed/truncated');end
end
save(fullfile(out,'native_results.mat'),'results','resultsdesign','-v7.3');
qc=psy.glmsingle_export(results,plan,mask,reference,out,cfg);
summary.status='glmsingle_models_estimated';summary.modelTypes=qc.modelTypes;
summary.units=qc.units;summary.pcnum=qc.pcnum;summary.nModels=numel(qc.modelTypes);
writeJson(fullfile(out,'summary.json'),summary);save(fullfile(out,'GLMSINGLE_COMPLETE.mat'),'summary','qc','cfg','dependency');
clear restore;
end

function checkGrid(v,reference)
if ~isscalar(v)||~isequal(v.dim,reference.dim)||max(abs(v.mat-reference.mat),[],'all')>1e-5
    error('psy:GLMGrid','All frames and masks must share geometry; no automatic resampling');
end
end
function writeJson(file,value)
f=fopen(file,'w');if f<0,error('psy:GLMOutput','Cannot write summary');end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value,PrettyPrint=true));clear cleanup;
end
function restoreState(oldPath,oldDirectory,oldRng)
path(oldPath);cd(oldDirectory);rng(oldRng);
end
