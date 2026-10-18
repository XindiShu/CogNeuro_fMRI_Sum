function report=validate_glm_outputs_engineering(outputRoot,reuse)
%VALIDATE_GLM_OUTPUTS_ENGINEERING 合成示例贯通结果导出/统一beta/ROI；可复用成功源模型。
root=fileparts(fileparts(mfilename('fullpath')));oldPath=path;oldRng=rng;oldDirectory=pwd;
restore=onCleanup(@()restoreState(oldPath,oldRng,oldDirectory));addpath(root,fullfile(root,'matlab'),fullfile(root,'config'),fullfile(root,'examples'));
if nargin<1,outputRoot=fullfile(tempdir,['glm_outputs_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);end
if nargin<2,reuse=struct('groupRoot','','glmsingleRoot','');end
outputRoot=psy.glm_absolute_path(outputRoot);if isfile(outputRoot)||isfolder(outputRoot),error('psy:GLMExists','Use a new example root');end
mkdir(outputRoot);groupRoot=reuse.groupRoot;gsRoot=reuse.glmsingleRoot;
if isempty(groupRoot),groupRoot=fullfile(outputRoot,'synthetic_groups');validate_glm_group_engineering(groupRoot);end
if isempty(gsRoot),gsRoot=fullfile(outputRoot,'synthetic_glmsingle');validate_glmsingle_engineering(gsRoot,'slow');end
cfg=glm_config;addpath(cfg.spmPath);
% 前面的示例会恢复路径；SPM的persistent初始化状态不代表matlabbatch仍在路径中。
spm('defaults','fmri');spm_jobman('initcfg');
p=load(fullfile(gsRoot,'SYNTHETIC_VALIDATION_COMPLETE.mat')); %#ok<NASGU>
run=struct('subject','synthetic','session','','name','run01','temporal_state','unfiltered_unregressed', ...
    'bold',fullfile(gsRoot,'run_01','bold.nii'),'events',fullfile(gsRoot,'run_01','events.tsv'), ...
    'confounds',fullfile(gsRoot,'run_01','confounds.tsv'),'mask',fullfile(gsRoot,'mask.nii'));
cfg.execute=true;cfg.continueOnError=false;cfg.conditions={'A','B'};cfg.model.unit='event';cfg.model.targetConditions={'A'};
cfg.hrf.type='canonical';cfg.design.motionModel='none';cfg.design.includeTissueMeans=false;cfg.design.linearTrend=false;cfg.serialCorrelation='AR(1)';cfg.qc.plot=false;
if isfield(reuse,'frameworkRoot')&&~isempty(reuse.frameworkRoot)
    % [可调] 指向已有成功framework_lsa/framework_lss的父目录，复用模型而不重复估计。
    lsa=fullfile(reuse.frameworkRoot,'framework_lsa');lss=fullfile(reuse.frameworkRoot,'framework_lss');
    assert(isfile(fullfile(lsa,'GLM_FRAMEWORK_COMPLETE.mat'))&&isfile(fullfile(lss,'GLM_FRAMEWORK_COMPLETE.mat')),'Successful framework sources required');
else
    lsa=fullfile(outputRoot,'framework_lsa');lss=fullfile(outputRoot,'framework_lss');
    psy.glm_framework_run(run,cfg,lsa);cfg.fit.strategy='lss';psy.glm_framework_run(run,cfg,lss);
end
model=fullfile(groupRoot,'two_sample','contrast_001');id="synthetic_group";spm_mat=string(fullfile(model,'SPM.mat'));contrast_index=1;
resultsManifest=fullfile(outputRoot,'results.tsv');writetable(table(id,spm_mat,contrast_index),resultsManifest,'FileType','text','Delimiter','\t');
id=["framework_lsa";"framework_lss";"gs_C";"gs_D"];engine=["framework";"framework";"glmsingle";"glmsingle"];
gs=string(fullfile(gsRoot,'models','sub-synthetic','combined'));source_dir=[string(lsa);string(lss);gs;gs];variant=["auto";"auto";"C";"D"];
betaManifest=fullfile(outputRoot,'beta_sources.tsv');writetable(table(id,engine,source_dir,variant),betaManifest,'FileType','text','Delimiter','\t');
roiFile=fullfile(outputRoot,'beta_roi.nii');m=spm_read_vols(spm_vol(fullfile(gsRoot,'mask.nii')));m(4:end,:,:)=0;
writeLike(fullfile(gsRoot,'mask.nii'),roiFile,m);roi="synthetic_half_grid";mask_file=string(roiFile);label=0;
roiManifest=fullfile(outputRoot,'rois.tsv');writetable(table(roi,mask_file,label),roiManifest,'FileType','text','Delimiter','\t');
c=glm_outputs_config;c.mode='betas';c.outputRoot=fullfile(outputRoot,'unified_betas');c.betas.manifestFile=betaManifest;c.betas.roiManifestFile=roiManifest;
report.betas=run_glm_outputs(c);report.results=cell(1,3);
groupRoi=fullfile(outputRoot,'group_roi.nii');writeLike(fullfile(model,'mask.nii'),groupRoi,spm_read_vols(spm_vol(fullfile(model,'mask.nii'))));
mask_file=string(groupRoi);roi="synthetic_group_grid";groupRoiManifest=fullfile(outputRoot,'group_rois.tsv');
writetable(table(roi,mask_file,label),groupRoiManifest,'FileType','text','Delimiter','\t');
for k=1:3
    methods={'none','fwe','fdr'};c=glm_outputs_config;c.mode='results';c.results.manifestFile=resultsManifest;
    c.results.correction=methods{k};c.results.tail='two_sided';c.results.roiManifestFile=groupRoiManifest;c.outputRoot=fullfile(outputRoot,['results_' methods{k}]);
    report.results{k}=run_glm_outputs(c);
end
save(fullfile(outputRoot,'GLM_OUTPUTS_ENGINEERING_COMPLETE.mat'),'report','reuse');clear restore;
end
function writeLike(reference,file,data)
v=spm_vol(reference);v.fname=file;v.dt=[16 0];v.pinfo=[1;0;0];spm_write_vol(v,data);
end
function restoreState(oldPath,oldRng,oldDirectory)
path(oldPath);rng(oldRng);cd(oldDirectory);
end
