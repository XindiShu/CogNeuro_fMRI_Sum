function [nll,latent]=rw_softmax(choice,reward,blocks,parameters,o)
%RW_SOFTMAX 选择发生前计算概率/值；当前奖励只用于其后的chosen-action更新。
choice=double(choice(:));reward=double(reward(:));blocks=string(blocks(:));n=numel(choice);a=parameters(1);beta=parameters(2);
if numel(parameters)~=2||any(~isfinite(parameters))||a<0||a>1||beta<0||numel(reward)~=n||numel(blocks)~=n||any(~isfinite(choice)|choice<1|choice>o.nActions|choice~=fix(choice))||any(~isfinite(reward)|reward<o.rewardRange(1)|reward>o.rewardRange(2))||any(ismissing(blocks)|blocks=="")||~isscalar(o.initialValue)||~isfinite(o.initialValue)||~isscalar(o.lapse)||o.lapse<0||o.lapse>=1,error('cog:RWInput','Finite ordered choices/rewards/block IDs and valid RW parameters required');end
q=zeros(1,o.nActions);qBefore=zeros(n,o.nActions);qAfter=qBefore;pe=zeros(n,1);prob=zeros(n,1);reset=false(n,1);
for t=1:n
    if t==1||blocks(t)~=blocks(t-1),q(:)=o.initialValue;reset(t)=true;end
    qBefore(t,:)=q;z=beta*q;z=z-max(z);p=exp(z)/sum(exp(z));prob(t)=(1-o.lapse)*p(choice(t))+o.lapse/o.nActions;pe(t)=reward(t)-q(choice(t));q(choice(t))=q(choice(t))+a*pe(t);qAfter(t,:)=q;
end
loss=-log(max(realmin,prob));nll=sum(loss);latent=struct('qBefore',qBefore,'qAfter',qAfter,'predictionError',pe,'chosenProbability',prob,'negativeLogProbability',loss,'resetBeforeTrial',reset);
end
