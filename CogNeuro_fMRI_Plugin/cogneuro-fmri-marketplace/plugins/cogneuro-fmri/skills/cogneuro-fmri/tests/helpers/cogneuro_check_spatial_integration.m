function audit=cogneuro_check_spatial_integration(attempt,fixtureFile,resultFile)
%COGNEURO_CHECK_SPATIAL_INTEGRATION 只读核对已完成全链路，并在新目录验证另一选图交接。
% [约束] 不重跑分割/配准/GLM；不覆盖原始数据、主链路或已有检查结果。
assert(~isfile(resultFile),'Audit result exists');
review=jsondecode(fileread(fullfile(attempt,'review.json')));fixture=jsondecode(fileread(fixtureFile));
addpath(review.spm_root,fullfile(review.toolkit_root,'matlab'),fullfile(attempt,'adapter'),'-begin');
receipt=jsondecode(fileread(fullfile(attempt,'receipt.json')));pre=receipt.result.preprocessing;
assert(numel(pre.runs)==1&&strcmp(pre.status,'complete'));
r=pre.runs;out=r.output_path;
assert(all(ismember({'spm_segment','coregister_estimate','normalise_write','smooth'},r.executed_steps)));
for name={'03_segment.mat','04_coregister.mat','05_normalise.mat','06_smooth.mat','SEGMENT_COMPLETE.mat','SMOOTHING_COMPLETE.mat'}
    assert(isfile(fullfile(out,name{1})),name{1});
end
native=load(fullfile(out,'input_info.mat'),'cfg','run');cfg=native.cfg;
seg=load(fullfile(out,'SEGMENT_COMPLETE.mat'),'result');segment=seg.result;
assert(strcmp(segment.backend,'spm')&&isfile(segment.forward));
for k=1:numel(segment.requiredOutputs),assert(isfile(segment.requiredOutputs{k}));end
batch=load(fullfile(out,'03_segment.mat'),'matlabbatch');
[expectedBatch,~]=psy.spm_segment_batch({segment.t1},segment.plan,cfg);
assert(isequaln(batch.matlabbatch,expectedBatch),'Executed Segment batch differs from executed configuration');
coreg=load(fullfile(out,'04_coregister.mat'),'matlabbatch');coreg=coreg.matlabbatch{1}.spm.spatial.coreg.estimate;
assert(strcmp(coreg.ref{1},[segment.t1 ',1']));
assert(isequal(coreg.eoptions,struct('cost_fun',cfg.coreg.costFunction,'sep',cfg.coreg.separationMm, ...
    'tol',cfg.coreg.tolerance,'fwhm',cfg.coreg.smoothingFwhmMm)));
normalise=load(fullfile(out,'05_normalise.mat'),'matlabbatch');normalise=normalise.matlabbatch{1}.spm.spatial.normalise.write;
assert(strcmp(normalise.subj.def{1},segment.forward));
assert(isequal(normalise.woptions,struct('bb',cfg.boundingBoxMm,'vox',cfg.voxelSizeMm,'interp',cfg.normalise.interpolation,'prefix','w')));
scans=arrayfun(@(k)sprintf('%s,%d',r.realigned_bold,k),(1:fixture.retained_frames)', 'UniformOutput',false);
assert(isequal(coreg.other,scans));
assert(numel(normalise.subj.resample)==numel(scans)+1&&isequal(normalise.subj.resample(1:numel(scans)),scans));
assert(strcmp(normalise.subj.resample{end},coreg.source{1}));
sm=load(fullfile(out,'SMOOTHING_COMPLETE.mat'),'record');record=sm.record;
assert(strcmp(record.input,r.normalized_bold)&&strcmp(record.output,r.smoothed_bold));
assert(strcmp(record.prefix,'g')&&strcmp(record.requestedDataType,'float32')&&record.effectiveDataTypeCode==16);
[folder,stem,extension]=fileparts(r.normalized_bold);
assert(strcmp(r.smoothed_bold,fullfile(folder,['g' stem extension])));
assert(isequal(record.requestedImplicitMasking,cfg.smooth.implicitMasking));
assert(isequal(record.fwhmMm,fixture.smoothing_fwhm_mm')||isequal(record.fwhmMm,fixture.smoothing_fwhm_mm));
assert(record.nVolumes==fixture.retained_frames&&record.trSeconds==fixture.tr_seconds);
for file={r.normalized_bold,r.smoothed_bold}
    volumes=spm_vol(file{1});assert(numel(volumes)==fixture.retained_frames);
    for k=1:numel(volumes)
        assert(isequal(volumes(k).dim,fixture.expected_dimensions(:)'));
        assert(max(abs(volumes(k).mat-fixture.expected_affine),[],'all')<1e-5);
    end
end
% 原先已知8mm的EPI偏移需降到一个4mm测试体素内；此指标只适用于本合成构造。
after=spm_vol(coreg.source{1});before=fixture.raw_bold_affine;target=fixture.native_t1_affine;
corners=[1 1 1 1;20 1 1 1;1 20 1 1;1 1 20 1]';
reference=target*corners;initial=before*corners;aligned=after.mat*corners;
initialError=sqrt(mean(sum((initial(1:3,:)-reference(1:3,:)).^2,1)));
finalError=sqrt(mean(sum((aligned(1:3,:)-reference(1:3,:)).^2,1)));
assert(finalError<4&&finalError<initialError,'Known synthetic coregistration displacement was not corrected');
handoff=receipt.result.handoff;chosen=handoff.runs;
assert(strcmp(chosen.bold,r.smoothed_bold));
mask=spm_read_vols(spm_vol(chosen.mask))>0;
model=receipt.result.glm.runs.output_path;
estimated=load(fullfile(model,'models','joint','SPM.mat'),'SPM');
contrastFile=estimated.SPM.xCon(1).Vcon.fname;
if ~java.io.File(contrastFile).isAbsolute(),contrastFile=fullfile(model,'models','joint',contrastFile);end
contrast=spm_read_vols(spm_vol(contrastFile));
values=contrast(mask);assert(all(isfinite(values)));effect=mean(values);assert(effect>0);
% 复用同一完成记录，只写另一个全新交接目录；不重新执行任何空间处理。
altRoot=fullfile(fileparts(resultFile),'normalized_handoff');
job=struct('schema_version',1,'route','handoff','mode','execute','toolkit_root',review.toolkit_root, ...
    'spm_root',review.spm_root,'output_root',altRoot,'preprocessing_result_file',fullfile(attempt,'execution_result.json'), ...
    'options',struct('bold_source','normalized_unsmoothed','include_tissue_means',false), ...
    'expected_runs',review.staged_expected_runs);
alt=cogneuro_preprocess_handoff(job);
assert(strcmp(alt.status,'complete')&&strcmp(alt.runs.bold,r.normalized_bold));
assert(strcmp(psy.file_sha256(alt.runs.events),psy.file_sha256(chosen.events)));
assert(strcmp(psy.file_sha256(alt.runs.confounds),psy.file_sha256(chosen.confounds)));
% 另一项独立的合成停止点测试；科学选项变化明确记录，仅适用于开发幻影。
% 不沿用真实用户确认、不复用主链路输出，验证segment确实不继续Coreg/Normalise/Smooth。
segmentJob=jsondecode(fileread(fullfile(attempt,'execution_job.json')));
segmentJob.options.preprocessing.stop_after='segment';
segmentJob.work_root=fullfile(fileparts(resultFile),'segment_only_work');
segmentJob.output_root=fullfile(fileparts(resultFile),'segment_only_results');
segmentJob.result_file=fullfile(fileparts(resultFile),'segment_only_result.json');
writeJson(fullfile(fileparts(resultFile),'segment_only_job.json'),segmentJob);
segmentOnly=cogneuro_preprocess_adapter(segmentJob);writeJson(segmentJob.result_file,segmentOnly);
assert(strcmp(segmentOnly.status,'complete')&&isfile(fullfile(segmentOnly.runs.output_path,'SEGMENT_COMPLETE.mat')));
assert(isempty(segmentOnly.runs.normalized_bold)&&isempty(segmentOnly.runs.smoothed_bold));
for name={'04_coregister.mat','05_normalise.mat','06_smooth.mat','SMOOTHING_COMPLETE.mat'}
    assert(~isfile(fullfile(segmentOnly.runs.output_path,name{1})),name{1});
end
audit=struct('status','passed','real_participant_data',false,'segment_batch_matches_executed_configuration',true, ...
    'coreg_batch_matches_executed_configuration',true,'normalise_batch_matches_executed_configuration',true, ...
    'normalized_and_smoothed_grid_checked',true,'custom_smoothing_prefix','g','smoothing_fwhm_mm',record.fwhmMm, ...
    'retained_frames',record.nVolumes,'tr_seconds',record.trSeconds,'dimensions',fixture.expected_dimensions, ...
    'initial_known_coreg_displacement_mm',initialError,'remaining_coreg_displacement_mm',finalError, ...
    'known_A_gt_B_mean_contrast',effect,'primary_glm_input','smoothed','alternate_handoff_input','normalized_unsmoothed', ...
    'both_handoffs_identical_events_and_confounds',true,'segment_only_stop_checked',true, ...
    'separate_segment_test_approval','synthetic_development_only','scientific_qc_passed',false);
writeJson(resultFile,audit);
end
function writeJson(file,value)
assert(~isfile(file),'Refuse to overwrite audit evidence');
f=fopen(file,'w','n','UTF-8');assert(f>0);cleanup=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'%s',jsonencode(value,PrettyPrint=true));
end
