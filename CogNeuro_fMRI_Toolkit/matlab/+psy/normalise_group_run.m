function context=normalise_group_run(p,cfg)
%NORMALISE_GROUP_RUN 一次准备整个群体；完成结果按来源/参数/代码及输出哈希复用。
% 所有模板和原生配准输入写到 outputRoot 外置结果目录，绝不改外部模板。
n=p.options;folder=fullfile(cfg.outputRoot,'normalisation_group',n.method);
codeFiles=dir(fullfile(fileparts(mfilename('fullpath')),'*.m'));
codeHashes=cellfun(@(x)psy.file_sha256(fullfile(fileparts(mfilename('fullpath')),x)), ...
    {codeFiles.name},'UniformOutput',false);
signature=jsonencode(struct('plan',p,'code',{codeHashes},'voxel',cfg.voxelSizeMm,'bb',cfg.boundingBoxMm));
done=fullfile(folder,'GROUP_COMPLETE.mat');
if isfile(done)&&cfg.resume
    prior=load(done,'context');context=prior.context;
    if ~strcmp(signature,context.signature)||~all(cellfun(@isfile,context.requiredOutputs))
        error('psy:ChangedConfig','群体成员、参数或输出改变；请选择新的 outputRoot');
    end
    hashes=cellfun(@psy.file_sha256,context.requiredOutputs,'UniformOutput',false);
    if ~isequal(hashes,context.outputHashes),error('psy:ChangedConfig','群体已完成输出被改变；请用新目录');end
    return;
end
if isfolder(folder),error('psy:ExistingOutput','群体目录已有半成品，请检查后改用新 outputRoot：%s',folder);end
mkdir(folder);save(fullfile(folder,'GROUP_PLAN.mat'),'p','signature');
old=pwd;boundary=spm_diffeo('boundary');cleanup=onCleanup(@()restore(old,boundary));cd(folder);
diary(fullfile(folder,'group_log.txt'));logCleanup=onCleanup(@()diary('off'));
entries=struct([]);images={cell(numel(p.entries),1),cell(numel(p.entries),1)};
required={fullfile(folder,'GROUP_PLAN.mat')};
for k=1:numel(p.entries)
    e=p.entries(k);out=fullfile(folder,sprintf('anatomy_%04d',k));mkdir(out);
    e.segment=psy.segment_run(e.run,cfg,out,e.segmentPlan);
    [anat,stem]=fileparts(e.segment.t1);
    images{1}{k}=fullfile(anat,['rc1' stem '.nii']);images{2}{k}=fullfile(anat,['rc2' stem '.nii']);
    e.imported={images{1}{k},images{2}{k}};
    if k==1,entries=e;else,entries(k)=e;end
    required=[required,e.segment.requiredOutputs]; %#ok<AGROW>
end
importedQC=validate_imports(images);
templates={};
if strcmp(n.group.mode,'existing')
    target=fullfile(folder,'templates');mkdir(target);
    for k=1:numel(n.group.templates)
        if ~strcmp(psy.file_sha256(n.group.templates{k}),p.templateHashes{k})
            error('psy:NormaliseChanged','模板在预检后改变');
        end
        templates{k}=fullfile(target,sprintf('Template_%d.nii',k)); %#ok<AGROW>
        copyfile(n.group.templates{k},templates{k});
    end
    validate_template_match(images{1}{1},templates{1});
end
if strcmp(n.method,'dartel')
    job=psy.dartel_job(images,n,templates);execution='spm_dartel_template';
    if strcmp(n.group.mode,'existing'),execution='spm_dartel_warp';end
    record=fullfile(folder,'dartel_registration_job.mat');save(record,'job','execution');
    result=feval(execution,job);fields=result.files;
    if strcmp(n.group.mode,'create'),templates=result.template;end
else
    job=struct('images',{images});if ~isempty(templates),job.templates=templates;end
    result=psy.shooting_run(job,n,folder,n.group.mode);fields=result.def;
    if strcmp(n.group.mode,'create'),templates=result.template;end
    record=fullfile(folder,'shoot_registration_job.mat');
    required=[required,reshape(result.vel,1,[]),reshape(result.jac,1,[])];
    required=[required,{fullfile(folder,'shoot_defaults_adapter','defaults.mat'), ...
        fullfile(folder,'shoot_defaults_adapter','spm_shoot_defaults.m')}];
end
templates=reshape(templates,1,[]);fields=reshape(fields,1,[]);
finalTemplate=templates{end};
% 官方 MNI affine 估计；缓存只在本群体私有模板目录生成。
Nt=nifti(finalTemplate);tpm=fullfile(cfg.spmPath,'tpm','TPM.nii');
mni=struct('affine',spm_get_space(tpm)/spm_klaff(Nt,tpm,1),'code','MNI152');
if any(~isfinite(mni.affine(:)))||abs(det(mni.affine(1:3,1:3)))<eps
    error('psy:NormaliseMNI','模板到 MNI 的仿射无效');
end
[tp,stem]=fileparts(finalTemplate);affineFile=fullfile(tp,[stem '_2mni.mat']);save(affineFile,'mni');
required=[required,{record,affineFile},templates,fields];
for k=1:numel(entries)
    out=fileparts(fileparts(entries(k).segment.t1));
    [forward,inverse,outputs]=psy.group_deformations(fields{k},finalTemplate,entries(k).segment.t1,n,cfg,out,mni);
    entries(k).registrationField=fields{k};entries(k).forward=forward;entries(k).inverse=inverse;
    required=[required,outputs]; %#ok<AGROW>
end
required=unique(required,'stable');
if ~all(cellfun(@isfile,required)),error('psy:NormaliseGroupOutputs','群体原生模块输出不完整');end
context=struct('method',n.method,'options',n,'folder',folder,'entries',entries, ...
    'runToAnatomy',p.runToAnatomy,'templates',{templates},'finalTemplate',finalTemplate, ...
    'mni',mni,'importedQC',importedQC,'signature',signature,'requiredOutputs',{required}, ...
    'outputHashes',{cellfun(@psy.file_sha256,required,'UniformOutput',false)});
save(done,'context');
end
function restore(folder,boundary)
cd(folder);spm_diffeo('boundary',boundary);
end
function qc=validate_imports(images)
reference=spm_vol(images{1}{1});reference=reference(1);
vox=sqrt(sum(reference.mat(1:3,1:3).^2));
if max(vox)-min(vox)>1e-4,error('psy:NormaliseImported','Imported 图需要等方性网格');end
qc=struct('gmwmNonfiniteFractions',zeros(2,numel(images{1})), ...
    'note','NaN为原生Imported覆盖之外；保留并交给SPM的缺失区域处理，不在接口中填成组织概率');
validMasks=cell(1,numel(images{1}));
for channel=1:2
    for k=1:numel(images{channel})
        v=spm_vol(images{channel}{k});
        if numel(v)~=1||~isequal(v.dim,reference.dim)||max(abs(v.mat(:)-reference.mat(:)))>1e-4
            error('psy:NormaliseImported','所有 Imported GM/WM 须在一致网格；拒绝混合不同导入协议');
        end
        x=spm_read_vols(v);
        valid=isfinite(x);qc.gmwmNonfiniteFractions(channel,k)=nnz(~valid)/numel(x);
        if any(isinf(x(:)))||any(x(valid)<-1e-6)||any(x(valid)>1+1e-6)||~any(x(valid)>0)
            error('psy:NormaliseImported','Imported 有效区域须为非空概率图，不能含Inf');
        end
        if channel==1,validMasks{k}=valid;
        elseif ~isequal(validMasks{k},valid),error('psy:NormaliseImported','同一结构的GM/WM缺失区域不一致');end
    end
end
end
function validate_template_match(imported,template)
a=spm_vol(imported);b=spm_vol(template);b=b(1);
if ~isequal(a.dim,b.dim)||max(abs(a.mat(:)-b.mat(:)))>1e-4
    error('psy:NormaliseTemplates','已有模板与 Imported 图网格不兼容；请选择相同导入协议的模板');
end
end
