function records=manual_normalisation_routes(outputRoot,method,dataRoot)
%MANUAL_NORMALISATION_ROUTES 三个真实HCP被试、四run的新增路线工程验证。
% 仅测试：4mm工作输入、每run前8帧并删除前2帧、低迭代模板、4mm输出。
% 不将这些低迭代/低分辨率设置作为科研默认，不修改原始输入/成功结果。
project=fileparts(fileparts(mfilename('fullpath')));
if nargin<3,dataRoot='D:\IBM';end
if isfolder(outputRoot),error('psy:ExistingOutput','验证须使用新的目录');end
addpath(fullfile(project,'matlab'),fullfile(project,'config'));
cfg=preprocess_config;cfg.dataRoot=dataRoot;cfg.subjects={'100206','100307','100408'};
cfg.runNames={'tfMRI_LANGUAGE_LR','tfMRI_LANGUAGE_RL'};sources=psy.discover_hcp(cfg);
keep=strcmp({sources.name},'tfMRI_LANGUAGE_LR') | ...
    (strcmp({sources.subject},'100206') & strcmp({sources.name},'tfMRI_LANGUAGE_RL'));
sources=sources(keep);assert(numel(sources)==4,'应找到三人四run');
addpath(cfg.spmPath);spm('defaults','fmri');spm_jobman('initcfg');
mkdir(outputRoot);fixture=fullfile(outputRoot,'fixture');mkdir(fixture);
cfg.inputMode='manifest';cfg.subjects={};cfg.runNames={};cfg.execute=true;
cfg.outputRoot=fullfile(outputRoot,'processed');cfg.manifestFile=fullfile(fixture,'runs.tsv');
cfg.sdc.method='none';cfg.sliceTiming.enabled=false;cfg.sliceTiming.mode='off';
cfg.discardVolumes=2;cfg.qc.enabled=false;cfg.realign.mask=false;
cfg.normalise=psy.normalise_options(cfg);cfg.normalise.method=method;
cfg.normalise.dartel.innerIterations=ones(1,6);cfg.normalise.dartel.timeSteps=zeros(1,6);
cfg.normalise.shooting.iterations=2;cfg.normalise.shooting.maxTimeSteps=1;cfg.normalise.shooting.smoothingIterations=1;
cfg.voxelSizeMm=[4 4 4];cfg.smoothingFwhmMm=[4 4 4];cfg.resume=true;cfg.continueOnError=false;
hashes={};inputFiles={};preparedSubjects={};t1s={};
fid=fopen(cfg.manifestFile,'w');closer=onCleanup(@()fclose(fid));
fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\n');
for k=1:numel(sources)
    r=sources(k);index=find(strcmp(preparedSubjects,r.subject),1);
    if isempty(index)
        folder=fullfile(fixture,['sub-' r.subject]);mkdir(folder);
        source=psy.stage_image(r.t1,fullfile(folder,'source_t1'));v=spm_vol(source);
        t1=fullfile(folder,'T1_4mm.nii');resample(v(1),t1,4,[]);
        preparedSubjects{end+1}=r.subject;t1s{end+1}=t1;index=numel(t1s); %#ok<AGROW>
        inputFiles{end+1}=r.t1;hashes{end+1}=psy.file_sha256(r.t1); %#ok<AGROW>
    end
    folder=fullfile(fixture,['sub-' r.subject],r.name);mkdir(folder);
    source=psy.stage_image(r.bold,fullfile(folder,'source_bold'));v=spm_vol(source);
    bold=fullfile(folder,'bold_first8_4mm.nii');resample(v(1:8),bold,4,.72);
    fprintf(fid,'%s\t\t%s\t%s\t%s\traw\n',r.subject,r.name,bold,t1s{index});
    inputFiles{end+1}=r.bold;hashes{end+1}=psy.file_sha256(r.bold); %#ok<AGROW>
end
clear closer;
report=psy.preprocess_batch(cfg);assert(numel(report)==4&&all(startsWith({report.status},'spatial_pipeline')));
group=load(fullfile(cfg.outputRoot,'normalisation_group',method,'GROUP_COMPLETE.mat'));
assert(numel(group.context.entries)==3,'同一被试两个run不应重复计入模板');
for k=1:numel(report)
    rec=load(fullfile(report(k).output,'NORMALISATION_COMPLETE.mat'));
    assert(rec.record.nVolumes==6&&abs(rec.record.trSeconds-.72)<1e-6);
end
reused=psy.preprocess_batch(cfg);assert(all(strcmp({reused.status},'reused_completed_run')));
for k=1:numel(inputFiles),assert(strcmp(hashes{k},psy.file_sha256(inputFiles{k})));end
records=struct('method',method,'report',report,'reused',reused,'group',group.context, ...
    'inputFiles',{inputFiles},'rawHashes',{hashes},'cfg',cfg, ...
    'limitations','4mm工程工作副本/8帧/删2帧/低迭代；未做SDC或全切片人工QC，不是正式科研预处理结果');
save(fullfile(outputRoot,'MANUAL_VALIDATION_COMPLETE.mat'),'records');
end
function resample(v,file,step,tr)
vox=sqrt(sum(v(1).mat(1:3,1:3).^2));dim=ceil((v(1).dim-1).*vox/step)+1;
mat=v(1).mat;mat(1:3,1:3)=v(1).mat(1:3,1:3)*diag(step./vox);mapping=v(1).mat\mat;
n=nifti;n.dat=file_array(file,[dim numel(v)],'FLOAT32-LE',0,1,0);n.mat=mat;n.mat0=mat;
if ~isempty(tr),n.timing.tspace=tr;end
create(n);[x,y]=ndgrid(1:dim(1),1:dim(2));
for j=1:numel(v)
    for z=1:dim(3)
        xyz=mapping*[x(:)';y(:)';z*ones(1,numel(x));ones(1,numel(x))];
        values=spm_sample_vol(v(j),xyz(1,:),xyz(2,:),xyz(3,:),1);
        n.dat(:,:,z,j)=reshape(single(values),dim(1:2));
    end
end
end
