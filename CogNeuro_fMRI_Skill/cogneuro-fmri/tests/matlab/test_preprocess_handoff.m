function tests=test_preprocess_handoff
%TEST_PREPROCESS_HANDOFF 微型完成记录与合成影像；不运行预处理、不访问真实被试。
tests=functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.oldPath=path;t.TestData.oldDirectory=pwd;
skill=fileparts(fileparts(fileparts(mfilename('fullpath'))));addpath(fullfile(skill,'matlab'));
toolkit=getenv('COGNEURO_PREPROCESS_TEST_TOOLKIT'); % [路径/约束] 显式指定预处理发布包根目录。
spmRoot=getenv('COGNEURO_PREPROCESS_TEST_SPM'); % [路径] 空时使用当前已安装并可定位的SPM。
if isempty(spmRoot),spmRoot=fileparts(which('spm'));end
assumeTrue(t,~isempty(toolkit)&&isfile(fullfile(toolkit,'matlab','+psy','motion_regressors.m'))&& ...
    isfile(fullfile(spmRoot,'spm.m')),'Set COGNEURO_PREPROCESS_TEST_TOOLKIT/SPM for native helper tests');
t.TestData.toolkit=toolkit;t.TestData.spmRoot=spmRoot;
addpath(fullfile(toolkit,'matlab'),'-begin');addpath(spmRoot,'-begin');
end

function teardownOnce(t)
cd(t.TestData.oldDirectory);path(t.TestData.oldPath);
end

function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;
staged=fullfile(root,'staged');mkdir(staged);
out=fullfile(root,'preprocessed','sub-pilot','ses-baseline','task1');mkdir(out);
n=8;matrix=diag([2 2 2 1]);bold=fullfile(out,'arbitrary_recorded_series.nii');
makeImage(bold,100+reshape(sin(1:64*n),4,4,4,n),2,matrix);
normalized=fullfile(out,'no_prefix_inference_allowed.nii');copyfile(bold,normalized);
mask=fullfile(staged,'mask.nii');makeImage(mask,ones(4,4,4),2,matrix);
events=fullfile(staged,'events.tsv');onset=[2;8;14];duration=[1;1;4];trial_type=["A";"B";"A"];
stimulus_id=["item1";"item2";"item3"];
writetable(table(onset,duration,trial_type,stimulus_id),events,'FileType','text','Delimiter','\t');
dummyDir=fullfile(out,'dummy_trim');mkdir(dummyDir);adjusted=fullfile(dummyDir,'events_retained_first_volume.tsv');
onset=onset-4;writetable(table(onset,duration,trial_type,stimulus_id),adjusted,'FileType','text','Delimiter','\t');
motion=fullfile(out,'recorded_motion.txt');rp=zeros(n,6);rp(:,1)=(0:n-1)'*.1;rp(:,5)=(0:n-1)'*.01;
writematrix(rp,motion,'Delimiter','tab');
dummy=struct('count',2,'originalVolumes',10,'retainedVolumes',8,'trSeconds',2, ...
    'discardedSeconds',4,'eventReference','original_first_volume','eventShiftSeconds',4,'retainedDurationSeconds',16);
plan=struct('dummy',dummy);planFile=fullfile(out,'preprocessing_plan.json');writeJson(planFile,plan);
run=struct('subject','pilot','session','baseline','name','task1','events',events);
cfg=struct('execute',true,'fdRadiusMm',37);info=struct('nVolumes',10,'trSeconds',2);
inputFile=fullfile(out,'input_info.mat');save(inputFile,'run','cfg','info','plan');
status='realigned_without_distortion_correction';signature='synthetic fixture only'; %#ok<NASGU>
requiredOutputs={planFile,bold,normalized,motion,adjusted};marker=fullfile(out,'COMPLETE.mat');
save(marker,'status','signature','requiredOutputs');
record=struct('subject','pilot','session','baseline','run','task1','output_path',out, ...
    'completion_marker',marker,'retained_frames',8,'tr_seconds',2,'realigned_bold',bold, ...
    'normalized_bold',normalized,'smoothed_bold','','motion_file',motion,'adjusted_events',adjusted,'plan_file',planFile);
source=struct('schema_version',1,'route','preprocess','status','complete','runs',record, ...
    'output_files',{{marker,inputFile,planFile,bold,normalized,motion,adjusted}});
sourceFile=fullfile(root,'preprocessing_result.json');writeJson(sourceFile,source);
job=struct('schema_version',1,'route','handoff','mode','execute','toolkit_root',t.TestData.toolkit, ...
    'spm_root',t.TestData.spmRoot,'output_root',fullfile(root,'handoff'), ...
    'preprocessing_result_file',sourceFile,'options',struct('bold_source','realigned','include_tissue_means',false), ...
    'expected_runs',struct('subject','pilot','session','baseline','run','task1','tr_seconds',2,'mask',mask));
t.TestData.job=job;t.TestData.source=source;t.TestData.rp=rp;
end

function teardown(t)
cd(t.TestData.oldDirectory);root=t.TestData.root;
if isfolder(root)&&startsWith(lower(root),lower(tempdir)),rmdir(root,'s');end
end

function testDummyShiftOnceMotionNumbersAndInputProtection(t)
j=t.TestData.job;source=t.TestData.source;r=source.runs;
files=[source.output_files,{j.expected_runs.mask,fullfile(t.TestData.root,'staged','events.tsv')}];
before=cellfun(@psy.file_sha256,files,'UniformOutput',false);oldPath=path;oldDirectory=pwd;
result=cogneuro_preprocess_handoff(j);
verifyEqual(t,result.status,'complete');verifyEqual(t,result.runs.subject,'pilot');
verifyEqual(t,result.runs.session,'baseline');verifyEqual(t,result.runs.run,'task1');
verifyEqual(t,result.runs.n_frames,8);verifyEqual(t,result.runs.tr_seconds,2);
verifyEqual(t,result.runs.event_shift_already_applied_seconds,4);verifyEqual(t,result.runs.negative_onset_count,1);
verifyEqual(t,result.runs.fd_radius_mm,37);verifyEqual(t,readBytes(result.runs.events),readBytes(r.adjusted_events));
events=readtable(result.runs.events,'FileType','text','Delimiter','\t','TextType','string');
verifyEqual(t,events.onset,[-2;4;10]);verifyEqual(t,events.stimulus_id,["item1";"item2";"item3"]);
confounds=readtable(result.runs.confounds,'FileType','text','Delimiter','\t');
[values,names,fd]=psy.motion_regressors(t.TestData.rp,37);
verifyEqual(t,width(confounds),25);verifyEqual(t,height(confounds),8);
verifyEqual(t,confounds.Properties.VariableNames,[names,{'framewise_displacement'}]);
verifyEqual(t,confounds{:,1:24},values,'AbsTol',1e-10);verifyEqual(t,confounds.framewise_displacement,fd,'AbsTol',1e-10);
verifyEqual(t,fd,[0;repmat(.47,7,1)],'AbsTol',1e-12);
manifest=readtable(result.manifest_file,'FileType','text','Delimiter','\t','TextType','string');
verifyEqual(t,manifest.Properties.VariableNames,{'subject','session','run','bold','events','confounds','temporal_state','mask'});
verifyEqual(t,manifest.temporal_state,"unfiltered_unregressed");
verifyEqual(t,cellfun(@psy.file_sha256,files,'UniformOutput',false),before);
verifyEqual(t,path,oldPath);verifyEqual(t,pwd,oldDirectory);
verifyTrue(t,all(cellfun(@isfile,result.output_files)));
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffExists');
end

function testSelectionUsesRecordedOutputNotPrefix(t)
j=t.TestData.job;j.options.bold_source='normalized_unsmoothed';
r=cogneuro_preprocess_handoff(j);
verifyEqual(t,r.runs.bold,t.TestData.source.runs.normalized_bold);
verifyTrue(t,contains(r.runs.bold,'no_prefix_inference_allowed.nii'));
end

function testNoDummyUsesOriginalStagedEventsUnshifted(t)
j=t.TestData.job;s=t.TestData.source;r=s.runs;native=load(fullfile(r.output_path,'input_info.mat'));
d=native.plan.dummy;d.count=0;d.originalVolumes=8;d.discardedSeconds=0;
d.eventReference='retained_first_volume';d.eventShiftSeconds=0;
native.plan.dummy=d;native.info.nVolumes=8;
run=native.run;cfg=native.cfg;info=native.info;plan=native.plan; %#ok<NASGU>
save(fullfile(r.output_path,'input_info.mat'),'run','cfg','info','plan');writeJson(r.plan_file,plan);
s.runs.adjusted_events=run.events;writeJson(j.preprocessing_result_file,s);
result=cogneuro_preprocess_handoff(j);
verifyEqual(t,result.runs.event_shift_already_applied_seconds,0);
verifyEqual(t,readBytes(result.runs.events),readBytes(run.events));
verifyEqual(t,result.runs.event_end_overrun_seconds,2); % 原生策略保留末事件超出2秒。
end

function testRepeatedOrWrongDummyShiftRejected(t)
j=t.TestData.job;r=t.TestData.source.runs;
e=readtable(r.adjusted_events,'FileType','text','Delimiter','\t','TextType','string');e.onset=e.onset-4;
writetable(e,r.adjusted_events,'FileType','text','Delimiter','\t');
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffEventShift');verifyFalse(t,isfolder(j.output_root));
end

function testNonOnsetEventMutationRejected(t)
j=t.TestData.job;r=t.TestData.source.runs;
e=readtable(r.adjusted_events,'FileType','text','Delimiter','\t','TextType','string');e.stimulus_id(2)="changed";
writetable(e,r.adjusted_events,'FileType','text','Delimiter','\t');
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffEventShift');
end

function testIdentityAndIncompleteNativeStatusRejected(t)
j=t.TestData.job;j.expected_runs.run='different';
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffIdentity');
j=t.TestData.job;r=t.TestData.source.runs;native=load(r.completion_marker);native.status='validated_inputs';
save(r.completion_marker,'-struct','native');
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffIncomplete');
end

function testMissingCompletedOutputAndUnavailableSelectionRejected(t)
j=t.TestData.job;j.options.bold_source='smoothed';
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffPath');
j=t.TestData.job;delete(t.TestData.source.runs.motion_file);
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffMissing');
end

function testMaskAffineAndMaskedNonfiniteRejected(t)
j=t.TestData.job;matrix=diag([2 2 2 1]);matrix(1,4)=3;
makeImage(j.expected_runs.mask,ones(4,4,4),2,matrix);
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffMask');
makeImage(j.expected_runs.mask,ones(4,4,4),2,diag([2 2 2 1]));
data=ones(4,4,4,8)*100;data(2,2,2,6)=NaN;
makeImage(t.TestData.source.runs.realigned_bold,data,2,diag([2 2 2 1]));
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffNonfinite');
end

function testFrameAndDummyPlanDisagreementRejected(t)
j=t.TestData.job;s=t.TestData.source;s.runs.retained_frames=9;writeJson(j.preprocessing_result_file,s);
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffPlan');
s=t.TestData.source;writeJson(j.preprocessing_result_file,s);plan=jsondecode(fileread(s.runs.plan_file));
plan.dummy.eventShiftSeconds=8;writeJson(s.runs.plan_file,plan);
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffPlan');
end

function testTissueAndInvalidBOLDChoicesRejected(t)
j=t.TestData.job;j.options.include_tissue_means=true;
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffTissue');
j=t.TestData.job;j.options.bold_source='guess_from_prefix';
verifyError(t,@()cogneuro_preprocess_handoff(j),'cogneuro:HandoffOptions');
end

function makeImage(file,data,tr,matrix)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);
ni.mat=matrix;ni.mat0=matrix;ni.timing=struct('toffset',0,'tspace',tr);create(ni);ni.dat(:)=single(data(:));
end

function writeJson(file,value)
f=fopen(file,'w','n','UTF-8');assert(f>=0);cleanup=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'%s',jsonencode(value,PrettyPrint=true));
end

function bytes=readBytes(file)
f=fopen(file,'rb');assert(f>=0);cleanup=onCleanup(@()fclose(f));bytes=fread(f,Inf,'*uint8'); %#ok<NASGU>
end
