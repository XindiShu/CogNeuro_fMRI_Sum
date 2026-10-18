function result=run_transfer(cfg)
%RUN_TRANSFER 跨任务/时段/被试的冻结模型应用，来源身份显式。
setup_function;if nargin<1,cfg=transfer_config;end;s=load(cfg.dataFile,'train','test');cog.transfer_check(s.train,s.test,cfg.options);result=struct('status','preflight');if ~cfg.execute,return;end
if isfolder(cfg.outputRoot),error('cog:Exists','New transfer output root required');end
model=cog.pattern_fit(s.train.X,s.train.Y,s.train.featureIds,cfg.options);result=cog.pattern_apply(model,s.test.X,s.test.featureIds);result.model=model;result.sourceDomain=s.train.domainId;result.targetDomain=s.test.domainId;result.targetSampleIds=s.test.sampleIds;result.options=cfg.options;
if isfield(s.test,'Y')
    if ~strcmp(cfg.options.estimator,'ridge')
        y=string(s.test.Y(:));if any(~ismember(y,model.classes)),error('cog:TransferTarget','Target class absent from source training classes');end;result.accuracy=mean(y==result.prediction);recall=nan(numel(model.classes),1);for k=1:numel(model.classes),use=y==model.classes(k);if any(use),recall(k)=mean(result.prediction(use)==y(use));end,end;result.recallBySourceClass=recall;result.balancedAccuracy=mean(recall);result.balancedAccuracyComplete=all(isfinite(recall));
    else,y=double(s.test.Y(:));if any(~isfinite(y)),error('cog:TransferTarget','Finite target outcomes required');end;result.mae=mean(abs(y-result.prediction));result.mse=mean((y-result.prediction).^2);result.sourceMeanBaselineMse=mean((y-model.trainingTargetMean).^2);result.rSquared=1-sum((y-result.prediction).^2)/sum((y-mean(y)).^2);end
end
result.status='complete';result.note='Fixed source fit, target features only to apply; no target-domain scaling/tuning, population inference or upstream independence guarantee. Matched-unit domain transfer addresses known subjects; disjoint-unit transfer addresses new units.';mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'transfer.mat'),'result','cfg','-v7.3');
end
