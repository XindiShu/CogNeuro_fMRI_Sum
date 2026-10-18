% HCP LANGUAGE 单 run 工程验证；未解决的空间/组织掩膜问题仍然存在。
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'matlab'),fullfile(root,'config'));
h=preprocess_config; runs=psy.discover_hcp(h); r=runs(strcmp({runs.name},'tfMRI_LANGUAGE_LR'));
e=psy.read_hcp_events(r.ev,{'story','math'},316*.72,"preserve");
eventFile=fullfile(root,'examples','hcp_language_lr_events.tsv');
if ~isfile(eventFile)
    onset=vertcat(e.onsets{:}); duration=vertcat(e.durations{:}); trial_type=[repmat("story",numel(e.onsets{1}),1);repmat("math",numel(e.onsets{2}),1)];
    t=sortrows(table(onset,duration,trial_type),'onset'); writetable(t,eventFile,'FileType','text','Delimiter','\t');
end
cfg=rmfield(glm_config,'model'); cfg.spmPath=h.spmPath; cfg.execute=true; % 历史验证示例保留原逐run输出布局；新框架从run_glm启动。
cfg.conditions={'story','math'}; cfg.contrastNames={'story_minus_math','math_minus_story'}; cfg.contrastWeights=[1 -1;-1 1];
cfg.manifestFile=fullfile(root,'examples','hcp_glm_engineering.tsv'); cfg.outputRoot=fullfile(root,'derivatives','glm_engineering_validation');
report=psy.glm_batch(cfg); disp(struct2table(report,'AsArray',true));
assert(all(strcmp({report.status},'run_glm_estimated_spatial_limitations_unchanged')));
