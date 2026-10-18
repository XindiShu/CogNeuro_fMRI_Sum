function plan=bold_unwarp_validate(spec,cfg)
%BOLD_UNWARP_VALIDATE 检查已完成 TOPUP 场、SBRef、BOLD 与 PE 参数。
required={'subject','session','run','topupDir','sbref','bold','boldDirection','boldReadoutSeconds'};
if ~all(isfield(spec,required)), error('psy:BoldUnwarpMetadata','缺少被试/run、TOPUP 目录、SBRef/BOLD 或 PE 元数据'); end
complete=fullfile(spec.topupDir,'TOPUP_COMPLETE.json');
if ~isfile(complete), error('psy:BoldUnwarpTopup','TOPUP 完成记录不存在'); end
record=jsondecode(fileread(complete));
if ~strcmp(record.status,'topup_estimated') && ~strcmp(record.status,'topup_estimated_bold_direct_apply_engineering')
    error('psy:BoldUnwarpTopup','TOPUP 状态不是完成');
end
field=fullfile(spec.topupDir,'field_hz.nii.gz');
se=fullfile(spec.topupDir,'se_unwarped_mean.nii.gz');
for p={field,se,spec.sbref,spec.bold}
    if ~isfile(p{1}), error('psy:BoldUnwarpInput','输入不存在: %s',p{1}); end
end
hf=psy.nifti_geometry(field); hs=psy.nifti_geometry(se);
hr=psy.nifti_geometry(spec.sbref); hb=psy.nifti_geometry(spec.bold);
ds=dims(hs); df=dims(hf); dr=dims(hr); db=dims(hb);
sameGrid(hs,hf,ds,df,cfg.affineTolerance,'SE 参考与 Hz 场');
sameGrid(hr,hb,dr,db,cfg.affineTolerance,'SBRef 与 BOLD');
if ds(4)~=1 || df(4)~=1 || dr(4)~=1 || db(4)<2
    error('psy:BoldUnwarpGeometry','场/SE/SBRef 必须为 3D，BOLD 必须为至少两帧的 4D');
end
v=direction(spec.boldDirection);
t=spec.boldReadoutSeconds;
if ~isnumeric(t)||~isscalar(t)||~isfinite(t)||t<=0||t>=1
    error('psy:BoldUnwarpReadout','BOLD 总读出时间须为 (0,1) 内的秒数');
end
axis=find(v~=0); dwell=double(t)/(db(axis)-1);
if ~isfinite(dwell)||dwell<=0, error('psy:BoldUnwarpReadout','无效的 BOLD 有效回波间隔'); end
plan=struct('boldFrames',db(4),'boldSize',db(1:3),'seSize',ds(1:3), ...
    'phaseVector',v,'phaseAxis',axis,'boldReadoutSeconds',double(t), ...
    'effectiveEchoSpacingSeconds',dwell,'fieldHz',field,'seMagnitude',se);
end
function d=dims(h)
d=double(h.ImageSize);d(end+1:4)=1;
if numel(d)>4||any(d(1:3)<2), error('psy:BoldUnwarpGeometry','仅支持 3D/4D NIfTI'); end
end
function sameGrid(a,b,da,db,tol,name)
if ~isequal(da(1:3),db(1:3))||norm(a.Transform.T-b.Transform.T,'fro')>tol
    error('psy:BoldUnwarpGeometry','%s 网格/仿射矩阵不一致',name);
end
end
function v=direction(label)
switch char(string(label))
    case 'i',v=[1 0 0];
    case 'i-',v=[-1 0 0];
    case 'j',v=[0 1 0];
    case 'j-',v=[0 -1 0];
    case 'k',v=[0 0 1];
    case 'k-',v=[0 0 -1];
    otherwise,error('psy:BoldUnwarpDirection','BOLD 编码方向必须为 NIfTI i/i-/j/j-/k/k-');
end
end
