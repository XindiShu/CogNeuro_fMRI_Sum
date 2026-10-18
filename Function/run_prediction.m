function result=run_prediction(cfg)
%RUN_PREDICTION 一行一被试；重复session/run应先构成同一被试的特征，不能伪增N。
setup_function;if nargin<1,cfg=prediction_config;end
s=load(cfg.dataFile,'data');d=s.data;if ~all(isfield(d,{'x','target','subjectIds','groupIds','featureIds'})),error('cog:PredictionInput','Data requires x/target/subjectIds/groupIds/featureIds');end
subjects=string(d.subjectIds(:));features=string(d.featureIds(:));if size(d.x,1)~=numel(subjects)||size(d.x,2)~=numel(features)||numel(unique(subjects))~=numel(subjects)||numel(unique(features))~=numel(features)||any(ismissing(subjects)|subjects=="")||any(ismissing(features)|features==""),error('cog:PredictionInput','Unique named subject rows and feature columns required');end
covariates=zeros(size(d.x,1),0);if isfield(d,'covariates'),covariates=d.covariates;end
blocks=repmat("all",size(d.x,1),1);if isfield(d,'exchangeBlocks'),blocks=d.exchangeBlocks;end
result=cog.predict_nested(d.x,d.target,d.groupIds,covariates,blocks,cfg.options,false);if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New prediction result directory required');end
result=cog.predict_nested(d.x,d.target,d.groupIds,covariates,blocks,cfg.options,true);mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'prediction.mat'),'result','subjects','features','cfg','-v7.3');predictions=table(subjects,d.target(:),result.prediction,result.nuisanceOnlyPrediction,'VariableNames',{'subject','target','prediction','nuisance_only_prediction'});writetable(predictions,fullfile(cfg.outputRoot,'out_of_group_predictions.tsv'),'FileType','text','Delimiter','\t');save(fullfile(cfg.outputRoot,'PREDICTION_COMPLETE.mat'),'result');
end
