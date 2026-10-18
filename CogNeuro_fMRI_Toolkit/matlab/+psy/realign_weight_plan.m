function plan=realign_weight_plan(run,cfg,bold)
%REALIGN_WEIGHT_PLAN 解析可选估计权重图，并按 SPM 世界坐标核查参考 EPI 覆盖。
% 默认无权重；TSV realign_weight 的路径覆盖全局，none 明确禁用。
% 允许不同体素网格，SPM 按仿射采样；重叠不等于解剖对齐，仍需人工叠加检查。
value=''; source='default';
if isfield(cfg.realign,'weightImage')
    value=text_value(cfg.realign.weightImage); source='config';
end
if isfield(run,'realignWeightImage')
    override=text_value(run.realignWeightImage);
    if ~isempty(override), value=override; source='manifest'; end
end
plan=struct('enabled',false,'path','','source',source,'sha256','', ...
    'weightSize',[],'referenceSize',[],'positiveReferenceVoxels',0);
if isempty(value) || strcmpi(value,'none'), return; end
if ~java.io.File(value).isAbsolute()
    error('psy:RealignWeightPath','全局 Weighting 请填绝对路径；TSV 相对路径由清单读取器解析');
end
value=char(java.io.File(value).getCanonicalPath());
if ~isfile(value) || ~endsWith(lower(value),{'.nii','.nii.gz'})
    error('psy:RealignWeightPath','Weighting 必须为存在的 .nii/.nii.gz 文件: %s',value);
end
local=value;
if endsWith(lower(value),'.gz')
    folder=tempname; mkdir(folder);
    cleanup=onCleanup(@()rmdir(folder,'s'));
    local=psy.stage_image(value,folder);
end
v=spm_vol(local);
if numel(v)~=1
    error('psy:RealignWeightShape','Weighting 必须为单幅三维图，不能用多帧 BOLD');
end
values=spm_read_vols(v); % SPM 会应用 NIfTI 数值缩放。
if any(~isfinite(values(:))) || any(values(:)<0) || ~any(values(:)>0.01)
    error('psy:RealignWeightValues','权重须有限、非负，且至少有值 >0.01；SPM 仅保留权重 >0.01 的采样位置');
end
ref=spm_vol(bold); ref=ref(1);
if any(~isfinite(v.mat(:))) || any(~isfinite(ref.mat(:))) || ...
        abs(det(v.mat(1:3,1:3)))<eps || abs(det(ref.mat(1:3,1:3)))<eps
    error('psy:RealignWeightGeometry','权重图与参考 EPI 必须具有有效的空间仿射');
end
map=v.mat\ref.mat; count=0;
[x,y]=ndgrid(1:ref.dim(1),1:ref.dim(2));
for slice=1:ref.dim(3)
    coords=map*[x(:)';y(:)';slice*ones(1,numel(x));ones(1,numel(x))];
    samples=spm_sample_vol(v,coords(1,:),coords(2,:),coords(3,:),1);
    count=count+nnz(isfinite(samples) & samples>0.01);
end
if count==0
    error('psy:RealignWeightOverlap','权重图在参考 EPI 上没有 >0.01 的有效覆盖；请检查空间对齐');
end
plan.enabled=true; plan.path=value; plan.sha256=file_hash(value);
plan.weightSize=v.dim; plan.referenceSize=ref.dim;
plan.positiveReferenceVoxels=count;
end

function value=text_value(value)
if ~(ischar(value) && (isrow(value)||isempty(value))) && ...
        ~(isstring(value) && isscalar(value) && ~ismissing(value))
    error('psy:RealignWeightPath','Weighting 应为路径字符串、空字符串或 none');
end
value=strtrim(char(value));
end

function hash=file_hash(file)
fid=fopen(file,'rb');
if fid<0, error('psy:RealignWeightPath','无法读取 Weighting: %s',file); end
cleanup=onCleanup(@()fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes), digest.update(typecast(bytes,'int8')); end
end
hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
end
