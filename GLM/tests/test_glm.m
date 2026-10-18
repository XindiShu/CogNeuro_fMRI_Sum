function tests=test_glm
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path; root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testContrastMapping(t)
x=[(1:40)' sin((1:40)') ones(40,1)];
w=psy.glm_contrasts({'Sn(1) A*bf(1)','Sn(1) B*bf(1)','constant'},{'A','B'},[1 -1],x,20);
verifyEqual(t,w,[1 -1 0]);
verifyError(t,@()psy.glm_contrasts({'Sn(1) A*bf(1)','Sn(1) B*bf(1)','constant'},{'A','B'},[1 -1],[x(:,1) x(:,1) x(:,3)],20),'psy:GLMEstimability');
end
function testEventsAndUnknown(t)
p=[tempname '.tsv']; f=fopen(p,'w'); fprintf(f,'onset\tduration\ttrial_type\n0\t4\tA\n8\t4\tB\n'); fclose(f); c=onCleanup(@()delete(p));
r=psy.glm_events(p,40,{'A','B'}); verifyEqual(t,r(2).onset,8);
verifyError(t,@()psy.glm_events(p,40,{'A','C'}),'psy:GLMConditions');
end
function testResidualInputGuard(t)
r=struct('temporal_state','filtered');
verifyError(t,@()psy.glm_run(r,glm_config,tempname),'psy:GLMState');
end
