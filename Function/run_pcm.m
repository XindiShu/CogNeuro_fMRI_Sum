function result=run_pcm(cfg)
%RUN_PCM 独立被试各一行，不将session/run当独立被试拟合共享组参数。
setup_function;if nargin<1,cfg=pcm_config;end
if ~isempty(cfg.pcmPath),addpath(cfg.pcmPath);end
t=cog.read_tsv(cfg.manifestFile,{'subject','data_file'});if isempty(t)||numel(unique(t.subject))~=height(t)||any(t.subject==""),error('cog:PCMSubjects','Unique independent subject rows required');end
data=cell(height(t),1);for k=1:height(t),t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');data{k}=s.data;end
if numel(unique(lower(t.data_file)))~=height(t),error('cog:PCMSubjects','Same file cannot represent multiple independent subjects');end
result=cog.pcm_fit(data,cfg.conditionLabels,cfg.models,cfg.options,false);if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New PCM result directory required');end
result=cog.pcm_fit(data,cfg.conditionLabels,cfg.models,cfg.options,true);mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'PCM.mat'),'result','cfg','t','-v7.3');writematrix(result.likelihood,fullfile(cfg.outputRoot,'model_likelihood.tsv'),'FileType','text','Delimiter','\t');save(fullfile(cfg.outputRoot,'PCM_COMPLETE.mat'),'result');
end
