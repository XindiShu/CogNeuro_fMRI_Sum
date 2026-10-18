function tests=test_function_graph
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testKnownGraphTopology(t)
o=struct('threshold',0,'negativePolicy','reject');r=cog.graph_metrics(ones(4)-eye(4),o);verifyEqual(t,r.degree,3*ones(4,1));verifyEqual(t,r.binaryClustering,ones(4,1));verifyEqual(t,r.globalEfficiency,1);
w=diag(ones(3,1),1);w=w+w';r=cog.graph_metrics(w,o);verifyEqual(t,r.degree,[1;2;2;1]);verifyEqual(t,r.globalEfficiency,13/18,'AbsTol',1e-12);verifyEqual(t,r.binaryClustering,zeros(4,1));
r=cog.graph_metrics(zeros(3),o);verifyEqual(t,r.globalEfficiency,0);verifyEqual(t,r.nDisconnectedPairs,3);verifyTrue(t,isnan(r.meanFinitePathLength));
end
function testGraphGuards(t)
o=struct('threshold',.2,'negativePolicy','reject');verifyError(t,@()cog.graph_metrics([1 -.5;-.5 1],o),'cog:NegativeEdges');o.negativePolicy='drop';r=cog.graph_metrics([1 -.5;-.5 1],o);verifyEqual(t,r.nNegativeEdgesDropped,1);
verifyError(t,@()cog.graph_metrics([0 1;0 0],o),'cog:Graph');
end
