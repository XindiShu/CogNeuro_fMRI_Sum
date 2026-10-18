function summary=run_function(cfg)
%RUN_FUNCTION 从清单运行第一批连续时序方法；矩阵方法有各自明确输入接口。
setup_function;if nargin<1,cfg=function_config;end
if ~isempty(cfg.spmPath),addpath(cfg.spmPath);end
if isempty(which('spm')),error('cog:SPM','SPM required');end
allowed={'static_fc','alff','reho','graph'};
if isempty(cfg.methods)||~all(ismember(cfg.methods,allowed))||numel(unique(cfg.methods))~=numel(cfg.methods),error('cog:Methods','Unsupported/repeated methods');end
runs=cog.read_runs(cfg.manifestFile);summary=struct('execute',cfg.execute,'nRuns',height(runs),'completed',0,'failed',0,'runs',{{}});
% 所有清单声明先预检；不把有问题的run静默丢掉。
for k=1:height(runs)
    if ismember('alff',cfg.methods)&&runs.temporal_state(k)=="denoised_bandpassed",error('cog:SpectrumState','fALFF requires pre-bandpass input');end
    if ismember('reho',cfg.methods)&&runs.smoothing_fwhm_mm(k)~=0,error('cog:ReHoState','ReHo requires declared unsmoothed input');end
    if runs.temporal_state(k)~="unfiltered_unregressed"&&strlength(runs.confounds(k))>0,error('cog:TemporalState','Do not regress nuisance twice');end
    if ~endsWith(lower(runs.bold(k)),'.nii')||~endsWith(lower(runs.mask(k)),'.nii')||~endsWith(lower(runs.roi_file(k)),'.nii'),error('cog:Format','NIfTI .nii paths required');end
end
if ~cfg.execute,summary.runs=table2struct(runs);return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Use a new output root');end
mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','runs');
for k=1:height(runs)
    row=runs(k,:);parts={char(row.subject)};if strlength(row.session)>0,parts{end+1}=char(row.session);end;parts{end+1}=char(row.run);
    out=fullfile(cfg.outputRoot,parts{:});mkdir(out);record=struct('subject',row.subject,'session',row.session,'run',row.run,'status','failed','error','');
    try
        [y,space]=cog.load_bold(row.bold,row.mask,row.tr_seconds,cfg.maxMatrixGiB);
        conf=[];if strlength(row.confounds)>0,t=cog.read_tsv(row.confounds);conf=str2double(string(table2cell(t)));end
        noBand=cfg.clean;noBand.bandHz=[];[unfiltered,baseInfo]=cog.clean_timeseries(y,row.tr_seconds,conf,noBand);
        [clean,cleanInfo]=cog.clean_timeseries(y,row.tr_seconds,conf,cfg.clean);
        [roi,roiInfo]=cog.roi_extract(clean,space,row.roi_file,cfg.roiMinVoxels);
        writetable(roiInfo,fullfile(out,'roi_coverage.tsv'),'FileType','text','Delimiter','\t');save(fullfile(out,'roi_timeseries.mat'),'roi','roiInfo','cleanInfo','baseInfo','row');
        if any(ismember({'static_fc','graph'},cfg.methods))
            fc=cog.fc(roi,cfg.fc.estimator);save(fullfile(out,'static_fc.mat'),'fc','roiInfo');
            writematrix(fc.correlation,fullfile(out,'fc_r.tsv'),'FileType','text','Delimiter','\t');
            if ismember('graph',cfg.methods),graph=cog.graph_metrics(fc.correlation,cfg.graph);save(fullfile(out,'graph_metrics.mat'),'graph','roiInfo');end
            if ~isempty(cfg.fc.seedColumns)
                idx=cfg.fc.seedColumns;if any(idx<1|idx~=fix(idx)|idx>size(roi,2)),error('cog:Seeds','Invalid ROI seed columns');end
                maps=cog.seed_fc(roi(:,idx),clean);
                for j=1:numel(idx),cog.write_map(fullfile(out,sprintf('seed_%g_r.nii',roiInfo.label(idx(j)))),maps(j,:),space,'Seed Pearson r');end
            end
        end
        if ismember('alff',cfg.methods)
            s=cog.spectrum_metrics(unfiltered,row.tr_seconds,cfg.spectrum.bandHz);save(fullfile(out,'spectrum.mat'),'s','baseInfo');
            cog.write_map(fullfile(out,'alff.nii'),s.alff,space,'ALFF unpadded one-sided amplitude mean');cog.write_map(fullfile(out,'falff.nii'),s.falff,space,'fALFF positive-frequency amplitude ratio');
        end
        if ismember('reho',cfg.methods)
            h=cog.reho(clean,space,cfg.reho.neighborhood,cfg.reho.minNeighbors);save(fullfile(out,'reho.mat'),'h','cleanInfo');
            cog.write_map(fullfile(out,'reho.nii'),h.kendallW,space,'Kendall W tie-corrected');cog.write_map(fullfile(out,'reho_neighbors.nii'),h.nNeighbors,space,'ReHo actual neighborhood count');
        end
        record.status='complete';record.nFrames=size(y,1);record.nVoxels=size(y,2);record.methods=cfg.methods;record.processing=cleanInfo;
        save(fullfile(out,'COMPLETE.mat'),'record','cfg','row');summary.completed=summary.completed+1;
    catch e
        record.error=e.message;record.errorIdentifier=e.identifier;summary.failed=summary.failed+1;
        cog.write_json(fullfile(out,'FAILED.json'),record);if ~cfg.continueOnError,rethrow(e);end
    end
    cog.write_json(fullfile(out,'summary.json'),record);summary.runs{end+1}=record;
end
cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);
if summary.failed==0,save(fullfile(cfg.outputRoot,'BATCH_COMPLETE.mat'),'summary');end
end
