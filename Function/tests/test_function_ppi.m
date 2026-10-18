function tests=test_function_ppi
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function('D:/matlab/atoolbox/spm12');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testNativePpiLinearityAndDeconvolution(t)
folder=tempname;mkdir(folder);old=pwd;c=onCleanup(@()cleanup(old,folder)); %#ok<NASGU>
n=64;nt=16;SPM=struct;SPM.pwd=folder;SPM.xY.RT=1;SPM.xBF.dt=1/nt;SPM.xBF.T0=1;SPM.xX.W=speye(n);SPM.Sess.row=1:n;
u=zeros(n*nt+32,1);u(33:32+n*nt/2)=1;SPM.Sess.U(1)=struct('name',{{'a'}},'u',u);SPM.Sess.U(2)=struct('name',{{'b'}},'u',[zeros(32,1);1-u(33:end)]);
rng(16);xY=struct('u',sin((1:n)'*.1)+randn(n,1)*.1,'X0',ones(n,1),'Sess',1,'name','synthetic');
a=spm_peb_ppi(SPM,'ppi',xY,[1 1 1],'a',0);b=spm_peb_ppi(SPM,'ppi',xY,[2 1 1],'b',0);contrast=spm_peb_ppi(SPM,'ppi',xY,[1 1 1;2 1 -1],'difference',0);
verifyEqual(t,contrast.ppi,a.ppi-b.ppi,'AbsTol',1e-10);verifyNumElements(t,a.ppi,n);verifyNumElements(t,a.xn,n*nt);verifyTrue(t,all(isfinite(a.ppi)));
end
function testIndependentGroupSummary(t)
y=[1 2;2 1;3 4;4 3];r=cog.group_summary(y,["s1";"s2";"s3";"s4"]);verifyEqual(t,r.mean,[2.5 2.5]);verifyEqual(t,r.t,[sqrt(15) sqrt(15)],'AbsTol',1e-12);
verifyError(t,@()cog.group_summary(y,["s1";"s1";"s2";"s3"]),'cog:Group');
end
function cleanup(old,folder)
cd(old);rmdir(folder,'s');
end
