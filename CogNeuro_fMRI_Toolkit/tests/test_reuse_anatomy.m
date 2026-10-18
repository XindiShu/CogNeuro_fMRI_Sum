function tests=test_reuse_anatomy
tests=functiontests(localfunctions);
end
function setup(t)
root=tempname;mkdir(root);t.TestData.root=root;
source=fullfile(root,'completed','anat');mkdir(source);
target=fullfile(root,'new','anat');mkdir(target);
stem='pilot_T1';
names={[stem '.nii'],['c1' stem '.nii'],['c2' stem '.nii'],['c3' stem '.nii'], ...
    ['y_' stem '.nii'],['m' stem '.nii'],[stem '_seg8.mat']};
for k=1:numel(names)
    fid=fopen(fullfile(source,names{k}),'w');fprintf(fid,'%s',names{k});fclose(fid);
end
copyfile(fullfile(source,[stem '.nii']),fullfile(target,[stem '.nii']));
cfg=struct('spmPath','C:\test_spm');status='spatial_pipeline_without_distortion_correction';
save(fullfile(root,'completed','SPATIAL_COMPLETE.mat'),'cfg','status');
t.TestData.source=source;t.TestData.target=target;t.TestData.cfg=cfg;
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testReuseIdenticalT1AndRecordSource(t)
r=psy.reuse_anatomy(fullfile(t.TestData.target,'pilot_T1.nii'),t.TestData.source,t.TestData.cfg);
verifyEqual(t,r.status,'reused_completed_anatomy_same_t1_bytes');
verifyTrue(t,isfile(fullfile(t.TestData.target,'ANATOMY_REUSE.json')));
verifyTrue(t,isfile(fullfile(t.TestData.target,'y_pilot_T1.nii')));
end
function testRejectDifferentT1(t)
fid=fopen(fullfile(t.TestData.target,'pilot_T1.nii'),'w');fprintf(fid,'different');fclose(fid);
verifyError(t,@()psy.reuse_anatomy(fullfile(t.TestData.target,'pilot_T1.nii'), ...
    t.TestData.source,t.TestData.cfg),'psy:AnatomyReuse');
verifyFalse(t,isfile(fullfile(t.TestData.target,'y_pilot_T1.nii')));
end
function testRejectIncompleteSourceMarker(t)
marker=fullfile(t.TestData.root,'completed','SPATIAL_COMPLETE.mat');
cfg=t.TestData.cfg;save(marker,'cfg');
verifyError(t,@()psy.reuse_anatomy(fullfile(t.TestData.target,'pilot_T1.nii'), ...
    t.TestData.source,t.TestData.cfg),'psy:AnatomyReuse');
verifyFalse(t,isfile(fullfile(t.TestData.target,'y_pilot_T1.nii')));
end

function testUnifiedCompletionReadsSavedConfig(t)
sourceParent=fileparts(t.TestData.source);
delete(fullfile(sourceParent,'SPATIAL_COMPLETE.mat'));
status='spatial_pipeline_after_fsl_topup';
save(fullfile(sourceParent,'COMPLETE.mat'),'status');
cfg=t.TestData.cfg;
save(fullfile(sourceParent,'input_info.mat'),'cfg');
r=psy.reuse_anatomy(fullfile(t.TestData.target,'pilot_T1.nii'), ...
    t.TestData.source,t.TestData.cfg);
verifyEqual(t,r.status,'reused_completed_anatomy_same_t1_bytes');
end
