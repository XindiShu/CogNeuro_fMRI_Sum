function reports=validate_glm_group_engineering(outputRoot)
%VALIDATE_GLM_GROUP_ENGINEERING 全合成被试/组别/协变量；逐体素独立OLS复核。
root=fileparts(fileparts(mfilename('fullpath')));oldPath=path;oldRng=rng;oldDirectory=pwd;
restore=onCleanup(@()restoreState(oldPath,oldRng,oldDirectory));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
if nargin<1,outputRoot=fullfile(tempdir,['glm_group_demo_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);end
if ~java.io.File(outputRoot).isAbsolute(),outputRoot=fullfile(pwd,outputRoot);end
outputRoot=char(java.io.File(outputRoot).getCanonicalPath());
if isfile(outputRoot)||isfolder(outputRoot),error('psy:GLMExists','Use a new demo output directory');end
cfg=glm_config;addpath(cfg.spmPath);mkdir(outputRoot);input=fullfile(outputRoot,'synthetic_inputs');mkdir(input);
cfg.engine='spm_classical';cfg.level='group';cfg.execute=true;cfg.continueOnError=false;cfg.qc.plot=false;
rng(2716,'twister');n=12;dim=[5 4 4];nVox=prod(dim);
subject=compose('synthetic%02d',(1:n)');session=repmat("",n,1);contrast=repmat("synthetic_effect",n,1);
group=[repmat("demo_A",6,1);repmat("demo_B",6,1)];
synthetic_score=[1;4;2;6;3;5;2;5;1;6;3;4];synthetic_age=[25;31;29;43;37;47;28;34;32;40;50;44];
signal=1.5+.4*(synthetic_score-mean(synthetic_score))-.025*(synthetic_age-mean(synthetic_age))+.75*(group=="demo_A");
values=signal*(1+.2*sin(1:nVox))+.2*randn(n,nVox);baseline=.4*randn(n,nVox);
maskFile=fullfile(input,'mask.nii');mask=ones(dim);mask(end)=0;writeImage(maskFile,mask);
contrast_image=strings(n,1);pre=contrast_image;mask=repmat(string(maskFile),n,1);
for k=1:n
    contrast_image(k)=fullfile(input,sprintf('post_%02d.nii',k));pre(k)=fullfile(input,sprintf('pre_%02d.nii',k));
    writeImage(contrast_image(k),reshape(values(k,:),dim));writeImage(pre(k),reshape(baseline(k,:),dim));
end
base=table(subject,session,contrast,contrast_image,mask);
regression=addvars(base,synthetic_score,synthetic_age);
twoSample=addvars(base,group);twoAdjusted=addvars(regression,group);
before=base;before.contrast_image=pre;before.pair_level=repmat("pre",n,1);after=base;after.pair_level=repmat("post",n,1);
paired=[after;before];paired=paired(randperm(2*n),:); % 故意打乱配对输入，依靠subject和pair_level匹配。
cases={'paired','two_sample','regression','one_sample_adjusted','two_sample_adjusted'};
tables={paired,twoSample,regression,regression,twoAdjusted};reports=cell(1,numel(cases));verification=struct([]);
for k=1:numel(cases)
    c=cfg;c.group.design=cases{k};c.group.groupLabels={'demo_A','demo_B'};c.group.pairedLevels={'post','pre'};
    if endsWith(cases{k},'_adjusted'),c.group.design=erase(cases{k},'_adjusted');end
    if k>=3,c.group.covariateColumns={'synthetic_score','synthetic_age'};end
    c.manifestFile=fullfile(input,[cases{k} '.tsv']);c.outputRoot=fullfile(outputRoot,cases{k});
    writetable(tables{k},c.manifestFile,'FileType','text','Delimiter','\t');reports{k}=psy.glm_batch(c);
    assert(all(endsWith(string({reports{k}.status}),'_estimated')));
    plan=psy.glm_group_plan(c);folder=fullfile(c.outputRoot,'contrast_001');x=plan.designMatrix;
    y=zeros(size(x,1),nVox);
    if strcmp(c.group.design,'paired')
        for j=1:plan.nSubjects
            a=spm_read_vols(spm_vol(char(plan.rows.contrast_image(2*j-1))));b=spm_read_vols(spm_vol(char(plan.rows.contrast_image(2*j))));
            y(j,:)=double(single(a(:)-b(:)))';
        end
    else
        for j=1:height(plan.rows),a=spm_read_vols(spm_vol(char(plan.rows.contrast_image(j))));y(j,:)=a(:)';end
    end
    coefficients=x\y;residual=y-x*coefficients;sigma2=sum(residual.^2,1)/plan.residualDF;
    modelMask=spm_read_vols(spm_vol(fullfile(folder,'mask.nii')))>0;maxEffectError=0;maxTError=0;
    for j=1:size(plan.contrastWeights,1)
        w=plan.contrastWeights(j,:);effect=w*coefficients;statistic=effect./sqrt((w*pinv(x'*x)*w')*sigma2);
        con=spm_read_vols(spm_vol(fullfile(folder,sprintf('con_%04d.nii',j))));t=spm_read_vols(spm_vol(fullfile(folder,sprintf('spmT_%04d.nii',j))));
        maxEffectError=max(maxEffectError,max(abs(con(modelMask)-effect(modelMask)')));
        maxTError=max(maxTError,max(abs(t(modelMask)-statistic(modelMask)')));
    end
    assert(maxEffectError<1e-4&&maxTError<1e-3);
    v=struct('case',cases{k},'nSubjects',plan.nSubjects,'residualDF',plan.residualDF,'nContrasts',size(plan.contrastWeights,1), ...
        'maximumEffectError',maxEffectError,'maximumTError',maxTError,'allMaskedVoxelsChecked',nnz(modelMask));
    if isempty(verification),verification=v;else,verification(k)=v;end
end
purpose='fully synthetic code demonstration; no real HCP grouping, age or behavioral variables';
save(fullfile(outputRoot,'GROUP_ENGINEERING_COMPLETE.mat'),'reports','verification','purpose');
f=fopen(fullfile(outputRoot,'validation_summary.json'),'w');closeFile=onCleanup(@()fclose(f));
fprintf(f,'%s',jsonencode(struct('purpose',purpose,'cases',verification),PrettyPrint=true));clear closeFile restore;
end
function writeImage(file,data)
ni=nifti;ni.dat=file_array(char(file),size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;
create(ni);ni.dat(:)=single(data(:));
end
function restoreState(oldPath,oldRng,oldDirectory)
path(oldPath);rng(oldRng);cd(oldDirectory);
end
