function requiredOutputs = spatial_steps(run,cfg,out,realigned,meanImage,nVolumes,segmentPlan,context)
%SPATIAL_STEPS 用 SPM 的 Segment、Coregister、Normalise、Smooth 处理一个 run。
% 计算参数只从 toolkit_config.m / preprocess_config.m 取得；原始 T1 只读。
% stopAfter=segment 只完成 T1 分割；stopAfter=smooth 需要前向 y_ 形变场。
[meanFolder,meanName,meanExt]=fileparts(meanImage);
[seriesFolder,seriesName,seriesExt]=fileparts(realigned);
if nargin<7, segmentPlan=psy.segment_plan(run,cfg); end
if nargin<8,context=[];end
if isempty(context)
    seg=psy.segment_run(run,cfg,out,segmentPlan);
else
    seg=context.anatomy.segment;
    seg.forward=context.anatomy.forward;seg.inverse=context.anatomy.inverse;
    seg.requiredOutputs=[seg.requiredOutputs,{context.groupComplete,seg.forward,seg.inverse}];
end
t1=seg.t1;deformation=seg.forward;requiredOutputs=seg.requiredOutputs;
if strcmp(segmentPlan.atlasOptions.target,'t1')
    requiredOutputs=[requiredOutputs,psy.apply_atlases(segmentPlan,seg.inverse,t1,out)];
end
if strcmp(cfg.stopAfter,'segment')
    % none / inverse 两种输出选择在此结束；不伪造后续 MNI 标准化结果。
    return;
end

reslicedScans=arrayfun(@(k)sprintf('%s,%d',realigned,k),(1:nVolumes)', ...
    'UniformOutput',false);
b={}; b{1}.spm.spatial.coreg.estimate=struct('ref',{{[t1 ',1']}}, ...
    'source',{{[meanImage ',1']}},'other',{reslicedScans});
b{1}.spm.spatial.coreg.estimate.eoptions=struct( ...
    'cost_fun',cfg.coreg.costFunction,'sep',cfg.coreg.separationMm, ...
    'tol',cfg.coreg.tolerance,'fwhm',cfg.coreg.smoothingFwhmMm);
psy.spm_step(b,fullfile(out,'04_coregister.mat'));
if strcmp(segmentPlan.atlasOptions.target,'bold')
    requiredOutputs=[requiredOutputs,psy.apply_atlases(segmentPlan,seg.inverse,meanImage,out)];
end
if ~isempty(context)
    requiredOutputs=[requiredOutputs,psy.group_normalise_write(context,cfg,out,realigned,meanImage,nVolumes)];return;
end
b={}; b{1}.spm.spatial.normalise.write.subj=struct('def',{{deformation}}, ...
    'resample',{[reslicedScans;{[meanImage ',1']} ]});
b{1}.spm.spatial.normalise.write.woptions=struct('bb',cfg.boundingBoxMm, ...
    'vox',cfg.voxelSizeMm,'interp',cfg.normalise.interpolation,'prefix','w');
psy.spm_step(b,fullfile(out,'05_normalise.mat'));
normalized=fullfile(seriesFolder,['w' seriesName seriesExt]);
[smoothed,record]=psy.smooth_run(normalized,cfg,fullfile(out,'06_smooth.mat'));
smoothComplete=fullfile(out,'SMOOTHING_COMPLETE.mat');save(smoothComplete,'record');
requiredOutputs=[requiredOutputs,{normalized, ...
    smoothed,fullfile(meanFolder,['w' meanName meanExt]),smoothComplete}];
end
