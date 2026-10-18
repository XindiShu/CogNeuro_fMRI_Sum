function summary=run_network(cfg)
%RUN_NETWORK 每run拓扑及可选独立单位NBS，所有节点顺序显式核对。
setup_function;if nargin<1,cfg=network_config;end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t),error('cog:NetworkInput','Unique run keys required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:NetworkInput','Unsafe run key');end,end,end
input=cell(height(t),1);nodeIds=[];
for k=1:height(t)
    t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');d=s.data;ids=string(d.nodeIds(:));if numel(ids)~=size(d.matrix,1)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids==""),error('cog:NetworkInput','Unique node IDs must match matrix');end
    cog.graph_metrics(d.matrix,struct('negativePolicy',cfg.options.negativePolicy,'threshold',0));if k==1,nodeIds=ids;elseif ~isequal(nodeIds,ids),error('cog:NetworkInput','Node order differs across runs');end;input{k}=d;
end
nbs=[];if strlength(string(cfg.nbsDataFile))>0,s=load(cfg.nbsDataFile,'data');nbs=s.data;if ~isequal(string(nbs.nodeIds(:)),nodeIds),error('cog:NetworkInput','NBS node order differs');end;if numel(unique(string(nbs.independentUnitIds)))~=size(nbs.matrices,3),error('cog:NBSInput','One matrix per independent unit required');end;end
summary=struct('execute',cfg.execute,'nRuns',height(t),'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New network output root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
for k=1:height(t)
    result=cog.network_analysis(input{k}.matrix,cfg.options,cfg.bctPath);parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);save(fullfile(out,'network.mat'),'result','nodeIds','-v7.3');
end
if ~isempty(nbs),result=cog.nbs_onesample(nbs.matrices,nbs.independentUnitIds,cfg.nbs);save(fullfile(cfg.outputRoot,'nbs.mat'),'result','nodeIds','-v7.3');end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'NETWORK_COMPLETE.mat'),'summary');
end
