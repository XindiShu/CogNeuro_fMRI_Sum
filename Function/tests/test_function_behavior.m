function tests=test_function_behavior
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testRwAnalyticUpdatesAndFutureRewardIsolation(t)
c=behavior_config;o=c.rw;o.nActions=2;o.initialValue=0;o.lapse=0;choices=[1;1;2];rewards=[1;0;1];blocks=["b1";"b1";"b2"];[loss,r]=cog.rw_softmax(choices,rewards,blocks,[.5 0],o);verifyEqual(t,loss,3*log(2),'AbsTol',1e-12);verifyEqual(t,r.qBefore,[0 0;.5 0;0 0]);verifyEqual(t,r.predictionError,[1;-.5;1]);[~,r2]=cog.rw_softmax(choices,[1;1;0],blocks,[.5 4],o);[~,r3]=cog.rw_softmax(choices,rewards,blocks,[.5 4],o);verifyEqual(t,r2.chosenProbability(1:2),r3.chosenProbability(1:2));
end
function testRwFitImprovesLikelihoodOnSimulatedBandit(t)
rng(9);n=400;choice=zeros(n,1);reward=choice;q=[.5 .5];o=behavior_config;o=o.rw;o.nActions=2;o.nStarts=2;for k=1:n,p=exp(4*q-max(4*q));p=p/sum(p);p=.98*p+.02/2;choice(k)=1+(rand>p(1));reward(k)=rand<([.8 .2]*[choice(k)==1;choice(k)==2]);q(choice(k))=q(choice(k))+.25*(reward(k)-q(choice(k)));end
blocks=repmat("b",n,1);baseline=cog.rw_softmax(choice,reward,blocks,[.9 .1],o);r=cog.fit_rw(choice,reward,blocks,o);verifyLessThan(t,r.negativeLogLikelihood,baseline);verifyGreaterThanOrEqual(t,r.alpha,o.alphaBounds(1));verifyLessThanOrEqual(t,r.alpha,o.alphaBounds(2));
end
function testNativeDdmSimulationAndFit(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
root=fileparts(fileparts(mfilename('fullpath')));cog.python_process('D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe',fullfile(root,'tests','ddm_native_smoke.py'),{folder},fullfile(folder,'native.log'),180);s=load(fullfile(folder,'posterior.mat'));verifyEqual(t,numel(s.parameterValues),3);verifyTrue(t,all(isfinite(s.pdfUpper),'all'));verifyTrue(t,all(isfinite(s.pdfLower),'all'));
end
function testParametricEventsContractAndCentering(t)
e=cog.parametric_events([1;3;5],zeros(3,1),[1 3;2 2;3 1],{'value','pe'},'choice',true);verifyEqual(t,e.onsets{1},[1;3;5]);verifyEqual(t,e.pmod.param{1},[-1;0;1]);verifyEqual(t,e.pmod.param{2},[1;0;-1]);verifyEqual(t,e.orth,{0});verifyError(t,@()cog.parametric_events([1;0],zeros(2,1),ones(2,1),{'pe'},'choice',true),'cog:ParametricEvents');
end
