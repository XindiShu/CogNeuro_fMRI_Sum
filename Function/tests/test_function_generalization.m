function tests=test_function_generalization
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;addpath(fileparts(fileparts(mfilename('fullpath'))));setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testIccAgreementVersusConsistencyAnalytic(t)
c=reliability_config;o=c.options;o.designNote='Synthetic fixed rater offset';y=[(1:5)' (6:10)'];r=cog.icc(y,string(1:5),["a" "b"],o);verifyEqual(t,r.values(3),1/6,'AbsTol',1e-12);verifyEqual(t,r.values(4),2/7,'AbsTol',1e-12);verifyEqual(t,r.values(5:6),[1;1],'AbsTol',1e-12);r=cog.icc(ones(5,2),string(1:5),["a" "b"],o);verifyTrue(t,all(isnan(r.values),'all'));
end
function testIccRowBootstrapAndNegativeRetained(t)
c=reliability_config;o=c.options;o.designNote='Synthetic';o.nBootstrap=39;y=[(1:8)' (1:8)'];before=rng;r=cog.icc(y,string(1:8),["a" "b"],o);verifyEqual(t,rng,before);verifyEqual(t,r.confidenceInterval(:,5),[1;1],'AbsTol',1e-12);o.nBootstrap=0;r=cog.icc([(1:5)' (5:-1:1)'],string(1:5),["a" "b"],o);verifyLessThan(t,r.values(5),0);
end
function testFrozenRidgeAndFeatureIdentity(t)
rng(153);x=randn(40,4);y=x*[1;2;3;4]+.1*randn(40,1);c=transfer_config;o=c.options;o.estimator='ridge';o.lambda=.1;ids=string(1:4);m=cog.pattern_fit(x,y,ids,o);z=cog.pattern_apply(m,x(1:3,:),ids);verifyEqual(t,m.trainingMean,mean(x),'AbsTol',1e-12);verifyEqual(t,z.prediction,((x(1:3,:)-mean(x))./std(x))*m.weights+mean(y),'AbsTol',1e-12);verifyError(t,@()cog.pattern_apply(m,x,fliplr(ids)),'cog:PatternApply');
end
function testDomainBoundariesAndParallelHalf(t)
c=transfer_config;o=c.options;o.dependencyNote='Synthetic new subjects';a=struct('X',randn(8,2),'Y',repmat(["a";"b"],4,1),'sampleIds',"train"+string((1:8)'),'independentUnitIds',repmat("person1",8,1),'domainId','task1','featureIds',["f1";"f2"]);b=a;b.sampleIds="test"+string((1:8)');b.domainId='task2';verifyError(t,@()cog.transfer_check(a,b,o),'cog:TransferLeakage');o.unitPolicy='matched_units_distinct_domains';cog.transfer_check(a,b,o);m=cog.pattern_fit(a.X,a.Y,a.featureIds,o);p=cog.pattern_apply(m,b.X,b.featureIds);b.Y=flip(b.Y);q=cog.pattern_apply(m,b.X,b.featureIds);verifyEqual(t,p.prediction,q.prediction);
c=reliability_config;v=c.options;v.designNote='Synthetic identical parallel items';r=cog.split_half(repmat((1:10)',1,8),string(1:10),string(1:8),v);verifyEqual(t,r.correlation,1,'AbsTol',1e-12);verifyEqual(t,r.spearmanBrown,1,'AbsTol',1e-12);
v.splitPolicy='random_balanced';v.nSplits=7;before=rng;r=cog.split_half(repmat((1:10)',1,8),string(1:10),string(1:8),v);verifyEqual(t,rng,before);verifyEqual(t,r.spearmanBrown,ones(7,1),'AbsTol',1e-12);for k=1:7,verifyEmpty(t,intersect(r.leftItems{k},r.rightItems{k}));verifyEqual(t,numel(r.leftItems{k}),4);end
end
