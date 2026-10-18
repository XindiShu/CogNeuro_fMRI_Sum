function tests=test_function_patterns
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testDecodingSignalAndTrainingOnlyScaling(t)
rng(5);n=120;target=repmat(["a";"b"],n/2,1);g=repelem(["r1";"r2";"r3"],40);x=randn(n,5)*.1;x(:,1)=x(:,1)+3*(target=="b");o=pattern_config;
r=cog.decode(x,target,g,o.decode);verifyEqual(t,r.accuracy,1);verifyEqual(t,r.balancedAccuracy,1);
verifyEqual(t,r.folds{1}.trainingMean,mean(x(g~="r1",:),1),'AbsTol',1e-12);
changed=x;changed(g=="r1",2)=changed(g=="r1",2)+1e5;s=cog.decode(changed,target,g,o.decode);verifyEqual(t,s.folds{1}.trainingMean,r.folds{1}.trainingMean);
verifyError(t,@()cog.decode(x,target,repmat("one",n,1),o.decode),'cog:CV');
end
function testRidgePrediction(t)
rng(6);x=randn(120,4);y=x*[1;2;-3;.5];g=repelem((1:4)',30);o=pattern_config;o.decode.task='regression';o.decode.lambda=.01;
r=cog.decode(x,y,g,o.decode);verifyGreaterThan(t,r.rSquared,.999);verifyLessThan(t,r.mae,.002);
end
function testRsaGeometryAndCrossvalidation(t)
x=[1 0 0;0 1 0;0 0 1];o=pattern_config;labels=["a";"b";"c"];
r=cog.rsa(x,labels,ones(3,1),o.rsa);verifyEqual(t,r.rdm,[0 1.5 1.5;1.5 0 1.5;1.5 1.5 0],'AbsTol',1e-12);
o.rsa.metric='crossnobis';o.rsa.noiseCovariance=eye(3);r=cog.rsa([x;x],[labels;labels],[ones(3,1);2*ones(3,1)],o.rsa);
verifyEqual(t,r.rdm,(2/3)*(ones(3)-eye(3)),'AbsTol',1e-12);
r=cog.rsa([x;-x],[labels;labels],[ones(3,1);2*ones(3,1)],o.rsa);verifyLessThan(t,r.rdm(1,2),0);
verifyError(t,@()cog.rsa(x,labels,ones(3,1),o.rsa),'cog:RSAPartitions');
end
function testBetaSeriesGroupsAndUnits(t)
rng(9);n=16;meta=table(repmat("s",n,1),repmat("",n,1),repelem(["r1";"r2"],8),repmat("a",n,1),"id"+string((1:n)'),repmat("trial",n,1),'VariableNames',{'subject','session','run','condition','estimate_id','estimate_unit'});
x=randn(n,3);r=cog.beta_series(x,meta,4);verifyNumElements(t,r,2);verifyEqual(t,r{1}.nTrials,8);
meta.estimate_unit(1)="condition";verifyError(t,@()cog.beta_series(x,meta,4),'cog:BetaUnit');
end
function testSpearmanEuclideanAndModelLabels(t)
y=[1 5;1 4;3 3;4 2;7 1];r=cog.fc(y,'spearman');verifyEqual(t,r.correlation,corr(y,'Type','Spearman'),'AbsTol',1e-12);
o=pattern_config;o.rsa.metric='euclidean';labels=["a";"b";"c"];x=[0 0;3 0;3 4];r=cog.rsa(x,labels,ones(3,1),o.rsa);verifyEqual(t,r.rdm,[0 3 5;3 0 4;5 4 0],'AbsTol',1e-12);
o.rsa.modelRDMs=r.rdm;o.rsa.modelLabels=labels;s=cog.rsa(x,labels,ones(3,1),o.rsa);verifyEqual(t,s.modelFits,1,'AbsTol',1e-12);
o.rsa.modelLabels=flipud(labels);verifyError(t,@()cog.rsa(x,labels,ones(3,1),o.rsa),'cog:RSAModelLabels');
end
