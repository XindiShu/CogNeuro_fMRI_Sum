function tests=test_finalize_realign
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.root=tempname;mkdir(t.TestData.root);
data=ones(8,8,8,3,'single')*100;
data(1,1,1,:)=NaN;data(2,2,2,:)=NaN;
niftiwrite(data,fullfile(t.TestData.root,'r.nii'));
niftiwrite(ones(8,8,8,'single')*100,fullfile(t.TestData.root,'mean.nii'));
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testPreserveRawAndExcludeMissing(t)
root=t.TestData.root;
r=psy.finalize_realign(fullfile(root,'r.nii'),fullfile(root,'mean.nii'),fullfile(root,'out'));
verifyEqual(t,r.unionNonfiniteVoxels,2);
verifyEqual(t,r.validSignalVoxels,8^3-2);
source=niftiread(fullfile(root,'r.nii'));
verifyTrue(t,isnan(source(1,1,1,1)));
v=spm_vol(r.cleanSeries);
verifyEqual(t,numel(v),3);
for k=1:3, verifyTrue(t,all(isfinite(spm_read_vols(v(k))),'all')); end
mask=niftiread(r.maskFile);verifyEqual(t,nnz(mask),8^3-2);
end
function testRejectExcessiveMissing(t)
root=t.TestData.root;
verifyError(t,@()psy.finalize_realign(fullfile(root,'r.nii'), ...
    fullfile(root,'mean.nii'),fullfile(root,'out2'),maxNonfiniteFraction=0.001), ...
    'psy:FinalizeCoverage');
end
function testRejectChangingMissingPattern(t)
root=t.TestData.root;
data=niftiread(fullfile(root,'r.nii'));
data(2,2,2,3)=100;
niftiwrite(data,fullfile(root,'changing.nii'));
verifyError(t,@()psy.finalize_realign(fullfile(root,'changing.nii'), ...
    fullfile(root,'mean.nii'),fullfile(root,'out3')),'psy:FinalizePattern');
end
