function f=inspect_fieldmaps(file)
%INSPECT_FIELDMAPS 核对逐 run 场图清单；保持原始影像不变。
% 相位使用真实弧度，绝不按图像极值推测厂商单位；VDM 使用体素位移。
f=jsondecode(fileread(file));
types={'pepolar','phasediff','phase_magnitude','real_imaginary','fieldmap_hz','vdm'};
if ~isfield(f,'Type') || ~ismember(f.Type,types) || ...
        ~isfield(f,'Images') || isempty(f.Images)
    error('psy:FieldmapSchema','场图需要 Type 和 Images；支持 pepolar/phasediff/phase_magnitude/real_imaginary/fieldmap_hz/vdm');
end
base=fileparts(file);
for k=1:numel(f.Images)
    image=f.Images(k);
    if ~isfield(image,'Path'), error('psy:FieldmapSchema','Image Path missing'); end
    p=image.Path;
    if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
    p=char(java.io.File(p).getCanonicalPath());
    h=niftiinfo(p);
    if ~strcmp(f.Type,'pepolar')
        if ~isfield(image,'Role'), error('psy:FieldmapSchema','SPM 场图需要 Role'); end
        magnitude=startsWith(image.Role,'magnitude');
        valid3D=numel(h.ImageSize)==3;
        validMagnitude4D=magnitude && numel(h.ImageSize)==4 && ismember(h.ImageSize(4),[1 2]);
        if ~valid3D && ~validMagnitude4D
            error('psy:FieldmapShape','相位/实虚部/Hz/VDM 须为 3D；幅度图可为双回波 4D');
        end
    else
        if ~all(isfield(image,{'PhaseEncodingDirection','TotalReadoutTime'}))
            error('psy:FieldmapSchema','PE metadata missing');
        end
        direction(image.PhaseEncodingDirection); positive(image.TotalReadoutTime);
    end
    f.Images(k).Path=p;
end
switch f.Type
    case 'pepolar'
        pe={f.Images.PhaseEncodingDirection}; paired=false;
        for k=1:numel(pe)
            paired=paired || (any(strcmp(pe,[erase(pe{k},'-') '-'])) && any(strcmp(pe,erase(pe{k},'-'))));
        end
        if ~paired, error('psy:FieldmapPair','No opposite encoding pair'); end
        return;
    case 'phasediff', roles={'phasediff','magnitude'};
    case 'phase_magnitude', roles={'phase1','magnitude1','phase2','magnitude2'};
    case 'real_imaginary', roles={'real1','imaginary1','real2','imaginary2'};
    case 'fieldmap_hz', roles={'fieldmap_hz'};
    case 'vdm', roles={'vdm'};
end
actual={f.Images.Role};
if strcmp(f.Type,'fieldmap_hz') && any(strcmp(actual,'magnitude')), roles{end+1}='magnitude'; end
if numel(actual)~=numel(roles) || ~isequal(sort(actual),sort(roles))
    error('psy:FieldmapSchema','%s 需要且只接受角色: %s',f.Type,strjoin(roles,', '));
end
if ismember(f.Type,{'phasediff','phase_magnitude','real_imaginary'})
    if ~all(isfield(f,{'EchoTime1','EchoTime2'})), error('psy:FieldmapSchema','需要两回波时间，单位秒'); end
    positive(f.EchoTime1); positive(f.EchoTime2);
    if f.EchoTime2<=f.EchoTime1, error('psy:FieldmapSchema','EchoTime2 必须大于 EchoTime1'); end
end
if ismember(f.Type,{'phasediff','phase_magnitude'})
    if ~isfield(f,'Units') || ~strcmp(f.Units,'rad'), error('psy:FieldmapSchema','相位单位必须明确为 rad'); end
elseif strcmp(f.Type,'fieldmap_hz')
    if ~isfield(f,'Units') || ~strcmp(f.Units,'Hz'), error('psy:FieldmapSchema','预计算场图必须为 Hz'); end
elseif strcmp(f.Type,'vdm')
    if ~isfield(f,'Units') || ~ismember(f.Units,{'voxel','voxels'}), error('psy:FieldmapSchema','VDM 单位必须为 voxel'); end
end
reference=[];
for k=1:numel(f.Images)
    p=f.Images(k).Path; role=f.Images(k).Role; h=niftiinfo(p);
    values=double(niftiread(p)); slope=h.MultiplicativeScaling;
    if slope==0, slope=1; end
    values=values*slope+h.AdditiveOffset;
    if any(~isfinite(values(:))), error('psy:FieldmapValues','场图数值必须有限: %s',role); end
    if startsWith(role,'phase') && (min(values(:)) < -pi-0.01 || max(values(:)) > pi+0.01)
        error('psy:PhaseUnits','相位须为 [-pi,+pi] rad，不能直接使用厂商整数相位');
    end
    if startsWith(role,'magnitude') && (any(values(:)<0) || ~any(values(:)>0))
        error('psy:FieldmapValues','幅度图应非负且不能全零');
    end
    if ismember(f.Type,{'phase_magnitude','real_imaginary'})
        grid=struct('size',h.ImageSize(1:3),'affine',h.Transform.T);
        if isempty(reference), reference=grid;
        elseif ~isequal(grid.size,reference.size) || norm(grid.affine-reference.affine,'fro')>1e-4
            error('psy:FieldmapGeometry','双回波四幅图须同网格同仿射，不自动猜配准');
        end
    end
end
end
function positive(v)
if ~isnumeric(v)||~isscalar(v)||~isfinite(v)||v<=0, error('psy:MetadataValue','采集时间须为正秒数'); end
end
function direction(v)
if ~ischar(v)||~ismember(v,{'i','i-','j','j-','k','k-'}), error('psy:PEDirection','使用 NIfTI i/j/k 方向'); end
end
