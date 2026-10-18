function tests=test_function_pcm
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;addpath('D:/matlab/atoolbox/pcm_toolbox-master/pcm_toolbox-master');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testNativeFixedFitsAndCrossvalidation(t)
[d,models,o]=fixture;
for mode={'individual','group','individual_cv','group_cv'},o.mode=mode{1};r=cog.pcm_fit(d,["a";"b";"c"],models,o);verifySize(t,r.likelihood,[3 2]);verifyGreaterThan(t,mean(r.likelihood(:,2)-r.likelihood(:,1)),0);verifyFalse(t,r.convergenceAssessed);end
end
function testComponentAndNoiseIdentifiabilityGuards(t)
[d,~,o]=fixture;v=[1;-1;0];w=[0;1;-1];models={struct('name','two_components','type','component','Gc',cat(3,v*v',w*w'))};r=cog.pcm_fit(d,["a";"b";"c"],models,o);verifyTrue(t,all(isfinite(r.likelihood),'all'));
models{1}.Gc=cat(3,v*v',2*v*v');verifyError(t,@()cog.pcm_fit(d,["a";"b";"c"],models,o),'cog:PCMIdentifiability');models{1}.Gc=v*v';d{1}.rowNoiseCovariance(1,1)=-1;verifyError(t,@()cog.pcm_fit(d,["a";"b";"c"],models,o),'cog:PCMCovariance');
end
function testGaussianConditionalAgainstAnalyticNormal(t)
[score,d]=cog.gaussian_predictive_score(2,1,1,.5,1,zeros(1,0),zeros(1,0));verifyEqual(t,d.meanPrediction,1,'AbsTol',1e-12);verifyEqual(t,d.conditionalCovariance,.75,'AbsTol',1e-12);verifyEqual(t,score,-.5*log(2*pi*.75),'AbsTol',1e-12);
end
function testLearnedGroupCvParametersExcludeHeldOutSubject(t)
[d,~,o]=fixture;v=[1;-1;0];w=[0;1;-1];models={struct('name','components','type','component','Gc',cat(3,v*v',w*w'))};o.mode='group_cv';r=cog.pcm_fit(d,["a";"b";"c"],models,o);changed=d;changed{1}.y=changed{1}.y*10;r2=cog.pcm_fit(changed,["a";"b";"c"],models,o);verifyEqual(t,r.fits{1}.theta{1}(:,1),r2.fits{1}.theta{1}(:,1),'AbsTol',1e-9);
end
function testFeatureNoiseWhiteningLeavesEquivalentLikelihood(t)
[d,models,o]=fixture;reference=cog.pcm_fit(d,["a";"b";"c"],models,o);n=size(d{1}.y,2);l=eye(n)+diag(ones(n-1,1)*.2,-1);for k=1:numel(d),d{k}.y=d{k}.y*l';d{k}.featureNoiseCovariance=l*l';d{k}.spatialNoiseState='provided_covariance';end
r=cog.pcm_fit(d,["a";"b";"c"],models,o);verifyEqual(t,r.likelihood,reference.likelihood,'AbsTol',1e-7);
end
function [d,models,o]=fixture
rng(61);nc=3;part=repelem((1:4)',nc*2);cond=repmat(repelem((1:nc)',2),4,1);labels=["a";"b";"c"];d=cell(3,1);v=[1;-1;0];for s=1:3,u=v*randn(1,25)*2;y=u(cond,:)+randn(24,25)*.3;d{s}=struct('y',y,'condition',labels(cond),'partition',string(part),'rowNoiseCovariance',eye(24),'noiseNote','Independent synthetic observation/feature noise','spatialNoiseState','already_whitened');end
models={struct('name','null','type','fixed','Gc',zeros(3)),struct('name','signal','type','fixed','Gc',v*v')};cfg=pcm_config;o=cfg.options;o.maxIterations=50;
end
