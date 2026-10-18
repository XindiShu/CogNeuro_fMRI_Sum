function tests=test_function_task_fc
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testWeightedAndBackground(t)
rng(92);n=100;y=randn(n,3);r=cog.weighted_fc(y,ones(n,1));verifyEqual(t,r.correlation,corr(y),'AbsTol',1e-12);
c=randn(n,2);r=cog.weighted_fc(y,ones(n,1),c);x=[ones(n,1) c];res=y-x*(x\y);verifyEqual(t,r.correlation,corr(res),'AbsTol',1e-12);
w=ones(n,1);w(1:50)=0;r=cog.weighted_fc(y,w);verifyEqual(t,r.correlation,corr(y(51:end,:)),'AbsTol',1e-12);
verifyError(t,@()cog.weighted_fc(y,-ones(n,1)),'cog:WeightedFC');
end
function testNetworkEdges(t)
r=[1 .2 .3 .4;.2 1 .5 .6;.3 .5 1 .7;.4 .6 .7 1];s=cog.network_summary(r,["A";"A";"B";"B"]);verifyEqual(t,s.meanR,[.2 .45;.45 .7],'AbsTol',1e-12);verifyEqual(t,s.nEdges,[1 4;4 1]);
end
