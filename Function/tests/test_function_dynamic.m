function tests=test_function_dynamic
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testSharedPhasePreservesAllCrossSpectra(t)
rng(4);for nt=[81 82],x=randn(nt,3);y=cog.phase_surrogate(x);a=fft(x);b=fft(y);verifyEqual(t,abs(a),abs(b),'AbsTol',1e-11);for j=1:3,for k=1:3,verifyEqual(t,a(:,j).*conj(a(:,k)),b(:,j).*conj(b(:,k)),'AbsTol',1e-10);end,end;verifyEqual(t,corr(x),corr(y),'AbsTol',1e-12);end
end
function testWindowsCannotCrossAcquisitionGapAndJointNull(t)
rng(19);y=randn(80,3);frames=[(1:40)';(101:140)'];c=dynamic_fc_config;o=c.options;o.windowSeconds=[20 30];o.stepSeconds=10;o.taper='rectangular';o.nSurrogates=3;r=cog.sliding_fc(y,1,frames,o);verifyEqual(t,r.windows{1}.startFrameIndices,[1;11;21;101;111;121]);verifyEqual(t,r.windows{1}.endFrameIndices,[20;30;40;120;130;140]);verifyEqual(t,r.windows{1}.effectiveWeightCount,20,'AbsTol',1e-12);a=cog.fc(y(1:20,:),'pearson');verifyEqual(t,r.windows{1}.correlation(:,:,1),a.correlation,'AbsTol',1e-12);verifyGreaterThanOrEqual(t,r.windows{1}.pFweEdgesAndLengths,r.windows{1}.pUncorrected);verifySize(t,r.nullEdgeSdR,[3 2 3]);
end
