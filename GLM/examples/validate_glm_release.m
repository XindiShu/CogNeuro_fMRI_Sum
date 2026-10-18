function report=validate_glm_release(outputRoot,spmPath)
%VALIDATE_GLM_RELEASE 从当前发布包运行全合成验收；结果写在包外，不读取HCP。
% [可调] outputRoot为不存在的新目录；spmPath为SPM12安装目录，空时按当前路径查找。
oldPath=path;oldDirectory=pwd;oldRng=rng;
restore=onCleanup(@()restoreState(oldPath,oldDirectory,oldRng));
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1||isempty(outputRoot)
    outputRoot=fullfile(tempdir,['glm_release_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
end
if nargin<2||isempty(spmPath),spmPath=fileparts(which('spm'));end
if ~isfile(fullfile(spmPath,'spm.m')),error('psy:SPMPath','Provide an installed SPM path');end
addpath(root,fullfile(root,'matlab'),fullfile(root,'config'),fullfile(root,'examples'),spmPath);
outputRoot=psy.glm_absolute_path(outputRoot);
if strcmpi(outputRoot,root)||startsWith(lower(outputRoot),lower([root filesep]))
    error('psy:GLMReleaseOutput','Keep validation outputs outside the clean package');
end
if isfile(outputRoot)||isfolder(outputRoot),error('psy:GLMExists','Use a new validation root');end
mkdir(outputRoot);
names=["glm_config";"glm_outputs_config";"run_glm_outputs"; ...
    "validate_glm_outputs_engineering";"validate_glm_group_engineering"; ...
    "validate_glmsingle_engineering";"psy.glm_batch";"psy.glm_framework_run"; ...
    "psy.glm_subject_run";"psy.glm_group_batch";"psy.glmsingle_run"; ...
    "psy.glm_results_export";"psy.glm_beta_catalog";"psy.glm_beta_read"];
resolved=resolveFunctions(names,root);
writetable(resolved,fullfile(outputRoot,'resolved_functions.tsv'),'FileType','text','Delimiter','\t');
packageFiles=dir(fullfile(root,'**','*'));packageFiles=packageFiles(~[packageFiles.isdir]);
paths=string(fullfile({packageFiles.folder},{packageFiles.name}))';
before=psy.glm_file_inventory(paths);
try
    % 复用现有可运行示例，生成小型合成二级、LSA/LSS、GLMsingle及只读后处理。
    demo=fullfile(outputRoot,'example');outputs=validate_glm_outputs_engineering(demo);
    cfg=glm_config;cfg.spmPath=spmPath;cfg.execute=true;cfg.continueOnError=false;
    cfg.engine='spm_classical';cfg.conditions={'A','B'};cfg.contrastNames={'A_minus_B'};cfg.contrastWeights=[1 -1];
    cfg.design.motionModel='none';cfg.design.includeTissueMeans=false;cfg.design.linearTrend=false;
    cfg.serialCorrelation='AR(1)';cfg.qc.plot=false;
    cfg.manifestFile=fullfile(demo,'synthetic_glmsingle','runs.tsv');
    cfg.outputRoot=fullfile(outputRoot,'condition_runs');cfg.level='run';runReport=psy.glm_batch(cfg);
    assert(numel(runReport)==2&&all(strcmp({runReport.status},'framework_models_estimated')));
    cfg.outputRoot=fullfile(outputRoot,'condition_subject');cfg.level='subject';subjectReport=psy.glm_batch(cfg);
    assert(isscalar(subjectReport)&&strcmp(subjectReport.status,'subject_models_estimated'));
    matrix=load(fullfile(demo,'unified_betas','betas','beta_matrix.mat'));
    assert(isequal(size(matrix.betaMatrix),[80 143])&&height(matrix.catalog)==80);
    maximumReadbackError=0;
    for k=1:height(matrix.catalog)
        headers=spm_vol(char(matrix.catalog.image_path(k)));
        data=spm_read_vols(headers(matrix.catalog.volume_index(k)));
        expected=single(data(matrix.space.linearIndices))';
        maximumReadbackError=max(maximumReadbackError,max(abs(double(matrix.betaMatrix(k,:))-double(expected))));
    end
    assert(maximumReadbackError==0,'Beta readback differs from source images');
    assert(isequal(resolved,resolveFunctions(names,root)),'Package function resolution changed');
    after=psy.glm_file_inventory(paths);assert(isequal(before,after),'Clean package files changed');
    writetable(before,fullfile(outputRoot,'package_hashes_before.tsv'),'FileType','text','Delimiter','\t');
    writetable(after,fullfile(outputRoot,'package_hashes_after.tsv'),'FileType','text','Delimiter','\t');
    report=struct('status','glm_release_example_complete','packageRoot',root,'outputRoot',outputRoot, ...
        'matlabVersion',version,'spmVersion',spm('Ver'),'spmPath',spmPath, ...
        'conditionRunModels',2,'conditionSubjectModels',1,'syntheticGroupDesigns',5, ...
        'lsaTargets',nnz(matrix.catalog.method=="LSA"),'lssTargets',nnz(matrix.catalog.method=="LSS"), ...
        'betaMatrixSize',size(matrix.betaMatrix),'maximumBetaReadbackError',maximumReadbackError, ...
        'source','fully synthetic; no HCP input or existing model re-estimation', ...
        'scope','packaged example and numeric readback; isolated-path execution must be checked by the caller');
    psy.glm_write_json(fullfile(outputRoot,'acceptance_summary.json'),report);
    save(fullfile(outputRoot,'GLM_RELEASE_EXAMPLE_COMPLETE.mat'),'report','outputs','runReport','subjectReport');
catch ex
    errorReport=getReport(ex,'extended','hyperlinks','off');save(fullfile(outputRoot,'GLM_RELEASE_EXAMPLE_FAILED.mat'),'errorReport');
    rethrow(ex);
end
clear restore;
end
function resolved=resolveFunctions(names,root)
paths=strings(size(names));
for k=1:numel(names)
    paths(k)=string(which(names(k)));
    assert(startsWith(lower(paths(k)),lower(string([root filesep]))),'Function resolved outside the current package');
end
resolved=table(names,paths,'VariableNames',{'function_name','path'});
end
function restoreState(oldPath,oldDirectory,oldRng)
path(oldPath);cd(oldDirectory);rng(oldRng);
end
