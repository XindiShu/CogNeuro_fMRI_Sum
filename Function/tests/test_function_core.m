function tests=test_function_core
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function('D:/matlab/atoolbox/spm12');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testFcAnalyticAndPartial(t)
rng(17);a=randn(250,1);b=randn(250,1);z=randn(250,1);r=cog.fc([a a -a],'pearson');
verifyEqual(t,r.correlation,[1 1 -1;1 1 -1;-1 -1 1],'AbsTol',1e-12);verifyTrue(t,all(isnan(diag(r.fisherZ))));
y=[a+z b+z z];r=cog.fc(y,'partial');p=partialcorr(y);verifyEqual(t,r.correlation,p,'AbsTol',1e-10);
verifyError(t,@()cog.fc([a ones(250,1)]),'cog:Constant');verifyError(t,@()cog.fc([a a],'partial'),'cog:Singular');
end
function testSeedAndFdr(t)
rng(4);y=randn(50,8);r=cog.seed_fc(y(:,1:2),y);expected=corr(y(:,1:2),y);verifyEqual(t,r,expected,'AbsTol',1e-12);
[q,k]=cog.bh_fdr([.001 .01 .04 .2 NaN]);verifyEqual(t,q(1:4),[.004 .02 .04*4/3 .2],'AbsTol',1e-12);verifyEqual(t,k,[true true false false false]);
end
function testJointProjectionAndGuards(t)
rng(8);n=160;c=randn(n,2);y=5+linspace(-4,4,n)'+c*[1 2 3;2 -1 4]+randn(n,3);o=struct('detrend',true,'bandHz',[],'minResidualDimensions',10);
[r,s]=cog.clean_timeseries(y,.8,c,o);x=[ones(n,1) c linspace(-1,1,n)'];expected=y-x*(x\y);verifyEqual(t,r,expected,'AbsTol',1e-11);verifyEqual(t,s.projectionRank,4);
verifyError(t,@()cog.clean_timeseries(y,.8,c(1:end-1,:),o),'cog:Confounds');o.bandHz=[.1 1];verifyError(t,@()cog.clean_timeseries(y,.8,c,o),'cog:Band');
end
function testSpectrumIndependentSines(t)
n=200;tr=1;time=(0:n-1)';y=3*sin(2*pi*.05*time)+sin(2*pi*.2*time);
r=cog.spectrum_metrics(y,tr,[.04 .06]);verifyEqual(t,r.falff,.75,'AbsTol',1e-12);verifyEqual(t,r.alff,3/r.nBandBins,'AbsTol',1e-12);
r=cog.spectrum_metrics(ones(n,1),tr,[.04 .06]);verifyEqual(t,r.alff,0,'AbsTol',1e-12);verifyTrue(t,isnan(r.falff));
end
function testRehoTiesAndOpposite(t)
mask=true(3,3,3);indices=find(mask);[i,j,k]=ind2sub(size(mask),indices);s=struct('mask',mask,'indices',indices,'ijk',[i j k]);
a=repmat([1;1;3;4;5;5;7;8],1,27);r=cog.reho(a,s,27,7);verifyEqual(t,r.kendallW,ones(1,27),'AbsTol',1e-12);
r=cog.reho(ones(8,27),s,7,2);verifyTrue(t,all(isnan(r.kendallW)));
end
function testNiftiRoundtripAndBatchIsolation(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
cfg=function_config;cfg.clean.minResidualDimensions=3;cfg.methods={'static_fc','alff','reho'};cfg.execute=true;cfg.outputRoot=fullfile(folder,'output');cfg.spectrum.bandHz=[.05 .2];cfg.roiMinVoxels=2;
dim=[4 4 3];n=40;tr=.8;mask=ones(dim);labels=ones(dim);labels(3:4,:,:)=2;
writeImage(fullfile(folder,'mask.nii'),mask,tr);writeImage(fullfile(folder,'roi.nii'),labels,tr);rng(10);data=100+randn([dim n]);writeImage(fullfile(folder,'bold.nii'),data,tr);
subject=["0001";"0002"];session=["s1";"s2"];run=["r1";"r1"];bold=repmat("bold.nii",2,1);mask=repmat("mask.nii",2,1);roi_file=repmat("roi.nii",2,1);tr_seconds=repmat(tr,2,1);temporal_state=repmat("unfiltered_unregressed",2,1);smoothing_fwhm_mm=zeros(2,1);confounds=repmat("",2,1);purpose=repmat("engineering",2,1);
tab=table(subject,session,run,bold,mask,roi_file,tr_seconds,temporal_state,smoothing_fwhm_mm,confounds,purpose);file=fullfile(folder,'runs.tsv');writetable(tab,file,'FileType','text','Delimiter','\t');cfg.manifestFile=file;
p=cfg;p.execute=false;s=run_function(p);verifyEqual(t,s.nRuns,2);verifyFalse(t,isfolder(cfg.outputRoot));
s=run_function(cfg);verifyEqual(t,s.completed,2);verifyEqual(t,s.failed,0);verifyTrue(t,isfile(fullfile(cfg.outputRoot,'0002','s2','r1','falff.nii')));
verifyError(t,@()run_function(cfg),'cog:Exists');[y,space]=cog.load_bold(fullfile(folder,'bold.nii'),fullfile(folder,'mask.nii'),tr,1);verifySize(t,y,[40 48]);
verifyError(t,@()cog.load_bold(fullfile(folder,'bold.nii'),fullfile(folder,'mask.nii'),1,1),'cog:TR');
v=space.reference;v.mat(1,4)=7;verifyError(t,@()cog.check_grid(v,space.reference),'cog:Grid');
% 一run失败不丢失已成功run；失败记录字段与成功记录可不同。
badConf=fullfile(folder,'short_confounds.tsv');writetable(table((1:10)','VariableNames',{'motion'}),badConf,'FileType','text','Delimiter','\t');tab.confounds(2)=string(badConf);writetable(tab,file,'FileType','text','Delimiter','\t');
cfg.methods={'static_fc'};cfg.outputRoot=fullfile(folder,'partial_failure');s=run_function(cfg);verifyEqual(t,s.completed,1);verifyEqual(t,s.failed,1);verifyFalse(t,isfile(fullfile(cfg.outputRoot,'BATCH_COMPLETE.mat')));
end
function writeImage(file,data,tr)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;ni.timing=struct('toffset',0,'tspace',tr);create(ni);ni.dat(:,:,:,:)=data;
end
