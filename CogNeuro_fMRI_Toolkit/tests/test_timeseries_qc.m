function tests=test_timeseries_qc
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=preprocess_config; addpath(cfg.spmPath);
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
root=tempname; mkdir(root); t.TestData.root=root;
series=cell(3,1);
for k=1:3
    series{k}=fullfile(root,sprintf('frame%d.nii',k));
    write(series{k},ones(2,2,2)*(9+k));
end
t.TestData.series=series;
write(fullfile(root,'mean.nii'),ones(2,2,2)*11);
writematrix(zeros(3,6),fullfile(root,'rp.txt'),'Delimiter','tab');
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testKnownMetrics(t)
root=t.TestData.root;
s=psy.timeseries_qc(t.TestData.series,fullfile(root,'mean.nii'),fullfile(root,'rp.txt'),fullfile(root,'qc'));
verifyEqual(t,s.medianTSNR,11,'AbsTol',1e-10);
verifyEqual(t,s.meanDVARS,1,'AbsTol',1e-10);
verifyEqual(t,s.meanFDmm,0); verifyEqual(t,s.maskVoxels,8);
q=readtable(fullfile(root,'qc','timeseries.tsv'),'FileType','text','Delimiter','\t');
verifyTrue(t,isnan(q.DVARS_native(1)));
end
function testRejectNonfinite(t)
root=t.TestData.root; d=ones(2,2,2); d(1)=NaN; write(t.TestData.series{2},d);
verifyError(t,@()psy.timeseries_qc(t.TestData.series,fullfile(root,'mean.nii'),fullfile(root,'rp.txt'),fullfile(root,'qc')),'psy:NonfiniteFrame');
end
function write(file,data)
h=struct('fname',file,'dim',[2 2 2],'dt',[64 0],'mat',eye(4),'pinfo',[1;0;0],'n',[1 1],'descrip','synthetic QC test');
spm_write_vol(h,data);
end
