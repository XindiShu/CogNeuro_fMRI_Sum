function tests=test_function_rest_extended
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testDistinctEntropyDefinitionsAndTies(t)
c=rest_extended_config;o=c.entropy;r=cog.entropy_metrics(ones(30,1),o);verifyEqual(t,r.sampleEntropyNats,0);verifyTrue(t,isnan(r.permutationEntropyBits));verifyEqual(t,r.histogramEntropyBits,0);r=cog.entropy_metrics((1:30)',o);verifyEqual(t,r.permutationEntropyNormalized,0);rng(95);x=randn(1800,1);a=cog.entropy_metrics(x,o);b=cog.entropy_metrics(3*x+10,o);verifyEqual(t,a.sampleEntropyNats,b.sampleEntropyNats,'AbsTol',1e-12);verifyGreaterThan(t,a.permutationEntropyNormalized,.98);verifyEqual(t,a.sampleEntropyNats,-log(erf(.1)),'AbsTol',.15);
end
function testArOneScaleAndNoGapConcatenation(t)
rng(97);n=20000;x=filter(1,[1 -.8],randn(n+200,1));x=x(201:end);c=rest_extended_config;o=c.timescales;o.expFitMaxLagSeconds=3;r=cog.autocorrelation_timescales(x,.5,(1:n)',o);verifyEqual(t,r.acfBiasedNormalized(1),1,'AbsTol',1e-12);verifyEqual(t,r.positiveAreaSeconds,2.25,'AbsTol',.5);verifyEqual(t,r.exponentialApproxTauSeconds,-.5/log(.8),'AbsTol',.5);verifyError(t,@()cog.autocorrelation_timescales(x,.5,[(1:100)';(201:n+100)'],o),'cog:TimescaleContinuity');
end
function testHomotopicSignAndMappingDeclaration(t)
x=(1:20)';y=[x -x sin(x) cos(x)];c=rest_extended_config;o=c.homotopic;verifyError(t,@()cog.homotopic_fc(y,[1 2;3 4],o),'cog:HomotopicMapping');o.mappingStatus='engineering_mirror';o.mappingNote='Synthetic declared pairs only';o.allowEngineeringMapping=true;r=cog.homotopic_fc(y,[1 2;3 4],o);verifyEqual(t,r.correlation(1),-1,'AbsTol',1e-12);verifyFalse(t,r.scientificMappingVerified);verifyTrue(t,isinf(r.fisherZ(1)));
r=cog.homotopic_fc([1e-10*x -1e-10*x ones(20,1) cos(x)],[1 2;3 4],o);verifyEqual(t,r.correlation(1),-1,'AbsTol',1e-12);verifyTrue(t,isnan(r.correlation(2)));verifyFalse(t,r.valid(2));
end
