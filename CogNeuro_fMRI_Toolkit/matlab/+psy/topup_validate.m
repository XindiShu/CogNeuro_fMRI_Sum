function plan = topup_validate(spec,cfg)
%TOPUP_VALIDATE 检查反向 PE 场图，并生成 TOPUP 所需采集参数。
% 所有方向均指 NIfTI i/j/k 体素轴；文件名中的 LR/RL 不参与推断。
required={'negative','positive','negativeDirection','positiveDirection', ...
    'negativeReadoutSeconds','positiveReadoutSeconds'};
if ~all(isfield(spec,required)), error('psy:TopupMetadata','缺少场图路径、方向或总读出时间'); end
for name={'negative','positive'}
    if ~isfile(spec.(name{1})), error('psy:TopupInput','场图不存在: %s',spec.(name{1})); end
end
a=niftiinfo(spec.negative); b=niftiinfo(spec.positive);
da=dims(a); db=dims(b);
if ~isequal(da(1:3),db(1:3)) || norm(a.Transform.T-b.Transform.T,'fro')>cfg.affineTolerance
    error('psy:TopupGeometry','两组 SE-EPI 必须使用相同网格/仿射矩阵');
end
v1=pevector(spec.negativeDirection); v2=pevector(spec.positiveDirection);
if ~isequal(v1,-v2), error('psy:TopupDirection','两组 SE-EPI 必须同轴反向编码'); end
t1=readout(spec.negativeReadoutSeconds); t2=readout(spec.positiveReadoutSeconds);
if isfield(spec,'bold') && ~isempty(spec.bold)
    if ~isfile(spec.bold), error('psy:TopupInput','BOLD 不存在: %s',spec.bold); end
    bold=niftiinfo(spec.bold); d=dims(bold);
    if ~isequal(da(1:3),d(1:3)) || norm(a.Transform.T-bold.Transform.T,'fro')>cfg.affineTolerance
        error('psy:TopupGeometry','当前实现要求 BOLD/SBRef 与 SE-EPI 网格一致；不能仅靠文件名推断配准');
    end
    if ~all(isfield(spec,{'boldDirection','boldReadoutSeconds'}))
        error('psy:TopupMetadata','应用到 BOLD 前必须提供其编码方向和总读出时间');
    end
    vb=pevector(spec.boldDirection); tb=readout(spec.boldReadoutSeconds);
    if ~(isequal(vb,v1)||isequal(vb,v2)), error('psy:TopupDirection','BOLD 编码轴与场图不同'); end
else
    vb=[]; tb=[];
end
plan=struct('negativeVolumes',da(4),'positiveVolumes',db(4), ...
    'negativeVector',v1,'positiveVector',v2,'negativeReadoutSeconds',t1, ...
    'positiveReadoutSeconds',t2,'boldVector',vb,'boldReadoutSeconds',tb, ...
    'imageSize',da(1:3),'affine',a.Transform.T);
if any(mod(plan.imageSize,2)) && endsWith(cfg.fslConfig,'b02b0.cnf')
    error('psy:TopupSubsample','b02b0.cnf 要求三个维度均为偶数；请改用 b02b0_1.cnf');
end
end

function d=dims(info)
d=double(info.ImageSize); d(end+1:4)=1;
if numel(d)>4 || any(d(1:3)<2) || any(~isfinite(d)), error('psy:TopupGeometry','需要 3D/4D NIfTI'); end
end
function v=pevector(label)
label=char(string(label));
switch label
    case 'i', v=[1 0 0];
    case 'i-',v=[-1 0 0];
    case 'j', v=[0 1 0];
    case 'j-',v=[0 -1 0];
    case 'k', v=[0 0 1];
    case 'k-',v=[0 0 -1];
    otherwise, error('psy:TopupDirection','方向必须为 i/i-/j/j-/k/k-，不能用解剖 LR/RL 标签');
end
end
function t=readout(value)
if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<=0||value>=1
    error('psy:TopupReadout','总读出时间须为 (0,1) 内的秒数');
end
t=double(value);
end
