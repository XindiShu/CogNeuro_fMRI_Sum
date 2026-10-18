function tests = test_fc_adapter
%TEST_FC_ADAPTER 极小合成影像测试；不读取HCP、不运行真实被试分析。
% 路径通过COGNEURO_TEST_FUNCTION_ROOT、COGNEURO_TEST_SPM_ROOT显式提供。
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.oldPath = path;
toolkitRoot = getenv('COGNEURO_TEST_FUNCTION_ROOT'); % 测试路径：所选分析方法包根目录。
spmRoot = getenv('COGNEURO_TEST_SPM_ROOT'); % 测试路径：本机SPM根目录。
assert(isfolder(toolkitRoot),'Set COGNEURO_TEST_FUNCTION_ROOT before running these tests');
assert(isfolder(spmRoot),'Set COGNEURO_TEST_SPM_ROOT before running these tests');
t.TestData.toolkitRoot = toolkitRoot;
t.TestData.spmRoot = spmRoot;
skillRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(skillRoot,'matlab'),spmRoot,'-begin');
end

function teardownOnce(t)
path(t.TestData.oldPath);
end

function testReadOnlyPreflightWithTwoIdentities(t)
[job,rows,folder] = fixture(t);
rows(2,:) = rows(1,:); rows.subject(2) = "002"; rows.session(2) = "ses02";
writeManifest(job.manifest_file,rows);
job.expected_runs = table2struct(rows(:,{'subject','session','run','tr_seconds'}));
boldBytes = readBytes(fullfile(folder,'bold.nii'));
beforeListing = dir(fullfile(folder,'*')); beforeNames = string({beforeListing.name});
beforePath = path;
r = cogneuro_fc_adapter(job);
verifyEqual(t,r.status,'preflight_passed');
verifyEqual(t,r.n_runs,2);
verifyEqual(t,r.runs(1).subject,'001');
verifyEqual(t,r.runs(1).session,'');
verifyEqual(t,r.runs(2).session,'ses02');
verifyEqual(t,r.runs(1).n_frames,40);
verifyEqual(t,r.runs(1).n_voxels,18);
verifyEqual(t,r.runs(1).n_rois,3);
verifyEqual(t,r.runs(1).projection_rank,2);
verifyEqual(t,r.runs(1).residual_dimensions,38);
verifyEqual(t,[r.runs(1).roi_coverage.label],[1 2 3]);
verifyEqual(t,[r.runs(1).roi_coverage.n_voxels],[6 6 6]);
verifyEqual(t,[r.runs(1).roi_coverage.coverage_fraction],[1 1 1]);
verifyFalse(t,isfolder(job.output_root));
verifyEmpty(t,r.output_files);
afterListing = dir(fullfile(folder,'*'));
verifyEqual(t,string({afterListing.name}),beforeNames);
verifyEqual(t,readBytes(fullfile(folder,'bold.nii')),boldBytes);
verifyEqual(t,path,beforePath);
verifyTrue(t,all(structfun(@(value)value,r.checks)));
end

function testExecuteVerifiesOutputsAndRejectsReuse(t)
[job,~,folder] = fixture(t);
job.mode = 'execute';
originalBytes = readBytes(fullfile(folder,'bold.nii'));
r = cogneuro_fc_adapter(job);
verifyEqual(t,r.status,'complete');
verifyEqual(t,r.summary.completed,1);
verifyEqual(t,r.summary.failed,0);
verifyEqual(t,numel(r.output_files),9);
verifyTrue(t,all(cellfun(@isfile,r.output_files)));
verifyEqual(t,readBytes(fullfile(folder,'bold.nii')),originalBytes);
saved = load(fullfile(job.output_root,'001','r1','roi_timeseries.mat'));
fc = load(fullfile(job.output_root,'001','r1','static_fc.mat'));
verifyEqual(t,fc.fc.correlation,corr(saved.roi),'AbsTol',1e-12);
verifyError(t,@()cogneuro_fc_adapter(job),'cogneuro:OutputExists');
end

function testExecuteVerifiesAllRunIdentities(t)
[job,rows] = fixture(t);
rows(2,:) = rows(1,:); rows.subject(2) = "002"; rows.session(2) = "ses02";
writeManifest(job.manifest_file,rows);
job.expected_runs = table2struct(rows(:,{'subject','session','run','tr_seconds'}));
job.mode = 'execute';
r = cogneuro_fc_adapter(job);
verifyEqual(t,r.status,'complete');
verifyEqual(t,r.summary.completed,2);
verifyEqual(t,r.summary.failed,0);
verifyEqual(t,numel(r.output_files),15);
verifyTrue(t,all(cellfun(@isfile,r.output_files)));
first = load(fullfile(job.output_root,'001','r1','COMPLETE.mat'),'record');
second = load(fullfile(job.output_root,'002','ses02','r1','COMPLETE.mat'),'record');
verifyEqual(t,string(first.record.subject),"001");
verifyEqual(t,string(first.record.session),"");
verifyEqual(t,string(second.record.subject),"002");
verifyEqual(t,string(second.record.session),"ses02");
end

function testRejectsIdentityAndTRDisagreement(t)
[job,rows] = fixture(t);
wrong = job; wrong.expected_runs.subject = 'other';
verifyError(t,@()cogneuro_fc_adapter(wrong),'cogneuro:RunIdentity');
rows.tr_seconds = 1; writeManifest(job.manifest_file,rows);
job.expected_runs.tr_seconds = 1;
verifyError(t,@()cogneuro_fc_adapter(job),'cog:TR');
verifyFalse(t,isfolder(job.output_root));
end

function testMissingApprovedRunIdentitiesAreRejected(t)
[job,~] = fixture(t);
bad = rmfield(job,'expected_runs');
verifyError(t,@()cogneuro_fc_adapter(bad),'cogneuro:RunIdentity');
bad = job; bad.expected_runs = struct([]);
verifyError(t,@()cogneuro_fc_adapter(bad),'cogneuro:RunIdentity');
verifyFalse(t,isfolder(job.output_root));
end

function testRejectsMaskedNonfiniteAndGridMismatch(t)
[job,~,folder] = fixture(t);
data = zeros(3,3,2,40); data(1,1,1,39) = NaN;
writeImage(fullfile(folder,'bold.nii'),data,.8);
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Nonfinite');
[job,~,folder] = fixture(t);
writeImage(fullfile(folder,'mask.nii'),ones(3,3,2),.8,diag([2 2 2 1]));
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Grid');
end

function testRejectsShortConfoundsAndInsufficientResidualDimensions(t)
[job,rows,folder] = fixture(t);
file = fullfile(folder,'confounds.tsv');
writetable(table((1:9)','VariableNames',{'motion'}),file,'FileType','text','Delimiter','\t');
rows.confounds = string(file); writeManifest(job.manifest_file,rows);
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Confounds');
rows.confounds = ""; writeManifest(job.manifest_file,rows);
job.options.cleaning.minResidualDimensions = 39;
verifyError(t,@()cogneuro_fc_adapter(job),'cog:ResidualDimensions');
end

function testRejectsROICoverageAndConstantSeries(t)
[job,~,folder] = fixture(t);
job.options.roi_min_voxels = 7;
verifyError(t,@()cogneuro_fc_adapter(job),'cog:ROICoverage');
job.options.roi_min_voxels = 1;
state = rng; restoreRng = onCleanup(@()rng(state)); %#ok<NASGU>
rng(12); data = randn(3,3,2,40); data(1,:,:,:) = 0;
writeImage(fullfile(folder,'bold.nii'),data,.8);
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Constant');
% 正常数经投影产生约机器精度的残差，不能因此被当作有效ROI时序。
data = 100+randn(3,3,2,40); data(1,:,:,:) = 100;
writeImage(fullfile(folder,'bold.nii'),data,.8);
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Constant');
end

function testRejectsSingularPartialAndInvalidBand(t)
[job,~,folder] = fixture(t);
time = reshape(sin((1:40)/3),1,1,1,40);
data = repmat(time,3,3,2,1);
writeImage(fullfile(folder,'bold.nii'),data,.8);
job.options.fc_measure = 'partial';
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Singular');
job.options.fc_measure = 'pearson'; job.options.cleaning.bandHz = [.01 1];
verifyError(t,@()cogneuro_fc_adapter(job),'cog:Band');
verifyFalse(t,isfolder(job.output_root));
end

function testRejectsRepeatedNuisanceAndBandpass(t)
[job,rows,folder] = fixture(t);
rows.temporal_state = "nuisance_regressed_unfiltered";
file = fullfile(folder,'confounds.tsv');
writetable(table((1:40)','VariableNames',{'motion'}),file,'FileType','text','Delimiter','\t');
rows.confounds = string(file); writeManifest(job.manifest_file,rows);
verifyError(t,@()cogneuro_fc_adapter(job),'cogneuro:TemporalState');
rows.confounds = ""; rows.temporal_state = "denoised_bandpassed";
writeManifest(job.manifest_file,rows); job.options.cleaning.bandHz = [.01 .1];
verifyError(t,@()cogneuro_fc_adapter(job),'cogneuro:TemporalState');
end

function testAlreadyCleanedInputsWithoutConfoundsOrBandAreRejected(t)
[job,rows] = fixture(t);
job.options.cleaning.bandHz = [];
rows.confounds = "";
states = ["nuisance_regressed_unfiltered","nuisance_regressed_highpassed","denoised_bandpassed"];
for state = states
    rows.temporal_state = state;
    writeManifest(job.manifest_file,rows);
    verifyError(t,@()cogneuro_fc_adapter(job),'cogneuro:TemporalState');
end
verifyFalse(t,isfolder(job.output_root));
end

function testJobOptionsAreExplicitAndTyped(t)
[job,~,~] = fixture(t);
bad = job; bad.options.cleaning.detrend = 1;
verifyError(t,@()cogneuro_fc_adapter(bad),'cogneuro:Options');
bad = job; bad.options = rmfield(bad.options,'fc_measure');
verifyError(t,@()cogneuro_fc_adapter(bad),'cogneuro:Options');
bad = job; bad.manifest_file = 'runs.tsv';
verifyError(t,@()cogneuro_fc_adapter(bad),'cogneuro:Path');
bad = job; bad.output_root = fullfile(job.toolkit_root,'must_not_exist_test');
verifyError(t,@()cogneuro_fc_adapter(bad),'cogneuro:OutputLocation');
end

function testCurrentFolderShadowIsRejected(t)
[job,~,folder] = fixture(t);
shadow = fullfile(folder,'shadow'); mkdir(shadow);
fid = fopen(fullfile(shadow,'run_function.m'),'w');
assert(fid>=0); fprintf(fid,'function out=run_function(varargin)\nerror(''test:ShadowCalled'',''Wrong package'');\nout=[];\nend\n'); fclose(fid);
originalFolder = pwd; restoreFolder = onCleanup(@()cd(originalFolder)); %#ok<NASGU>
cd(shadow);
verifyError(t,@()cogneuro_fc_adapter(job),'cogneuro:SourceMismatch');
verifyFalse(t,isfolder(job.output_root));
end

function [job,rows,folder] = fixture(t)
folder = tempname; mkdir(folder);
addTeardown(t,@()removeFixture(folder));
state = rng; restoreRng = onCleanup(@()rng(state)); %#ok<NASGU>
rng(41); data = 100+randn(3,3,2,40);
labels = repmat(reshape(1:3,3,1,1),1,3,2);
writeImage(fullfile(folder,'bold.nii'),data,.8);
writeImage(fullfile(folder,'mask.nii'),ones(3,3,2),.8);
writeImage(fullfile(folder,'labels.nii'),labels,.8);
subject="001"; session=""; run="r1";
bold=string(fullfile(folder,'bold.nii')); mask=string(fullfile(folder,'mask.nii'));
roi_file=string(fullfile(folder,'labels.nii')); tr_seconds=.8;
temporal_state="unfiltered_unregressed"; smoothing_fwhm_mm=0;
confounds=""; purpose="engineering";
rows=table(subject,session,run,bold,mask,roi_file,tr_seconds,temporal_state, ...
    smoothing_fwhm_mm,confounds,purpose);
manifest=fullfile(folder,'runs.tsv'); writeManifest(manifest,rows);
job=struct('schema_version',1,'route','fc','mode','preflight', ...
    'toolkit_root',t.TestData.toolkitRoot,'spm_root',t.TestData.spmRoot, ...
    'manifest_file',manifest,'output_root',fullfile(folder,'output'), ...
    'expected_runs',table2struct(rows(:,{'subject','session','run','tr_seconds'})), ...
    'options',struct('cleaning',struct('detrend',true,'bandHz',[], ...
    'minResidualDimensions',10),'fc_measure','pearson','max_matrix_gib',.01, ...
    'roi_min_voxels',2));
end

function writeManifest(file,rows)
writetable(rows,file,'FileType','text','Delimiter','\t');
end

function writeImage(file,data,tr,affine)
if nargin<4, affine=eye(4); end
ni=nifti; ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);
ni.mat=affine; ni.mat0=affine;
ni.timing=struct('toffset',0,'tspace',tr); create(ni); ni.dat(:,:,:,:)=data;
end

function bytes = readBytes(file)
fid=fopen(file,'rb'); assert(fid>=0,'Cannot read fixture file');
closeFile=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
end

function removeFixture(folder)
% 删除前核对绝对目标仍位于MATLAB临时目录，且只删除本测试创建的目录。
target=char(java.io.File(folder).getCanonicalPath());
tempRoot=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(lower(target),[lower(tempRoot) filesep]),'Unsafe test cleanup path');
if isfolder(target), rmdir(target,'s'); end
end
