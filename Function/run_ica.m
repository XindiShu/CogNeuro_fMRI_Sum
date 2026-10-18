function summary=run_ica(cfg)
%RUN_ICA 共享特征空间的多被试/session/run组ICA、逐run双回归和FNC。
setup_function;if nargin<1,cfg=ica_config;end
if ~isempty(cfg.giftPath),addpath(cfg.giftPath);end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});base=fileparts(cfg.manifestFile);keys=t.subject+"/"+t.session+"/"+t.run;
if isempty(t)||numel(unique(lower(keys)))~=height(t),error('cog:ICAInput','Unique nonempty run keys required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:ICAInput','Unsafe subject/session/run identifier');end,end,end
y=cell(height(t),1);spaces=cell(height(t),1);tr=zeros(height(t),1);
for k=1:height(t)
    t.data_file(k)=string(cog.resolve_path(t.data_file(k),base));s=load(t.data_file(k),'data');d=s.data;
    if ~all(isfield(d,{'y','featureIds','trSeconds'})),error('cog:ICAInput','Data requires y, featureIds, trSeconds');end
    ids=string(d.featureIds(:));if numel(ids)~=size(d.y,2)||numel(unique(ids))~=numel(ids)||any(ismissing(ids)|ids=="")||any(~isfinite(d.y),'all')||~isreal(d.y)||~isscalar(d.trSeconds)||~isfinite(d.trSeconds)||d.trSeconds<=0,error('cog:ICAInput','Invalid feature IDs/data/TR');end
    if k==1,referenceIds=ids;elseif ~isequal(ids,referenceIds),error('cog:ICAInput','All runs must share feature identity/order');end
    y{k}=d.y;tr(k)=d.trSeconds;if isfield(d,'space'),spaces{k}=d.space;end
end
hasSpace=~cellfun(@isempty,spaces);if any(hasSpace)&&~all(hasSpace),error('cog:ICAInput','Use spatial metadata for every run or none');end
if all(hasSpace),for k=2:height(t),cog.check_grid(spaces{k}.reference,spaces{1}.reference);if ~isequal(spaces{k}.indices,spaces{1}.indices),error('cog:ICAInput','Common voxel mask/order required');end,end,end
summary=struct('execute',cfg.execute,'nRuns',height(t),'nComponents',cfg.nComponents,'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use a new ICA result root');end
result=cog.ica_group(y,cfg);mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'ICA.mat'),'result','cfg','t','tr','referenceIds','-v7.3');
if all(hasSpace),for j=1:cfg.nComponents,cog.write_map(fullfile(cfg.outputRoot,sprintf('group_component_%03d.nii',j)),result.groupMaps(:,j),spaces{1},'Spatial ICA map standardized across features');end,end
for k=1:height(t)
    parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);dual=result.dual{k};save(fullfile(out,'dual_fnc.mat'),'dual');writematrix(dual.timecourses,fullfile(out,'component_timecourses.tsv'),'FileType','text','Delimiter','\t');
    if all(hasSpace),for j=1:cfg.nComponents,cog.write_map(fullfile(out,sprintf('dual_component_%03d.nii',j)),dual.subjectMaps(:,j),spaces{k},'Dual regression stage2 coefficient');end,end
end
summary.status='complete';summary.componentStabilityAssessed=false;cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'ICA_COMPLETE.mat'),'summary');
end
