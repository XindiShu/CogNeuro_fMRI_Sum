function report=glm_group_batch(cfg)
%GLM_GROUP_BATCH 独立被试的二级GLM；配对差值、等方差两组、协变量回归。
cfg=psy.glm_framework_options(cfg);
if ~strcmp(cfg.level,'group'),error('psy:GLMLevel','Set level=group');end
if ~isfile(fullfile(cfg.spmPath,'spm.m')),error('psy:SPMPath','Set SPM path');end
% Java的user.dir不随MATLAB cd可靠改变，先按调用者pwd展开相对路径。
if ~java.io.File(cfg.manifestFile).isAbsolute(),cfg.manifestFile=fullfile(pwd,cfg.manifestFile);end
if ~java.io.File(cfg.outputRoot).isAbsolute(),cfg.outputRoot=fullfile(pwd,cfg.outputRoot);end
if isfolder(cfg.outputRoot)||isfile(cfg.outputRoot),error('psy:GLMExists','Choose a new output root');end
cfg.manifestFile=char(java.io.File(cfg.manifestFile).getCanonicalPath());
plans=psy.glm_group_plan(cfg); % 整批清单/配对/秩/协变量预检，禁止自动删人或伪造缺失值。
addpath(cfg.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
previous=pwd;restoreDirectory=onCleanup(@()cd(previous));
cfg.outputRoot=char(java.io.File(cfg.outputRoot).getCanonicalPath());
mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','plans');report=struct([]);
for k=1:numel(plans)
    p=plans(k);out=fullfile(cfg.outputRoot,sprintf('contrast_%03d',k));
    row=struct('contrast',p.effectLabel,'status','failed','nSubjects',p.nSubjects,'path',out,'message','');
    try
        runGroup(p,cfg,out);row.status='group_prepared_not_estimated';
        if cfg.execute,row.status=['group_' p.design '_estimated'];end
    catch ex
        row.message=ex.message;
    end
    if isempty(report),report=row;else,report(end+1)=row;end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    if strcmp(row.status,'failed')&&~cfg.continueOnError,error('psy:GLMFailed','%s',row.message);end
end
end

function runGroup(plan,cfg,out)
rows=plan.rows;reference=spm_vol(char(rows.contrast_image(1)));
if ~isscalar(reference),error('psy:GLMGroupGrid','Each effect must be one 3-D image');end
common=true(reference.dim);
for k=1:height(rows)
    v=spm_vol(char(rows.contrast_image(k)));m=spm_vol(char(rows.mask(k)));
    checkGrid(v,reference);checkGrid(m,reference);values=spm_read_vols(m);
    if any(~isfinite(values(:))|values(:)<0)||~any(values(:)>0),error('psy:GLMMask','Invalid subject mask');end
    values=values>0;data=spm_read_vols(v);
    if any(~isfinite(data(values))),error('psy:GLMGroupInput','Nonfinite effect inside source mask');end
    common=common&values;
end
if ~isempty(cfg.explicitMask)
    v=spm_vol(cfg.explicitMask);checkGrid(v,reference);m=spm_read_vols(v);
    if any(~isfinite(m(:))|m(:)<0),error('psy:GLMMask','Invalid global mask');end
    common=common&m>0;
end
if ~any(common(:)),error('psy:GLMMask','Empty coverage intersection');end
files=unique([string(cfg.manifestFile);rows.contrast_image;rows.mask;string(cfg.explicitMask)],'stable');files(strlength(files)==0)=[];
before=hashFiles(files);mkdir(out);maskFile=fullfile(out,'coverage_intersection.nii');
v=struct('fname',maskFile,'dim',reference.dim,'dt',[spm_type('uint8') spm_platform('bigend')], ...
    'mat',reference.mat,'pinfo',[1;0;0],'descrip','Intersection of all source effect masks');
spm_write_vol(v,double(common));
writetable(rows,fullfile(out,'subjects_used.tsv'),'FileType','text','Delimiter','\t');
writetable(array2table(plan.designMatrix,'VariableNames',plan.columnNames),fullfile(out,'design_matrix.tsv'),'FileType','text','Delimiter','\t');
contrasts=array2table(plan.contrastWeights,'VariableNames',plan.columnNames);
contrasts=addvars(contrasts,string(plan.contrastNames(:)),'Before',1,'NewVariableNames','contrast_name');
writetable(contrasts,fullfile(out,'contrasts.tsv'),'FileType','text','Delimiter','\t');
if ~isempty(plan.covariateAudit),writetable(plan.covariateAudit,fullfile(out,'covariate_values.tsv'),'FileType','text','Delimiter','\t');end
writetable(before,fullfile(out,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');
scans=cellstr(rows.contrast_image+",1");
if strcmp(plan.design,'paired')
    folder=fullfile(out,'paired_differences');mkdir(folder);scans=cell(plan.nSubjects,1);
    for k=1:plan.nSubjects
        a=spm_read_vols(spm_vol(char(rows.contrast_image(2*k-1))));
        b=spm_read_vols(spm_vol(char(rows.contrast_image(2*k))));
        image=NaN(reference.dim);image(common)=a(common)-b(common);
        v.dt=[16 0];v.fname=fullfile(folder,sprintf('difference_%04d.nii',k));v.descrip='Paired difference: configured level 1 minus level 2';
        spm_write_vol(v,image);scans{k}=[v.fname ',1'];
    end
    pairing=table(rows.subject(1:2:end),rows.contrast_image(1:2:end),rows.contrast_image(2:2:end),string(scans), ...
        'VariableNames',{'subject','level1_image','level2_image','difference_scan'});
    writetable(pairing,fullfile(out,'pairing.tsv'),'FileType','text','Delimiter','\t');
end
s=struct;s.dir={out};
switch plan.design
    case 'two_sample'
        n1=plan.sampleCounts(1);
        s.des.t2=struct('scans1',{scans(1:n1)},'scans2',{scans(n1+1:end)},'dept',0,'variance',0,'gmsca',0,'ancova',0);
    case 'regression'
        s.des.mreg=struct('scans',{scans},'mcov',struct('c',{},'cname',{},'iCC',{}),'incint',1);
    otherwise
        s.des.t1.scans=scans; % paired在各人的差值图上进行单样本t，与配对t等价。
end
s.cov=struct('c',{},'cname',{},'iCFI',{},'iCC',{});
for k=1:numel(cfg.group.covariateColumns)
    index=size(plan.designMatrix,2)-numel(cfg.group.covariateColumns)+k;
    s.cov(k)=struct('c',plan.designMatrix(:,index),'cname',cfg.group.covariateColumns{k},'iCFI',1,'iCC',5);
end
s.multi_cov=struct('files',{},'iCFI',{},'iCC',{});
s.masking=struct('tm',struct('tm_none',1),'im',0,'em',{{maskFile}});
s.globalc.g_omit=1;s.globalm.gmsca.gmsca_no=1;s.globalm.glonorm=1;
b={};b{1}.spm.stats.factorial_design=s;save(fullfile(out,'specification.mat'),'b','cfg','plan');
summary=struct('design',plan.design,'contrast',plan.effectLabel,'comparison',plan.comparison, ...
    'nSubjects',plan.nSubjects,'nInputImages',height(rows),'sampleCounts',plan.sampleCounts, ...
    'designRank',plan.rank,'residualDF',plan.residualDF,'coverageIntersectionVoxels',nnz(common), ...
    'covariates',{cfg.group.covariateColumns},'covariateCenter',cfg.group.covariateCenter, ...
    'varianceModel','independent equal-variance observations; paired uses within-subject differences', ...
    'inputRole','unthresholded effect images; no T/F maps or event beta pooling', ...
    'inferenceScope','unthresholded signed T maps; no FWE/FDR/cluster inference');
marker='GLM_GROUP_PREPARED.mat';
if cfg.execute
    psy.spm_step(b,fullfile(out,'01_specify.mat'));
    p=load(fullfile(out,'SPM.mat'),'SPM');actual=p.SPM.xX.X;
    if ~isequal(size(actual),size(plan.designMatrix))||max(abs(actual-plan.designMatrix),[],'all')>1e-9*max(1,max(abs(plan.designMatrix),[],'all'))
        error('psy:GLMGroupDesign','SPM design differs from the audited design');
    end
    b={};b{1}.spm.stats.fmri_est.spmmat={fullfile(out,'SPM.mat')};
    b{1}.spm.stats.fmri_est.write_residuals=0;b{1}.spm.stats.fmri_est.method.Classical=1;
    psy.spm_step(b,fullfile(out,'02_estimate.mat'));
    b={};b{1}.spm.stats.con.spmmat={fullfile(out,'SPM.mat')};
    for k=1:numel(plan.contrastNames)
        b{1}.spm.stats.con.consess{k}.tcon=struct('name',plan.contrastNames{k},'weights',plan.contrastWeights(k,:),'sessrep','none');
    end
    b{1}.spm.stats.con.delete=0;psy.spm_step(b,fullfile(out,'03_contrasts.mat'));
    qc=psy.verify_glm(out);save(fullfile(out,'verification.mat'),'qc');
    p=load(fullfile(out,'SPM.mat'),'SPM');summary.residualDF=p.SPM.xX.erdf;
    if abs(summary.residualDF-plan.residualDF)>1e-6,error('psy:GLMGroupDF','Unexpected equal-variance model residual DF');end
    marker='GLM_GROUP_COMPLETE.mat';
end
after=hashFiles(files);writetable(after,fullfile(out,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');
if ~isequal(before,after),error('psy:GLMGroupInput','Source inputs changed; no completion marker');end
summary.inputHashesUnchanged=height(before);
f=fopen(fullfile(out,'summary.json'),'w');if f<0,error('psy:GLMOutput','Cannot write summary');end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(summary,PrettyPrint=true));clear cleanup;
save(fullfile(out,marker),'summary','cfg','plan');
end
function checkGrid(v,reference)
if ~isscalar(v)||~isequal(v.dim,reference.dim)||max(abs(v.mat-reference.mat),[],'all')>1e-5
    error('psy:GLMGroupGrid','Effects and masks must share the same grid; no automatic resampling');
end
end
function t=hashFiles(files)
bytes=zeros(numel(files),1);sha256=strings(numel(files),1);
for k=1:numel(files),entry=dir(char(files(k)));bytes(k)=entry.bytes;sha256(k)=psy.file_sha256(char(files(k)));end
t=table(files,bytes,sha256,'VariableNames',{'path','bytes','sha256'});
end
