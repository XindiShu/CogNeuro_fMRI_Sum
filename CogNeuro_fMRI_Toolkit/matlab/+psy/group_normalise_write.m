function outputs=group_normalise_write(context,cfg,out,series,meanImage,nVolumes)
%GROUP_NORMALISE_WRITE 调用原生写出或已合成场的 Normalise Write，保留两类BOLD。
n=context.options;entry=context.anatomy;
psy.smooth_options(cfg); % 直接调用本函数时也提前拒绝不兼容选项。
if ~strcmp(psy.file_sha256(context.groupComplete),context.groupSha256)
    error('psy:NormaliseChanged','群体完成记录在 run 处理期间发生变化');
end
[folder,stem,ext]=fileparts(series);[mf,ms,me]=fileparts(meanImage);
if strcmp(n.group.writeMethod,'deformations')
    scans=arrayfun(@(k)sprintf('%s,%d',series,k),(1:nVolumes)','UniformOutput',false);
    b={};b{1}.spm.spatial.normalise.write=struct('subj',struct('def',{{entry.forward}}, ...
        'resample',{[scans;{[meanImage ',1']}]}),'woptions',struct('bb',cfg.boundingBoxMm, ...
        'vox',cfg.voxelSizeMm,'interp',n.interpolation,'prefix','w'));
    psy.spm_step(b,fullfile(out,'05_normalise.mat'));
    normalized=fullfile(folder,['w' stem ext]);meanNormalized=fullfile(mf,['w' ms me]);
    [smoothed,smoothing]=psy.smooth_run(normalized,cfg,fullfile(out,'06_smooth.mat'));
    effectiveInterpolation=n.interpolation;
else
    % Native GUI 写出仅使用固定三线性和等方性平滑；不忽略用户指定的各向异性核。
    if max(cfg.smoothingFwhmMm)-min(cfg.smoothingFwhmMm)>1e-8
        error('psy:NormaliseNativeSmoothing','native 需等方性平滑；各向异性核请选 deformations');
    end
    job=struct('template',{{context.finalTemplate}},'vox',cfg.voxelSizeMm, ...
        'bb',cfg.boundingBoxMm,'preserve',n.group.preserve,'fwhm',0);
    if strcmp(n.method,'dartel')
        job.data.subj=struct('flowfield',{{entry.registrationField}},'images',{{series,meanImage}});
        execution='spm_dartel_norm_fun';
    else
        job.data.subj=struct('deformation',{{entry.registrationField}},'images',{{series,meanImage}});
        execution='spm_shoot_norm';
    end
    save(fullfile(out,'05_normalise.mat'),'job','execution');result=feval(execution,job);
    normalized=result{1}{1};meanNormalized=result{1}{2};
    job.data.subj.images={series};job.fwhm=cfg.smoothingFwhmMm(1);
    save(fullfile(out,'06_native_smooth.mat'),'job','execution');
    if job.fwhm==0
        [f,s,e]=fileparts(normalized);smoothed=fullfile(f,['s' s e]);copyfile(normalized,smoothed);
    else
        result=feval(execution,job);smoothed=result{1}{1};
    end
    % 原生算法仍写默认s前缀；仅重命名本次新结果，不改SPM算法、不重复平滑。
    options=psy.smooth_options(cfg);
    [targetFolder,targetStem,targetExt]=fileparts(normalized);
    target=fullfile(targetFolder,[options.prefix targetStem targetExt]);
    if ~strcmp(smoothed,target)
        if isfile(target),error('psy:SmoothOutputExists','自定义前缀目标已存在，未覆盖：%s',target);end
        [ok,message]=movefile(smoothed,target);
        if ~ok,error('psy:SmoothRename','无法重命名本次原生平滑结果：%s',message);end
        smoothed=target;
    end
    smoothing=psy.smooth_record(cfg,normalized,smoothed,execution);
    effectiveInterpolation=1;
end
smoothComplete=fullfile(out,'SMOOTHING_COMPLETE.mat');record=smoothing;save(smoothComplete,'record');
outputs={normalized,meanNormalized,smoothed};
record=psy.normalise_output_check(series,outputs,nVolumes,cfg.voxelSizeMm);
record.method=n.method;record.writeMethod=n.group.writeMethod;record.preserve=n.group.preserve;
record.effectiveInterpolation=effectiveInterpolation;record.groupComplete=context.groupComplete;
record.normalized=normalized;record.smoothed=smoothed;record.meanNormalized=meanNormalized;
record.smoothing=smoothing;
save(fullfile(out,'NORMALISATION_COMPLETE.mat'),'record');
outputs=[outputs,{smoothComplete,fullfile(out,'NORMALISATION_COMPLETE.mat')}];
end
