function plan = preprocess_plan(run,info,cfg)
%PREPROCESS_PLAN 一次运行前的逐 run 参数解析；缺失元数据立即报错，不猜方向。
% HCP 专属文件名和协议只在此适配层使用；SPM/FSL 计算层不包含被试编号。
plan=struct;
method=char(string(cfg.sdc.method));
if isfield(run,'sdcMethod') && ~isempty(run.sdcMethod)
    method=char(string(run.sdcMethod)); % TSV 中 sdc_method 可逐 run 覆盖总配置。
end
allowed={'none','fsl_topup','spm_fieldmap_unwarp','spm_fieldmap_applyvdm','spm_unwarp','spm_vdm_only'};
if ~ismember(method,allowed), error('psy:SDCMethod','不支持的畸变校正方法: %s',method); end
if strcmp(method,'spm_vdm_only')
    plan.slice=struct('enabled',false,'mode','not_applied_vdm_only');
    plan.realignWeight=psy.realign_weight_plan(struct('realignWeightImage','none'),cfg,run.bold);
    plan.realignWeight.source='disabled_by_vdm_only';
else
    plan.slice=psy.slice_timing_plan(run,info,cfg);
    plan.realignWeight=psy.realign_weight_plan(run,cfg,run.bold);
end
plan.sdc=struct('method',method);
if ~strcmp(method,'spm_vdm_only') && strcmp(cfg.stopAfter,'smooth')
    flags=psy.deformation_field_flags(cfg.segment.deformationFields);
    if ~flags(2), error('psy:ForwardDeformationRequired','该 run 的完整空间链需要前向形变场'); end
end
if strcmp(method,'none'), return; end
if ~strcmp(cfg.inputStage,'raw')
    error('psy:SDCStage','新畸变校正只能接收 raw；已经校正的影像不能重复校正');
end
if strcmp(method,'fsl_topup')
    if strcmp(cfg.inputMode,'hcp')
        source=hcp_pepolar(run,info,cfg);
    else
        source=manifest_pepolar(info);
    end
    if ~isfield(run,'sbref') || ~isfile(run.sbref)
        error('psy:SDCSBRef','FSL TOPUP→BOLD 分支需要该 run 的原始 SBRef');
    end
    plan.sdc.topupSpec=struct('subject',run.subject,'session',run.session,'run',run.name, ...
        'negative',source.negative,'positive',source.positive, ...
        'negativeDirection',source.negativeDirection, ...
        'positiveDirection',source.positiveDirection, ...
        'negativeReadoutSeconds',source.negativeReadoutSeconds, ...
        'positiveReadoutSeconds',source.positiveReadoutSeconds);
    plan.sdc.boldSpec=struct('subject',run.subject,'session',run.session,'run',run.name, ...
        'topupDir','','sbref',run.sbref,'bold',run.bold, ...
        'boldDirection',source.boldDirection, ...
        'boldReadoutSeconds',source.boldReadoutSeconds);
    % 调用现有 TOPUP 预检，提前拒绝不相反的编码或不一致网格。
    check=struct('affineTolerance',cfg.sdc.affineTolerance,'fslConfig',cfg.sdc.fslConfig);
    psy.topup_validate(plan.sdc.topupSpec,check);
    return;
end
plan.sdc=psy.prepare_spm_sdc(run,info,cfg,method);
end

function source=manifest_pepolar(info)
if ~isfield(info.contract,'fieldmaps') || ~isfield(info.contract,'metadata')
    error('psy:TOPUPMetadata','FSL TOPUP 需要 pepolar fieldmaps JSON 和 BOLD metadata JSON');
end
f=info.contract.fieldmaps; m=info.contract.metadata;
if ~strcmp(f.Type,'pepolar') || numel(f.Images)~=2
    error('psy:TOPUPFieldMaps','当前统一入口每 run 需要恰好一对相反方向 SE-EPI');
end
if ~isfield(m,'PhaseEncodingDirection') || ~isfield(m,'TotalReadoutTime')
    error('psy:TOPUPMetadata','BOLD metadata 缺少方向或总读出时间');
end
a=f.Images(1); b=f.Images(2);
if endsWith(a.PhaseEncodingDirection,'-')
    negative=a;positive=b;
elseif endsWith(b.PhaseEncodingDirection,'-')
    negative=b;positive=a;
else
    error('psy:TOPUPDirection','SE-EPI 需要正、负一对编码方向');
end
source=struct('negative',negative.Path,'positive',positive.Path, ...
    'negativeDirection',negative.PhaseEncodingDirection, ...
    'positiveDirection',positive.PhaseEncodingDirection, ...
    'negativeReadoutSeconds',negative.TotalReadoutTime, ...
    'positiveReadoutSeconds',positive.TotalReadoutTime, ...
    'boldDirection',m.PhaseEncodingDirection, ...
    'boldReadoutSeconds',m.TotalReadoutTime);
end

function source=hcp_pepolar(run,info,cfg)
if ~isfield(cfg,'hcp') || ~isfield(cfg.hcp,'echoSpacingSeconds')
    error('psy:HCPAcquisition','HCP 示例需要显式的有效 echo spacing 配置');
end
folder=fileparts(run.bold);
negative=fullfile(folder,sprintf('%s_3T_SpinEchoFieldMap_LR.nii.gz',run.subject));
positive=fullfile(folder,sprintf('%s_3T_SpinEchoFieldMap_RL.nii.gz',run.subject));
if ~isfile(negative) || ~isfile(positive)
    error('psy:HCPFieldMaps','该 HCP run 缺少原始 LR/RL SpinEchoFieldMap');
end
spacing=cfg.hcp.echoSpacingSeconds;
if ~isscalar(spacing) || ~isfinite(spacing) || spacing<=0 || spacing>=0.01
    error('psy:HCPAcquisition','HCP echoSpacingSeconds 必须是有效的秒数');
end
if endsWith(run.name,'_LR')
    bd=cfg.hcp.lrBoldDirection;
elseif endsWith(run.name,'_RL')
    bd=cfg.hcp.rlBoldDirection;
else
    error('psy:HCPDirection','HCP run 名未明确 LR/RL 方向');
end
negdir=cfg.hcp.negativeDirection; posdir=cfg.hcp.positiveDirection;
hn=niftiinfo(negative); hp=niftiinfo(positive);
nd=find('ijk'==negdir(1)); pd=find('ijk'==posdir(1)); bdaxis=find('ijk'==bd(1));
source=struct('negative',negative,'positive',positive, ...
    'negativeDirection',negdir,'positiveDirection',posdir, ...
    'negativeReadoutSeconds',(hn.ImageSize(nd)-1)*spacing, ...
    'positiveReadoutSeconds',(hp.ImageSize(pd)-1)*spacing, ...
    'boldDirection',bd,'boldReadoutSeconds',(info.size(bdaxis)-1)*spacing);
end

