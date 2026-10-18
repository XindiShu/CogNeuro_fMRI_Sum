function result=run_naturalistic(cfg)
%RUN_NATURALISTIC 同刺激同时间网格身份明确；SRM映射只从训练epoch拟合。
setup_function;if nargin<1,cfg=naturalistic_config;end
if isempty(cfg.methods)||~all(ismember(cfg.methods,{'isc','isfc','srm','eventseg'}))||numel(unique(cfg.methods))~=numel(cfg.methods),error('cog:NaturalisticMethods','Explicit supported nonduplicate methods required');end
s=load(cfg.dataFile,'data');d=s.data;if ~all(isfield(d,{'series','subjectIds','featureIds','timeSeconds','stimulusId','alignmentNote'})),error('cog:NaturalisticInput','Explicit series/subject/feature/time/stimulus identities and alignment provenance required');end
subjects=string(d.subjectIds(:));if ~iscell(d.series)||numel(d.series)<2||numel(subjects)~=numel(d.series)||numel(unique(subjects))~=numel(subjects)||any(ismissing(subjects)|subjects=="")||~iscell(d.featureIds)||numel(d.featureIds)~=numel(subjects)||strlength(string(d.stimulusId))==0||strlength(string(d.alignmentNote))==0,error('cog:NaturalisticInput','Unique independent subjects and explicit stimulus alignment required');end
checkTime(d.timeSeconds);nt=numel(d.timeSeconds);bytes=0;common=true;
for k=1:numel(subjects),x=d.series{k};ids=string(d.featureIds{k}(:));if size(x,1)~=nt||size(x,2)~=numel(ids)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids=="")||any(~isfinite(x),'all')||~isreal(x),error('cog:NaturalisticInput','Finite aligned observations with unique feature identity required');end;bytes=bytes+numel(x)*8;if k>1,common=common&&isequal(string(d.featureIds{k}(:)),string(d.featureIds{1}(:)));end,end
if any(ismember({'isc','isfc','eventseg'},cfg.methods))&&~common,error('cog:NaturalisticFeatures','ISC/ISFC/original-space group events require matched feature identity/order; SRM alone allows different feature spaces');end
if ismember('isfc',cfg.methods),nf=size(d.series{1},2);bytes=bytes+8*nf^2*(2*numel(subjects)+cfg.isc.nSurrogates+2);end
if ~isscalar(cfg.maxArrayGiB)||~isfinite(cfg.maxArrayGiB)||cfg.maxArrayGiB<=0||bytes/2^30>cfg.maxArrayGiB,error('cog:NaturalisticMemory','Input/main result arrays exceed configured budget');end
hasTest=isfield(d,'testSeries');if hasTest
    if ~all(isfield(d,{'testTimeSeconds','testStimulusId','testSubjectIds','testFeatureIds','testAlignmentNote'}))||numel(d.testSeries)~=numel(d.series)||~isequal(string(d.testSubjectIds(:)),subjects)||strlength(string(d.testAlignmentNote))==0||strlength(string(d.testStimulusId))==0,error('cog:NaturalisticTest','Explicit held-out stimulus/time/ordered identities and alignment required');end
    checkTime(d.testTimeSeconds);for k=1:numel(subjects),if ~isequal(string(d.testFeatureIds{k}(:)),string(d.featureIds{k}(:)))||~isequal(size(d.testSeries{k}),[numel(d.testTimeSeconds) size(d.series{k},2)])||any(~isfinite(d.testSeries{k}),'all'),error('cog:NaturalisticTest','Held-out subject feature/order/time mismatch');end,end
    if isequal(d.series,d.testSeries),error('cog:NaturalisticTest','Identical numeric data cannot be labeled held-out');end
end
result=struct('status','preflight','nSubjects',numel(subjects),'nTimepoints',nt,'execute',cfg.execute);if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New naturalistic output root required');end
if any(ismember({'isc','isfc'},cfg.methods)),o=cfg.isc;o.computeISFC=ismember('isfc',cfg.methods);result.intersubject=cog.intersubject(d.series,o);end
if ismember('srm',cfg.methods),result.srm=cog.srm_fit(d.series,cfg.srm);if hasTest,result.srmHeldOutProjection=cog.srm_apply(result.srm,d.testSeries);o=cfg.isc;o.computeISFC=false;o.nSurrogates=0;result.srmHeldOutIsc=cog.intersubject(result.srmHeldOutProjection,o);end,end
if ismember('eventseg',cfg.methods),group=mean(cat(3,d.series{:}),3);result.events=cog.ordered_events(group,cfg.events);end
mkdir(cfg.outputRoot);result.status='complete';provenance=rmfield(d,'series');if hasTest,provenance=rmfield(provenance,'testSeries');end;save(fullfile(cfg.outputRoot,'naturalistic.mat'),'result','cfg','provenance','-v7.3');save(fullfile(cfg.outputRoot,'NATURALISTIC_COMPLETE.mat'),'cfg');
end
function checkTime(time)
time=double(time(:));if numel(time)<8||any(~isfinite(time))||any(diff(time)<=0)||max(abs(diff(time)-median(diff(time))))>1e-6,error('cog:NaturalisticTime','Explicit finite increasing common uniform time grid required');end
end
