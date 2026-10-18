function result=confound_design(confounds,cfg)
%CONFOUND_DESIGN 构造显式混杂设计；不回归影像，不滤波，不删除行。
% 常量和完全线性相关项通过 SVD 处理；输出正交基用于稳定投影。
% rank/remainingDF 仅为代数维度，不是考虑自相关后的统计自由度。
if ischar(confounds)||isstring(confounds)
    t=readtable(confounds,'FileType','text','Delimiter','\t');
else
    t=confounds;
end
n=height(t); if n<3, error('psy:DesignLength','Need at least 3 frames'); end
base={'trans_x','trans_y','trans_z','rot_x','rot_y','rot_z'};
switch cfg.motionModel
    case 'none', names={};
    case '6', names=base;
    case '24', names=[base,strcat(base,'_derivative1'),strcat(base,'_power2'),strcat(base,'_derivative1_power2')];
    otherwise, error('psy:DesignMotion','Choose none, 6 or 24');
end
if cfg.includeTissueMeans, names=[names,{'white_matter','csf'}]; end
if ~all(ismember(names,t.Properties.VariableNames)), error('psy:DesignColumns','Missing selected confound columns'); end
x=zeros(n,0);
if ~isempty(names), x=t{:,names}; end
if ~isnumeric(x)||any(~isfinite(x),'all'), error('psy:DesignValues','Selected regressors must be finite numeric'); end
% 连续项中心化/单位范数缩放；常量项剔除并在报告列出。
x=x-mean(x,1); scale=sqrt(sum(x.^2,1)); keep=scale>0;
dropped=names(~keep); names=names(keep); x=x(:,keep)./scale(keep);
if cfg.linearTrend
    trend=linspace(-1,1,n)'; x=[x,trend/norm(trend)]; names=[names,{'linear_trend'}];
end
flag=false(n,1);
if cfg.addSpikes
    if ~ismember('framewise_displacement',t.Properties.VariableNames), error('psy:DesignColumns','FD column required for spikes'); end
    fd=t.framewise_displacement;
    if ~isnumeric(fd)||any(~isfinite(fd)|fd<0), error('psy:DesignFD','FD must be finite nonnegative'); end
    if ~(isscalar(cfg.fdThresholdMm)&&isfinite(cfg.fdThresholdMm)&&cfg.fdThresholdMm>=0), error('psy:DesignFD','Invalid FD threshold'); end
    flag=fd>cfg.fdThresholdMm; ids=find(flag);
    spikes=zeros(n,numel(ids));
    for j=1:numel(ids), spikes(ids(j),j)=1; end
    x=[x,spikes]; names=[names,arrayfun(@(k)sprintf('spike_frame_%d',k),ids','UniformOutput',false)];
end
x=[ones(n,1)/sqrt(n),x]; names=[{'intercept'},names];
[u,s,~]=svd(x,'econ'); singular=diag(s); tolerance=max(size(x))*eps(max(singular));
rankX=sum(singular>tolerance); remaining=n-rankX;
if ~(isscalar(cfg.minResidualDF)&&isfinite(cfg.minResidualDF)&&cfg.minResidualDF>=1&&fix(cfg.minResidualDF)==cfg.minResidualDF)
    error('psy:DesignDF','minResidualDF must be positive integer');
end
if remaining<cfg.minResidualDF, error('psy:DesignDF','Only %d residual dimensions remain; need %d',remaining,cfg.minResidualDF); end
result=struct('matrix',x,'names',{names},'orthonormalBasis',u(:,1:rankX), ...
    'rank',rankX,'remainingDF',remaining,'dependentColumnCount',size(x,2)-rankX, ...
    'droppedConstantColumns',{dropped},'flaggedFrames',find(flag),'nFrames',n, ...
    'scope','nuisance_only_not_joint_task_model_not_filtered');
end
