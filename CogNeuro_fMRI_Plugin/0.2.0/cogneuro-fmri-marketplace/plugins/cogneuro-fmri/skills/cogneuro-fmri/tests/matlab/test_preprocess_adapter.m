function tests=test_preprocess_adapter
%TEST_PREPROCESS_ADAPTER 极小合成NIfTI验证；不读取HCP，不执行分割/标准化。
% 路径由COGNEURO_TEST_PREPROCESS_ROOT和COGNEURO_TEST_SPM_ROOT显式提供。
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
t.TestData.toolkit=getenv('COGNEURO_TEST_PREPROCESS_ROOT'); % 测试路径：官方预处理包。
t.TestData.spm=getenv('COGNEURO_TEST_SPM_ROOT'); % 测试路径：所选SPM安装根目录。
assert(isfolder(t.TestData.toolkit),'Set COGNEURO_TEST_PREPROCESS_ROOT');
assert(isfolder(t.TestData.spm),'Set COGNEURO_TEST_SPM_ROOT');
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'matlab'),t.TestData.spm,'-begin');
t.TestData.configFile=fullfile(t.TestData.toolkit,'config','toolkit_config.m');
t.TestData.configHash=sha256(t.TestData.configFile);
end
function teardownOnce(t)
path(t.TestData.oldPath);
end

function testPreflightPlansAllRunsWithoutProcessing(t)
[job,rows,folder]=fixture(t);
rows(2,:)=rows(1,:);rows.subject(2)="002";rows.session(2)="followup";
writeRows(job.manifest_file,rows);job.expected_runs=identities(rows);
before=readBytes(fullfile(folder,'bold.nii'));beforeConfig=readBytes(t.TestData.configFile);
beforePath=path;
r=cogneuro_preprocess_adapter(job);
verifyEqual(t,r.status,'preflight_passed');verifyEqual(t,r.n_runs,2);
verifyEqual(t,{r.runs.subject},{'001','002'});
verifyEqual(t,{r.runs.session},{'','followup'});
verifyEqual(t,[r.runs.retained_frames],[6 6]);
verifyTrue(t,all(cellfun(@isfile,{r.runs.plan_file})));
verifyTrue(t,isfile(fullfile(job.work_root,'input_checks','sub-002','ses-followup','r1','header.mat')));
verifyFalse(t,isfolder(job.output_root));
verifyFalse(t,isfile(fullfile(job.work_root,'sub-001','r1','02_realign.mat')));
verifyEqual(t,r.runs(1).realigned_bold,'');verifyEmpty(t,r.runs(1).executed_steps);
verifyFalse(t,r.scientific_qc_passed);verifyEqual(t,path,beforePath);
verifyEqual(t,readBytes(fullfile(folder,'bold.nii')),before);
verifyEqual(t,readBytes(t.TestData.configFile),beforeConfig);
verifyEqual(t,r.runs(1).adjusted_events,char(rows.events(1)));
end

function testRealignDummyAndSliceTimingUsePrivateCopies(t)
[job,rows,folder]=fixture(t);
rows.discard_volumes=2;rows.event_reference="original_first_volume";
writeRows(job.manifest_file,rows);job.mode='execute';
job.options.preprocessing.overrides(2).value='ascending';
job.options.preprocessing.overrides(end+1)=struct('path','sliceTiming.reference','value','first');
sources={fullfile(folder,'bold.nii'),fullfile(folder,'t1.nii'),fullfile(folder,'events.tsv'),t.TestData.configFile};
before=cellfun(@readBytes,sources,'UniformOutput',false);
r=cogneuro_preprocess_adapter(job);a=r.runs(1);
verifyEqual(t,r.status,'complete');verifyEqual(t,a.retained_frames,4);
verifyEqual(t,a.tr_seconds,2);verifyTrue(t,isfile(a.completion_marker));
verifyEqual(t,a.output_path,fullfile(job.output_root,'sub-001','r1'));
verifyTrue(t,isfile(fullfile(a.output_path,'01_slice_timing.mat')));
verifyTrue(t,ismember('slice_timing',a.executed_steps));
verifyTrue(t,contains(a.realigned_bold,'abold_retained.nii'));
verifyEqual(t,numel(spm_vol(a.realigned_bold)),4);
verifyEqual(t,size(readmatrix(a.motion_file,'FileType','text')),[4 6]);
events=readtable(a.adjusted_events,'FileType','text','Delimiter','\t');
verifyEqual(t,events.onset,[-4;4]);
verifyEqual(t,a.normalized_bold,'');verifyEqual(t,a.smoothed_bold,'');
verifyTrue(t,all(cellfun(@isfile,r.output_files)));
for k=1:numel(sources),verifyEqual(t,readBytes(sources{k}),before{k});end
verifyError(t,@()cogneuro_preprocess_adapter(job),'cogneuro:PreprocessOutput');
end

function testRealignCompletesBothRunIdentities(t)
[job,rows]=fixture(t);
rows(2,:)=rows(1,:);rows.subject(2)="002";rows.session(2)="visit2";
writeRows(job.manifest_file,rows);job.expected_runs=identities(rows);job.mode='execute';
r=cogneuro_preprocess_adapter(job);
verifyEqual(t,r.status,'complete');verifyEqual(t,numel(r.runs),2);
verifyEqual(t,r.runs(1).output_path,fullfile(job.output_root,'sub-001','r1'));
verifyEqual(t,r.runs(2).output_path,fullfile(job.output_root,'sub-002','ses-visit2','r1'));
verifyTrue(t,all(cellfun(@isfile,{r.runs.completion_marker})));
verifyEqual(t,[r.runs.retained_frames],[6 6]);
verifyTrue(t,all(cellfun(@(f)numel(spm_vol(f))==6,{r.runs.realigned_bold})));
end

function testWrongTRAndBudgetRejectedBeforeNativePreflight(t)
[job,~]=fixture(t);
bad=job;bad.expected_runs.tr_seconds=1;
verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessTR');
bad=job;bad.options.max_matrix_gib=1e-12;
verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessMemory');
verifyFalse(t,isfolder(job.work_root));verifyFalse(t,isfolder(job.output_root));
end

function testMissingT1AndIdentityMismatchRejected(t)
[job,rows]=fixture(t);
bad=job;bad.expected_runs.subject='wrong';
verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessIdentity');
rows.t1="";writeRows(job.manifest_file,rows);
verifyError(t,@()cogneuro_preprocess_adapter(job),'psy:MissingImage');
verifyFalse(t,isfolder(job.work_root));
end

function testRawNonfiniteAndNon3DT1Rejected(t)
[job,~,folder]=fixture(t);
n=nifti(fullfile(folder,'bold.nii'));n.dat(1,1,1,6)=NaN;
verifyError(t,@()cogneuro_preprocess_adapter(job),'cogneuro:PreprocessNonfinite');
[job,~,folder]=fixture(t);
writeImage(fullfile(folder,'t1.nii'),ones(4,4,4,2),2);
verifyError(t,@()cogneuro_preprocess_adapter(job),'cogneuro:PreprocessShape');
end

function testOfficialConfigHashAndForbiddenOverridesRejected(t)
[job,~]=fixture(t);
bad=job;bad.options.preprocessing.toolkit_config_sha256=repmat('0',1,64);
verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessConfigHash');
for key={'outputRoot','inputMode','execute','realign.weightImage','segment.tpmPath','segment.inputVolume'}
    bad=job;bad.options.preprocessing.overrides=struct('path',key{1},'value','forbidden');
    verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessOverride');
end
bad=job;bad.options.preprocessing.overrides=[struct('path','sliceTiming.mode','value','off') ...
    struct('path','sliceTiming.mode','value','ascending')];
verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessOverride');
verifyFalse(t,isfolder(job.work_root));
verifyEqual(t,sha256(t.TestData.configFile),t.TestData.configHash);
end

function testUnsupportedScientificRoutesRejected(t)
[job,~]=fixture(t);
keys={'sdc.method','segment.backend','normalise.method'};values={'fsl_topup','cat12','dartel'};
for k=1:3
    bad=job;bad.options.preprocessing.overrides=struct('path',keys{k},'value',values{k});
    verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessPilot');
end
verifyFalse(t,isfolder(job.work_root));
end

function testSPMBatchShapeMismatchesRejectedBeforePreflight(t)
[job,~]=fixture(t);
keys={'realign.separationMm','realign.smoothingFwhmMm','realign.estimateInterpolation','coreg.smoothingFwhmMm'};
values={[4 2],[5 5],[1 2],7};
for k=1:numel(keys)
    bad=job;bad.options.preprocessing.overrides=struct('path',keys{k},'value',values{k});
    verifyError(t,@()cogneuro_preprocess_adapter(bad),'cogneuro:PreprocessOptions');
end
verifyFalse(t,isfolder(job.work_root));
end

function testPerRunUnsupportedRoutesAndMissingDummyReferenceRejected(t)
[job,rows]=fixture(t);
rows.sdc_method="spm_unwarp";writeRows(job.manifest_file,rows);
verifyError(t,@()cogneuro_preprocess_adapter(job),'cogneuro:PreprocessPilot');
rows.sdc_method="none";rows.discard_volumes=2;rows.event_reference="";
writeRows(job.manifest_file,rows);
verifyError(t,@()cogneuro_preprocess_adapter(job),'psy:DummyEventReference');
verifyFalse(t,isfolder(job.work_root));
end

function testInfiniteScientificOptionHasExplicitReviewEncoding(t)
[job,~]=fixture(t);
job.options.preprocessing.overrides(end+1)=struct('path','segment.biasFwhmMm','value','Inf');
r=cogneuro_preprocess_adapter(job);
verifyEqual(t,r.resolved_preprocessing_config.segment.biasFwhmMm,'Inf');
encoded=jsonencode(r);verifyTrue(t,contains(encoded,'"biasFwhmMm":"Inf"'));
saved=load(fullfile(job.work_root,'config_and_inventory.mat'),'cfg');
verifyEqual(t,saved.cfg.segment.biasFwhmMm,Inf);
end

function [job,rows,folder]=fixture(t)
folder=tempname;mkdir(folder);addTeardown(t,@()removeFixture(folder));
[x,y,z]=ndgrid(1:32,1:32,1:16);
base=single(1000*exp(-((x-16).^2+(y-16).^2+(z-8).^2)/70)+10);
data=zeros(32,32,16,6,'single');
for k=1:6,data(:,:,:,k)=base+single(k);end
writeImage(fullfile(folder,'bold.nii'),data,2);writeImage(fullfile(folder,'t1.nii'),base,2);
eventsFile=fullfile(folder,'events.tsv');
writetable(table([0;8],[1;1],["A";"B"],'VariableNames',{'onset','duration','trial_type'}), ...
    eventsFile,'FileType','text','Delimiter','\t');
subject="001";session="";run="r1";bold=string(fullfile(folder,'bold.nii'));
t1=string(fullfile(folder,'t1.nii'));input_stage="raw";events=string(eventsFile);
discard_volumes=0;event_reference="";
rows=table(subject,session,run,bold,t1,input_stage,events,discard_volumes,event_reference);
manifest=fullfile(folder,'runs.tsv');writeRows(manifest,rows);
overrides=[struct('path','qc.enabled','value',false) ...
    struct('path','sliceTiming.mode','value','off') ...
    struct('path','sdc.method','value','none') ...
    struct('path','segment.backend','value','spm') ...
    struct('path','normalise.method','value','segmentation')];
job=struct('schema_version',1,'route','preprocess','mode','preflight', ...
    'toolkit_root',t.TestData.toolkit,'spm_root',t.TestData.spm, ...
    'manifest_file',manifest,'work_root',fullfile(folder,'work'), ...
    'output_root',fullfile(folder,'output'),'expected_runs',identities(rows), ...
    'options',struct('preprocessing',struct('stop_after','realign', ...
    'toolkit_config_sha256',t.TestData.configHash,'overrides',overrides),'max_matrix_gib',.05));
end
function expected=identities(rows)
expected=struct([]);
for k=1:height(rows)
    item=struct('subject',char(rows.subject(k)),'session',char(rows.session(k)), ...
        'run',char(rows.run(k)),'tr_seconds',2);
    if isempty(expected),expected=item;else,expected(end+1)=item;end %#ok<AGROW>
end
end
function writeRows(file,rows)
writetable(rows,file,'FileType','text','Delimiter','\t');
end
function writeImage(file,data,tr)
n=nifti;n.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);n.mat=eye(4);n.mat0=eye(4);
n.timing=struct('toffset',0,'tspace',tr);create(n);n.dat(:,:,:,:)=data;
end
function bytes=readBytes(file)
fid=fopen(file,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
end
function hash=sha256(file)
fid=fopen(file,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
d=java.security.MessageDigest.getInstance('SHA-256');
while true
    b=fread(fid,1024*1024,'*uint8');if isempty(b),break;end
    d.update(typecast(b,'int8'));
end
hash=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
function removeFixture(folder)
% 删除前核对绝对目标仍处于临时目录，且仅删除本测试创建的唯一目录。
target=char(java.io.File(folder).getCanonicalPath());base=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(lower(target),[lower(base) filesep]),'Unsafe test cleanup target');
if isfolder(target),rmdir(target,'s');end
end
