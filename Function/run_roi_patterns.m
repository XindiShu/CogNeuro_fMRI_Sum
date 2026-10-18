function summary=run_roi_patterns(cfg)
%RUN_ROI_PATTERNS 每subject/session独立模型；缺分区记skip，不伪造交叉验证。
setup_function;if nargin<1,cfg=roi_patterns_config;end
methods={'beta_series','decode','rsa'};if isempty(cfg.methods)||~all(ismember(cfg.methods,methods)),error('cog:Methods','Unknown pattern method');end
t=cog.read_tsv(cfg.catalogFile,{'estimate_id','subject','session','run','condition','image_path','mask_path','volume_index'});
if ~isempty(cfg.sourceId)
    if ~ismember('source_id',t.Properties.VariableNames),error('cog:BetaSource','source_id missing');end;t=t(t.source_id==string(cfg.sourceId),:);
end
if isempty(t),error('cog:BetaSource','Empty selected source');end
if ismember('source_id',t.Properties.VariableNames)&&numel(unique(t.source_id))>1,error('cog:BetaSource','Select one source_id');end
if ~all(ismember([{cfg.targetColumn},cfg.partitionColumns],t.Properties.VariableNames)),error('cog:Patterns','Missing target/partition columns');end
if ~isfile(cfg.roiFile),error('cog:ROI','ROI file missing');end
summary=struct('execute',cfg.execute,'nEstimates',height(t),'records',{{}});if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use new output root');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg');
% 选择后的目录只写新输出；原目录及模型不变。
base=fileparts(cfg.catalogFile);for f={'image_path','mask_path'},for k=1:height(t),t.(f{1})(k)=string(cog.resolve_path(t.(f{1})(k),base));end,end
selected=fullfile(cfg.outputRoot,'selected_catalog.tsv');writetable(t,selected,'FileType','text','Delimiter','\t');
[x,t,space]=cog.load_betas(selected,cfg.maxMatrixGiB);[means,coverage]=cog.roi_extract(x,space,cfg.roiFile,cfg.roiMinVoxels);v=spm_vol(cfg.roiFile);label=spm_read_vols(v);label=label(space.indices);
writetable(coverage,fullfile(cfg.outputRoot,'roi_coverage.tsv'),'FileType','text','Delimiter','\t');
if ismember('beta_series',cfg.methods),b=cog.beta_series(means,t,cfg.options.betaSeries.minTrials,cfg.options.betaSeries.estimator);save(fullfile(cfg.outputRoot,'beta_series.mat'),'b','coverage');end
units=string(t.subject)+"/"+string(t.session);allUnits=unique(units,'stable');
for u=1:numel(allUnits)
    use=units==allUnits(u);meta=t(use,:);part=strings(height(meta),1);for p=1:numel(cfg.partitionColumns),part=part+"/"+string(meta.(cfg.partitionColumns{p}));end
    for j=1:height(coverage)
        cols=label==coverage.label(j);a=x(use,cols);record=struct('unit',allUnits(u),'roi',coverage.label(j),'decode','not_requested','rsa','not_requested');
        stem=sprintf('unit_%03d_roi_%g',u,coverage.label(j));
        if ismember('decode',cfg.methods)
            if numel(unique(part))<2,record.decode='skipped: requires >=2 independent partitions';
            else
                target=meta.(cfg.targetColumn);if strcmp(cfg.options.decode.task,'regression'),target=str2double(target);end
                d=cog.decode(a,target,part,cfg.options.decode);save(fullfile(cfg.outputRoot,[stem '_decode.mat']),'d','meta');record.decode='complete';
            end
        end
        if ismember('rsa',cfg.methods)
            if numel(unique(meta.condition))<2,record.rsa='skipped: requires >=2 conditions';
            else,r=cog.rsa(a,meta.condition,part,cfg.options.rsa);save(fullfile(cfg.outputRoot,[stem '_rsa.mat']),'r','meta');record.rsa='complete';end
        end
        summary.records{end+1}=record;
    end
end
cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'PATTERNS_COMPLETE.mat'),'summary');
end
