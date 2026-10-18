function summary=run_behavior(cfg)
%RUN_BEHAVIOR 每run独立行为模型；不默默清理试次、不改变原始记录。
setup_function;if nargin<1,cfg=behavior_config;end
t=cog.read_tsv(cfg.manifestFile,{'subject','session','run','trials_file'});keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t)||~ismember(cfg.method,{'rw_softmax','ddm'}),error('cog:BehaviorInput','Unique run keys and supported method required');end
actions=string(cfg.actionLabels(:));if numel(actions)<2||numel(unique(actions))~=numel(actions)||any(ismissing(actions)|actions=="")||strcmp(cfg.method,'ddm')&&numel(actions)~=2,error('cog:BehaviorInput','Unique action labels required; DDM is binary');end
if ~isscalar(cfg.minimumTrials)||~isfinite(cfg.minimumTrials)||cfg.minimumTrials<3||cfg.minimumTrials~=fix(cfg.minimumTrials),error('cog:BehaviorInput','Positive integer minimum trial count >=3 required');end
values={t.subject,t.session,t.run};for j=1:3,v=values{j};for k=1:numel(v),if j==2&&v(k)=="",continue;end;if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:BehaviorInput','Unsafe run ID');end,end,end
trials=cell(height(t),1);for k=1:height(t)
    t.trials_file(k)=string(cog.resolve_path(t.trials_file(k),fileparts(cfg.manifestFile)));required={'trial_id','block_id','choice'};if strcmp(cfg.method,'ddm'),required=[required {'rt_seconds'}];else,required=[required {'reward'}];end;tr=cog.read_tsv(t.trials_file(k),required);choice=str2double(tr.choice);
    if height(tr)<cfg.minimumTrials||numel(unique(tr.trial_id))~=height(tr)||any(tr.trial_id==""|tr.block_id=="")||any(~isfinite(choice)|choice<1|choice>numel(actions)|choice~=fix(choice)),error('cog:BehaviorInput','Complete ordered unique trial IDs/blocks and declared action indices required');end
    if strcmp(cfg.method,'rw_softmax'),o=cfg.rw;o.nActions=numel(actions);cog.rw_softmax(choice,str2double(tr.reward),tr.block_id,[mean(o.alphaBounds) mean(o.betaBounds)],o);
    else,rt=str2double(tr.rt_seconds);if any(~isfinite(rt)|rt<=0|rt>cfg.ddm.maxRtSeconds),error('cog:BehaviorRT','Explicit seconds RT outside allowed range');end;end
    trials{k}=tr;
end
summary=struct('execute',cfg.execute,'method',cfg.method,'nRuns',height(t),'records',{{}},'status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New behavior output root required');end;mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg','t','actions');root=fileparts(mfilename('fullpath'));
for k=1:height(t)
    tr=trials{k};choice=str2double(tr.choice);parts={char(t.subject(k))};if t.session(k)~="",parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));out=fullfile(cfg.outputRoot,parts{:});mkdir(out);
    if strcmp(cfg.method,'rw_softmax')
        o=cfg.rw;o.nActions=numel(actions);result=cog.fit_rw(choice,str2double(tr.reward),tr.block_id,o);latent=table(tr.trial_id,tr.block_id,choice,str2double(tr.reward),result.latent.chosenProbability,result.latent.predictionError,result.latent.negativeLogProbability,'VariableNames',{'trial_id','block_id','choice','reward','chosen_probability','prediction_error','negative_log_probability'});for a=1:numel(actions),latent.(sprintf('q_before_action_%d',a))=result.latent.qBefore(:,a);end
        writetable(latent,fullfile(out,'trial_latents.tsv'),'FileType','text','Delimiter','\t');record=struct('subject',t.subject(k),'run',t.run(k),'negativeLogLikelihood',result.negativeLogLikelihood);
        if ismember('onset_seconds',tr.Properties.VariableNames),onset=str2double(tr.onset_seconds);if any(~isfinite(onset)|onset<0),error('cog:BehaviorOnsets','Explicit finite nonnegative scanner-relative onsets required');end;latent.onset_seconds=onset;writetable(latent,fullfile(out,'trial_latents_with_onsets.tsv'),'FileType','text','Delimiter','\t');end
    else
        rtSeconds=str2double(tr.rt_seconds);upperChoice=double(choice==1);input=fullfile(out,'ddm_input.mat');save(input,'rtSeconds','upperChoice','-v7');spec=struct('inputFile',input,'outputFile',fullfile(out,'ddm_fit.mat'),'modelFile',fullfile(out,'native_ddm.pkl'),'options',cfg.ddm);file=fullfile(out,'ddm_request.json');cog.write_json(file,spec);cog.python_process(cfg.pythonExecutable,fullfile(root,'scripts','ddm_bridge.py'),{file},fullfile(out,'ddm_native.log'),cfg.pythonTimeoutSeconds);result=load(spec.outputFile);record=struct('subject',t.subject(k),'run',t.run(k),'negativeLogLikelihood',result.negativeLogLikelihood);
        density=table(tr.trial_id,choice,rtSeconds,result.perTrialNegativeLogDensity(:),'VariableNames',{'trial_id','choice','rt_seconds','negative_log_density'});writetable(density,fullfile(out,'trial_ddm_density.tsv'),'FileType','text','Delimiter','\t');
    end
    save(fullfile(out,'behavior_model.mat'),'result','tr','actions');save(fullfile(out,'BEHAVIOR_COMPLETE.mat'),'record');summary.records{end+1}=record;
end
summary.status='complete';cog.write_json(fullfile(cfg.outputRoot,'summary.json'),summary);save(fullfile(cfg.outputRoot,'BEHAVIOR_BATCH_COMPLETE.mat'),'summary');
end
