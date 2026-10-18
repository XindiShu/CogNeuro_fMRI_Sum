function tests=test_function_naturalistic
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testIdenticalAlignedSignalsAndShiftFamily(t)
time=(1:80)';a=[sin(time/7) cos(time/11)];c=naturalistic_config;o=c.isc;o.nSurrogates=9;r=cog.intersubject({a,2*a,3*a},o);verifyEqual(t,r.iscFisherMean,[1 1],'AbsTol',1e-12);verifyEqual(t,diag(r.isfcFisherMean),[1;1],'AbsTol',1e-12);verifyGreaterThanOrEqual(t,r.iscPFwe,r.iscP);verifyGreaterThanOrEqual(t,r.isfcPFwe,r.isfcP);o.computeISFC=false;r=cog.intersubject({a,2*a,3*a},o);verifyEmpty(t,r.isfcDirectionalPerSubject);
end
function testOrthogonalSrmTransfersToHeldOutTimepoints(t)
rng(71);shared=randn(80,2);shared=shared-mean(shared);test=randn(45,2);series=cell(3,1);heldout=series;for s=1:3,[w,~]=qr(randn(7+s,2),0);series{s}=shared*w';heldout{s}=test*w';end;c=naturalistic_config;o=c.srm;o.nFeatures=2;o.scaleFeatures=false;m=cog.srm_fit(series,o);p=cog.srm_apply(m,heldout);verifyEqual(t,m.weights{1}'*m.weights{1},eye(2),'AbsTol',1e-12);verifyEqual(t,p{1},p{3},'AbsTol',1e-8);verifyTrue(t,all(diff(m.objective)<=1e-8));
end
function testOrderedEventsRecoverAndAlignKnownBoundaries(t)
rng(73);patterns=[2 0 -2;-2 2 0;0 -2 2];labels=repelem((1:3)',[35 50 35]);y=patterns(labels,:)+randn(120,3)*.1;c=naturalistic_config;o=c.events;o.nEvents=3;r=cog.ordered_events(y,o);verifyEqual(t,r.boundaryBeforeRows,[36;86]);verifyEqual(t,sum(r.posterior,2),ones(120,1),'AbsTol',1e-12);verifyTrue(t,all(diff(r.logLikelihoodHistory)>=-1e-7));labels2=repelem((1:3)',[25 30 45]);y2=patterns(labels2,:)+randn(100,3)*.1;r2=cog.ordered_events(y2,o,r);verifyEqual(t,r2.boundaryBeforeRows,[26;56]);verifyTrue(t,r2.frozenPatternApplication);
end
