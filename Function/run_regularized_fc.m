function summary=run_regularized_fc(cfg)
%RUN_REGULARIZED_FC 每run独立收缩，不跨run估计协方差。
setup_function;if nargin<1,cfg=regularized_fc_config;end;t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t),error('cog:ShrinkageInput','Unique run keys required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:ShrinkageInput','Unsafe run key');end,end,end
input=cell(height(t),1);for k=1:height(t),t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');d=s.data;ids=string(d.featureIds(:));if numel(ids)~=size(d.y,2)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids==""),error('cog:ShrinkageInput','Unique feature identity required');end;input{k}=d;end
summary=struct('execute',cfg.execute,'status','preflight','nRuns',height(t));if ~cfg.execute,return;end;if isfolder(cfg.outputRoot),error('cog:Exists','New shrinkage output root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
for k=1:height(t),result=cog.shrinkage_covariance(input{k}.y,cfg.options);featureIds=input{k}.featureIds;parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);save(fullfile(out,'regularized_fc.mat'),'result','featureIds');end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);
end
