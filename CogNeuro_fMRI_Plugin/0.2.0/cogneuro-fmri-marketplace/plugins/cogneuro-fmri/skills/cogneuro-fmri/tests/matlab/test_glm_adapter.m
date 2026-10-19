function tests=test_glm_adapter
%TEST_GLM_ADAPTER 仅使用微型合成影像，实际调用 SPM；不读 HCP 数据。
tests=functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.oldPath=path;t.TestData.oldDirectory=pwd;
skill=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(skill,'matlab'));
toolkit=getenv('COGNEURO_GLM_TEST_TOOLKIT'); % [路径/约束] 必须显式指定完整 GLM 发布根目录。
spmRoot=getenv('COGNEURO_GLM_TEST_SPM'); % [路径] 可指定 SPM 安装根目录。
if isempty(spmRoot),spmRoot=fileparts(which('spm'));end
assumeTrue(t,~isempty(toolkit)&&isfile(fullfile(toolkit,'config','glm_config.m'))&&isfile(fullfile(spmRoot,'spm.m')), ...
    'Set COGNEURO_GLM_TEST_TOOLKIT and COGNEURO_GLM_TEST_SPM to run native integration tests');
t.TestData.toolkit=toolkit;t.TestData.spmRoot=spmRoot;
addpath(spmRoot);
end

function teardownOnce(t)
cd(t.TestData.oldDirectory);path(t.TestData.oldPath);
end

function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;n=96;
oldRng=rng;restore=onCleanup(@()rng(oldRng));rng(1817,'twister'); %#ok<NASGU>
% 明确植入与事件匹配的 canonical HRF 信号，使原生 SPM 非球形估计有
% 足够的 model-effects 体素；不改动 SPM 的 F 阈值或估计算法。
signal=taskSignal(n,2);
data=100+randn(4,4,4,n)+reshape(signal+sin((1:n)/7),1,1,1,n);
makeImage(fullfile(root,'bold.nii'),data,2,diag([2 2 2 1]));
makeImage(fullfile(root,'mask.nii'),ones(4,4,4),2,diag([2 2 2 1]));
onset=[4;20;36;52;68;84];duration=ones(6,1)*2;trial_type=["A";"B";"A";"B";"A";"B"];
writetable(table(onset,duration,trial_type),fullfile(root,'events.tsv'),'FileType','text','Delimiter','\t');
writetable(table((1:n)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'),'FileType','text','Delimiter','\t');
subject="pilot";session="baseline";run="task1";bold=string(fullfile(root,'bold.nii'));
events=string(fullfile(root,'events.tsv'));confounds=string(fullfile(root,'confounds.tsv'));
temporal_state="unfiltered_unregressed";mask=string(fullfile(root,'mask.nii'));
manifest=fullfile(root,'runs.tsv');
writetable(table(subject,session,run,bold,events,confounds,temporal_state,mask),manifest,'FileType','text','Delimiter','\t');
c=struct('motion_model','none','include_tissue_means',false,'linear_trend',false, ...
    'add_spikes',false,'fd_threshold_mm',0.5,'min_residual_df',10);
g=struct('highpass_seconds',128,'microtime_resolution',16,'microtime_onset',8, ...
    'serial_correlation','AR(1)','hrf','canonical','min_residual_df',10,'mask_threshold',0.8,'confounds',c);
options=struct('conditions',{{'A','B'}},'contrasts',struct('name','A_minus_B','weights',[1 -1]), ...
    'glm',g,'max_matrix_gib',0.25);
t.TestData.job=struct('schema_version',1,'route','glm','mode','preflight', ...
    'toolkit_root',t.TestData.toolkit,'spm_root',t.TestData.spmRoot,'manifest_file',manifest, ...
    'work_root',fullfile(root,'work'),'output_root',fullfile(root,'output'),'options',options, ...
    'expected_runs',struct('subject','pilot','session','baseline','run','task1','tr_seconds',2));
end

function teardown(t)
cd(t.TestData.oldDirectory);
% 只清除此测试刚创建的专用临时目录，不触及任何发布目录或真实数据。
root=t.TestData.root;
if isfolder(root)&&startsWith(lower(root),lower(tempdir)),rmdir(root,'s');end
end

function testNativeDesignOnlyAndInputProtection(t)
j=t.TestData.job;oldPath=path;oldDirectory=pwd;
config=readBytes(fullfile(j.toolkit_root,'config','glm_config.m'));
before=readBytes(fullfile(t.TestData.root,'bold.nii'));events=fileread(fullfile(t.TestData.root,'events.tsv'));
r=cogneuro_glm_adapter(j);
verifyEqual(t,r.status,'preflight_passed');verifyEqual(t,r.runs.n_frames,96);
verifyGreaterThanOrEqual(t,r.runs.remaining_dimensions,10);
verifyTrue(t,r.runs.contrast_estimability_checked);verifyTrue(t,r.runs.masked_bold_all_frames_finite);
verifyTrue(t,isfile(fullfile(r.runs.design_path,'SPM.mat')));
verifyFalse(t,isfile(fullfile(r.runs.design_path,'beta_0001.nii')));verifyFalse(t,isfolder(j.output_root));
verifyEqual(t,path,oldPath);verifyEqual(t,pwd,oldDirectory);
verifyEqual(t,readBytes(fullfile(t.TestData.root,'bold.nii')),before);
verifyEqual(t,fileread(fullfile(t.TestData.root,'events.tsv')),events);
verifyEqual(t,readBytes(fullfile(j.toolkit_root,'config','glm_config.m')),config);
verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMFresh');
end

function testNativeExecuteRequiresCompletionAndMaps(t)
j=t.TestData.job;j.mode='execute';r=cogneuro_glm_adapter(j);
verifyEqual(t,r.status,'complete');verifyEqual(t,r.runs.status,'complete');
verifyTrue(t,isfile(r.runs.completion_marker));verifyTrue(t,isfile(r.runs.qc_path));
model=fullfile(r.runs.output_path,'models','joint');
verifyTrue(t,isfile(fullfile(model,'spmT_0001.nii')));
verifyTrue(t,isfile(fullfile(model,'beta_0001.nii')));
qc=jsondecode(fileread(r.runs.qc_path));verifyEqual(t,qc.nFrames,96);verifyEqual(t,qc.nContrasts,1);
verifyGreaterThan(t,qc.nMaskedVoxels,0);
% 独立检查真实估计目录中的列/权重及数值，而不只相信完成标记。
loaded=load(fullfile(model,'SPM.mat'),'SPM');SPM=loaded.SPM;
a=find(strcmp(SPM.xX.name,'Sn(1) A*bf(1)'));b=find(strcmp(SPM.xX.name,'Sn(1) B*bf(1)'));
verifyEqual(t,numel(a),1);verifyEqual(t,numel(b),1);
expected=zeros(1,size(SPM.xX.X,2));expected(a)=1;expected(b)=-1;
verifyEqual(t,full(SPM.xCon(1).c(:))',expected,'AbsTol',1e-12);
mask=spm_read_vols(spm_vol(fullfile(model,'mask.nii')))>0;
betaA=spm_read_vols(spm_vol(fullfile(model,sprintf('beta_%04d.nii',a))));
betaB=spm_read_vols(spm_vol(fullfile(model,sprintf('beta_%04d.nii',b))));
contrast=spm_read_vols(spm_vol(fullfile(model,'con_0001.nii')));
statistic=spm_read_vols(spm_vol(fullfile(model,'spmT_0001.nii')));
verifyEqual(t,contrast(mask),betaA(mask)-betaB(mask),'AbsTol',1e-4);
verifyGreaterThan(t,median(contrast(mask)),0);verifyGreaterThan(t,median(statistic(mask)),0);
end

function testSameDimensionsDifferentAffineMaskRejected(t)
j=t.TestData.job;matrix=diag([2 2 2 1]);matrix(1,4)=10;
makeImage(fullfile(t.TestData.root,'mask.nii'),ones(4,4,4),2,matrix);
oldPath=path;verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMMask');
verifyFalse(t,isfolder(j.work_root));verifyFalse(t,isfolder(j.output_root));verifyEqual(t,path,oldPath);
end

function testNonfiniteMaskedFrameRejected(t)
j=t.TestData.job;data=ones(4,4,4,96)*100;data(2,2,2,75)=NaN;
makeImage(fullfile(t.TestData.root,'bold.nii'),data,2,diag([2 2 2 1]));
verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMNonfinite');verifyFalse(t,isfolder(j.work_root));
end

function testConfirmedTrMismatchRejected(t)
j=t.TestData.job;j.expected_runs.tr_seconds=1;
verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMTR');verifyFalse(t,isfolder(j.work_root));
end

function testNonestimableContrastIsPreflightFailure(t)
j=t.TestData.job;onset=[4;4;30;30;60;60];duration=ones(6,1)*2;
trial_type=["A";"B";"A";"B";"A";"B"];
writetable(table(onset,duration,trial_type),fullfile(t.TestData.root,'events.tsv'),'FileType','text','Delimiter','\t');
verifyError(t,@()cogneuro_glm_adapter(j),'psy:GLMEstimability');verifyFalse(t,isfolder(j.output_root));
end

function testHighpassResidualDimensionsCheckedBeforeEstimation(t)
j=t.TestData.job;j.options.glm.min_residual_df=95;
verifyError(t,@()cogneuro_glm_adapter(j),'psy:GLMDF');
verifyFalse(t,isfolder(j.output_root));verifyFalse(t,isfile(fullfile(j.work_root,'sub-pilot','ses-baseline','task1','models','joint','beta_0001.nii')));
end

function testUnknownOptionAndLowMemoryRejected(t)
j=t.TestData.job;j.options.glm.unused_override=true;
verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMOptions');
j=t.TestData.job;j.options.max_matrix_gib=1e-10;
verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMMemory');verifyFalse(t,isfolder(j.work_root));
end

function testSpikeBudgetRejectedBeforeNativeDesignSvd(t)
j=t.TestData.job;n=96;
writetable(table(ones(n,1),'VariableNames',{'framewise_displacement'}), ...
    fullfile(t.TestData.root,'confounds.tsv'),'FileType','text','Delimiter','\t');
j.options.glm.confounds.add_spikes=true;j.options.max_matrix_gib=1e-4;
% 全部帧均超过 FD 阈值：若原生设计已被调用，会先因残差为0报 psy:DesignDF。
% 正确行为是在构造 n×n spike 矩阵/SVD 前，用预算上界拒绝。
verifyError(t,@()cogneuro_glm_adapter(j),'cogneuro:GLMMemory');
verifyFalse(t,isfolder(j.work_root));verifyFalse(t,isfolder(j.output_root));
end

function testMultipleRunIdentitiesRemainSeparate(t)
j=t.TestData.job;manifest=readtable(j.manifest_file,'FileType','text','Delimiter','\t','TextType','string');
manifest=[manifest;manifest];manifest.subject(2)="second";manifest.session(2)="followup";manifest.run(2)="task2";
writetable(manifest,j.manifest_file,'FileType','text','Delimiter','\t');
j.expected_runs(2)=struct('subject','second','session','followup','run','task2','tr_seconds',2);
r=cogneuro_glm_adapter(j);verifyEqual(t,numel(r.runs),2);
verifyEqual(t,{r.runs.subject},{'pilot','second'});verifyNotEqual(t,r.runs(1).design_path,r.runs(2).design_path);
end

function makeImage(file,data,tr,matrix)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);
ni.mat=matrix;ni.mat0=matrix;ni.timing=struct('toffset',0,'tspace',tr);
create(ni);ni.dat(:)=single(data(:));
end

function signal=taskSignal(n,tr)
% [单位/约束] 16 个微时间格/TR、参考第 8 格；事件和下方正式表完全相同。
resolution=16;onsetBin=8;dt=tr/resolution;microtime=(0:n*resolution+256)*dt;
input=zeros(size(microtime));onsets=[4 20 36 52 68 84];amplitudes=[40 -20 40 -20 40 -20];
for k=1:numel(onsets)
    select=microtime>=onsets(k)&microtime<onsets(k)+2;
    input(select)=input(select)+amplitudes(k);
end
convolved=conv(input,reshape(spm_hrf(dt),1,[]));
signal=reshape(convolved((0:n-1)*resolution+onsetBin),1,[]);
end

function bytes=readBytes(file)
f=fopen(file,'rb');assert(f>=0);cleanup=onCleanup(@()fclose(f));bytes=fread(f,Inf,'*uint8'); %#ok<NASGU>
end
