function tests=test_native_dispatch
%TEST_NATIVE_DISPATCH 仅哑入口参数交接；不载入SPM、被试数据或分析函数。
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.previous=path;t.TestData.skill=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(t.TestData.skill,'matlab'));
end
function teardownOnce(t)
path(t.TestData.previous);
end
function testConfigurationDoesNotInvokeNativeEntry(t)
[job,~]=fixture(t,'function.prediction');job.mode='preflight';
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'preflight_passed');
verifyFalse(t,r.native_analysis_called);verifyFalse(t,isfolder(job.output_root));
verifyEqual(t,r.resolved_config.options.method,'literal_config');
end
function testCfgCallPreservesNativePrepareFlag(t)
[job,~]=fixture(t,'function.prediction');job.native_execute=false;
r=cogneuro_toolkit_dispatch(job);verifyTrue(t,r.native_analysis_called);
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');verifyFalse(t,s.observed.cfg.execute);
end
function testCfgAndManifestUsesTwoArguments(t)
[job,~]=fixture(t,'function.ppi_batch');
job.bindings=struct('path','argument_manifest','value','literal path with quote '' and spaces.tsv');
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'complete');
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');verifyEqual(t,s.observed.manifest,job.bindings.value);
end
function testDcmPreparationUsesFiveOriginalArguments(t)
[job,~]=fixture(t,'function.prepare_dcm_spm');
job.bindings=[struct('path','spmMat','value','source model.mat'),struct('path','roiManifest','value','regions.tsv'), ...
    struct('path','sessionIndex','value',2),struct('path','TESeconds','value',.031)];
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'complete');
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');
verifyEqual(t,s.observed.sessionIndex,2);verifyEqual(t,s.observed.TESeconds,.031);verifyEqual(t,s.observed.spmMat,'source model.mat');
end
function testQcUsesInputAndOutputRoots(t)
[job,~]=fixture(t,'preprocessing.timeseries_qc');
job.bindings=struct('path','inputRoot','value','literal input root');
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'complete');
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');verifyEqual(t,s.observed.inputRoot,'literal input root');
end
function testDemoPreservesSecondFactoryOutput(t)
[job,~]=fixture(t,'glm.glmsingle_demo');
job.overrides=struct('path','demo.maxVoxelsPerSubject','value',7);
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'complete');
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');verifyEqual(t,s.observed.demo.maxVoxelsPerSubject,7);
end
function testSpecsArePassedBeforeCfg(t)
[job,folder]=fixture(t,'preprocessing.topup');
specFile=fullfile(folder,'specs.json');writeText(specFile,'[{"subject":"s1","run":"r1"}]');
job.bindings=struct('path','specsFile','value',specFile);
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'complete');
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');verifyEqual(t,s.observed.specs.subject,'s1');
end
function testUnknownOverrideStopsBeforeCall(t)
[job,~]=fixture(t,'function.prediction');job.overrides=struct('path','nonexistent','value',1);
verifyError(t,@()cogneuro_toolkit_dispatch(job),'cogneuro:NativeOverride');verifyFalse(t,isfolder(job.output_root));
end
function testNativeFailureReturnPreservesEvidence(t)
[job,~]=fixture(t,'function.prediction');job.overrides=struct('path','status','value','failed');
verifyError(t,@()cogneuro_toolkit_dispatch(job),'cogneuro:NativeIncomplete');
verifyTrue(t,isfile(fullfile(job.output_root,'cogneuro_native_return.mat')));
end
function testMatParameterPreservesThreeDimensionsAndType(t)
[job,folder]=fixture(t,'function.prediction');
nativeOptions=struct('method','literal_MAT','tensor',reshape(uint8(1:12),[2 2 3])); %#ok<NASGU>
file=fullfile(folder,'native_options.mat');save(file,'nativeOptions');
job.overrides=struct('path','options','value',struct('matlab_value_file',file,'variable','nativeOptions'));
r=cogneuro_toolkit_dispatch(job);verifyEqual(t,r.status,'complete');
s=load(fullfile(job.output_root,'sentinel.mat'),'observed');
verifyEqual(t,s.observed.cfg.options.tensor,reshape(uint8(1:12),[2 2 3]));
end
function [job,folder]=fixture(t,id)
folder=tempname;mkdir(folder);addTeardown(t,@()cleanupFolder(folder));
root=fullfile(folder,'fake_toolkit');mkdir(root);mkdir(fullfile(root,'config'));mkdir(fullfile(root,'matlab'));
registryFile=fullfile(t.TestData.skill,'assets','toolkit-registry.json');r=jsondecode(fileread(registryFile));entry=r.entries(strcmp({r.entries.id},id));
if ~isempty(entry.config_file)
    [~,factory]=fileparts(entry.config_file);
    body="function [cfg,demo]="+factory+newline+ ...
        "cfg=struct('outputRoot','unused','execute',false,'dataFile','','inputRoot','','spmMat','','roiManifest','',"+ ...
        "'sessionIndex',1,'TESeconds',.03,'status','complete','options',struct('method','literal_config'));"+newline+ ...
        "demo=struct('maxVoxelsPerSubject',0);"+newline+"end";
    if strcmp(entry.style,'qc_roots'),body=replace(body,"'execute',false,","");end
    writeText(fullfile(root,entry.config_file),body);
end
switch entry.style
    case 'cfg',args='cfg';setup="out=cfg.outputRoot;observed=struct('cfg',cfg);status=cfg.status;";
    case 'cfg_manifest',args='cfg,manifest';setup="out=cfg.outputRoot;observed=struct('cfg',cfg,'manifest',manifest);status=cfg.status;";
    case 'cfg_demo',args='cfg,demo';setup="out=cfg.outputRoot;observed=struct('cfg',cfg,'demo',demo);status=cfg.status;";
    case 'qc_roots',args='inputRoot,out';setup="observed=struct('inputRoot',inputRoot);status='complete';";
    case 'specs_cfg',args='specs,cfg';setup="out=cfg.outputRoot;observed=struct('specs',specs,'cfg',cfg);status=cfg.status;";
    case 'dcm_spm',args='spmMat,roiManifest,sessionIndex,TESeconds,out';setup="observed=struct('spmMat',spmMat,'roiManifest',roiManifest,'sessionIndex',sessionIndex,'TESeconds',TESeconds);status='complete';";
end
parts=strsplit(entry.target,'.');
if numel(parts)==2
    targetDir=fullfile(root,'matlab',['+' parts{1}]);mkdir(targetDir);targetFile=fullfile(targetDir,[parts{2} '.m']);name=parts{2};
else,targetFile=fullfile(root,[entry.target '.m']);name=entry.target;end
body="function result="+name+"("+args+")"+newline+setup+newline+ ...
    "mkdir(out);save(fullfile(out,'sentinel.mat'),'observed');result=struct('status',status);"+newline+"end";
writeText(targetFile,body);
job=struct('schema_version',1,'route','toolkit_method','mode','execute','method_id',id,'toolkit_root',root, ...
    'catalog_file',registryFile,'spm_root','','output_root',fullfile(folder,'output'), ...
    'bindings',[],'overrides',[],'native_execute',true);
end
function writeText(file,value)
f=fopen(file,'w','n','UTF-8');assert(f>0);cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',value);
end
function cleanupFolder(folder)
target=char(java.io.File(folder).getCanonicalPath());base=char(java.io.File(tempdir).getCanonicalPath());
assert(startsWith(lower(target),[lower(base) filesep]),'Unsafe temporary test cleanup');
if isfolder(target),rmdir(target,'s');end
end
