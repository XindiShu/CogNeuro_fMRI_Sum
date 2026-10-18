function p=segment_plan(run,cfg)
%SEGMENT_PLAN 分割/图谱输入预检。JSON 路径相对 JSON 本身；不猜结构序列角色。
% 多通道输入必须是 NIfTI。新增通道不是 BOLD run，也不增加 TSV 的 run 行数。
s=psy.segment_options(cfg); a=psy.atlas_options(cfg);
p=struct('options',s,'deformationFlags',psy.deformation_field_flags(s.deformationFields), ...
    'channelsFile','','channels',struct([]),'atlasOptions',a,'atlasesFile','', ...
    'atlases',struct([]),'inputFiles',{{fullfile(cfg.spmPath,'tpm','TPM.nii')}},'hashes',{{}},'backendVersion','SPM12');
n=psy.normalise_options(cfg);
groupRoute=~strcmp(n.method,'segmentation')&&strcmp(cfg.stopAfter,'smooth');
if a.enabled && ~groupRoute
    if a.ensureInverse, p.deformationFlags(1)=1;
    elseif ~p.deformationFlags(1), error('psy:AtlasInverse','图谱应用需要 inverse/inverse_forward 或 ensureInverse=true'); end
end
channel=struct('Name','T1','Path',run.t1,'Volume',s.inputVolume, ...
    'BiasRegularisation',s.biasRegularisation,'BiasFwhmMm',s.biasFwhmMm,'SaveBias',s.saveBias);
file=pick(run,'anatomyChannels',s.channelsFile);
if ~isempty(file)
    file=absolute(file,''); j=jsondecode(fileread(file));
    if ~isfield(j,'Channels')||isempty(j.Channels), error('psy:AnatomyChannels','JSON 需要非空 Channels 数组'); end
    p.channelsFile=file; p.inputFiles{end+1}=file;
    channels=repmat(channel,1,numel(j.Channels));
    for k=1:numel(channels)
        c=j.Channels(k);
        if ~isfield(c,'Name')||~isfield(c,'Path'), error('psy:AnatomyChannels','每通道需要 Name 和 Path'); end
        channels(k).Name=upper(char(c.Name)); channels(k).Path=absolute(c.Path,fileparts(file));
        for n={'Volume','BiasRegularisation','BiasFwhmMm','SaveBias'}
            if isfield(c,n{1}), channels(k).(n{1})=c.(n{1}); end
        end
    end
else
    channels=channel;
end
if ~strcmp(channels(1).Name,'T1')||~strcmpi(absolute(channels(1).Path,''),absolute(run.t1,''))|| ...
        any(~ismember({channels.Name},{'T1','T2','PD'}))||numel(unique({channels.Name}))~=numel(channels)
    error('psy:AnatomyChannels','首通道须为 TSV t1 对应的 T1；可选 T2/PD，不允许重复角色');
end
if strcmp(s.backend,'cat12') && numel(channels)~=1
    error('psy:CATChannels','CAT12 只支持单通道 T1；T1+T2/PD 请选 spm');
end
for k=1:numel(channels)
    c=channels(k); c.Path=absolute(c.Path,'');
    if ~isnumeric(c.Volume)||~isscalar(c.Volume)||~isfinite(c.Volume)||c.Volume<1||c.Volume~=floor(c.Volume)
        error('psy:AnatomyVolume','Volume 须为正整数');
    end
    if ~ismember(c.BiasRegularisation,[0 1e-5 1e-4 1e-3 1e-2 .1 1 10])|| ...
            ~ismember(c.BiasFwhmMm,[30:10:150 Inf])
        error('psy:AnatomyBias','逐通道偏置参数不在 SPM 菜单范围');
    end
    psy.segment_output_flags('bias',c.SaveBias);
    h=niftiinfo(c.Path);
    if ~ismember(numel(h.ImageSize),[3 4]) || ~strcmpi(h.SpaceUnits,'millimeter')
        error('psy:AnatomyShape','通道须为毫米单位的 3D/4D NIfTI');
    end
    count=1;if numel(h.ImageSize)==4,count=h.ImageSize(4);end
    if c.Volume>count, error('psy:AnatomyVolume','%s Volume=%d 超过 %d',c.Name,c.Volume,count); end
    % SPM 可读 gzip 的私有临时解压副本；从不改原始 header。
    tmp=tempname;mkdir(tmp);cl=onCleanup(@()rmdir(tmp,'s'));
    local=psy.stage_image(c.Path,tmp); v=spm_vol(local);v=v(c.Volume);
    if any(~isfinite(v.mat(:)))||abs(det(v.mat(1:3,1:3)))<eps, error('psy:AnatomyGeometry','无效解剖仿射'); end
    x=spm_read_vols(v);
    if any(~isfinite(x(:)))||max(x(:))<=min(x(:)), error('psy:AnatomyValues','结构像须有限且非恒定'); end
    c.Size=v.dim;c.Affine=v.mat;channels(k).Path=c.Path;
    if k==1, reference=c;
    elseif strcmp(s.channelAlignment,'require_aligned') && ...
            (~isequal(c.Size,reference.Size)||max(abs(c.Affine(:)-reference.Affine(:)))>1e-4)
        error('psy:AnatomyAlignment','多通道须同网格且已解剖对齐；或选择 coregister_reslice');
    end
    clear cl;
    p.inputFiles{end+1}=c.Path;
end
p.channels=channels;
if strcmp(s.backend,'cat12')
    p.backendVersion=psy.cat12_environment(s.cat12.path);
end
if a.enabled
    file=absolute(pick(run,'atlases',a.manifestFile),'');
    j=jsondecode(fileread(file));p.atlasesFile=file;p.inputFiles{end+1}=file;
    if ~isfield(j,'Atlases')||isempty(j.Atlases), error('psy:AtlasInput','JSON 需要非空 Atlases'); end
    expected='spm_tpm_mni';if strcmp(s.backend,'cat12'),expected='cat12_mni2009c';end
    atlas=struct('Name','','Path','','Kind','','Space','','Interpolation',0);
    p.atlases=repmat(atlas,1,numel(j.Atlases));
    for k=1:numel(j.Atlases)
        c=j.Atlases(k);
        for n={'Name','Path','Kind','Space'}
            if ~isfield(c,n{1}), error('psy:AtlasInput','图谱缺少 %s',n{1}); end
            atlas.(n{1})=char(c.(n{1}));
        end
        atlas.Path=absolute(atlas.Path,fileparts(file));
        if isempty(regexp(atlas.Name,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once'))|| ...
                ~ismember(atlas.Kind,{'labels','probability'})||~strcmp(atlas.Space,expected)
            error('psy:AtlasSpace','Name 须安全；Kind=labels/probability；本路线 Space=%s，不能仅凭 MNI 名称替换',expected);
        end
        atlas.Interpolation=double(strcmp(atlas.Kind,'probability')); % 标签最近邻，概率线性，均不平滑。
        h=niftiinfo(atlas.Path);
        tmp=tempname;mkdir(tmp);cl=onCleanup(@()rmdir(tmp,'s'));
        local=psy.stage_image(atlas.Path,tmp);av=spm_vol(local);
        if numel(av)~=1,error('psy:AtlasValues','图谱须为单幅三维图');end
        x=spm_read_vols(av); % 与实际 SPM 运行相同，应用 NIfTI 缩放。
        if any(~isfinite(av.mat(:)))||abs(det(av.mat(1:3,1:3)))<eps,error('psy:AtlasSpace','无效图谱仿射');end
        if numel(h.ImageSize)~=3||~strcmpi(h.SpaceUnits,'millimeter')||any(~isfinite(x(:)))|| ...
                any(x(:)<0)|| (strcmp(atlas.Kind,'labels') && any(x(:)~=round(x(:))))|| ...
                (strcmp(atlas.Kind,'probability') && any(x(:)>1))
            error('psy:AtlasValues','图谱须为有限三维毫米图；labels=非负整数；probability=0..1');
        end
        clear cl;
        p.atlases(k)=atlas;p.inputFiles{end+1}=atlas.Path;
    end
    if numel(unique({p.atlases.Name}))~=numel(p.atlases), error('psy:AtlasInput','图谱 Name 不可重复'); end
end
p.hashes=cellfun(@psy.file_sha256,p.inputFiles,'UniformOutput',false);
end
function p=pick(r,n,default)
p=default;if isfield(r,n)&&~isempty(r.(n)),p=r.(n);end
end
function p=absolute(p,base)
p=char(p);
if isempty(p), error('psy:AnatomyPath','需要影像/JSON 路径，不能留空'); end
if ~java.io.File(p).isAbsolute()
    if isempty(base),error('psy:AnatomyPath','全局路径须为绝对路径: %s',p);end
    p=fullfile(base,p);
end
p=char(java.io.File(p).getCanonicalPath());
if ~isfile(p),error('psy:AnatomyPath','文件不存在（新增通道只接受 NIfTI，不接受 DICOM 目录）: %s',p);end
end
