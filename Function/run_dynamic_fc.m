function summary=run_dynamic_fc(cfg)
%RUN_DYNAMIC_FC 每subject/session/run单独开窗及零模型，不拼接边界。
setup_function;if nargin<1,cfg=dynamic_fc_config;end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t),error('cog:DynamicInput','Unique run keys required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:DynamicInput','Unsafe run key');end,end,end
data=cell(height(t),1);for k=1:height(t)
    t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');d=s.data;if ~all(isfield(d,{'y','trSeconds','roiNames'})),error('cog:DynamicInput','Data y/trSeconds/roiNames required');end
    ids=string(d.roiNames(:));if numel(ids)~=size(d.y,2)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids==""),error('cog:DynamicInput','Unique ordered region names required');end
    if ~isfield(d,'frameIndices'),d.frameIndices=(1:size(d.y,1))';end;cog.sliding_fc(d.y,d.trSeconds,d.frameIndices,cfg.options,false);data{k}=d;
end
summary=struct('execute',cfg.execute,'nRuns',height(t),'status','preflight','records',{{}});if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New dynamic FC root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
for k=1:height(t)
    d=data{k};result=cog.sliding_fc(d.y,d.trSeconds,d.frameIndices,cfg.options,true);parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);roiNames=d.roiNames;save(fullfile(out,'dynamic_fc.mat'),'result','roiNames','-v7.3');record=struct('subject',t.subject(k),'session',t.session(k),'run',t.run(k),'nWindows',cellfun(@(w)w.nWindows,result.windows));summary.records{end+1}=record;save(fullfile(out,'DYNAMIC_FC_COMPLETE.mat'),'record');
end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'DYNAMIC_FC_BATCH_COMPLETE.mat'),'summary');
end
