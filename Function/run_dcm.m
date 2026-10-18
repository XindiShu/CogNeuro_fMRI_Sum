function summary=run_dcm(cfg)
%RUN_DCM 数据集无关多被试/session/run、多个显式候选网络，SPM原生反演。
setup_function;if nargin<1,cfg=dcm_config;end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','data_file'});base=fileparts(cfg.manifestFile);keys=t.subject+"/"+t.session+"/"+t.run;
if isempty(t)||numel(unique(lower(keys)))~=height(t)||isempty(cfg.models),error('cog:DCMManifest','Nonempty unique run keys and explicit models required');end
ids=string({cfg.models.id});if numel(unique(lower(ids)))~=numel(ids),error('cog:DCMManifest','Unique model ids required');end
values={t.subject,t.session,t.run,ids(:)};
for j=1:numel(values)
    v=values{j};for k=1:numel(v),if v(k)==""&&j==2,continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:DCMManifest','Unsafe identifier');end,end
end
prepared=cell(height(t),numel(cfg.models));
for r=1:height(t)
    t.data_file(r)=string(cog.resolve_path(t.data_file(r),base));s=load(t.data_file(r),'data');if ~isfield(s,'data'),error('cog:DCMData','MAT file must contain data struct');end
    for m=1:numel(cfg.models),prepared{r,m}=cog.dcm_build(s.data,cfg.models(m),cfg.mode,cfg.options);end
end
summary=struct('execute',cfg.execute,'mode',cfg.mode,'nRuns',height(t),'nModels',numel(cfg.models),'records',{{}});if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use new DCM output root');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t');
catalog=table;
for r=1:height(t)
    for m=1:numel(cfg.models)
        parts={char(t.subject(r))};if t.session(r)~="",parts{end+1}=char(t.session(r));end;parts{end+1}=char(t.run(r));parts{end+1}=char(ids(m));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);
        file=fullfile(out,'DCM.mat');DCM=prepared{r,m};DCM.name=file;save(file,'DCM');record=struct('subject',t.subject(r),'session',t.session(r),'run',t.run(r),'model',ids(m),'status','prepared','file',file);
        try
            if cfg.estimate
                old=pwd;cleanup=onCleanup(@()cd(old));cd(out);
                if strcmp(cfg.mode,'task'),DCM=spm_dcm_estimate(file);else,DCM=spm_dcm_fmri_csd(file);end
                clear cleanup;record.qc=cog.dcm_check(DCM);record.status='estimated';save(fullfile(out,'DCM_COMPLETE.mat'),'record');
            end
        catch e
            record.status='failed';record.error=e.message;cog.write_json(fullfile(out,'FAILED.json'),record);if ~cfg.continueOnError,rethrow(e);end
        end
        cog.write_json(fullfile(out,'summary.json'),record);summary.records{end+1}=record;
        catalog=[catalog;table(t.subject(r),t.session(r),t.run(r),ids(m),string(file),string(record.status),'VariableNames',{'subject','session','run','model_id','dcm_file','status'})]; %#ok<AGROW>
    end
end
writetable(catalog,fullfile(cfg.outputRoot,'dcm_catalog.tsv'),'FileType','text','Delimiter','\t');cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);
if cfg.estimate&&all(catalog.status=="estimated"),save(fullfile(cfg.outputRoot,'DCM_BATCH_COMPLETE.mat'),'summary');end
end
