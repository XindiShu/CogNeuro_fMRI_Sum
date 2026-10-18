function status = process_run(run, info, cfg, out, plan)
%PROCESS_RUN Independently process a run; mean EPI is registered to native T1.
% Each run has a private anatomical copy so concurrent jobs cannot mutate it.
% 通用计算层：run.bold/run.t1 已由适配器解析为文件路径，不在本文件填被试编号。
% 所有用户常改的 SPM/FSL 方法和数值参数集中在 toolkit_config.m。
if nargin<5, plan=psy.preprocess_plan(run,info,cfg); end
if ~isfield(plan,'dummy'), plan.dummy=psy.dummy_plan(run,info,cfg); end
if ~isfield(plan,'realignWeight'), plan.realignWeight=psy.realign_weight_plan(run,cfg,run.bold); end
normalise=psy.normalise_options(cfg);
if ~strcmp(normalise.method,'segmentation')&&strcmp(cfg.stopAfter,'smooth')&& ...
        ~strcmp(plan.sdc.method,'spm_vdm_only')&&~isfield(plan,'normalise')
    error('psy:NormaliseContext','群体路线须通过 preprocess_batch 准备完整模板上下文');
end
if ~isfield(plan,'segment') && ismember(cfg.stopAfter,{'segment','smooth'}) && ~strcmp(plan.sdc.method,'spm_vdm_only')
    plan.segment=psy.segment_plan(run,cfg); % 直接调用也必须在创建输出前检查解剖输入。
end
stamp=cfg; stamp.execute=[]; stamp.resume=[]; stamp.continueOnError=[];
sourceFiles=dir(fullfile(fileparts(mfilename('fullpath')),'*.m'));
codeText=cellfun(@(f)fileread(fullfile(fileparts(mfilename('fullpath')),f)),{sourceFiles.name},'UniformOutput',false);
sourcePaths={run.bold,run.t1};
sourcePaths=sourcePaths(~cellfun(@isempty,sourcePaths));
if plan.realignWeight.enabled, sourcePaths{end+1}=plan.realignWeight.path; end
if isfield(plan,'segment'),sourcePaths=[sourcePaths,plan.segment.inputFiles];end
if isfield(plan,'normalise'),sourcePaths{end+1}=plan.normalise.groupComplete;end
for field={'events','metadata','fieldmaps','provenance'}
    if isfield(run,field{1}) && isfile(run.(field{1}))
        sourcePaths{end+1}=run.(field{1}); %#ok<AGROW>
    end
end
if strcmp(plan.sdc.method,'fsl_topup')
    sourcePaths=[sourcePaths,{plan.sdc.topupSpec.negative,plan.sdc.topupSpec.positive,run.sbref}];
elseif isfield(plan.sdc,'fieldmap')
    sourcePaths=[sourcePaths,plan.sdc.fieldmap.files];
end
if isfield(plan.sdc,'referenceSource') && ~isempty(plan.sdc.referenceSource)
    sourcePaths{end+1}=plan.sdc.referenceSource;
end
inputs=cell2mat(cellfun(@dir,sourcePaths,'UniformOutput',false));
signature=jsonencode(struct('cfg',stamp,'inputBytes',[inputs.bytes], ...
    'inputDates',[inputs.datenum],'bold',run.bold,'t1',run.t1, ...
    'plan',plan,'code',{codeText}));
done=fullfile(out,'COMPLETE.mat');
if isfile(done) && cfg.resume
    prior=load(done);
    if strcmp(prior.signature,signature) && all(cellfun(@isfile,prior.requiredOutputs))
        status='reused_completed_run'; return;
    end
    error('psy:ChangedConfig','Outputs differ or are missing; choose a new outputRoot');
end
if isfolder(out)
    error('psy:ExistingOutput','Partial/existing run directory: %s. Inspect it, then use a new outputRoot.',out);
end
mkdir(out); save(fullfile(out,'input_info.mat'),'info','run','cfg','plan');
fid=fopen(fullfile(out,'preprocessing_plan.json'),'w');
fprintf(fid,'%s',jsonencode(plan,PrettyPrint=true)); fclose(fid);
diary(fullfile(out,'spm_log.txt')); cleanup=onCleanup(@()diary('off'));
requiredOutputs={fullfile(out,'preprocessing_plan.json')};
sourceBold=run.bold;
if plan.dummy.count>0
    % 删除只发生在私有副本中，先于 STC、FSL BOLD 校正和 SPM 头动步骤。
    dummyDir=fullfile(out,'dummy_trim'); mkdir(dummyDir);
    sourceBold=psy.trim_dummy_bold(run.bold,plan.dummy.count,info.trSeconds,dummyDir,plan.dummy.originalVolumes);
    eventCopy=psy.write_dummy_events(run,plan.dummy,dummyDir);
    if ~isempty(eventCopy), requiredOutputs{end+1}=eventCopy; end
    fid=fopen(fullfile(dummyDir,'dummy_provenance.json'),'w');
    fprintf(fid,'%s',jsonencode(plan.dummy,PrettyPrint=true)); fclose(fid);
    requiredOutputs=[requiredOutputs,{sourceBold,fullfile(dummyDir,'dummy_provenance.json')}];
end
if strcmp(plan.sdc.method,'fsl_topup')
    % 已有 TOPUP/FSL 算法模块作为可选步骤纳入同一个 run，两个中间目录只属该 run。
    tc=struct('outputRoot',fullfile(out,'fsl_topup'),'wslDistro',cfg.sdc.wslDistro, ...
        'fslRoot',cfg.sdc.fslRoot,'fslConfig',cfg.sdc.fslConfig, ...
        'threads',cfg.sdc.threads,'affineTolerance',cfg.sdc.affineTolerance, ...
        'execute',true,'applyToBold',false);
    topup=psy.topup_run(plan.sdc.topupSpec,tc);
    bc=struct('outputRoot',fullfile(out,'fsl_bold_unwarp'), ...
        'wslDistro',cfg.sdc.wslDistro,'fslRoot',cfg.sdc.fslRoot, ...
        'affineTolerance',cfg.sdc.affineTolerance, ...
        'registrationSearchDegrees',cfg.sdc.registrationSearchDegrees, ...
        'jacobianModulation',cfg.sdc.jacobianModulation,'execute',true);
    bs=plan.sdc.boldSpec;bs.topupDir=topup.outputDir;bs.bold=sourceBold;
    corrected=psy.bold_unwarp_run(bs,bc);
    sourceBold=fullfile(corrected.outputDir,'bold_unwarped.nii.gz');
    if cfg.sdc.jacobianModulation
        sourceBold=fullfile(corrected.outputDir,'bold_unwarped_jac.nii.gz');
    end
    requiredOutputs=[requiredOutputs,{fullfile(topup.outputDir,'TOPUP_COMPLETE.json'), ...
        fullfile(topup.outputDir,'se_unwarped_mean.nii.gz'), ...
        fullfile(corrected.outputDir,'BOLD_UNWARP_COMPLETE.json'),sourceBold}];
end
bold=psy.stage_image(sourceBold,out);
if strcmp(plan.sdc.method,'spm_vdm_only')
    [~,fieldOutputs]=psy.spm_fieldmap_vdm(plan.sdc,bold,out,cfg);
    requiredOutputs=[requiredOutputs,fieldOutputs];
    status='vdm_generated_only';
    assert(all(cellfun(@isfile,requiredOutputs)),'VDM 输出缺失');
    save(done,'signature','status','requiredOutputs'); return;
end
v=spm_vol(bold); scans=arrayfun(@(k)sprintf('%s,%d',bold,k),(1:numel(v))','UniformOutput',false);
if plan.slice.enabled
    b={}; b{1}.spm.temporal.st.scans={scans};
    b{1}.spm.temporal.st.nslices=info.size(3); b{1}.spm.temporal.st.tr=info.trSeconds;
    b{1}.spm.temporal.st.ta=0; % Timing-vector mode: SPM timing = [0 TR].
    b{1}.spm.temporal.st.so=plan.slice.sliceSeconds*1000;
    b{1}.spm.temporal.st.refslice=plan.slice.referenceSeconds*1000;
    b{1}.spm.temporal.st.prefix='a';
    psy.spm_step(b,fullfile(out,'01_slice_timing.mat'));
    [folder,name,ext]=fileparts(bold); bold=fullfile(folder,['a' name ext]);
end
motion=psy.spm_motion_step(bold,numel(v),cfg,out,plan.sdc,plan.realignWeight);
requiredOutputs=[requiredOutputs,motion.fieldOutputs];
if ~isempty(motion.weightImage)
    requiredOutputs=[requiredOutputs,{motion.weightImage,fullfile(out,'realign_weighting','weight_info.mat')}];
end
meanImage=motion.mean; realigned=motion.series;rp=motion.motion;
psy.motion_qc(rp,cfg.fdRadiusMm,cfg.fdFlagMm,out);
requiredOutputs=[requiredOutputs,{realigned,rp,fullfile(out,'motion.tsv')}];
if ~isempty(meanImage), requiredOutputs{end+1}=meanImage; end
if ~isempty(motion.vdm), requiredOutputs=[requiredOutputs,{motion.vdm}]; end
correctedInput=strcmp(cfg.inputStage,'sdc_corrected') || ~strcmp(plan.sdc.method,'none');
if correctedInput && ~isempty(meanImage)
    % float32 校正后 BOLD 经 SPM mask=1 头动重采样可能在共同视野外写 NaN。
    % 保留原 r*.nii；另写有限值副本与全程有效掩膜，不把缺失体素纳入时间 QC。
    finalized=psy.finalize_realign(realigned,meanImage,fullfile(out,'finite_realign'), ...
        maskFraction=cfg.qc.maskFraction,maxNonfiniteFraction=cfg.qc.maxResliceNonfiniteFraction);
    realigned=finalized.cleanSeries;
    requiredOutputs=[requiredOutputs,{finalized.cleanSeries,finalized.maskFile, ...
        fullfile(out,'finite_realign','summary.json')}];
end
if isfield(cfg,'qc') && cfg.qc.enabled && ~isempty(meanImage)
    qcDir=fullfile(out,'timeseries_qc');
    if correctedInput
        psy.timeseries_qc(realigned,meanImage,rp,qcDir,maskFile=finalized.maskFile, ...
            fdRadiusMm=cfg.fdRadiusMm,fdFlagMm=cfg.fdFlagMm);
    else
        psy.timeseries_qc(realigned,meanImage,rp,qcDir,maskFraction=cfg.qc.maskFraction, ...
            fdRadiusMm=cfg.fdRadiusMm,fdFlagMm=cfg.fdFlagMm);
    end
    requiredOutputs=[requiredOutputs,{fullfile(qcDir,'QC_COMPLETE.mat'),fullfile(qcDir,'summary.json')}];
elseif isempty(meanImage)
    note='resliceImages=all 未输出均值，时序 QC 未执行；仅保留运动 QC。';
    save(fullfile(out,'TIMESERIES_QC_SKIPPED.mat'),'note');
end
status='realigned_without_distortion_correction';
if strcmp(cfg.inputStage,'sdc_corrected')
    status='realigned_after_susceptibility_correction';
elseif correctedInput
    status=['realigned_after_' plan.sdc.method];
end
if ismember(cfg.stopAfter,{'segment','smooth'})
    if ~isfield(plan,'segment'),plan.segment=psy.segment_plan(run,cfg);end
    context=[];if isfield(plan,'normalise'),context=plan.normalise;end
    requiredOutputs=[requiredOutputs,psy.spatial_steps(run,cfg,out,realigned,meanImage,numel(v),plan.segment,context)];
    if strcmp(cfg.stopAfter,'segment')
        status='segmented_without_distortion_correction';
        if strcmp(cfg.inputStage,'sdc_corrected')
            status='segmented_after_susceptibility_correction';
        elseif correctedInput
            status=['segmented_after_' plan.sdc.method];
        end
    else
        status='spatial_pipeline_without_distortion_correction';
        if strcmp(cfg.inputStage,'sdc_corrected')
            status='spatial_pipeline_after_susceptibility_correction';
        elseif correctedInput
            status=['spatial_pipeline_after_' plan.sdc.method];
        end
    end
end
assert(all(cellfun(@isfile,requiredOutputs)),'Expected SPM outputs are missing');
save(done,'signature','status','requiredOutputs');
end
