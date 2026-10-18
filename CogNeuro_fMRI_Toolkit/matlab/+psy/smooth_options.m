function s = smooth_options(cfg)
%SMOOTH_OPTIONS 普通 SPM Smooth 菜单；旧配置缺 smooth 时保持原有行为。
% 用户只改配置：dataType 为类型名称，implicitMasking 为 true/false，prefix 非空。
% 三轴 FWHM 继续用 cfg.smoothingFwhmMm，不再维护可能矛盾的“各向性”开关。
s=struct('dataType','same','implicitMasking',false,'prefix','s');
if isfield(cfg,'smooth')
    if ~isstruct(cfg.smooth)||~isscalar(cfg.smooth)
        error('psy:SmoothConfig','cfg.smooth 须为标量 struct');
    end
    for name=fieldnames(s)'
        if isfield(cfg.smooth,name{1}),s.(name{1})=cfg.smooth.(name{1});end
    end
end
s.dataType=text_value(s.dataType,'dataType');s.dataType=lower(s.dataType);
names={'same','uint8','int16','int32','float32','float64'};codes=[0 2 4 8 16 64];
index=find(strcmp(s.dataType,names),1);
if isempty(index),error('psy:SmoothConfig','smooth.dataType=same/uint8/int16/int32/float32/float64');end
s.dtypeCode=codes(index);
if ~(isnumeric(s.implicitMasking)||islogical(s.implicitMasking)) || ...
        ~isscalar(s.implicitMasking)||~ismember(s.implicitMasking,[0 1])
    error('psy:SmoothConfig','smooth.implicitMasking 须为 false/true 或 0/1');
end
s.implicitMasking=logical(s.implicitMasking);
s.prefix=text_value(s.prefix,'prefix');
if isempty(regexp(s.prefix,'^[A-Za-z][A-Za-z0-9_]*$','once'))
    error('psy:SmoothConfig','smooth.prefix 须非空、字母开头，后续只含字母/数字/下划线');
end
f=cfg.smoothingFwhmMm;
if ~isnumeric(f)||~isreal(f)||~isequal(size(f),[1 3])||any(~isfinite(f))||any(f<0)
    error('psy:SmoothConfig','smoothingFwhmMm 须为三个有限非负毫米值；[6 6 6]等方性，[6 6 4]各向异性');
end
n=psy.normalise_options(cfg);
s.native=~strcmp(n.method,'segmentation')&&strcmp(n.group.writeMethod,'native');
if s.native&&strcmp(cfg.stopAfter,'smooth')
    if max(f)-min(f)>1e-8
        error('psy:NormaliseNativeSmoothing','native 需等方性核；各向异性请选择 group.writeMethod=deformations');
    end
    if ~strcmp(s.dataType,'same')||s.implicitMasking
        error('psy:SmoothNativeOptions', ...
            ['DARTEL/Shooting native 没有普通 Smooth 的 dtype/im 菜单；请保持 same/false，' ...
             '或明确选择 group.writeMethod=deformations 使用类型/隐式掩模选项。']);
    end
end
end
function value=text_value(value,name)
if isstring(value)&&isscalar(value)&&~ismissing(value),value=char(value);end
if ~ischar(value)||(~isempty(value)&&~isrow(value))
    error('psy:SmoothConfig','smooth.%s 须为单个字符行或标量字符串',name);
end
end
