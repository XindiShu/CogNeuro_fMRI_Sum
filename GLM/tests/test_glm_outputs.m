function tests=test_glm_outputs
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root,fullfile(root,'matlab'),fullfile(root,'config'));
c=preprocess_config;addpath(c.spmPath);
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;t.TestData.cfg=glm_outputs_config;
t.TestData.statFolder=statFixture(root);t.TestData.manifest=betaFixture(root);
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testBhAndSignedTailProbabilities(t)
o=t.TestData.cfg.results;o.correction='fdr';o.alpha=.05;o.tail='positive';p0=[.001;.01;.04;.2];values=tan(pi*(.5-p0)); % df=1的独立Cauchy解析分位数。
[keep,p,q]=psy.glm_threshold(values,'T',[1 1],[],o);verifyEqual(t,p,p0,'AbsTol',1e-12);
verifyEqual(t,q,[.004;.02;.04*4/3;.2],'AbsTol',1e-12);verifyEqual(t,keep,[true;true;false;false]);
o.tail='negative';[~,pn]=psy.glm_threshold(-values,'T',[1 1],[],o);verifyEqual(t,pn,p,'AbsTol',1e-12);
o.tail='two_sided';[~,pt]=psy.glm_threshold([-values(1);values(2)],'T',[1 1],[],o);verifyEqual(t,pt,2*p(1:2),'AbsTol',1e-12);
end
function testFUpperTailAndNativeFwe(t)
o=t.TestData.cfg.results;o.correction='none';values=[0;1;10];[~,p]=psy.glm_threshold(values,'F',[2 20],[],o);
verifyEqual(t,p,1-spm_Fcdf(values,[2 20]),'AbsTol',1e-12);
o.tail='negative';verifyError(t,@()psy.glm_threshold(values,'F',[2 20],[],o),'psy:GLMInference');
o.tail='two_sided';o.correction='fwe';R=[1 3 3 1];[~,~,~,u]=psy.glm_threshold([1;2;4;5],'T',[1 20],R,o);
verifyEqual(t,u,spm_uc(.025,[1 20],'T',R,1,4),'AbsTol',1e-10);
verifyError(t,@()psy.glm_threshold(values,'T',[1 20],NaN(1,4),o),'psy:GLMInference');
end
function testNearZeroTailProbabilitiesByCauchyIdentities(t)
o=t.TestData.cfg.results;o.correction='none';z=[-1e-8;-1e-5;0;1e-8;1e-5;.1;1;1e4];
[~,p]=psy.glm_threshold(z,'T',[1 1],[],o);verifyEqual(t,p,.5-atan(z)/pi,'AbsTol',1e-15);
f=[0;1e-16;1e-10;.1;1;1e4;1e16];[~,p]=psy.glm_threshold(f,'F',[1 1],[],o);
verifyEqual(t,p,1-2*atan(sqrt(f))/pi,'AbsTol',1e-15);
end
function testSignedClustersCoordinatesAndSourcePreservation(t)
o=t.TestData.cfg.results;o.tail='two_sided';o.correction='none';o.alpha=.01;o.plot=false;o.writeVoxelTable=true;
file=fullfile(t.TestData.statFolder,'SPM.mat');before=psy.file_sha256(file);out=fullfile(t.TestData.root,'export');
s=psy.glm_results_export(file,1,o,out);verifyEqual(t,s.nDisplayedClusters,2);verifyEqual(t,s.nDisplayedVoxels,2);verifyEqual(t,psy.file_sha256(file),before);
c=readtable(fullfile(out,'clusters.tsv'),'FileType','text','Delimiter','\t');verifyEqual(t,sort(c.sign),[-1;1]);verifyEqual(t,c.n_voxels,[1;1]);
verifyEqual(t,sort(c.x_mm),[4;6]);verifyTrue(t,isfile(fullfile(out,'voxels.tsv')));
end
function testEmptyExtentExportAndOverlay(t)
o=t.TestData.cfg.results;o.correction='none';o.tail='two_sided';o.alpha=.01;o.minClusterVoxels=2;o.plot=true;
out=fullfile(t.TestData.root,'empty');s=psy.glm_results_export(fullfile(t.TestData.statFolder,'SPM.mat'),1,o,out);
verifyEqual(t,s.nDisplayedVoxels,0);verifyEqual(t,height(readtable(fullfile(out,'clusters.tsv'),'FileType','text','Delimiter','\t')),0);
verifyTrue(t,isfile(fullfile(out,'orthogonal_overlay.png')));verifyTrue(t,isfile(fullfile(out,'GLM_RESULTS_COMPLETE.mat')));
end
function testFrameworkItemGrainAndCanonicalMapping(t)
[c,e]=psy.glm_beta_catalog(t.TestData.manifest);a=c(c.method=="LSA",:);a=a(a.source_id=="framework",:);
verifyEqual(t,height(a),2);verifyEqual(t,a.estimate_unit,["item";"item"]);verifyEqual(t,nnz(ismember(e.estimate_id,a.estimate_id)),4);
verifyEqual(t,a.subject,["0007";"0007"]);
end
function testLegacyVariantsAndGlmsingleOriginalEventIdentity(t)
entries=psy.glm_read_table(t.TestData.manifest);writetable(entries([2 3 1 4],:),t.TestData.manifest,'FileType','text','Delimiter','\t');
[c,e]=psy.glm_beta_catalog(t.TestData.manifest);
verifyEqual(t,nnz(c.source_id=="legacy_lsa"),2);verifyEqual(t,nnz(c.source_id=="legacy_lss"),2);
g=c(c.method=="GLMsingle",:);verifyEqual(t,g.volume_index,[1;2]);links=e(ismember(e.estimate_id,g.estimate_id),:);
verifyEqual(t,g.unit_id,["event_000001";"event_000002"]);verifyEqual(t,g.cv_identity,["B";"A"]);
verifyEqual(t,links.source_event_index,[4;7]);verifyEqual(t,links.stimulus_id,["fileB";"fileA"]);
end
function testUnifiedMatrixRoiMeansAndEmptyRoi(t)
[c,~]=psy.glm_beta_catalog(t.TestData.manifest);[values,space]=psy.glm_beta_read(c,1);verifyEqual(t,size(values),[8 143]);
g=find(c.method=="GLMsingle");verifyEqual(t,values(g(1),1:3),single([-.5 -.49 -.48]),'AbsTol',1e-7);
roi=ones(6,6,4);roi(:)=0;roi(1:10)=1;file=fullfile(t.TestData.root,'roi.nii');image(file,roi);
manifest=fullfile(t.TestData.root,'rois.tsv');tab=table(["region";"missing"],repmat(string(file),2,1),[1;99],'VariableNames',{'roi','mask_file','label'});
writetable(tab,manifest,'FileType','text','Delimiter','\t');r=psy.glm_roi_extract(values,c,space,manifest,t.TestData.cfg.roi);
verifyEqual(t,r.mean(1:8),mean(double(values(:,1:10)),2),'AbsTol',1e-12);verifyTrue(t,all(isnan(r.mean(9:16))));
bad=t.TestData.cfg.roi;bad.emptyPolicy='error';verifyError(t,@()psy.glm_roi_extract(values,c,space,manifest,bad),'psy:GLMROI');
end
function testMatrixBudgetFrameAndCoverageGuards(t)
c=psy.glm_beta_catalog(t.TestData.manifest);verifyError(t,@()psy.glm_beta_read(c,1e-10),'psy:GLMBetaRead');
bad=c;bad.volume_index(1)=999;verifyError(t,@()psy.glm_beta_read(bad,1),'psy:GLMBetaRead');
bad=c;bad.estimate_id(2)=bad.estimate_id(1);verifyError(t,@()psy.glm_beta_read(bad,1),'psy:GLMBetaRead');
v=spm_vol(char(c.image_path(1)));data=spm_read_vols(v);data(1)=NaN;image(char(c.image_path(1)),data);
verifyError(t,@()psy.glm_beta_read(c,1),'psy:GLMBetaRead');
end
function testPreparedAndTamperedTargetsRejected(t)
manifest=t.TestData.manifest;entries=psy.glm_read_table(manifest);writetable(entries(1,:),manifest,'FileType','text','Delimiter','\t');
folder=char(entries.source_dir(1));file=fullfile(folder,'model_outputs.tsv');tab=psy.glm_read_table(file);tab.canonical_beta(1)=tab.canonical_beta(2);
writetable(tab,file,'FileType','text','Delimiter','\t');verifyError(t,@()psy.glm_beta_catalog(manifest),'psy:GLMBetaCatalog');
delete(fullfile(folder,'GLM_FRAMEWORK_COMPLETE.mat'));verifyError(t,@()psy.glm_beta_catalog(manifest),'psy:GLMBetaCatalog');
end
function testCompleteLauncherAndOutputProtection(t)
c=t.TestData.cfg;c.mode='both';c.betas.manifestFile=t.TestData.manifest;c.results.correction='fdr';c.results.plot=false;
c.results.manifestFile=fullfile(t.TestData.root,'results.tsv');tab=table("known",string(fullfile(t.TestData.statFolder,'SPM.mat')),1,'VariableNames',{'id','spm_mat','contrast_index'});
writetable(tab,c.results.manifestFile,'FileType','text','Delimiter','\t');c.outputRoot=fullfile(t.TestData.root,'all');oldPath=path;
r=run_glm_outputs(c);verifyEqual(t,path,oldPath);verifyEqual(t,r.betaEstimates,8);verifyEqual(t,r.eventLinks,10);
verifyTrue(t,isfile(fullfile(c.outputRoot,'betas','beta_matrix.mat')));verifyTrue(t,isfile(fullfile(c.outputRoot,'GLM_OUTPUTS_COMPLETE.mat')));
verifyError(t,@()run_glm_outputs(c),'psy:GLMExists');
end
function testConfigurationRejectsInvalidModesAndLimits(t)
c=t.TestData.cfg;c.mode='FC';verifyError(t,@()psy.glm_outputs_options(c),'psy:GLMOutputsConfig');
c=t.TestData.cfg;c.results.alpha=1;verifyError(t,@()psy.glm_outputs_options(c),'psy:GLMOutputsConfig');
c=t.TestData.cfg;c.betas.maxMatrixGiB=0;verifyError(t,@()psy.glm_outputs_options(c),'psy:GLMOutputsConfig');
end
function testFExportAndGeometryReject(t)
folder=t.TestData.statFolder;p=load(fullfile(folder,'SPM.mat'));SPM=p.SPM;SPM.xCon.STAT='F';SPM.xCon.eidf=2;
SPM.xCon.Vspm.fname='spmF_0001.nii';image(fullfile(folder,'spmF_0001.nii'),abs(spm_read_vols(spm_vol(fullfile(folder,'spmT_0001.nii')))));
save(fullfile(folder,'SPM.mat'),'SPM');o=t.TestData.cfg.results;o.correction='none';o.plot=false;
s=psy.glm_results_export(fullfile(folder,'SPM.mat'),1,o,fullfile(t.TestData.root,'F_export'));verifyEmpty(t,s.effectFile);
c=psy.glm_beta_catalog(t.TestData.manifest);v=spm_vol(char(c.mask_path(1)));v.mat(1,4)=3;spm_write_vol(v,spm_read_vols(v));
verifyError(t,@()psy.glm_beta_read(c,1),'psy:GLMGrid');
end
function testFileInventoryHandlesScalarTextAndRelativePath(t)
file=t.TestData.manifest;a=psy.glm_file_inventory(file);b=psy.glm_file_inventory({file,file});
verifyEqual(t,height(a),1);verifyEqual(t,a,b);verifyEqual(t,a.sha256,string(psy.file_sha256(file)));
previous=pwd;restore=onCleanup(@()cd(previous));cd(t.TestData.root);c=psy.glm_file_inventory('sources.tsv');verifyEqual(t,a,c);clear restore;
end
function testMissingTargetsAndInvalidOriginalRowRejected(t)
file=t.TestData.manifest;entries=psy.glm_read_table(file);writetable(entries(1,:),file,'FileType','text','Delimiter','\t');
out=fullfile(char(entries.source_dir(1)),'model_outputs.tsv');tab=psy.glm_read_table(out);tab.estimated(2)="0";writetable(tab,out,'FileType','text','Delimiter','\t');
verifyError(t,@()psy.glm_beta_catalog(file),'psy:GLMBetaCatalog');
writetable(entries(4,:),file,'FileType','text','Delimiter','\t');preflight=fullfile(char(entries.source_dir(4)),'preflight.mat');p=load(preflight);
p.plan.sourceTables{1}.original_event_index(2)=0;save(preflight,'-struct','p');verifyError(t,@()psy.glm_beta_catalog(file),'psy:GLMBetaCatalog');
end
function testGlmsingleContradictoryIdentityAndFourDMaskRejected(t)
file=t.TestData.manifest;entries=psy.glm_read_table(file);writetable(entries(4,:),file,'FileType','text','Delimiter','\t');
mappingFile=fullfile(char(entries.source_dir(4)),'TYPED','beta_mapping.tsv');tab=psy.glm_read_table(mappingFile);tab.identity(1)="not_the_fitted_identity";
writetable(tab,mappingFile,'FileType','text','Delimiter','\t');verifyError(t,@()psy.glm_beta_catalog(file),'psy:GLMBetaCatalog');
writetable(entries(1,:),file,'FileType','text','Delimiter','\t');c=psy.glm_beta_catalog(file);image(char(c.mask_path(1)),ones(6,6,4,2));
verifyError(t,@()psy.glm_beta_read(c,1),'psy:GLMGrid');
end
function folder=statFixture(root)
folder=fullfile(root,'stats');mkdir(folder);mask=ones(6,6,4);mask(end)=0;image(fullfile(folder,'mask.nii'),mask);
data=zeros(6,6,4);data(2,2,2)=4;data(3,2,2)=-5;image(fullfile(folder,'spmT_0001.nii'),data);image(fullfile(folder,'con_0001.nii'),data/2);
SPM=struct;SPM.xX.erdf=20;SPM.xVol=struct('R',[1 3 3 1],'S',143);
SPM.xCon=struct('name','known signed statistic','STAT','T','eidf',1,'Vspm',struct('fname','spmT_0001.nii'),'Vcon',struct('fname','con_0001.nii'));
save(fullfile(folder,'SPM.mat'),'SPM');
end
function manifest=betaFixture(root)
run=struct('subject','0007','session','baseline','name','run1','events','not_available.tsv');cfg=glm_config;
folder=fullfile(root,'framework');mkdir(folder);model=fullfile(folder,'models','joint');modelFixture(model,{'unit_000001','unit_000002'});
unit_index=[1;2];model_label=["unit_000001";"unit_000002"];source_id=["itemA";"itemB"];condition=["A";"B"];n_event_rows=[2;2];target_selected=[true;true];
plan=struct('estimateUnit','item','strategy','joint','expression','duration');plan.units=table(unit_index,model_label,source_id,condition,n_event_rows,target_selected);
plan.sourceEvents=table([2;10;20;30],ones(4,1),["A";"A";"B";"B"],'VariableNames',{'onset','duration','trial_type'});
plan.mapping=table([1;1;2;2],[2;10;20;30],ones(4,1),ones(4,1),'VariableNames',{'unit_index','onset_seconds','original_duration_seconds','modeled_duration_seconds'});
save(fullfile(folder,'model_plan.mat'),'plan');save(fullfile(folder,'GLM_FRAMEWORK_COMPLETE.mat'),'run','cfg');
outputs=table(repmat("joint",2,1),[1;2],string({fullfile(model,'beta_0001.nii');fullfile(model,'beta_0002.nii')}),ones(2,1), ...
    'VariableNames',{'model','target_unit_index','canonical_beta','estimated'});writetable(outputs,fullfile(folder,'model_outputs.tsv'),'FileType','text','Delimiter','\t');
legacy=fullfile(root,'legacy');mkdir(legacy);modelFixture(fullfile(legacy,'LSA'),{'event_001','event_002'});
for k=1:2,modelFixture(fullfile(legacy,'LSS',sprintf('event_%03d',k)),{'target'});end
summary=struct('methods',{{'LSA','LSS'}});mapping=table(["event_001";"event_002"],["A";"B"],[2;10],ones(2,1),[true;true], ...
    'VariableNames',{'event_label','original_condition','onset_seconds','duration_seconds','target_selected'});
save(fullfile(legacy,'SINGLE_TRIAL_COMPLETE.mat'),'summary','mapping','run','cfg');
gs=fullfile(root,'gs');mkdir(gs);mkdir(fullfile(gs,'TYPED'));mask=ones(6,6,4);mask(end)=0;image(fullfile(gs,'analysis_mask.nii'),mask);
data=cat(4,reshape(-.5+(0:143)*.01,[6 6 4]),reshape(2+(0:143)*.02,[6 6 4]));image(fullfile(gs,'TYPED','event_betas.nii'),data);
summary=struct('modelTypes',{{'B','D'}},'units','percent BOLD');cfg.hrf.type='library';cfg.events.expression='fixed';save(fullfile(gs,'GLMSINGLE_COMPLETE.mat'),'summary','cfg');
plan=struct;plan.mapping=table([1;1],[2;1],["B";"A"],["B";"A"],[10;20],[10;20],ones(2,1),ones(2,1)*20,[1;2], ...
    'VariableNames',{'run_index','source_event_index','identity','condition','onset_seconds','grid_onset_seconds','original_duration_seconds','modeled_duration_seconds','beta_index'});
events=table([7;4],["fileA";"fileB"],'VariableNames',{'original_event_index','stimulus_id'});plan.sourceTables={events};runs=run;
save(fullfile(gs,'preflight.mat'),'plan','runs');writetable(plan.mapping,fullfile(gs,'TYPED','beta_mapping.tsv'),'FileType','text','Delimiter','\t');
id=["framework";"legacy_lsa";"legacy_lss";"gs_D"];engine=["framework";"single_trial";"single_trial";"glmsingle"];
source_dir=[string(folder);string(legacy);string(legacy);string(gs)];variant=["auto";"LSA";"LSS";"D"];
manifest=fullfile(root,'sources.tsv');writetable(table(id,engine,source_dir,variant),manifest,'FileType','text','Delimiter','\t');
end
function modelFixture(folder,labels)
mkdir(folder);mask=ones(6,6,4);mask(end)=0;image(fullfile(folder,'mask.nii'),mask);SPM=struct;
for k=1:numel(labels)
    file=sprintf('beta_%04d.nii',k);image(fullfile(folder,file),reshape((k-1)*10+(0:143)*.1,[6 6 4]));
    SPM.xX.name{k}=sprintf('Sn(1) %s*bf(1)',labels{k});SPM.Vbeta(k).fname=file;
end
save(fullfile(folder,'SPM.mat'),'SPM');
end
function image(file,data)
ni=nifti;ni.dat=file_array(char(file),size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;create(ni);ni.dat(:)=single(data(:));
end
