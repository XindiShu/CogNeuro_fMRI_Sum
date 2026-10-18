function tests=test_function_prediction
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testNestedModelsRecoverSignalAndKeepGroupRowsTogether(t)
rng(51);n=48;x=randn(n,10);y=3*x(:,1)-2*x(:,2)+randn(n,1)*.15;groups=repelem(string((1:12)'),4);c=prediction_config;o=c.options;o.lambdaGrid=[.1 1];o.cpmPGrid=[.01 .1];
for method={'ridge','cpm'},o.method=method{1};r=cog.predict_nested(x,y,groups,zeros(n,0),repmat("all",n,1),o);verifyGreaterThan(t,r.correlation,.8);for k=1:12,verifyEqual(t,numel(r.models{k}.testRowIds),4);end,end
end
function testHeldOutTargetCannotChangeItsTrainingModel(t)
rng(14);n=12;x=randn(n,4);c=randn(n,1);y=x(:,1)+3*c+randn(n,1)*.1;groups=string((1:n)');cfg=prediction_config;o=cfg.options;o.lambdaGrid=[.1 1];r=cog.predict_nested(x,y,groups,c,repmat("all",n,1),o);changed=y;changed(1)=changed(1)+100;r2=cog.predict_nested(x,changed,groups,c,repmat("all",n,1),o);verifyEqual(t,r.models{1},r2.models{1});verifyEqual(t,r.prediction(1),r2.prediction(1));
o.nPermutations=1;o.exchangeabilityJustification='simulation';verifyError(t,@()cog.predict_nested(x,y,groups,c,repmat("all",n,1),o),'cog:PredictionPermutation');
end
function testPermutationAndMinimumGroups(t)
rng(7);n=10;x=randn(n,3);y=x(:,1)+.1*randn(n,1);groups=string((1:n)');cfg=prediction_config;o=cfg.options;o.lambdaGrid=1;o.nPermutations=3;o.exchangeabilityJustification='Independent simulated subject targets';r=cog.predict_nested(x,y,groups,zeros(n,0),repmat("all",n,1),o);verifyGreaterThanOrEqual(t,r.pHigherCorrelation,.25);verifySize(t,r.nullCorrelation,[3 1]);verifyError(t,@()cog.predict_nested(x(1:3,:),y(1:3),groups(1:3),zeros(3,0),repmat("all",3,1),o),'cog:PredictionInput');
end
