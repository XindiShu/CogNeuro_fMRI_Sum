function tests=test_function_ica
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function('D:/matlab/atoolbox/spm12');addpath('D:/matlab/atoolbox/gift_minimal_df369a2');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testKnownDualRegressionAndVarianceNormalization(t)
rng(22);maps=randn(60,2);maps=maps-mean(maps,1);tc=randn(100,2).*[2 3];tc=tc-mean(tc,1);y=tc*maps';r=cog.dual_regression(y,maps,false);verifyEqual(t,r.timecourses,tc,'AbsTol',1e-12);verifyEqual(t,r.subjectMaps,maps,'AbsTol',1e-12);r=cog.dual_regression(y,maps,true);verifyEqual(t,r.subjectMaps,maps.*std(tc,0,1),'AbsTol',1e-12);verifyError(t,@()cog.dual_regression(y,[maps maps(:,1)],false),'cog:DualRegression');
end
function testOfficialFastIcaRecoversIndependentSpatialSources(t)
rng(5);v=2500;s=-sign(rand(2,v)-.5).*log(max(eps,1-2*abs(rand(2,v)-.5)));s=s-mean(s,2);a=randn(100,2);b=randn(110,2);y={a*s,b*s};o=ica_config;o.nComponents=2;o.perRunPca=2;o.voxelVarianceNormalize=false;r=cog.ica_group(y,o);match=abs(corr(s',r.groupMaps));verifyGreaterThan(t,min(max(match,[],2)),.95);verifySize(t,r.dual{2}.timecourses,[110 2]);verifyFalse(t,r.componentStabilityAssessed);
o.perRunPca=3;verifyError(t,@()cog.ica_group(y,o),'cog:ICA');
end
function testFeatureOrderAndBatchIsolation(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
rng(8);subject=["001";"002"];session=["s1";"s2"];run=["r1";"r2"];data_file=strings(2,1);
for k=1:2,data=struct('y',randn(25,35),'featureIds',string((1:35)'),'trSeconds',1);data_file(k)=fullfile(folder,sprintf('d%d.mat',k));save(data_file(k),'data');end
manifest=fullfile(folder,'runs.tsv');writetable(table(subject,session,run,data_file),manifest,'FileType','text','Delimiter','\t');c=ica_config;c.manifestFile=manifest;c.nComponents=2;c.perRunPca=3;c.outputRoot=fullfile(folder,'out');c.giftPath='D:/matlab/atoolbox/gift_minimal_df369a2';r=run_ica(c);verifyEqual(t,r.nRuns,2);verifyFalse(t,isfolder(c.outputRoot));c.execute=true;run_ica(c);verifyTrue(t,isfile(fullfile(c.outputRoot,'002','s2','r2','dual_fnc.mat')));verifyError(t,@()run_ica(c),'cog:Exists');
data.featureIds=flipud(data.featureIds);save(data_file(2),'data');c.execute=false;verifyError(t,@()run_ica(c),'cog:ICAInput');
end
