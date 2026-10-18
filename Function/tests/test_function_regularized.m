function tests=test_function_regularized
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;t.TestData.root=fileparts(fileparts(mfilename('fullpath')));addpath(t.TestData.root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testOasNativeOracleHighDimension(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s'));rng(179);x=randn(12,25).*(1:25);file=fullfile(folder,'input.mat');save(file,'x','-v7');output=fullfile(folder,'oracle.mat');cog.python_process('D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe',fullfile(t.TestData.root,'tests','oas_oracle.py'),{file,output},fullfile(folder,'oracle.log'),60);s=load(output);c=regularized_fc_config;r=cog.shrinkage_covariance(x,c.options);verifyEqual(t,r.covariance,s.covariance,'AbsTol',1e-10);verifyEqual(t,r.shrinkage,s.shrinkage,'AbsTol',1e-12);verifyGreaterThan(t,min(eig(r.covariance)),0);verifyEqual(t,r.covariance*r.precision,eye(25),'AbsTol',1e-10);
end
function testStandardizationAndNativeBinaryModels(t)
rng(181);x=randn(80,5);y=repmat(["a";"b"],40,1);x(:,1)=x(:,1)+4*(double(y=="b")-.5);c=linear_decode_config;o=c.options;o.dependencyNote='Synthetic independent groups';groups="g"+string(ceil((1:80)'/20));for method={'svm','logistic'},o.estimator=method{1};r=cog.linear_decode(x,y,groups,string(1:5),o);verifyGreaterThanOrEqual(t,r.accuracy,.9);z=x;z(1:20,:)=z(1:20,:)+100;q=cog.linear_decode(z,y,groups,string(1:5),o);verifyEqual(t,r.folds{1}.model.trainingMean,q.folds{1}.model.trainingMean);verifyEqual(t,r.folds{1}.model.native.Beta,q.folds{1}.model.native.Beta,'AbsTol',1e-12);end
c=regularized_fc_config;c.options.standardize=true;a=cog.shrinkage_covariance(x,c.options);b=cog.shrinkage_covariance(x.*(1:5)+10,c.options);verifyEqual(t,a.covariance,b.covariance,'AbsTol',1e-12);
end
function testIdenticalRdmCeilingsAndBootstrap(t)
a=[0 1 2 4;1 0 3 5;2 3 0 6;4 5 6 0];c=rsa_ceiling_config;o=c.options;o.nBootstrap=29;o.designNote='Synthetic independent subjects, fixed conditions';r=cog.rsa_noise_ceiling(repmat(a,1,1,5),string(1:5),string(1:4),a,"exact",o);verifyEqual(t,[r.lower r.upper r.modelMeanScores],[1 1 1],'AbsTol',1e-12);verifyEqual(t,r.confidenceInterval(:,3),[1;1],'AbsTol',1e-12);verifyError(t,@()cog.rsa_noise_ceiling(zeros(2,2,3),string(1:3),string(1:2),[],[],o),'cog:CeilingInput');
end
function testCeilingBootstrapExcludesOriginalIdentity(t)
a=[0 1 2;1 0 4;2 4 0];b=[0 4 1;4 0 2;1 2 0];c=[0 2 4;2 0 1;4 1 0];cfg=rsa_ceiling_config;o=cfg.options;o.nBootstrap=80;o.designNote='Synthetic';r=cog.rsa_noise_ceiling(cat(3,a,b,c),string(1:3),string(1:3),[],[],o);verifyGreaterThan(t,nnz(~isfinite(r.bootstrapEstimates(:,1))),0);ix=triu(true(3),1);expected=corr(a(ix),mean([(b(ix)-mean(b(ix)))/norm(b(ix)-mean(b(ix))) (c(ix)-mean(c(ix)))/norm(c(ix)-mean(c(ix)))],2));verifyEqual(t,r.perSubject.lower(1),expected,'AbsTol',1e-12);
end
