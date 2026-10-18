function result=spm_motion_step(bold,nVolumes,cfg,out,sdc,weightPlan)
%SPM_MOTION_STEP 统一调用 SPM 头动估计及所选 FieldMap 校正分支。
% none/FSL 已校正：Realign Estimate & Reslice。
% SPM AP/PA：FieldMap VDM + Realign & Unwarp（联合头动与动态畸变）。
% SPM i/j/k：Realign Estimate + FieldMap VDM + Apply VDM（静态畸变）。
% 三条路线分别使用 SPM 自带 batch；这里不实现重采样算法。
v=spm_vol(bold);
if numel(v)~=nVolumes, error('psy:MotionFrames','工作影像帧数与输入检查不一致'); end
scans=arrayfun(@(k)sprintf('%s,%d',bold,k),(1:nVolumes)','UniformOutput',false);
[folder,name,ext]=fileparts(bold);
opt=cfg.realign;
if nargin<6, weightPlan=psy.realign_weight_plan(struct,cfg,bold); end
weight='';
if weightPlan.enabled
    % 在真正进入头动步骤的 EPI 上再核查；TOPUP/STC 后可能是不同的工作影像。
    current=psy.realign_weight_plan(struct('realignWeightImage',weightPlan.path),cfg,bold);
    if ~strcmp(current.sha256,weightPlan.sha256)
        error('psy:RealignWeightChanged','Weighting 在预检后发生变化；请重新预检并使用新输出目录');
    end
    weightDir=fullfile(out,'realign_weighting');
    weight=psy.stage_image(weightPlan.path,weightDir); % 只使用私有副本，gzip 在此解压。
    save(fullfile(weightDir,'weight_info.mat'),'weightPlan','current');
end
e=struct('quality',opt.quality,'sep',opt.separationMm, ...
    'fwhm',opt.smoothingFwhmMm,'rtm',double(opt.registerToMean), ...
    'interp',opt.estimateInterpolation,'wrap',opt.wrap,'weight',{{weight}});
method=sdc.method; options=psy.sdc_spm_options(cfg); fieldOutputs={};
which=[2 double(strcmp(options.resliceImages,'all_mean'))];
switch method
    case {'none','fsl_topup'}
        b={}; b{1}.spm.spatial.realign.estwrite.data={scans};
        b{1}.spm.spatial.realign.estwrite.eoptions=e;
        b{1}.spm.spatial.realign.estwrite.roptions=struct('which',[2 1], ...
            'interp',opt.writeInterpolation,'wrap',opt.wrap, ...
            'mask',double(opt.mask),'prefix','r');
        psy.spm_step(b,fullfile(out,'02_realign.mat'));
        % SPM 的均值图命名为 mean<估计输入名>，不是 meanr<输入名>。
        % 重采样序列才带 r 前缀；混淆二者会在 SPM 已成功运行后误报缺失。
        prefix='r'; meanPrefix='mean'; vdm='';
    case {'spm_fieldmap_unwarp','spm_unwarp'}
        vdm='';
        if strcmp(method,'spm_fieldmap_unwarp')
            [vdm,fieldOutputs]=psy.spm_fieldmap_vdm(sdc,bold,out,cfg);
        end
        b={}; b{1}.spm.spatial.realignunwarp.data=struct( ...
            'scans',{scans},'pmscan',{{vdm}});
        e.einterp=e.interp;e.ewrap=e.wrap;e=rmfield(e,{'interp','wrap'});
        b{1}.spm.spatial.realignunwarp.eoptions=e;
        u=cfg.unwarp;
        b{1}.spm.spatial.realignunwarp.uweoptions=struct( ...
            'basfcn',u.basisFunctions,'regorder',u.regularisationOrder, ...
            'lambda',u.regularisationWeight,'jm',double(u.jacobianModulation), ...
            'fot',u.firstOrderEffects,'sot',u.secondOrderEffects, ...
            'uwfwhm',u.smoothingFwhmMm,'rem',double(u.reestimateMotion), ...
            'noi',u.iterations,'expround',u.expansionPoint);
        b{1}.spm.spatial.realignunwarp.uwroptions=struct('uwwhich',which, ...
            'rinterp',opt.writeInterpolation,'wrap',opt.wrap, ...
            'mask',double(opt.mask),'prefix',options.outputPrefix);
        psy.spm_step(b,fullfile(out,'02_realign_unwarp.mat'));
        prefix=options.outputPrefix; meanPrefix=['mean' prefix];
    case 'spm_fieldmap_applyvdm'
        b={}; b{1}.spm.spatial.realign.estimate.data={scans};
        b{1}.spm.spatial.realign.estimate.eoptions=e;
        psy.spm_step(b,fullfile(out,'02_realign_estimate.mat'));
        [vdm,fieldOutputs]=psy.spm_fieldmap_vdm(sdc,bold,out,cfg);
        b={}; b{1}.spm.tools.fieldmap.applyvdm.data=struct( ...
            'scans',{scans},'vdmfile',{{vdm}});
        b{1}.spm.tools.fieldmap.applyvdm.roptions=struct( ...
            'pedir',sdc.phaseEncodingAxis,'which',which, ...
            'rinterp',cfg.sdc.spm.applyVdmInterpolation,'wrap',opt.wrap, ...
            'mask',double(opt.mask),'prefix',options.outputPrefix);
        psy.spm_step(b,fullfile(out,'03_apply_vdm.mat'));
        prefix=options.outputPrefix; meanPrefix=['mean' prefix];
    otherwise
        error('psy:MotionMethod','未知的头动/场图处理方法: %s',method);
end
result=struct('series',fullfile(folder,[prefix name ext]), ...
    'mean',fullfile(folder,[meanPrefix name ext]), ...
    'motion',fullfile(folder,['rp_' name '.txt']),'vdm',vdm,'method',method,'weightImage',weight, ...
    'fieldOutputs',{fieldOutputs});
if ~ismember(method,{'none','fsl_topup'}) && which(2)==0, result.mean=''; end
required={result.series,result.motion};
if ~isempty(result.mean), required{end+1}=result.mean; end
for p=required
    if ~isfile(p{1}), error('psy:MotionOutput','SPM 未产生预期输出: %s',p{1}); end
end
end
