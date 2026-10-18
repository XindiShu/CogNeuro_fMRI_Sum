function tests=test_normalisation_interfaces
% 新路线配置、结构去重、原生真实算子、方向/时间/原始文件保护的工程回归。
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;addpath(fullfile(spm('Dir'),'toolbox','DARTEL'),fullfile(spm('Dir'),'toolbox','Shoot'));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
folder=tempname;mkdir(folder);t.TestData.folder=folder;
cfg=toolkit_config;cfg.normalise.method='dartel';cfg.stopAfter='smooth';
cfg.normalise=psy.normalise_options(cfg);t.TestData.cfg=cfg;
file=fullfile(folder,'t1.nii');[x,y,z]=ndgrid(1:16,1:16,1:16);
write_image(file,single(x+y+z),eye(4));
t.TestData.run=struct('subject','S01','session','','name','run1','t1',file,'anatomyChannels','','atlases','');
end
function teardown(t)
rmdir(t.TestData.folder,'s');
end
function testDefaultCompatibilityAndMenus(t)
cfg=toolkit_config;n=psy.normalise_options(cfg);verifyEqual(t,n.method,'segmentation');
cfg=t.TestData.cfg;cfg.segment.deformationFields='none';psy.validate_preprocess_config(cfg);
cfg.normalise.method='wrong';verifyError(t,@()psy.normalise_options(cfg),'psy:NormaliseConfig');
cfg=t.TestData.cfg;cfg.segment.backend='cat12';verifyError(t,@()psy.normalise_options(cfg),'psy:NormaliseBackend');
cfg=t.TestData.cfg;cfg.normalise.group.mode='existing';verifyError(t,@()psy.normalise_options(cfg),'psy:NormaliseTemplates');
cfg=t.TestData.cfg;cfg.normalise.group.writeMethod='deformations';cfg.normalise.group.preserve=1;
verifyError(t,@()psy.normalise_options(cfg),'psy:NormaliseConfig');
cfg=t.TestData.cfg;cfg.smoothingFwhmMm=[4 6 8];verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:NormaliseNativeSmoothing');
cfg.normalise.group.writeMethod='deformations';psy.validate_preprocess_config(cfg);
cfg.boundingBoxMm=nan(2,3);verifyError(t,@()psy.validate_preprocess_config(cfg),'psy:PreprocessConfig');
end
function testTwoRunsOneAnatomyAndConflicts(t)
cfg=t.TestData.cfg;r=t.TestData.run;p=plan(r,cfg);
r2=r;r2.name='run2';g=psy.normalise_group_plan([r r2],{p p},cfg);
verifyEqual(t,numel(g.entries),1);verifyEqual(t,g.runToAnatomy,[1 1]);
verifyEqual(t,g.entries.segmentPlan.options.nativeOutputs(1:2),{'native_dartel','native_dartel'});
copy=fullfile(t.TestData.folder,'same_copy.nii');copyfile(r.t1,copy);r2.t1=copy;p2=plan(r2,cfg);
g=psy.normalise_group_plan([r r2],{p p2},cfg);verifyEqual(t,numel(g.entries),1);
r2.subject='S02';r2.t1=r.t1;p2=plan(r2,cfg);
verifyError(t,@()psy.normalise_group_plan([r r2],{p p2},cfg),'psy:NormaliseDuplicateT1');
r2=r;r2.session='day2';r2.name='run2';v=spm_vol(r.t1);write_image(copy,spm_read_vols(v)+1,v.mat);r2.t1=copy;p2=plan(r2,cfg);
verifyError(t,@()psy.normalise_group_plan([r r2],{p p2},cfg),'psy:NormaliseAnatomyConflict');
cfg.normalise.group.anatomyUnit='subject_session';g=psy.normalise_group_plan([r r2],{p p2},cfg);
verifyEqual(t,numel(g.entries),2);
end
function testTwentyFourSubjectsFortyEightRuns(t)
cfg=t.TestData.cfg;r=t.TestData.run;runs=repmat(r,1,48);plans=cell(1,48);
for k=1:24
    file=fullfile(t.TestData.folder,sprintf('T1_%02d.nii',k));copyfile(r.t1,file);
    for j=1:2
        a=r;a.subject=sprintf('S%02d',k);a.name=sprintf('run%d',j);a.t1=file;
        index=(k-1)*2+j;runs(index)=a;plans{index}=plan(a,cfg);
    end
end
g=psy.normalise_group_plan(runs,plans,cfg);verifyEqual(t,numel(g.entries),24);
verifyEqual(t,g.runToAnatomy,repelem(1:24,2));
end
function testDartelSettingsAndExistingMapping(t)
n=t.TestData.cfg.normalise;images={{'gm1';'gm2'},{'wm1';'wm2'}};
j=psy.dartel_job(images,n);verifyEqual(t,j.settings.param(6).K,6);verifyEqual(t,j.images,images);
files=arrayfun(@(k)sprintf('Template_%d.nii',k),1:6,'UniformOutput',false);
j=psy.dartel_job(images,n,files);verifyEqual(t,j.settings.param(5).template,files(5));
verifyFalse(t,isfield(j.settings.param,'slam'));
end
function testExistingTemplateInputChecks(t)
cfg=t.TestData.cfg;r=t.TestData.run;p=plan(r,cfg);folder=t.TestData.folder;
[x,y,z]=ndgrid(1:16,1:16,1:16);files=cell(1,6);
for k=1:6
    files{k}=fullfile(folder,sprintf('Template_%d.nii',k));
    n=nifti;n.dat=file_array(files{k},[16 16 16 3],'FLOAT32-LE',0,1,0);n.mat=eye(4);n.mat0=eye(4);create(n);
    n.dat(:,:,:,1)=single(x/100);n.dat(:,:,:,2)=single(y/100);n.dat(:,:,:,3)=single(1-(x+y)/100);
end
cfg.normalise.group.mode='existing';cfg.normalise.group.templates=files;
g=psy.normalise_group_plan(r,{p},cfg);verifyEqual(t,numel(g.templateHashes),6);
cfg.normalise.group.templates{1}='relative.nii';verifyError(t,@()psy.normalise_group_plan(r,{p},cfg),'psy:NormaliseTemplates');
cfg.normalise.group.templates=files;n=nifti(files{3});n.mat(1,4)=1;create(n);
verifyError(t,@()psy.normalise_group_plan(r,{p},cfg),'psy:NormaliseTemplates');
cfg.normalise.method='shooting';cfg.normalise.group.templates=files(1);
g=psy.normalise_group_plan(r,{p},cfg);verifyEqual(t,numel(g.templateHashes),1);
end
function testShootingDefaultsAndRestoreAfterFailure(t)
n=t.TestData.cfg.normalise;official=spm_shoot_defaults;d=psy.shooting_defaults(n);
for name={'sched','eul_its','rparam','sparam','cyc_its','scale','issym','smits'}
    verifyEqual(t,d.(name{1}),official.(name{1}),'AbsTol',1e-12);
end
old=path;boundary=spm_diffeo('boundary');location=which('spm_shoot_defaults');
try
    psy.shooting_run(struct('images',{{{fullfile(t.TestData.folder,'missing.nii')}}}),n,t.TestData.folder,'create');
    verifyFail(t,'缺文件应失败');
catch e
    verifyNotEqual(t,e.identifier,'MATLAB:unittest:VerificationFailed');
end
verifyEqual(t,path,old);verifyEqual(t,which('spm_shoot_defaults'),location);
verifyEqual(t,spm_diffeo('boundary'),boundary);
end
function testActualDartelAndShootingRegistration(t)
% 小合成概率图：真正运行官方模板创建/已有模板配准，不只检查 batch 字段。
folder=t.TestData.folder;[x,y,z]=ndgrid(1:16,1:16,1:16);
gm=single(.7*exp(-((x-8).^2+(y-8).^2+(z-8).^2)/18));
wm=single(.5*exp(-((x-8).^2+(y-8).^2+(z-8).^2)/6));
gm(1,:,:)=NaN;wm(1,:,:)=NaN; % 原生Imported视野外缺失，交给SPM处理。
images={cell(2,1),cell(2,1)};
for k=1:2
    sub=fullfile(folder,sprintf('subject%d',k));mkdir(sub);
    images{1}{k}=fullfile(sub,'rc1T1.nii');images{2}{k}=fullfile(sub,'rc2T1.nii');
    write_image(images{1}{k},circshift(gm,[k-1 0 0]),diag([2 2 2 1]));
    write_image(images{2}{k},circshift(wm,[k-1 0 0]),diag([2 2 2 1]));
end
n=t.TestData.cfg.normalise;n.dartel.innerIterations=ones(1,6);n.dartel.timeSteps=zeros(1,6);
j=psy.dartel_job(images,n);result=spm_dartel_template(j);
verifyTrue(t,all(cellfun(@isfile,result.files)));verifyEqual(t,numel(result.template),7);
j=psy.dartel_job(images,n,result.template(2:end));r=spm_dartel_warp(j);verifyTrue(t,all(cellfun(@isfile,r.files)));
n.shooting.iterations=2;n.shooting.smoothingIterations=1;n.shooting.maxTimeSteps=1;
shootFolder=fullfile(folder,'shoot');mkdir(shootFolder);
r=psy.shooting_run(struct('images',{images}),n,shootFolder,'create');
verifyTrue(t,all(cellfun(@isfile,r.def)));verifyEqual(t,numel(r.template),2);
j=struct('images',{images},'templates',{r.template});r=psy.shooting_run(j,n,shootFolder,'existing');
verifyTrue(t,all(cellfun(@isfile,r.vel)));verifyTrue(t,all(cellfun(@isfile,r.jac)));
end
function testNativeAndDeformationWritersPreserveTime(t)
folder=t.TestData.folder;[x,y,z]=ndgrid(1:16,1:16,1:16);mat=eye(4);
data=single(100+x+y+z);series=fullfile(folder,'bold.nii');
n=nifti;n.dat=file_array(series,[size(data) 3],'FLOAT32-LE',0,1,0);n.mat=mat;n.mat0=mat;n.timing.tspace=2;create(n);
for k=1:3,n.dat(:,:,:,k)=data+k;end
mean=fullfile(folder,'mean.nii');write_image(mean,data+2,mat);
flow=fullfile(folder,'u_test.nii');write_vector(flow,zeros([size(data) 3],'single'),mat);
field=fullfile(folder,'y_test.nii');write_vector(field,cat(4,x,y,z),mat);
template=fullfile(folder,'Template.nii');write_image(template,data,mat);
mni=struct('affine',mat,'code','MNI152');save(fullfile(folder,'Template_2mni.mat'),'mni');
group=fullfile(folder,'GROUP_COMPLETE.mat');save(group,'mni');
cfg=t.TestData.cfg;cfg.voxelSizeMm=[1 1 1];cfg.boundingBoxMm=[1 1 1;16 16 16];cfg.smoothingFwhmMm=[2 2 2];
before=psy.file_sha256(series);
for method={'dartel','shooting'}
    cfg.normalise.method=method{1};opts=psy.normalise_options(cfg);
    registration=flow;if strcmp(method{1},'shooting'),registration=field;end
    ctx=struct('options',opts,'anatomy',struct('registrationField',registration,'forward',field), ...
        'finalTemplate',template,'groupComplete',group,'groupSha256',psy.file_sha256(group));
    out=fullfile(folder,method{1});mkdir(out);
    outputs=psy.group_normalise_write(ctx,cfg,out,series,mean,3);
    verifyTrue(t,all(cellfun(@isfile,outputs)));record=load(outputs{end});
    verifyEqual(t,record.record.nVolumes,3);verifyEqual(t,record.record.trSeconds,2);
    verifyEqual(t,record.record.effectiveInterpolation,1);
    ctx.options.group.preserve=1;modOut=fullfile(folder,['mod_' method{1}]);mkdir(modOut);
    modFiles=psy.group_normalise_write(ctx,cfg,modOut,series,mean,3);modRecord=load(modFiles{end});
    verifyEqual(t,modRecord.record.preserve,1);
    [~,modStem]=fileparts(modRecord.record.normalized);verifyTrue(t,startsWith(modStem,'mw'));
    [~,smoothStem]=fileparts(modRecord.record.smoothed);verifyTrue(t,startsWith(smoothStem,'smw'));
end
cfg.normalise.group.writeMethod='deformations';opts=psy.normalise_options(cfg);ctx.options=opts;
out=fullfile(folder,'deforms');mkdir(out);outputs=psy.group_normalise_write(ctx,cfg,out,series,mean,3);
verifyTrue(t,all(cellfun(@isfile,outputs)));record=load(outputs{end});
verifyEqual(t,record.record.effectiveInterpolation,4);verifyEqual(t,psy.file_sha256(series),before);
end
function testActualFinalFieldAndAtlasDirections(t)
% 已知两毫米平移验证 MNI→native 拉回和 native→MNI 逆向方向，两路线一致。
folder=t.TestData.folder;[x,y,z]=ndgrid(1:16,1:16,1:16);mat=eye(4);
flow=fullfile(folder,'u_test.nii');write_vector(flow,zeros([16 16 16 3],'single'),mat);
field=fullfile(folder,'y_test.nii');write_vector(field,cat(4,x,y,z),mat);
template=fullfile(folder,'Template.nii');write_image(template,single(x+y+z),mat);
mni=struct('affine',mat,'code','MNI152');mni.affine(1,4)=2;
save(fullfile(folder,'Template_2mni.mat'),'mni');
cfg=t.TestData.cfg;cfg.voxelSizeMm=[1 1 1];cfg.boundingBoxMm=[1 1 1;16 16 16];
atlas=fullfile(folder,'labels.nii');write_image(atlas,single(10*(x>=5 & x<=7)),mat);
json=fullfile(folder,'atlases.json');fid=fopen(json,'w');fprintf(fid,'%s',jsonencode(struct('Atlases', ...
    struct('Name','ROI','Path',atlas,'Kind','labels','Space','spm_tpm_mni'))));fclose(fid);
run=t.TestData.run;run.atlases=json;cfg.atlas.enabled=true;
cfg.atlas.ensureInverse=false;cfg.segment.deformationFields='none';
before=psy.file_sha256(atlas);
for method={'dartel','shooting'}
    cfg.normalise.method=method{1};opts=psy.normalise_options(cfg);
    f=flow;if strcmp(method{1},'shooting'),f=field;end
    out=fullfile(folder,['fields_' method{1}]);mkdir(out);
    [forward,inverse,outputs]=psy.group_deformations(f,template,run.t1,opts,cfg,out,mni);
    verifyTrue(t,all(cellfun(@isfile,outputs)));
    a=nifti(forward);b=nifti(inverse);
    world=a.mat*[8;8;8;1]; % SPM输出数组第一维不必朝世界x正方向。
    verifyEqual(t,double(a.dat(8,8,8,1,1)),world(1)-2,'AbsTol',1e-3);
    verifyEqual(t,double(b.dat(8,8,8,1,1)),10,'AbsTol',1e-3);
    p=psy.segment_plan(run,cfg);files=psy.apply_atlases(p,inverse,run.t1,out);
    verifyTrue(t,all(cellfun(@isfile,files)));
    dest=spm_read_vols(spm_vol(fullfile(out,'atlases','ROI','native_labels.nii')));
    verifyEqual(t,dest(4,8,8),10);verifyEqual(t,dest(6,8,8),0);
end
verifyEqual(t,psy.file_sha256(atlas),before);
end
function testGroupBatchPreflightAndNoExecution(t)
folder=t.TestData.folder;cfg=t.TestData.cfg;cfg.execute=false;cfg.qc.enabled=false;cfg.sdc.method='none';
cfg.outputRoot=fullfile(folder,'preflight');cfg.manifestFile=fullfile(folder,'runs.tsv');
cfg.inputMode='manifest';cfg.subjects={};cfg.runNames={};
file=fullfile(folder,'bold.nii');n=nifti;n.dat=file_array(file,[16 16 16 3],'FLOAT32-LE',0,1,0);
n.mat=eye(4);n.mat0=eye(4);n.timing.tspace=2;create(n);n.dat(:,:,:,:)=ones(16,16,16,3,'single');
fid=fopen(cfg.manifestFile,'w');fprintf(fid,'subject\tsession\trun\tbold\tt1\tinput_stage\n');
for k=1:2,fprintf(fid,'S01\t\trun%d\t%s\t%s\traw\n',k,file,t.TestData.run.t1);end
fclose(fid);r=psy.preprocess_batch(cfg);verifyEqual(t,{r.status},{'validated_inputs','validated_inputs'});
p=load(fullfile(cfg.outputRoot,'normalisation_group_plan.mat'));verifyEqual(t,numel(p.p.entries),1);
verifyFalse(t,isfolder(fullfile(cfg.outputRoot,'normalisation_group')));
end
function write_image(file,x,mat)
v=struct('fname',file,'dim',size(x),'dt',[16 0],'mat',mat,'pinfo',[1;0;0]);spm_write_vol(v,x);
end
function p=plan(r,cfg)
p=struct('segment',psy.segment_plan(r,cfg));
end
function write_vector(file,x,mat)
n=nifti;n.dat=file_array(file,[size(x,1) size(x,2) size(x,3) 1 3],'FLOAT32-LE',0,1,0);
n.mat=mat;n.mat0=mat;create(n);n.dat(:,:,:,:,:)=reshape(single(x),[size(x,1) size(x,2) size(x,3) 1 3]);
end
