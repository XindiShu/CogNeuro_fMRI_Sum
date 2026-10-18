function p=normalise_group_plan(runs,plans,cfg)
%NORMALISE_GROUP_PLAN 将 run 清单映射为唯一结构单位，防止重复 T1 加权模板。
% 默认一个 subject 一份解剖；纵向不同 T1 可明确选 subject_session。
n=psy.normalise_options(cfg);
p=struct('options',n,'entries',struct([]),'runToAnatomy',zeros(1,numel(runs)), ...
    'templateHashes',{{}},'environmentFiles',{{}},'environmentHashes',{{}});
units={};unitIdentities={};identities={};paths={};subjects={};
for k=1:numel(runs)
    r=runs(k);s=plans{k}.segment;
    % 图谱逐 run 处理，不参与结构单位去重；仍由原计划核对图谱来源。
    s.atlasOptions.enabled=false;s.atlases=struct([]);s.atlasesFile='';
    s.deformationFlags=psy.deformation_field_flags(s.options.deformationFields);
    s.inputFiles={fullfile(cfg.spmPath,'tpm','TPM.nii')};
    if ~isempty(s.channelsFile),s.inputFiles{end+1}=s.channelsFile;end
    s.inputFiles=[s.inputFiles,{s.channels.Path}];
    s.hashes=cellfun(@psy.file_sha256,s.inputFiles,'UniformOutput',false);
    for tissue=1:2
        f=psy.segment_output_flags('native',s.options.nativeOutputs{tissue});
        if f(1),s.options.nativeOutputs{tissue}='native_dartel';
        else,s.options.nativeOutputs{tissue}='dartel';end
    end
    channelHashes=cellfun(@psy.file_sha256,{s.channels.Path},'UniformOutput',false);
    channelIdentity=s.channels;
    for channel=1:numel(channelIdentity),channelIdentity(channel).Path='';end
    identity=jsonencode(struct('subject',r.subject,'channels',channelIdentity,'hashes',{channelHashes}, ...
        'options',s.options,'coreg',cfg.coreg));
    unit=char(r.subject);if strcmp(n.group.anatomyUnit,'subject_session'),unit=[unit '/' char(r.session)];end
    prior=find(strcmp(units,unit),1);
    if ~isempty(prior)&&~strcmp(identity,unitIdentities{prior})
        error('psy:NormaliseAnatomyConflict','结构单位 %s 有不同 T1/通道设置；纵向数据选 subject_session，并核对清单',unit);
    end
    if isempty(prior),units{end+1}=unit;unitIdentities{end+1}=identity;end %#ok<AGROW>
    source=char(java.io.File(s.channels(1).Path).getCanonicalPath());
    existing=find(strcmpi(paths,source),1);
    if ~isempty(existing)&&~strcmp(subjects{existing},r.subject)
        error('psy:NormaliseDuplicateT1','不同 subject 指向同一 T1：%s；拒绝重复计入模板',source);
    end
    index=find(strcmp(identities,identity),1);
    if isempty(index)
        index=numel(identities)+1;identities{index}=identity;paths{index}=source;subjects{index}=r.subject;
        entry=struct('subject',r.subject,'session',r.session,'identity',identity,'run',r,'segmentPlan',s);
        if index==1,p.entries=entry;else,p.entries(index)=entry;end
    end
    p.runToAnatomy(k)=index;
end
if isempty(p.entries),error('psy:NormaliseGroup','没有可进行标准化的结构单位');end
for k=1:numel(n.group.templates)
    file=n.group.templates{k};
    if ~java.io.File(file).isAbsolute()||~isfile(file)||~endsWith(lower(file),'.nii')
        error('psy:NormaliseTemplates','模板须为现有绝对路径 .nii：%s',file);
    end
    [v,channels]=template_geometry(file);
    needed=2;if strcmp(n.method,'shooting'),needed=3;end
    if channels<needed,error('psy:NormaliseTemplates','当前模板需要至少%d通道（GM/WM；Shoot另需背景）',needed);end
    if k==1,reference=v;
    elseif ~isequal(v.dim,reference.dim)||max(abs(v.mat(:)-reference.mat(:)))>1e-4
        error('psy:NormaliseTemplates','模板序列的网格不一致');
    end
    p.templateHashes{k}=psy.file_sha256(file);
end
files={'spm_diffeo','spm_klaff','spm_deformations'};
if strcmp(n.method,'dartel'),files=[files,{'spm_dartel_template','spm_dartel_warp','spm_dartel_norm_fun','spm_dartel_integrate'}];
else,files=[files,{'spm_shoot_template','spm_shoot_warp','spm_shoot_defaults','spm_shoot_norm','spm_shoot3d'}];end
for k=1:numel(files)
    file=which(files{k});
    if isempty(file),error('psy:NormaliseEnvironment','缺少本机 SPM 模块 %s',files{k});end
    p.environmentFiles{k}=file;p.environmentHashes{k}=psy.file_sha256(file);
end
end
function [v,channels]=template_geometry(file)
v=spm_vol(file);channels=numel(v);v=v(1);
if any(~isfinite(v.mat(:)))||abs(det(v.mat(1:3,1:3)))<eps
    error('psy:NormaliseTemplates','模板仿射无效');
end
vox=sqrt(sum(v.mat(1:3,1:3).^2));
if max(vox)-min(vox)>1e-4,error('psy:NormaliseTemplates','DARTEL/Shooting 模板需等方性体素');end
end
