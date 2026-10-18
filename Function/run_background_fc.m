function summary=run_background_fc(cfg)
%RUN_BACKGROUND_FC 任务效应与混杂/频率基联合回归后ROI背景连接。
setup_function;if nargin<1,cfg=background_config;end
if ~strcmp(cfg.temporalState,'unfiltered_unregressed'),error('cog:TemporalState','Require unfiltered/unregressed source BOLD');end
for name={'spmMat','maskFile','roiFile'},if ~isfile(cfg.(name{1})),error('cog:Path','Missing explicit input %s',name{1});end,end
summary=struct('execute',cfg.execute,'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','Choose new output root');end
[y,space,design]=cog.read_spm_session(cfg.spmMat,cfg.sessionIndex,cfg.maskFile,cfg.maxMatrixGiB);
[roi,coverage]=cog.roi_extract(y,space,cfg.roiFile,cfg.roiMinVoxels);
[residual,cleanInfo]=cog.clean_timeseries(roi,space.trSeconds,[design.task design.confounds],cfg.clean);fc=cog.fc(residual,cfg.estimator);
mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'background_fc.mat'),'roi','residual','coverage','design','cleanInfo','fc','cfg');
summary.status='complete';summary.nFrames=size(y,1);summary.nRois=size(roi,2);summary.nTaskColumns=size(design.task,2);summary.processing=cleanInfo;
cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'BACKGROUND_COMPLETE.mat'),'summary');
end
