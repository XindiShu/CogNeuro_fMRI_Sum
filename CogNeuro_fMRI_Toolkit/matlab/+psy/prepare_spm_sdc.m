function sdc=prepare_spm_sdc(run,info,cfg,method)
%PREPARE_SPM_SDC 准备静态场图、已有 VDM 或无 VDM 的动态 Unwarp。
options=psy.sdc_spm_options(cfg);
sdc=struct('method',method,'options',options,'referenceSource','');
m=struct;
if isfield(info.contract,'metadata'), m=info.contract.metadata; end
if strcmp(options.distortionAxis,'metadata')
    if ~isfield(m,'PhaseEncodingDirection')
        error('psy:SPMFieldMapMetadata','需要 metadata.PhaseEncodingDirection，或明确选择 distortionAxis=i/j/k');
    end
    axisIndex=find('ijk'==m.PhaseEncodingDirection(1));
else
    axisIndex=find('ijk'==options.distortionAxis);
    if isfield(m,'PhaseEncodingDirection') && m.PhaseEncodingDirection(1)~=options.distortionAxis
        error('psy:SPMDistortionAxis','手选轴与采集 JSON 冲突；请核查原始协议');
    end
end
if isempty(axisIndex), error('psy:SPMDistortionAxis','无效畸变轴'); end
sdc.phaseEncodingAxis=axisIndex;
if ismember(method,{'spm_fieldmap_unwarp','spm_unwarp'})
    % 本机 SPM Unwarp 在工作图像 y 轴校正；世界 AP/PA 还须同时一致。
    h=niftiinfo(run.bold); vector=h.Transform.T(axisIndex,1:3);
    if axisIndex~=2 || norm(vector)==0 || abs(vector(2))/norm(vector)<0.9
        error('psy:SPMUnwarpDirection','Unwarp 要求 NIfTI j 工作轴且近似 AP/PA；其他方向用 Apply VDM，不自动重排图像');
    end
end
if ~strcmp(method,'spm_vdm_only') && strcmp(options.resliceImages,'all') && ~strcmp(cfg.stopAfter,'realign')
    error('psy:SDCOutputChoice','all 不写均值，只可 stopAfter=realign；完整空间链请选择 all_mean');
end
if strcmp(method,'spm_unwarp'), return; end % 不要求场图、TE 或读出时间。
switch options.referenceEpi
    case 'sbref'
        if ~isfield(run,'sbref') || ~isfile(run.sbref), error('psy:SDCReference','sbref 模式缺少 SBRef'); end
        sdc.referenceSource=run.sbref;
    case 'manifest'
        if ~isfield(run,'fieldmapEpi') || ~isfile(run.fieldmapEpi)
            error('psy:SDCReference','manifest 模式需 TSV fieldmap_epi 的三维 EPI 文件');
        end
        sdc.referenceSource=run.fieldmapEpi;
    case 'volume'
        if isfield(info,'nVolumes')
            discard=cfg.discardVolumes;
            if isfield(run,'discardVolumes') && ~isempty(run.discardVolumes), discard=run.discardVolumes; end
            if options.referenceVolume>info.nVolumes-discard
                error('psy:SDCReference','referenceVolume 超出删除 dummy 后的帧数');
            end
        end
end
if ~isempty(sdc.referenceSource)
    h=niftiinfo(sdc.referenceSource);
    if numel(h.ImageSize)~=3, error('psy:SDCReference','代表 EPI/SBRef 必须为单幅三维影像'); end
end
if ~isfield(info.contract,'fieldmaps')
    error('psy:SPMFieldMapMetadata','这条路线需要逐 run fieldmaps JSON；无场图选 spm_unwarp');
end
f=info.contract.fieldmaps;
if ~ismember(f.Type,{'phasediff','phase_magnitude','real_imaginary','fieldmap_hz','vdm'})
    error('psy:SPMFieldMapType','SPM 路线不把反向 PE 图当作 GRE 场图，请选 fsl_topup');
end
source=struct('type',f.Type,'files',{{f.Images.Path}});
for k=1:numel(f.Images), source.(f.Images(k).Role)=f.Images(k).Path; end
if strcmp(f.Type,'vdm')
    if options.writeReferenceEpi && cfg.sdc.spm.jacobianModulation
        error('psy:SPMReferenceJacobian','已有 VDM 的 Apply VDM 参考图没有此 Jacobian 菜单，请关闭 FieldMap 调制');
    end
    same_grid(source.vdm,run.bold,cfg.sdc.affineTolerance,'导入 VDM');
    sdc.fieldmap=source; return; % 已有位移，不重新使用 TE/readout/blip 缩放。
end
if ~isfield(m,'TotalReadoutTime')
    error('psy:SPMFieldMapMetadata','计算 VDM 需要 metadata.TotalReadoutTime，单位秒');
end
readout=m.TotalReadoutTime;
if ~isnumeric(readout)||~isscalar(readout)||~isfinite(readout)||readout<=0||readout>=1
    error('psy:SPMReadout','TotalReadoutTime 必须是 (0,1) 秒内的实测值');
end
blip=cfg.sdc.spm.blipDirection;
if isfield(f,'SPMBlipDirection'), blip=f.SPMBlipDirection; end
if ~isscalar(blip)||~ismember(blip,[-1 1])
    error('psy:SPMBlipDirection','需核实 SPM blip 极性 -1/+1，不从 BIDS 符号猜测');
end
sdc.blipDirection=blip; sdc.readoutMs=readout*1000;
if isfield(m,'SPMTotalReadoutTimeMs')
    v=m.SPMTotalReadoutTimeMs;
    if ~isnumeric(v)||~isscalar(v)||~isfinite(v)||v<=0, error('psy:SPMReadout','SPMTotalReadoutTimeMs 必须为正实测值'); end
    sdc.readoutMs=v;
end
if strcmp(f.Type,'fieldmap_hz')
    source.hz=source.fieldmap_hz; source.echoTimesMs=[1 2]; % API 要求 et，但 Hz 输入不使用差分 TE。
    if ~isfield(source,'magnitude'), source.magnitude=''; end
    if cfg.sdc.spm.maskBrain
        error('psy:SPMHzMask','预计算 Hz 已应做好掩膜；本机 CreateFieldMap 不处理该输入的 Mask Brain');
    end
    if isempty(source.magnitude) || ~options.matchVdm
        same_grid(source.hz,run.bold,cfg.sdc.affineTolerance,'预计算 Hz');
    end
else
    source.echoTimesMs=[f.EchoTime1 f.EchoTime2]*1000;
    if strcmp(f.Type,'phasediff'), source.phase=source.phasediff; end
end
canMatch=~strcmp(f.Type,'fieldmap_hz') || ~isempty(source.magnitude);
if options.writeReferenceEpi && cfg.sdc.spm.jacobianModulation && axisIndex~=2
    error('psy:SPMReferenceJacobian','本机 FieldMap 参考图调制沿 y；其他轴使用不调制的 Apply VDM');
end
if options.matchVdm && canMatch && axisIndex~=2
    error('psy:SPMMatchDirection','本机 MatchVDM 沿 y 建模；其他轴须预先对齐场图并设 matchVdm=false');
end
for k=1:numel(f.Images)
    if startsWith(f.Images(k).Role,'magnitude')
        h=niftiinfo(f.Images(k).Path); frames=1;
        if numel(h.ImageSize)==4, frames=h.ImageSize(4); end
        if options.magnitudeVolume>frames, error('psy:SDCMagnitudeFrame','magnitudeVolume 超出幅度图帧数'); end
    end
end
sdc.fieldmap=source;
end
function same_grid(a,b,tolerance,name)
ha=niftiinfo(a); hb=niftiinfo(b);
if ~isequal(ha.ImageSize(1:3),hb.ImageSize(1:3)) || norm(ha.Transform.T-hb.Transform.T,'fro')>tolerance
    error('psy:SPMHzAlignment','%s 须已与当前 EPI 同网格同仿射；不自动猜配准',name);
end
end
