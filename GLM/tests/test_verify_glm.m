function tests=test_verify_glm
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=preprocess_config;addpath(cfg.spmPath);
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
out=tempname;mkdir(out);t.TestData.out=out;
v=struct('fname','','dim',[4 4 4],'dt',[16 0],'mat',eye(4), ...
    'pinfo',[1;0;0],'n',[1 1],'descrip','synthetic GLM QC');
names={'mask.nii','beta_0001.nii','ResMS.nii','con_0001.nii','spmT_0001.nii'};
for k=1:numel(names)
    v.fname=fullfile(out,names{k});spm_write_vol(v,ones(4,4,4)*k);
end
SPM=struct;SPM.xX.X=ones(12,2);
SPM.xCon=struct('name','conditionA','STAT','T');
SPM.Vbeta=struct('fname','beta_0001.nii');
SPM.VResMS=struct('fname','ResMS.nii');
save(fullfile(out,'SPM.mat'),'SPM');
end
function teardown(t)
rmdir(t.TestData.out,'s');
end
function testCompleteMapsInsideMask(t)
qc=psy.verify_glm(t.TestData.out);
verifyEqual(t,qc.nFrames,12);
verifyEqual(t,qc.nMaskedVoxels,64);
verifyEqual(t,qc.nContrasts,1);
verifyTrue(t,isfile(fullfile(t.TestData.out,'glm_qc.json')));
end
function testRejectNonfiniteContrastInsideMask(t)
v=spm_vol(fullfile(t.TestData.out,'con_0001.nii'));
a=spm_read_vols(v);a(2,2,2)=NaN;spm_write_vol(v,a);
verifyError(t,@()psy.verify_glm(t.TestData.out),'psy:GLMQC');
verifyFalse(t,isfile(fullfile(t.TestData.out,'glm_qc.json')));
end
