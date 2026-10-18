function validate_preprocess_config(cfg)
%VALIDATE_PREPROCESS_CONFIG 在昂贵步骤前核对集中配置是否为 SPM 可接受的值。
% 各项允许值来自本机 SPM12 的 config/spm_cfg_*.m 和 FieldMap batch。
if ~isnumeric(cfg.discardVolumes) || ~isscalar(cfg.discardVolumes) || ...
        ~isfinite(cfg.discardVolumes) || cfg.discardVolumes<0 || ...
        cfg.discardVolumes~=floor(cfg.discardVolumes)
    error('psy:Discard','discardVolumes 必须为非负整数');
end
if isfield(cfg,'dicom') && isfield(cfg.dicom,'enabled')
    flag(cfg.dicom.enabled,'dicom.enabled');
end
v=cfg.realign;
if isfield(v,'weightImage') && ...
        ~((ischar(v.weightImage) && (isrow(v.weightImage)||isempty(v.weightImage))) || ...
        (isstring(v.weightImage) && isscalar(v.weightImage) && ~ismissing(v.weightImage)))
    error('psy:RealignWeightPath','realign.weightImage 应为路径字符串、空字符串或 none');
end
range(v.quality,0,1,'realign.quality');
positive(v.separationMm,'realign.separationMm');
nonnegative(v.smoothingFwhmMm,'realign.smoothingFwhmMm');
if ~ismember(v.estimateInterpolation,1:7)
    error('psy:PreprocessConfig','realign.estimateInterpolation 应为本机 SPM 菜单的 1..7');
end
interp(v.writeInterpolation,'realign.writeInterpolation');
flag(v.registerToMean,'realign.registerToMean');flag(v.mask,'realign.mask');
if ~isequal(size(v.wrap),[1 3]) || any(~ismember(v.wrap,[0 1]))
    error('psy:PreprocessConfig','realign.wrap 必须是 3 个 0/1');
end
s=cfg.segment;
psy.segment_options(cfg);psy.atlas_options(cfg); % 新菜单采用兼容默认值。
if ~ismember(s.biasRegularisation,[0 1e-5 1e-4 1e-3 1e-2 0.1 1 10])
    error('psy:PreprocessConfig','segment.biasRegularisation 不在本机 SPM 菜单候选值内');
end
if ~ismember(s.biasFwhmMm,[30:10:150 Inf])
    error('psy:PreprocessConfig','segment.biasFwhmMm 应为 30:10:150 或 Inf');
end
if ~isequal(size(s.gaussians),[1 6]) || any(~ismember(s.gaussians,1:8))
    error('psy:PreprocessConfig','segment.gaussians 必须为六个 1..8 整数；本接口暂不支持 SPM Nonparametric');
end
if ~ismember(s.affineRegistration,{'','mni','eastern','subj','none'}) || ...
        ~ismember(s.cleanup,[0 1 2]) || ~isscalar(s.mrf)
    error('psy:PreprocessConfig','Segment 配置不在 SPM 支持范围');
end
nonnegative(s.mrf,'segment.mrf');
deformationFlags=psy.deformation_field_flags(s.deformationFields);
n=psy.normalise_options(cfg);
if strcmp(cfg.stopAfter,'smooth') && strcmp(n.method,'segmentation') && ~deformationFlags(2) && ~strcmp(cfg.sdc.method,'spm_vdm_only')
    error('psy:ForwardDeformationRequired', ...
        '完整 MNI 标准化需要前向 y_ 场；选 none/inverse 时请设 stopAfter=segment');
end
if numel(s.warpRegularisation)~=5 || any(~isfinite(s.warpRegularisation)) || any(s.warpRegularisation<0)
    error('psy:PreprocessConfig','segment.warpRegularisation 应有五个非负值');
end
positive(s.warpSamplingMm,'segment.warpSamplingMm');
c=cfg.coreg;
if ~ismember(c.costFunction,{'mi','nmi','ecc','ncc'})
    error('psy:PreprocessConfig','coreg.costFunction 应为 mi/nmi/ecc/ncc');
end
positive(c.separationMm,'coreg.separationMm');
nonnegative(c.smoothingFwhmMm,'coreg.smoothingFwhmMm');
if numel(c.tolerance)~=12 || any(~isfinite(c.tolerance)) || any(c.tolerance<=0)
    error('psy:PreprocessConfig','coreg.tolerance 应为十二个正数');
end
interp(cfg.normalise.interpolation,'normalise.interpolation');
if ~isnumeric(cfg.boundingBoxMm)||~isequal(size(cfg.boundingBoxMm),[2 3]) || any(~isfinite(cfg.boundingBoxMm(:))) || ...
        any(cfg.boundingBoxMm(1,:)>=cfg.boundingBoxMm(2,:))
    error('psy:PreprocessConfig','boundingBoxMm 应为 2×3 且下界小于上界');
end
if numel(cfg.voxelSizeMm)~=3 || numel(cfg.smoothingFwhmMm)~=3
    error('psy:PreprocessConfig','voxelSizeMm 和 smoothingFwhmMm 应各有 3 项');
end
positive(cfg.voxelSizeMm,'voxelSizeMm');
nonnegative(cfg.smoothingFwhmMm,'smoothingFwhmMm');
psy.smooth_options(cfg); % 兼容旧配置；新菜单与native限制在昂贵计算前检查。
if ~strcmp(n.method,'segmentation')&&strcmp(cfg.stopAfter,'smooth')&&strcmp(n.group.writeMethod,'native') && ...
        max(cfg.smoothingFwhmMm)-min(cfg.smoothingFwhmMm)>1e-8
    error('psy:NormaliseNativeSmoothing','原生 DARTEL/Shooting 写出需等方性平滑；各向异性请选 deformations');
end
f=cfg.sdc.spm;
options=psy.sdc_spm_options(cfg);
flag(options.matchVdm,'sdc.spm.matchVdm'); flag(options.writeReferenceEpi,'sdc.spm.writeReferenceEpi');
if ~ismember(options.referenceEpi,{'first','volume','mean','sbref','manifest'}) || ...
        ~ismember(options.distortionAxis,{'metadata','i','j','k'}) || ...
        ~ismember(options.resliceImages,{'all','all_mean'})
    error('psy:PreprocessConfig','无效的 SPM 代表 EPI/畸变轴/输出集合选择');
end
for name={'referenceVolume','magnitudeVolume'}
    value=options.(name{1});
    if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<1||value~=floor(value)
        error('psy:PreprocessConfig','%s 须为正整数帧编号',name{1});
    end
end
if isempty(regexp(options.outputPrefix,'^[A-Za-z][A-Za-z0-9_]*$','once'))
    error('psy:PreprocessConfig','outputPrefix 须为字母开头的字母/数字/下划线前缀');
end
interp(f.applyVdmInterpolation,'sdc.spm.applyVdmInterpolation');
if ~ismember(f.unwrapMethod,{'Mark3D','Mark2D','Huttonish'})
    error('psy:PreprocessConfig','SPM FieldMap 展开方法不受支持');
end
positive(f.unwrapFwhmMm,'sdc.spm.unwrapFwhmMm');
if ~isscalar(f.unwrapPadding) || f.unwrapPadding~=floor(f.unwrapPadding)
    error('psy:PreprocessConfig','sdc.spm.unwrapPadding 必须为非负整数');
end
nonnegative(f.unwrapPadding,'sdc.spm.unwrapPadding');
nonnegative(f.maskFwhmMm,'sdc.spm.maskFwhmMm');
for name={'maskErode','maskDilate'}
    x=f.(name{1});
    if ~isscalar(x) || ~isfinite(x) || x<0 || x~=floor(x)
        error('psy:PreprocessConfig','sdc.spm.%s 必须为非负整数',name{1});
    end
end
range(f.maskThreshold,0,1,'sdc.spm.maskThreshold');
positive(f.maskRegularisation,'sdc.spm.maskRegularisation');
for name={'epiBased','maskBrain','jacobianModulation','weightedSmoothing'}
    flag(f.(name{1}),['sdc.spm.' name{1}]);
end
u=cfg.unwarp;
if ~any(cellfun(@(x)isequal(u.basisFunctions,x),{[8 8],[10 10],[12 12],[14 14]})) || ...
        ~ismember(u.regularisationOrder,0:3) || ...
        ~ismember(u.regularisationWeight,[10000 100000 1000000]) || ...
        ~ismember(u.expansionPoint,{'Average','First','Last'})
    error('psy:PreprocessConfig','SPM Unwarp 参数不在 batch 菜单范围');
end
if isempty(u.firstOrderEffects) || any(~ismember(u.firstOrderEffects,1:6)) || ...
        any(~ismember(u.secondOrderEffects(:),1:6))
    error('psy:PreprocessConfig','Unwarp 运动效应索引应为 1..6');
end
positive(u.smoothingFwhmMm,'unwarp.smoothingFwhmMm');
flag(u.reestimateMotion,'unwarp.reestimateMotion');
flag(u.jacobianModulation,'unwarp.jacobianModulation');
positive(u.iterations,'unwarp.iterations');
if u.iterations~=floor(u.iterations)
    error('psy:PreprocessConfig','unwarp.iterations 必须为整数');
end
end

function positive(x,name)
if ~isnumeric(x) || isempty(x) || any(~isfinite(x(:))) || any(x(:)<=0)
    error('psy:PreprocessConfig','%s 应为有限正数',name);
end
end
function nonnegative(x,name)
if ~isnumeric(x) || isempty(x) || any(~isfinite(x(:))) || any(x(:)<0)
    error('psy:PreprocessConfig','%s 应为有限非负数',name);
end
end
function range(x,lo,hi,name)
if ~isnumeric(x) || ~isscalar(x) || ~isfinite(x) || x<lo || x>hi
    error('psy:PreprocessConfig','%s 应在 [%g,%g]',name,lo,hi);
end
end
function interp(x,name)
if ~isnumeric(x) || ~isscalar(x) || ~isfinite(x) || x~=floor(x) || ~ismember(x,0:7)
    error('psy:PreprocessConfig','%s 应为 SPM 支持的 0..7 插值阶数',name);
end
end
function flag(x,name)
if ~isscalar(x) || ~(islogical(x) || (isnumeric(x) && ismember(x,[0 1])))
    error('psy:PreprocessConfig','%s 应为 0/1',name);
end
end
