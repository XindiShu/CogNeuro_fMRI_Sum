function summary=run_states(cfg)
%RUN_STATES 共享模型、逐run边界/时间尺度明确；不把帧当独立群体被试。
setup_function;if nargin<1,cfg=state_config;end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t)||~ismember(cfg.options.method,{'cap','leida','hmm'})||~isscalar(cfg.options.nStates)||~isfinite(cfg.options.nStates)||cfg.options.nStates<2||cfg.options.nStates~=fix(cfg.options.nStates),error('cog:StateInput','Unique run rows and valid method/K required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:StateInput','Unsafe run key');end,end,end
if ~isscalar(cfg.maxMatrixGiB)||~isfinite(cfg.maxMatrixGiB)||cfg.maxMatrixGiB<=0||cfg.maxMatrixGiB>=2,error('cog:StateMemory','Matrix budget must be in (0,2) GiB for MAT-v7 HMM transport');end
ys=cell(height(t),1);localSegments=ys;frames=ys;offset=zeros(height(t),1);tr=zeros(height(t),1);segments=[];scales=ys;matrixBytes=0;
for k=1:height(t)
    t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');d=s.data;if ~all(isfield(d,{'y','trSeconds','roiNames'})),error('cog:StateInput','Data requires y/trSeconds/roiNames');end
    names=string(d.roiNames(:));y=double(d.y);nt=size(y,1);if size(y,2)~=numel(names)||numel(names)<2||nt<8||numel(unique(names))~=numel(names)||any(ismissing(names)|names=="")||any(~isfinite(y),'all')||~isreal(y)||~isscalar(d.trSeconds)||~isfinite(d.trSeconds)||d.trSeconds<=0,error('cog:StateInput','Finite variable common-node data and seconds TR required');end
    matrixBytes=matrixBytes+numel(y)*8;if matrixBytes/2^30>cfg.maxMatrixGiB,error('cog:StateMemory','Combined time-series matrix exceeds configured budget');end
    if k==1,roiNames=names;elseif ~isequal(roiNames,names),error('cog:StateInput','Shared state model requires identical ROI names/order');end
    if ~isfield(d,'frameIndices'),d.frameIndices=(1:nt)';end;f=double(d.frameIndices(:));if numel(f)~=nt||any(~isfinite(f)|f<1|f~=fix(f))||any(diff(f)<=0),error('cog:StateInput','True ascending integer acquisition frame IDs required');end
    cuts=[1;find(diff(f)~=1)+1;nt+1];localSegments{k}=[cuts(1:end-1) cuts(2:end)-1];if k>1,offset(k)=offset(k-1)+size(ys{k-1},1);end;segments=[segments;localSegments{k}+offset(k)]; %#ok<AGROW>
    mu=mean(y,1);sd=std(y,0,1);if any(sd<=eps),error('cog:StateInput','Constant ROI in run');end;if cfg.standardizeWithinRun,y=(y-mu)./sd;end;scales{k}=struct('mean',mu,'scale',sd,'applied',cfg.standardizeWithinRun);ys{k}=y;tr(k)=d.trSeconds;frames{k}=f;
end
if strcmp(cfg.options.method,'hmm')
    o=cfg.options;if any(abs(tr-tr(1))>1e-8)||~ismember(o.hmmCovariance,{'full','diag'})||~ismember(o.hmmMean,{'state','no'})||~isscalar(o.hmmMaxCycles)||~isfinite(o.hmmMaxCycles)||o.hmmMaxCycles<1||o.hmmMaxCycles~=fix(o.hmmMaxCycles)||~isscalar(o.hmmInitializations)||~isfinite(o.hmmInitializations)||o.hmmInitializations<1||o.hmmInitializations~=fix(o.hmmInitializations),error('cog:HMMInput','Common TR and valid Gaussian model/training options required');end
end
summary=struct('execute',cfg.execute,'method',cfg.options.method,'nRuns',height(t),'status','preflight','records',{{}});if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New state result root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t','segments','scales','frames','tr');y=vertcat(ys{:});
if strcmp(cfg.options.method,'hmm')
    map=[];indices=[];for s=1:size(segments,1),ii=segments(s,1):segments(s,2);if numel(ii)<8,continue;end;indices=[indices;numel(map) numel(map)+numel(ii)];map=[map ii];end %#ok<AGROW>
    if numel(map)<cfg.options.nStates*10,error('cog:HMMCoverage','Too few continuous HMM observations');end;Y=y(map,:);inputFile=fullfile(cfg.outputRoot,'hmm_input.mat');save(inputFile,'Y','indices','-v7');spec=struct('inputFile',inputFile,'outputFile',fullfile(cfg.outputRoot,'hmm_posterior.mat'),'modelFile',fullfile(cfg.outputRoot,'native_glhmm.pkl'),'options',cfg.options);specFile=fullfile(cfg.outputRoot,'hmm_request.json');cog.write_json(specFile,spec);root=fileparts(mfilename('fullpath'));
    cog.python_process(cfg.pythonExecutable,fullfile(root,'scripts','glhmm_bridge.py'),{specFile},fullfile(cfg.outputRoot,'hmm_native.log'),cfg.pythonTimeoutSeconds);h=load(spec.outputFile);result=struct('labels',zeros(size(y,1),1),'Gamma',zeros(size(y,1),cfg.options.nStates),'selectedFrames',false(size(y,1),1),'native',h,'options',cfg.options,'stabilityAssessed',false);result.labels(map)=h.labels(:);result.Gamma(map,:)=h.Gamma;result.selectedFrames(map)=true;
else,result=cog.cluster_states(y,segments,cfg.options);end
save(fullfile(cfg.outputRoot,'state_model.mat'),'result','roiNames','segments','scales','-v7.3');
for k=1:height(t)
    ii=offset(k)+(1:size(ys{k},1));metrics=cog.state_metrics(result.labels(ii),localSegments{k},tr(k),cfg.options.nStates);if isfield(result,'Gamma'),metrics.posteriorOccupancyAllObservedFrames=sum(result.Gamma(ii,:),1)/numel(ii);end
    parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);labels=result.labels(ii);frameIndices=frames{k};save(fullfile(out,'state_metrics.mat'),'metrics','labels','frameIndices');writetable(table(frameIndices,labels),fullfile(out,'state_path.tsv'),'FileType','text','Delimiter','\t');summary.records{end+1}=struct('subject',t.subject(k),'session',t.session(k),'run',t.run(k),'assignedFrames',metrics.nAssignedFrames,'observedFrames',metrics.nObservedFrames);
end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'STATES_COMPLETE.mat'),'summary');
end
