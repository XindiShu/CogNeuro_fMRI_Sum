function tests=test_confounds
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path; root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=preprocess_config; addpath(cfg.spmPath);
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
t.TestData.root=tempname; mkdir(t.TestData.root);
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testMotionConvention(t)
rp=zeros(3,6); rp(2:3,1)=2; rp(3,4)=.1;
[x,names,fd]=psy.motion_regressors(rp,50);
verifyEqual(t,size(x),[3 24]); verifyEqual(t,numel(names),24);
verifyEqual(t,fd,[0;2;5],'AbsTol',1e-12); verifyEqual(t,x(1,7:12),zeros(1,6));
verifyEqual(t,x(:,13:18),rp.^2);
end
function testWorldTransformAndErosion(t)
a=zeros(7,7,7); a(2:4,2:4,2:4)=1;
v=header(fullfile(t.TestData.root,'p.nii'),[7 7 7]); v.mat(1,4)=1; spm_write_vol(v,a);
ref=header('',[7 7 7]);
mask=psy.tissue_mask(v.fname,ref,.95,0);
expected=false(7,7,7); expected(3:5,2:4,2:4)=true;
verifyEqual(t,mask,expected);
mask=psy.tissue_mask(v.fname,ref,.95,1);
verifyEqual(t,nnz(mask),1); verifyTrue(t,mask(4,3,3));
end
function testSignalsBatchAndSessions(t)
root=t.TestData.root; wm=zeros(9,9,9); wm(1:3,1:3,1:3)=1;
csf=zeros(9,9,9); csf(7:9,7:9,7:9)=1;
spm_write_vol(header(fullfile(root,'wm.nii'),[9 9 9]),wm);
spm_write_vol(header(fullfile(root,'csf.nii'),[9 9 9]),csf);
for k=1:6
    a=ones(9,9,9)*5; a(wm>0)=10+k; a(csf>0)=30+2*k;
    v=header(fullfile(root,'bold.nii'),[9 9 9]); v.n=[k 1]; spm_write_vol(v,a);
end
rp=zeros(6,6); rp(:,1)=(0:5)'*.1; writematrix(rp,fullfile(root,'rp.txt'),'Delimiter','tab');
f=fopen(fullfile(root,'runs.tsv'),'w');
fprintf(f,'subject\tsession\trun\tbold\twm\tcsf\tmotion\talignment\n');
fprintf(f,'001\tbaseline\trest\tbold.nii\twm.nii\tcsf.nii\trp.txt\tworld_aligned\n');
fprintf(f,'001\tfollowup\trest\tbold.nii\twm.nii\tcsf.nii\trp.txt\tworld_aligned\n'); fclose(f);
cfg=confounds_config; h=preprocess_config; cfg.spmPath=h.spmPath;
cfg.manifestFile=fullfile(root,'runs.tsv'); cfg.outputRoot=fullfile(root,'out'); cfg.erosionMm=0; cfg.minVoxels=1;
r=psy.confounds_batch(cfg); verifyEqual(t,{r.status},repmat({'confounds_extracted_not_regressed'},1,2));
a=readtable(fullfile(r(1).output,'confounds.tsv'),'FileType','text','Delimiter','\t');
verifyEqual(t,a.white_matter,(11:16)','AbsTol',1e-8); verifyEqual(t,a.csf,(32:2:42)','AbsTol',1e-8);
verifyTrue(t,isfile(fullfile(r(2).output,'COMPLETE.mat')));
verifyError(t,@()psy.confounds_batch(cfg),'psy:ConfoundsExists');
run=struct('bold',fullfile(root,'bold.nii'),'wm',fullfile(root,'wm.nii'), ...
    'csf',fullfile(root,'csf.nii'),'motion',fullfile(root,'rp.txt'));
cfg.minVoxels=100;
verifyError(t,@()psy.extract_confounds(run,cfg,fullfile(root,'smallmask')),'psy:SmallTissueMask');
cfg.minVoxels=1; writematrix(zeros(5,6),run.motion,'Delimiter','tab');
verifyError(t,@()psy.extract_confounds(run,cfg,fullfile(root,'wronglength')),'psy:MotionLength');
end
function v=header(file,dim)
v=struct('fname',file,'dim',dim,'dt',[16 0],'mat',eye(4),'pinfo',[1;0;0],'n',[1 1],'descrip','synthetic test');
end
