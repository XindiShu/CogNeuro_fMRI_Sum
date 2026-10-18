function summary=run_gradients(cfg)
%RUN_GRADIENTS 多被试/session/run节点/特征ID一致才联合嵌入或对齐。
setup_function;if nargin<1,cfg=gradient_config;end
if ~isempty(cfg.brainSpacePath),addpath(genpath(cfg.brainSpacePath));end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(keys))~=height(t),error('cog:GradientInput','Unique nonempty input rows required');end
matrices=cell(height(t),1);
for k=1:height(t)
    t.data_file(k)=string(cog.resolve_path(t.data_file(k),fileparts(cfg.manifestFile)));s=load(t.data_file(k),'data');d=s.data;
    if ~all(isfield(d,{'matrix','nodeIds','featureIds'})),error('cog:GradientInput','Explicit matrix/nodeIds/featureIds required');end
    ni=string(d.nodeIds(:));fi=string(d.featureIds(:));if size(d.matrix,1)~=numel(ni)||size(d.matrix,2)~=numel(fi)||numel(unique(ni))~=numel(ni)||numel(unique(fi))~=numel(fi)||any(ismissing(ni)|ni=="")||any(ismissing(fi)|fi==""),error('cog:GradientInput','Unique named rows/columns must match matrix');end
    if k==1,nodeIds=ni;featureIds=fi;elseif ~isequal(ni,nodeIds)||~isequal(fi,featureIds),error('cog:GradientInput','Node/feature identities and order must agree');end
    matrices{k}=d.matrix;
end
spatial=[];if ~isempty(cfg.spatialNullFile),s=load(cfg.spatialNullFile,'spatial');spatial=s.spatial;if ~isequal(string(spatial.nodeIds(:)),nodeIds)||~isscalar(cfg.spatialGradientColumn)||cfg.spatialGradientColumn<1||cfg.spatialGradientColumn>cfg.options.nComponents||cfg.spatialGradientColumn~=fix(cfg.spatialGradientColumn),error('cog:SpatialNull','Spatial map node order or gradient column mismatch');end,end
summary=struct('execute',cfg.execute,'nInputs',height(t),'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New gradient result directory required');end
result=cog.gradients(matrices,cfg.options);associations=cell(height(t),1);if ~isempty(spatial),for k=1:height(t),associations{k}=cog.spatial_association(result.selected{k}(:,cfg.spatialGradientColumn),spatial.marker,spatial.method,spatial.options);end,end
mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'gradients.mat'),'result','cfg','t','nodeIds','featureIds','associations','-v7.3');for k=1:height(t),writematrix(result.selected{k},fullfile(cfg.outputRoot,sprintf('unit_%03d_gradients.tsv',k)),'FileType','text','Delimiter','\t');end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'GRADIENTS_COMPLETE.mat'),'summary');
end
