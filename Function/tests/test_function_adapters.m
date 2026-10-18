function tests=test_function_adapters
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function('D:/matlab/atoolbox/spm12');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testBackgroundAndPpiBatchPreflight(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
rng(15);n=40;dims=[3 3 3];data=100+randn([dims n]);bold=fullfile(folder,'bold.nii');writeImage(bold,data);mask=fullfile(folder,'mask.nii');writeImage(mask,ones(dims));roi=fullfile(folder,'roi.nii');labels=ones(dims);labels(3,:,:)=2;writeImage(roi,labels);
SPM.xY.VY=spm_vol(bold);SPM.xY.RT=1;SPM.Sess.row=1:n;SPM.Sess.col=1:2;SPM.Sess.Fc=struct('i',1,'name','task','p',1);SPM.Sess.U=struct('name',{{'task'}},'u',zeros(n*16+32,1));SPM.Sess.C=struct('C',randn(n,1),'name',{{'motion'}});SPM.xX.X=[sin((1:n)'/5) SPM.Sess.C.C ones(n,1)];SPM.xX.K.X0=zeros(n,0);SPM.xX.W=eye(n);SPM.Vbeta=SPM.xY.VY(1);
file=fullfile(folder,'SPM.mat');save(file,'SPM');c=background_config;c.spmMat=file;c.maskFile=mask;c.roiFile=roi;c.execute=true;c.outputRoot=fullfile(folder,'background');r=run_background_fc(c);verifyEqual(t,r.nTaskColumns,1);verifyEqual(t,r.processing.nConfounds,2);verifyTrue(t,isfile(fullfile(c.outputRoot,'BACKGROUND_COMPLETE.mat')));
c=ppi_config;c.spmMat=file;c.seedMask=mask;c.outputRoot=fullfile(folder,'ppi');
subject=["001";"002"];session=["a";"b"];run=repmat("r",2,1);spm_mat=repmat(string(file),2,1);seed_mask=repmat(string(mask),2,1);spm_session_index=ones(2,1);tab=table(subject,session,run,spm_mat,seed_mask,spm_session_index);manifest=fullfile(folder,'ppi_runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');r=run_ppi_batch(c,manifest);verifyNumElements(t,r,2);verifyFalse(t,isfolder(c.outputRoot));
tab.subject(2)=tab.subject(1);tab.session(2)=tab.session(1);writetable(tab,manifest,'FileType','text','Delimiter','\t');verifyError(t,@()run_ppi_batch(c,manifest),'cog:Manifest');
end
function writeImage(file,data)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);ni.mat=eye(4);ni.mat0=eye(4);ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:,:,:,:)=data;
end
