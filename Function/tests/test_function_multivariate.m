function tests=test_function_multivariate
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testClassicalCcaMatchesNativeCanonicalCorrelations(t)
rng(88);x=randn(80,4);y=x(:,1:2)*.7+randn(80,2)*.4;c=multivariate_config;o=c.options;o.nComponents=2;o.lambdaX=0;o.lambdaY=0;m=cog.multivariate_fit(x,y,zeros(80,0),'cca',o);[~,~,r]=canoncorr(x,y);verifyEqual(t,m.statistics,r(:)','AbsTol',1e-10);
end
function testPlsAssociationRefitPermutationAndUnitBootstrap(t)
rng(12);n=60;a=randn(n,1);x=[a randn(n,2)];y=[a*2 randn(n,1)*.4+a];c=multivariate_config;o=c.options;o.nPermutations=19;o.nBootstrap=19;o.exchangeabilityJustification='Independent synthetic rows';units=string((1:n)');r=cog.multivariate_analysis(x,y,zeros(n,0),units,repmat("all",n,1),units,'pls_covariance',o);verifyLessThanOrEqual(t,r.pComponent,.1);verifyGreaterThanOrEqual(t,r.pFweComponents,r.pComponent);verifySize(t,r.xWeightPercentileCi,[2 3]);verifyFalse(t,r.inferenceEligible);
end
function testPlsRegressionFrozenGroupPredictionAndTargetIsolation(t)
rng(92);n=80;x=randn(n,4);y=x(:,1:2)+randn(n,2)*.1;g=repelem(string((1:8)'),10);c=multivariate_config;o=c.options;o.nComponents=3;o.crossValidate=true;units=string((1:n)');r=cog.multivariate_analysis(x,y,zeros(n,0),units,repmat("all",n,1),g,'pls_regression',o);verifyGreaterThan(t,r.cv.rSquared,[.9 .9]);changed=y;changed(1:10,:)=changed(1:10,:)+100;r2=cog.multivariate_analysis(x,changed,zeros(n,0),units,repmat("all",n,1),g,'pls_regression',o);verifyEqual(t,r.cv.models{1},r2.cv.models{1});verifyEqual(t,r.cv.predictionY(1:10,:),r2.cv.predictionY(1:10,:));
end
function testMediationDecompositionAndBootstrap(t)
rng(83);n=180;x=randn(n,1);m=.7*x+randn(n,1)*.2;y=.4*x+1.2*m+randn(n,1)*.2;c=multivariate_config;o=c.options;o.nBootstrap=39;o.exchangeabilityJustification='Independent synthetic rows';r=cog.mediation(x,m,y,zeros(n,0),string((1:n)'),o);verifyEqual(t,r.total,r.direct+r.indirect,'AbsTol',1e-12);verifyEqual(t,r.indirect,.84,'AbsTol',.15);verifyGreaterThan(t,r.percentileCi(1,4),0);o.nBootstrap=0;small=cog.mediation([0;1;2],[1;0;2],[2;3;1],zeros(3,0),["a";"b";"c"],o);verifyEqual(t,small.residualDfOutcome,0);verifyFalse(t,small.inferenceEligible);
end
