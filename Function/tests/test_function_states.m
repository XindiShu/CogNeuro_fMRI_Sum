function tests=test_function_states
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testMetricsRespectBoundaryZeroAndDwellCensoring(t)
labels=[1;1;2;2;0;1;1;2;2];r=cog.state_metrics(labels,[1 4;5 9],.5,2);verifyEqual(t,r.transitionCounts,[2 2;0 2]);verifyEqual(t,r.fractionalOccupancyAllObservedFrames,[4;4]/9,'AbsTol',1e-12);verifyEqual(t,r.nVisits,[2;2]);verifyTrue(t,all(r.episodes.leftBoundaryCensored|r.episodes.rightBoundaryCensored));verifyTrue(t,all(isnan(r.meanDwellSecondsCompleteEpisodes)));verifyEqual(t,r.nEligibleAdjacentPairs,6);
end
function testCapKnownFramesAndSeedSelection(t)
rng(6);y=[repmat([2 -1 -1],30,1);repmat([-1 2 -1],30,1)]+randn(60,3)*.03;c=state_config;o=c.options;o.nStates=2;r=cog.cluster_states(y,[1 30;31 60],o);verifyEqual(t,numel(unique(r.labels(1:30))),1);verifyNotEqual(t,r.labels(1),r.labels(60));o.capSeedColumn=1;o.capSeedThreshold=0;r=cog.cluster_states(y,[1 60],o);verifyEqual(t,nnz(r.labels),30);verifyTrue(t,all(r.labels(31:end)==0));
end
function testLeidaProcessesEachSegmentAndTrimsEdges(t)
t0=(0:79)'*.2;y=[sin(t0) sin(t0+.8) sin(t0+2)];y=[y;y];c=state_config;o=c.options;o.method='leida';o.nStates=2;o.leidaTrimFrames=4;r=cog.cluster_states(y,[1 80;81 160],o);verifyTrue(t,all(r.labels([1:4 77:84 157:160])==0));verifyEqual(t,r.features(5:76,:),r.features(85:156,:),'AbsTol',1e-10);verifyEqual(t,sum(r.features(5:76,:).^2,2),ones(72,1),'AbsTol',1e-10);
end
function testNativeHmmPosteriorAndRaggedSequenceBoundaries(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
rng(67);tab=table;for k=1:2,nt=60+10*(k-1);data=struct('y',randn(nt,2)*.2+(k*4-6),'trSeconds',1,'roiNames',{{'a','b'}});file=fullfile(folder,sprintf('d%d.mat',k));save(file,'data');tab=[tab;table(string(k),"s1","run1",string(file),'VariableNames',{'subject','session','run','data_file'})];end %#ok<AGROW>
manifest=fullfile(folder,'runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');c=state_config;c.manifestFile=manifest;c.outputRoot=fullfile(folder,'out');c.pythonExecutable='D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe';c.standardizeWithinRun=false;c.options.method='hmm';c.options.nStates=2;c.options.hmmMaxCycles=8;c.options.hmmInitializations=1;c.execute=true;run_states(c);s=load(fullfile(c.outputRoot,'state_model.mat'),'result');r=s.result;verifySize(t,r.native.Xi,[128 2 2]);verifyEqual(t,sum(r.Gamma,2),ones(130,1),'AbsTol',1e-8);verifyEqual(t,numel(unique(r.labels(1:60))),1);verifyNotEqual(t,r.labels(1),r.labels(end));m=load(fullfile(c.outputRoot,'1','s1','run1','state_metrics.mat'),'metrics');verifyEqual(t,sum(m.metrics.transitionCounts,'all')-trace(m.metrics.transitionCounts),0);
end
