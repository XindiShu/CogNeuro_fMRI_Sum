function runs = read_manifest(cfg)
%READ_MANIFEST 通用原始影像清单，不要求 HCP/BIDS 命名。
% 必需列 subject/session/run/bold/t1/input_stage；session 可空，sbref 可选。
% 可选 metadata/events/fieldmaps/provenance 路径相对 TSV 目录。
if ~isfile(cfg.manifestFile)
    error('psy:MissingManifest','Create your TSV from config/runs_template.tsv: %s',cfg.manifestFile);
end
opts=detectImportOptions(cfg.manifestFile,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
opts.DataLines=[2 Inf]; % 第一行永远是列名；不让自动推断因混合编号跳过数据。
opts.ConsecutiveDelimitersRule='split'; % 空 session 保留为空字段，不能吞并制表符。
opts.ExtraColumnsRule='error';
required={'subject','session','run','bold','t1','input_stage'};
if ~all(ismember(required,opts.VariableNames))
    error('psy:ManifestColumns','Required columns: %s',strjoin(required,', '));
end
% 所有列按文本读取，保留 001 等被试编号前导零。
opts=setvartype(opts,opts.VariableNames,'string'); t=readtable(cfg.manifestFile,opts);
base=fileparts(char(java.io.File(cfg.manifestFile).getCanonicalPath()));
runs=struct([]);
keys=strings(0,1);
for i=1:height(t)
    subject=clean(t.subject(i)); session=clean(t.session(i)); name=clean(t.run(i));
    safe_id(subject,false); safe_id(session,true); safe_id(name,false);
    key=lower(string(subject)+"/"+string(session)+"/"+string(name));
    if any(keys==key), error('psy:DuplicateRun','Duplicate subject/session/run: %s',key); end
    keys(end+1)=key; %#ok<AGROW>
    if ~isempty(cfg.subjects) && ~ismember(subject,cfg.subjects), continue; end
    if ~isempty(cfg.runNames) && ~ismember(name,cfg.runNames), continue; end
    stage=clean(t.input_stage(i)); expected='raw';
    if isfield(cfg,'inputStage'), expected=cfg.inputStage; end
    if ~ismember(expected,{'raw','sdc_corrected','preprocessed'}) || ~strcmp(stage,expected)
        error('psy:InputStage','Row %d input_stage 与配置不符或不受支持。',i);
    end
    allowDicom=isfield(cfg,'dicom') && isfield(cfg.dicom,'enabled') && cfg.dicom.enabled;
    bold=resolve_image(clean(t.bold(i)),base,allowDicom); t1=''; sbref='';
    method=cfg.sdc.method;
    if ismember('sdc_method',t.Properties.VariableNames) && ~isempty(clean(t.sdc_method(i)))
        method=clean(t.sdc_method(i));
    end
    vdmOnly=strcmp(method,'spm_vdm_only');
    if ~isempty(clean(t.t1(i))) || (ismember(stage,{'raw','sdc_corrected'}) && ~vdmOnly)
        t1=resolve_image(clean(t.t1(i)),base,allowDicom);
    end
    if ismember('sbref',t.Properties.VariableNames) && ~isempty(clean(t.sbref(i)))
        sbref=resolve_image(clean(t.sbref(i)),base,allowDicom);
    end
    r=struct('subject',subject,'session',session,'name',name, ...
        'bold',bold,'t1',t1,'sbref',sbref,'ev','','eventFormat','none','inputStage',stage);
    r.sdcMethod=''; % 可选逐 run 选择；空值使用 toolkit_config.m 的 cfg.sdc.method。
    if ismember('sdc_method',t.Properties.VariableNames)
        r.sdcMethod=clean(t.sdc_method(i));
    end
    r.discardVolumes=[]; r.eventReference='';
    r.realignWeightImage=''; % 空=继承全局；none=本 run 禁用；路径=逐 run 权重图。
    if ismember('realign_weight',t.Properties.VariableNames)
        weight=clean(t.realign_weight(i));
        if strcmpi(weight,'none')
            r.realignWeightImage='none';
        elseif ~isempty(weight)
            r.realignWeightImage=resolve_image(weight,base,false); % 权重只接收 NIfTI，不做 DICOM 导入。
        end
    end
    if ismember('discard_volumes',t.Properties.VariableNames) && ~isempty(clean(t.discard_volumes(i)))
        r.discardVolumes=str2double(clean(t.discard_volumes(i)));
    end
    if ismember('event_reference',t.Properties.VariableNames)
        r.eventReference=clean(t.event_reference(i));
    end
    for field={'metadata','events','fieldmaps','provenance','anatomy_channels','atlases'}
        keyname=field{1}; r.(keyname)='';
        if ismember(keyname,t.Properties.VariableNames) && ~isempty(clean(t.(keyname)(i)))
            p=clean(t.(keyname)(i));
            if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
            p=char(java.io.File(p).getCanonicalPath());
            if ~isfile(p), error('psy:MissingSidecar','Missing %s: %s',keyname,p); end
            r.(keyname)=p;
        end
    end
    r.anatomyChannels=r.anatomy_channels; r=rmfield(r,'anatomy_channels');
    r.anatomyReuseDir='';
    r.fieldmapEpi='';
    if ismember('fieldmap_epi',t.Properties.VariableNames) && ~isempty(clean(t.fieldmap_epi(i)))
        r.fieldmapEpi=resolve_image(clean(t.fieldmap_epi(i)),base,false); % 代表 EPI 单幅 NIfTI。
    end
    if ismember('anatomy_reuse_dir',t.Properties.VariableNames) && ~isempty(clean(t.anatomy_reuse_dir(i)))
        p=clean(t.anatomy_reuse_dir(i));
        if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
        r.anatomyReuseDir=char(java.io.File(p).getCanonicalPath());
        if ~isfolder(r.anatomyReuseDir), error('psy:AnatomyReuse','解剖复用目录不存在: %s',r.anatomyReuseDir); end
    end
    if ismember(stage,{'preprocessed','sdc_corrected'}) && isempty(r.provenance)
        error('psy:Provenance','衍生输入需要 provenance JSON');
    end
    if allowDicom && ~strcmp(stage,'raw') && psy.has_dicom_sources(r)
        error('psy:DICOMMode','DICOM 导入只支持 raw 输入；衍生输入必须提供 NIfTI 和来源记录');
    end
    if isempty(runs), runs=r; else, runs(end+1)=r; end %#ok<AGROW>
end
if isempty(runs), error('psy:NoRuns','No selected runs in manifest'); end
end
function value=clean(value)
if ismissing(value), value=''; else, value=char(strtrim(value)); end
end
function safe_id(value,allowEmpty)
if allowEmpty && isempty(value), return; end
if isempty(regexp(value,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once'))
    error('psy:UnsafeID','IDs require letters/digits/underscore/hyphen: %s',value);
end
end
function file=resolve_image(file,base,allowDicom)
if isempty(file), error('psy:MissingImage','Missing required image path'); end
if ~java.io.File(file).isAbsolute(), file=fullfile(base,file); end
file=char(java.io.File(file).getCanonicalPath());
if allowDicom && isfolder(file), return; end % 目录必须只包含当前角色的一条 DICOM 序列。
if ~isfile(file), error('psy:MissingImage','Image not found: %s',file); end
if ~endsWith(file,{'.nii','.nii.gz'}), error('psy:ImageFormat','Expected .nii or .nii.gz: %s',file); end
end
