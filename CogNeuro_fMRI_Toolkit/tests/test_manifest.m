function tests=test_manifest
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path; root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
root=tempname; mkdir(root); t.TestData.root=root;
for name={'bold.nii','t1.nii'}
    f=fopen(fullfile(root,name{1}),'w'); fclose(f);
end
cfg=toolkit_config; cfg.manifestFile=fullfile(root,'runs.tsv'); t.TestData.cfg=cfg;
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function put(t,rows)
f=fopen(t.TestData.cfg.manifestFile,'w'); c=onCleanup(@()fclose(f));
fprintf(f,'subject\tsession\trun\tbold\tt1\tinput_stage\n');
for k=1:numel(rows), fprintf(f,'%s\n',rows{k}); end
end
function testArbitraryIDsAndSessions(t)
put(t,{sprintf('pilotA\tbaseline\trest\tbold.nii\tt1.nii\traw'), ...
    sprintf('pilotA\tfollowup\trest\tbold.nii\tt1.nii\traw'), ...
    sprintf('001\t\tmemory\tbold.nii\tt1.nii\traw')});
r=psy.read_manifest(t.TestData.cfg);
verifyEqual(t,numel(r),3); verifyEqual(t,r(3).subject,'001'); verifyEqual(t,r(3).session,'');
verifyTrue(t,isfile(r(1).bold));
verifyNotEqual(t,psy.run_output_dir(t.TestData.root,r(1)),psy.run_output_dir(t.TestData.root,r(2)));
verifyEqual(t,r(3).eventFormat,'none');
cfg=t.TestData.cfg; cfg.subjects={'001'}; verifyEqual(t,numel(psy.read_manifest(cfg)),1);
end
function testDuplicateRejected(t)
row=sprintf('p1\ts1\tr1\tbold.nii\tt1.nii\traw'); put(t,{row,row});
verifyError(t,@()psy.read_manifest(t.TestData.cfg),'psy:DuplicateRun');
end
function testDerivativeRejected(t)
put(t,{sprintf('p1\ts1\tr1\tbold.nii\tt1.nii\tpreprocessed')});
verifyError(t,@()psy.read_manifest(t.TestData.cfg),'psy:InputStage');
end
function testUnsafeIDRejected(t)
put(t,{sprintf('../escape\ts1\tr1\tbold.nii\tt1.nii\traw')});
verifyError(t,@()psy.read_manifest(t.TestData.cfg),'psy:UnsafeID');
end
function testMissingImageRejected(t)
put(t,{sprintf('p1\ts1\tr1\tmissing.nii\tt1.nii\traw')});
verifyError(t,@()psy.read_manifest(t.TestData.cfg),'psy:MissingImage');
end
function testFailedRowsPersistWithEmptySession(t)
% 空文件故意造成头检查失败，验证批次仍逐行记录，不吞掉异常。
put(t,{sprintf('p1\t\tr1\tbold.nii\tt1.nii\traw'),sprintf('p2\t\tr1\tbold.nii\tt1.nii\traw')});
cfg=t.TestData.cfg; h=preprocess_config; cfg.spmPath=h.spmPath;
cfg.outputRoot=fullfile(t.TestData.root,'report');
r=psy.preprocess_batch(cfg);
verifyEqual(t,numel(r),2); verifyTrue(t,all(strcmp({r.status},'failed')));
verifyTrue(t,isfile(fullfile(cfg.outputRoot,'batch_status.tsv')));
end
function testStopStillWritesFailure(t)
put(t,{sprintf('p1\t\tr1\tbold.nii\tt1.nii\traw')});
cfg=t.TestData.cfg; h=preprocess_config; cfg.spmPath=h.spmPath;
cfg.outputRoot=fullfile(t.TestData.root,'report'); cfg.continueOnError=false;
verifyError(t,@()psy.preprocess_batch(cfg),'psy:RunFailed');
verifyTrue(t,isfile(fullfile(cfg.outputRoot,'batch_status.tsv')));
end
function testOptionalAnatomyReuseDirectory(t)
root=t.TestData.root;mkdir(fullfile(root,'prior_anat'));
f=fopen(t.TestData.cfg.manifestFile,'w');
fprintf(f,'subject\tsession\trun\tbold\tt1\tinput_stage\tanatomy_reuse_dir\n');
fprintf(f,'pilotA\tvisit1\tfunc\tbold.nii\tt1.nii\traw\tprior_anat\n');
fclose(f);
r=psy.read_manifest(t.TestData.cfg);
verifyEqual(t,r.anatomyReuseDir,fullfile(root,'prior_anat'));
end
