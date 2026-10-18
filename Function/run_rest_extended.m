function summary=run_rest_extended(cfg)
%RUN_REST_EXTENDED 多run独立计算；熵/ACF不跨缺帧，同源对应显式输入。
setup_function;if nargin<1,cfg=rest_extended_config;end
if isempty(cfg.methods)||~all(ismember(cfg.methods,{'entropy','timescales','homotopic'}))||numel(unique(cfg.methods))~=numel(cfg.methods),error('cog:RestExtendedMethods','Explicit nonduplicate methods required');end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t),error('cog:RestExtendedInput','Unique run keys required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:RestExtendedInput','Unsafe run key');end,end,end
data=cell(height(t),1);for k=1:height(t)
    t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');d=s.data;if ~all(isfield(d,{'y','trSeconds','featureIds'})),error('cog:RestExtendedInput','Data y/trSeconds/featureIds required');end
    ids=string(d.featureIds(:));n=size(d.y,1);if numel(ids)~=size(d.y,2)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids=="")||any(~isfinite(d.y),'all')||~isreal(d.y)||numel(d.y)*8/2^30>cfg.maxMatrixGiB||~isscalar(d.trSeconds)||~isfinite(d.trSeconds)||d.trSeconds<=0,error('cog:RestExtendedInput','Finite data/common identities/TR and matrix budget required');end
    if ~isfield(d,'frameIndices'),d.frameIndices=(1:n)';end;if numel(d.frameIndices)~=n||any(~isfinite(d.frameIndices)|d.frameIndices<1|d.frameIndices~=fix(d.frameIndices))||any(diff(d.frameIndices(:))<=0),error('cog:RestExtendedFrames','True ascending frame IDs required');end
    if any(ismember({'entropy','timescales'},cfg.methods))&&any(diff(d.frameIndices(:))~=1),error('cog:RestExtendedContinuity','Entropy/ACF require continuous segment input; split gaps into separate manifest rows');end
    if ismember('homotopic',cfg.methods),if ~isfield(d,'pairs'),error('cog:HomotopicInput','Explicit data.pairs required');end;cog.homotopic_fc(d.y,d.pairs,cfg.homotopic);end;data{k}=d;
end
summary=struct('execute',cfg.execute,'nRuns',height(t),'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New extended-rest output root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
for k=1:height(t)
    d=data{k};result=struct;parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);
    if ismember('entropy',cfg.methods),result.entropy=cog.entropy_metrics(d.y,cfg.entropy);end
    if ismember('timescales',cfg.methods),result.timescales=cog.autocorrelation_timescales(d.y,d.trSeconds,d.frameIndices,cfg.timescales);end
    if ismember('homotopic',cfg.methods),result.homotopic=cog.homotopic_fc(d.y,d.pairs,cfg.homotopic);if isfield(d,'space'),a=nan(1,size(d.y,2));a(d.pairs(:,1))=result.homotopic.correlation;a(d.pairs(:,2))=result.homotopic.correlation;cog.write_map(fullfile(out,'homotopic_r.nii'),a,d.space,'Declared paired homotopic r, mapping status in MAT');end,end
    featureIds=d.featureIds;save(fullfile(out,'rest_extended.mat'),'result','featureIds','-v7.3');save(fullfile(out,'REST_EXTENDED_COMPLETE.mat'),'cfg');
end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'REST_EXTENDED_BATCH_COMPLETE.mat'),'summary');
end
