function tests=test_confound_design
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path; root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testKnownProjection(t)
z=(1:40)'; tsv=table(z,2*z,'VariableNames',{'white_matter','csf'});
cfg=design_config; cfg.motionModel='none'; cfg.linearTrend=false;
r=psy.confound_design(tsv,cfg);
verifyEqual(t,r.rank,2); verifyEqual(t,r.remainingDF,38); verifyEqual(t,r.dependentColumnCount,1);
y=3+7*z; residual=y-r.orthonormalBasis*(r.orthonormalBasis'*y);
verifyLessThan(t,norm(residual),1e-10);
verifyEqual(t,r.orthonormalBasis'*r.orthonormalBasis,eye(2),'AbsTol',1e-12);
end
function testSpikesAndConstant(t)
tsv=table(ones(40,1),(1:40)',[0;1;zeros(38,1)],'VariableNames',{'white_matter','csf','framewise_displacement'});
cfg=design_config; cfg.motionModel='none'; cfg.addSpikes=true;
r=psy.confound_design(tsv,cfg); verifyEqual(t,r.flaggedFrames,2);
verifyEqual(t,r.droppedConstantColumns,{'white_matter'}); verifyEqual(t,r.nFrames,40);
verifyEqual(t,r.matrix(:,end),double((1:40)'==2));
end
function testRejectSaturatedAndInvalid(t)
tsv=table((1:40)',(1:40)',ones(40,1),'VariableNames',{'white_matter','csf','framewise_displacement'});
cfg=design_config; cfg.motionModel='none'; cfg.addSpikes=true;
verifyError(t,@()psy.confound_design(tsv,cfg),'psy:DesignDF');
cfg.addSpikes=false; tsv.csf(1)=NaN;
verifyError(t,@()psy.confound_design(tsv,cfg),'psy:DesignValues');
end
