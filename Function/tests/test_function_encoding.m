function tests=test_function_encoding
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testLagCannotCrossRunOrMissingFrames(t)
x={(1:8)'};runs=[repmat("r1",4,1);repmat("r2",4,1)];frames=[1;2;5;6;1;2;3;4];[a,keep,rows]=cog.lag_features(x,runs,frames,[0 1]);verifyEqual(t,find(keep),[2;4;6;7;8]);verifyEqual(t,a{1}(4,:),[4 3]);verifyEqual(t,rows(5,2),0);
end
function testRidgeAndBandedNestedRecoverMultipleTargets(t)
rng(18);n=120;x={randn(n,4),randn(n,3)};y=[x{1}(:,1)*2-x{2}(:,1),x{1}(:,2)+x{2}(:,2)*3]+randn(n,2)*.1;g=repelem(string((1:4)'),30);frames=repmat((1:30)',4,1);c=encoding_config;o=c.options;o.lambdaCandidates=[.1;1;10];r=cog.encoding_cv(x,y,g,frames,g,zeros(n,0),o);verifyGreaterThan(t,r.rSquared,[.95 .95]);o.method='banded_ridge';o.lambdaCandidates=[.1 10;10 .1;.1 .1];r=cog.encoding_cv(x,y,g,frames,g,zeros(n,0),o);verifyGreaterThan(t,r.rSquared,[.95 .95]);verifyEqual(t,sum(r.featureSpacePredictionsValidRows,3)+r.nuisancePredictionValidRows,r.prediction,'AbsTol',1e-10);
end
function testHeldOutTargetsDoNotAffectItsFit(t)
rng(27);n=90;x={randn(n,3)};y=x{1}(:,1)+randn(n,1)*.1;g=repelem(["a";"b";"c"],30);frames=repmat((1:30)',3,1);c=encoding_config;o=c.options;o.lambdaCandidates=[.1;1];r=cog.encoding_cv(x,y,g,frames,g,zeros(n,0),o);y(1:30)=y(1:30)*100;r2=cog.encoding_cv(x,y,g,frames,g,zeros(n,0),o);verifyEqual(t,r.models{1},r2.models{1});verifyEqual(t,r.prediction(1:30),r2.prediction(1:30));
end
function testBandedPenaltyMatchesOrthogonalAnalyticSolution(t)
rng(13);n=20;a=randn(n,2);a=a-mean(a);[q,~]=qr(a,0);x=q*sqrt(n-1);y=x*[2;-3];model=cog.encoding_fit({x(:,1),x(:,2)},y,zeros(n,0),[1 10]);verifyEqual(t,model.weights,[2*(n-1)/(n-1+1);-3*(n-1)/(n-1+10)],'AbsTol',1e-12);
end
function testBlockedContinuousCvPurgesLagAndAdjacentFrames(t)
rng(8);n=90;x={randn(n,2)};y=x{1}(:,1)+randn(n,1)*.1;run=repmat("run1",n,1);frames=(1:n)';g=repelem(["a";"b";"c"],30);cfg=encoding_config;o=cfg.options;o.sampleKind='continuous';o.lagsFrames=[0 1];o.purgeFrames=2;o.lambdaCandidates=1;r=cog.encoding_cv(x,y,run,frames,g,zeros(n,0),o);ids=find(r.validRows);training=ids(r.models{2}.trainingValidRowIds);verifyFalse(t,any(ismember(training,[28:30 61:63])));verifyTrue(t,all(isnan(r.prediction(1,:))));
end
