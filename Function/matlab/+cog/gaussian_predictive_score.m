function [score,detail]=gaussian_predictive_score(yTrain,yTest,Vaa,Vta,Vtt,Xtrain,Xtest)
%GAUSSIAN_PREDICTIVE_SCORE 插件协方差条件预测；训练/测试各自固定效应平坦先验积分。
na=size(yTrain,1);nt=size(yTest,1);p=size(yTrain,2);
if size(yTest,2)~=p||~isequal(size(Vaa),[na na])||~isequal(size(Vta),[nt na])||~isequal(size(Vtt),[nt nt])||size(Xtrain,1)~=na||size(Xtest,1)~=nt,error('cog:GaussianPredictive','Incompatible data/covariance/fixed design');end
la=chol((Vaa+Vaa')/2,'lower');ia=la'\(la\eye(na));ir=ia;if ~isempty(Xtrain),a=Xtrain'*ia*Xtrain;chol(a);ir=ia-ia*Xtrain*(a\(Xtrain'*ia));end
meanPrediction=Vta*ir*yTrain;covariance=Vtt-Vta*ir*Vta';covariance=(covariance+covariance')/2;lt=chol(covariance,'lower');iv=lt'\(lt\eye(nt));irTest=iv;logdetFixed=0;
if ~isempty(Xtest),a=Xtest'*iv*Xtest;l=chol(a,'lower');logdetFixed=2*sum(log(diag(l)));irTest=iv-iv*Xtest*(a\(Xtest'*iv));end
residual=yTest-meanPrediction;score=-.5*p*(2*sum(log(diag(lt)))+logdetFixed+(nt-size(Xtest,2))*log(2*pi))-.5*sum(residual.*(irTest*residual),'all');if ~isfinite(score),error('cog:GaussianPredictive','Nonfinite held-out score');end
detail=struct('meanPrediction',meanPrediction,'conditionalCovariance',covariance,'testResidual',residual,'score',score,'note','Plug-in train-fitted covariance/hyperparameters; train nuisance uncertainty integrated with a flat prior, test nuisance integrated by restricted density. Not posterior integration over covariance hyperparameters.');
end
