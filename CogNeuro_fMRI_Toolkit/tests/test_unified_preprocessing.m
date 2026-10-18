function tests=test_unified_preprocessing
% 统一预处理入口的采集时间、畸变分支和拒绝错误输入测试。
tests=functiontests(localfunctions);
end

function testFiveSpmOrdersAndMicrotime(testCase)
cfg=toolkit_config;
info=struct('size',[12 12 8],'trSeconds',2);
names={'ascending','descending','interleaved_midtop', ...
    'interleaved_bottomup','interleaved_topdown'};
for k=1:numel(names)
    cfg.sliceTiming.mode=names{k};
    p=psy.slice_timing_plan(struct,info,cfg);
    verifyTrue(testCase,p.enabled);
    verifyEqual(testCase,sort(p.sliceSeconds),0:0.25:1.75,'AbsTol',1e-10);
    verifyEqual(testCase,p.taSeconds,1.75,'AbsTol',1e-10);
    if strcmp(names{k},'ascending')
        verifyEqual(testCase,p.sliceSeconds(1),0,'AbsTol',1e-10);
    end
    verifyGreaterThanOrEqual(testCase,p.microtimeOnset,1);
    verifyLessThanOrEqual(testCase,p.microtimeOnset,16);
end
cfg.sliceTiming.mode='ascending';cfg.sliceTiming.reference='seconds';
cfg.sliceTiming.referenceSeconds=0.75;
p=psy.slice_timing_plan(struct,info,cfg);
verifyEqual(testCase,p.microtimeOnset,7);
cfg.sliceTiming.acquisitionTimeSeconds=1.4; % 实测单带 TA 改一行即可改变逐层时间。
p=psy.slice_timing_plan(struct,info,cfg);
verifyEqual(testCase,p.taSeconds,1.4,'AbsTol',1e-10);
verifyEqual(testCase,p.sliceSeconds,0:0.2:1.4,'AbsTol',1e-10);
cfg.sliceTiming.acquisitionTimeSeconds=2;
verifyError(testCase,@()psy.slice_timing_plan(struct,info,cfg),'psy:SliceTimingTA');
end

function testMetadataMultibandAndInvalidTiming(testCase)
folder=tempname;mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
m=struct('SliceTiming',[0 .2 0 .2 .4 .6 .4 .6]);
path=fullfile(folder,'bold.json'); fid=fopen(path,'w');fprintf(fid,'%s',jsonencode(m));fclose(fid);
cfg=toolkit_config;cfg.sliceTiming.mode='metadata';
run=struct('metadata',path);info=struct('size',[12 12 8],'trSeconds',.8);
p=psy.slice_timing_plan(run,info,cfg);
verifyEqual(testCase,p.sliceSeconds,m.SliceTiming);
cfg.sliceTiming.mode='explicit_seconds';cfg.sliceTiming.seconds=[0 .2];
verifyError(testCase,@()psy.slice_timing_plan(run,info,cfg),'psy:SliceTimingValues');
end

function testSpmMethodSelectionAndAxisGuard(testCase)
folder=tempname;mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
phase=fullfile(folder,'phase.nii');mag=fullfile(folder,'mag.nii');
bold=fullfile(folder,'bold.nii');
niftiwrite(zeros(8,8,4,'single'),phase);
niftiwrite(ones(8,8,4,'single'),mag);
niftiwrite(ones(8,8,4,3,'single'),bold);
f=struct('Type','phasediff','EchoTime1',.004,'EchoTime2',.006, ...
    'SPMBlipDirection',-1,'Images',struct('Path',{phase,mag}, ...
    'Role',{'phasediff','magnitude'}));
info=struct('size',[8 8 4],'trSeconds',2,'contract', ...
    struct('fieldmaps',f,'metadata',struct('PhaseEncodingDirection','j-', ...
    'TotalReadoutTime',.04)));
run=struct('subject','pilot','session','','name','task', ...
    'bold',bold,'sdcMethod','');
cfg=toolkit_config;cfg.sdc.method='spm_fieldmap_unwarp';
p=psy.preprocess_plan(run,info,cfg);
verifyEqual(testCase,p.sdc.method,'spm_fieldmap_unwarp');
verifyEqual(testCase,p.sdc.readoutMs,40);
verifyEqual(testCase,p.sdc.fieldmap.echoTimesMs,[4 6]);
info.contract.metadata.SPMTotalReadoutTimeMs=41;
p=psy.preprocess_plan(run,info,cfg);
verifyEqual(testCase,p.sdc.readoutMs,41);
info.contract.metadata=rmfield(info.contract.metadata,'SPMTotalReadoutTimeMs');
info.contract.metadata.PhaseEncodingDirection='i-';
verifyError(testCase,@()psy.preprocess_plan(run,info,cfg), ...
    'psy:SPMUnwarpDirection');
run.sdcMethod='spm_fieldmap_applyvdm';
cfg.sdc.spm.matchVdm=false; % 非 y 轴的 GRE 场需先对齐，不能使用本机 y 轴 MatchVDM。
p=psy.preprocess_plan(run,info,cfg);
verifyEqual(testCase,p.sdc.phaseEncodingAxis,1);
f=rmfield(f,'SPMBlipDirection');info.contract.fieldmaps=f;
verifyError(testCase,@()psy.preprocess_plan(run,info,cfg), ...
    'psy:SPMBlipDirection');
f=struct('Type','fieldmap_hz','Units','Hz','SPMBlipDirection',-1, ...
    'Images',struct('Path',phase,'Role','fieldmap_hz'));
info.contract.fieldmaps=f;
jsonPath=fullfile(folder,'fieldmaps_hz.json');
fid=fopen(jsonPath,'w');fprintf(fid,'%s',jsonencode(f));fclose(fid);
run.fieldmaps=jsonPath;
inventory=psy.inspect_contract(run,info);
verifyEqual(testCase,inventory.fieldmapsStatus,'inventory_checked_correction_pending');
p=psy.preprocess_plan(run,info,cfg);
verifyEmpty(testCase,p.sdc.fieldmap.magnitude);
cfg.sdc.spm.maskBrain=true;
verifyError(testCase,@()psy.preprocess_plan(run,info,cfg), ...
    'psy:SPMHzMask');
end

function testManifestPerRunMethodOverride(testCase)
folder=tempname;mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
bold=fullfile(folder,'bold.nii'); t1=fullfile(folder,'t1.nii');
niftiwrite(ones(8,8,4,3,'single'),bold);
niftiwrite(ones(8,8,4,'single'),t1);
manifest=fullfile(folder,'runs.tsv'); fid=fopen(manifest,'w');
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\tsdc_method\n');
fprintf(fid,'pilot\tbaseline\ttask\t%s\t%s\traw\tspm_fieldmap_applyvdm\n',bold,t1);
fclose(fid);
cfg=toolkit_config;cfg.manifestFile=manifest;
r=psy.read_manifest(cfg);
verifyEqual(testCase,r.sdcMethod,'spm_fieldmap_applyvdm');
end

function testSegmentDeformationChoicesAndFullPipelineGuard(testCase)
cfg=toolkit_config;
choices={'none','inverse','forward','inverse_forward'};
expected={[0 0],[1 0],[0 1],[1 1]};
for k=1:numel(choices)
    cfg.segment.deformationFields=choices{k};
    verifyEqual(testCase,psy.deformation_field_flags(choices{k}),expected{k});
    cfg.stopAfter='segment';
    psy.validate_preprocess_config(cfg);
    cfg.stopAfter='smooth';
    flags=expected{k};
    if flags(2)
        psy.validate_preprocess_config(cfg);
    else
        verifyError(testCase,@()psy.validate_preprocess_config(cfg), ...
            'psy:ForwardDeformationRequired');
    end
end
verifyError(testCase,@()psy.deformation_field_flags('backward'), ...
    'psy:DeformationFields');
cfg.segment.deformationFields='forward';
cfg.segment.biasRegularisation=0; % SPM 菜单允许关闭偏置正则化。
cfg.segment.biasFwhmMm=Inf; % SPM 菜单的“不做偏置场校正”。
cfg.segment.gaussians=[8 8 8 8 8 8];
psy.validate_preprocess_config(cfg);
cfg.segment.gaussians(1)=9;
verifyError(testCase,@()psy.validate_preprocess_config(cfg),'psy:PreprocessConfig');
end
