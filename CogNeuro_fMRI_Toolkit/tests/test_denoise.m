function tests=test_denoise
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path; root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config')); h=preprocess_config; addpath(h.spmPath);
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
function testJointFrequencyAndConfounds(t)
n=100; time=(0:n-1)'+.5;
low=cos(pi*time*2/n); pass=cos(pi*time*10/n); high=cos(pi*time*70/n);
cfg=denoise_config; cfg.highpassHz=.02; cfg.lowpassHz=.1; cfg.minResidualDF=5;
m=psy.temporal_basis(high+cos(pi*time*12/n),1,cfg);
y=3+low+pass+high; residual=y-m.Q*(m.Q'*y);
verifyEqual(t,residual,pass,'AbsTol',1e-11);
verifyLessThan(t,norm(m.Q'*residual),1e-11);
end
function testRejectBandAndSaturation(t)
cfg=denoise_config; cfg.lowpassHz=.8;
verifyError(t,@()psy.temporal_basis(ones(40,1),1,cfg),'psy:TemporalBand');
cfg.lowpassHz=.09; cfg.minResidualDF=39;
verifyError(t,@()psy.temporal_basis(ones(40,1),1,cfg),'psy:TemporalDF');
end
function testImageBatchAndGeometry(t)
root=t.TestData.root; n=40; signal=sin((1:n)'*.8);
ni=nifti; ni.dat=file_array(fullfile(root,'bold.nii'),[3 4 2 n],'FLOAT32-LE',352,1,0);
ni.mat=diag([2 3 4 1]); ni.mat0=ni.mat; ni.timing=struct('toffset',0,'tspace',2); create(ni);
data=zeros(3,4,2,n,'single');
for j=1:n, data(:,:,:,j)=10+signal(j); end
ni.dat(:,:,:,:)=data;
writetable(table((1:n)','VariableNames',{'unused'}),fullfile(root,'confounds.tsv'),'FileType','text','Delimiter','\t');
f=fopen(fullfile(root,'runs.tsv'),'w'); fprintf(f,'subject\tsession\trun\tbold\tconfounds\tpurpose\ttemporal_state\n');
fprintf(f,'001\tbaseline\trest\tbold.nii\tconfounds.tsv\trest\tunfiltered_unregressed\n');
fprintf(f,'001\tfollowup\trest\tbold.nii\tconfounds.tsv\trest\tunfiltered_unregressed\n'); fclose(f);
cfg=denoise_config; h=preprocess_config; cfg.spmPath=h.spmPath;
cfg.design.motionModel='none'; cfg.design.includeTissueMeans=false; cfg.design.linearTrend=false;
cfg.highpassHz=0; cfg.lowpassHz=[]; cfg.outputRoot=fullfile(root,'out'); cfg.manifestFile=fullfile(root,'runs.tsv');
r=psy.denoise_batch(cfg); verifyTrue(t,all(strcmp({r.status},'temporally_projected_spatial_limitations_unchanged')));
out=fullfile(cfg.outputRoot,'sub-001','ses-baseline','rest','residual_bold.nii');
v=spm_vol(out); verifyEqual(t,numel(v),n); verifyEqual(t,v(1).mat,ni.mat,'AbsTol',1e-8);
result=spm_read_vols(v); original=double(squeeze(data(1,1,1,:))); expected=original-mean(original);
verifyEqual(t,squeeze(result(1,1,1,:)),expected,'AbsTol',1e-6);
verifyEqual(t,squeeze(result(3,4,2,:)),expected,'AbsTol',1e-6);
header=niftiinfo(out); verifyEqual(t,header.PixelDimensions(4),2); verifyEqual(t,header.TimeUnits,'Second');
verifyTrue(t,isfile(fullfile(cfg.outputRoot,'sub-001','ses-followup','rest','COMPLETE.mat')));
verifyEqual(t,double(ni.dat(:,:,:,:)),double(data));
end
function testTaskAndRepeatGuard(t)
cfg=denoise_config; r=struct('purpose','task','temporal_state','unfiltered_unregressed');
verifyError(t,@()psy.denoise_run(r,cfg,fullfile(t.TestData.root,'out')),'psy:DenoisePurpose');
r.purpose='rest'; r.temporal_state='filtered';
verifyError(t,@()psy.denoise_run(r,cfg,fullfile(t.TestData.root,'out')),'psy:DenoiseState');
end
