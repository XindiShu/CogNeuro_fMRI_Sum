function result=cluster_states(y,segments,o)
%CLUSTER_STATES CAP与LEiDA使用不同观测；固定K群体描述性聚类，不是HMM。
[nt,n]=size(y);if ~isnumeric(y)||~isreal(y)||any(~isfinite(y),'all')||n<2||~ismember(o.method,{'cap','leida'})||~isscalar(o.nStates)||o.nStates<2||o.nStates~=fix(o.nStates)||~isscalar(o.nReplicates)||o.nReplicates<1||o.nReplicates~=fix(o.nReplicates)||~isscalar(o.maxIterations)||o.maxIterations<1||o.maxIterations~=fix(o.maxIterations),error('cog:StateClustering','Finite time x nodes and valid method/clustering settings required');end
cog.state_metrics(zeros(nt,1),segments,1,o.nStates); % 统一检查分段覆盖与顺序，不从错误边界默默拼接。
selected=true(nt,1);features=zeros(nt,n);description='';
if strcmp(o.method,'cap')
    features=double(y);features=features-mean(features,2);norms=sqrt(sum(features.^2,2));selected=norms>eps;features(selected,:)=features(selected,:)./norms(selected);
    if ~isempty(o.capSeedColumn),k=o.capSeedColumn;if ~isscalar(k)||k<1||k>n||k~=fix(k)||~isscalar(o.capSeedThreshold)||~isfinite(o.capSeedThreshold),error('cog:CAPSelection','Invalid seed ROI/threshold');end;selected=selected&y(:,k)>o.capSeedThreshold;end
    distance='correlation';description='CAP: spatially centered/unit-normalized amplitude frames; correlation kmeans. Nonselected/constant-pattern frames have label0.';
else
    if ~isscalar(o.leidaTrimFrames)||~isfinite(o.leidaTrimFrames)||o.leidaTrimFrames<0||o.leidaTrimFrames~=fix(o.leidaTrimFrames),error('cog:LEiDA','Nonnegative integer edge trim required');end
    selected(:)=false;phases=nan(nt,n);
    for s=1:size(segments,1)
        ii=segments(s,1):segments(s,2);if numel(ii)<max(8,2*o.leidaTrimFrames+1),continue;end
        phases(ii,:)=angle(hilbert(double(y(ii,:))));keep=ii(1+o.leidaTrimFrames:end-o.leidaTrimFrames);selected(keep)=true;
        for t=keep,p=phases(t,:);sync=cos(p'-p);[v,d]=eig((sync+sync')/2,'vector');[~,j]=max(d);a=v(:,j);if nnz(a>0)>n/2||(nnz(a>0)==n/2&&sum(a)>0),a=-a;end;features(t,:)=a';end
    end
    distance='cosine';description='LEiDA: leading eigenvector of cos(phase_i-phase_j), Hilbert per contiguous segment, majority-negative sign (count tie uses negative sum), cosine kmeans.';
end
if nnz(selected)<max(o.nStates*3,o.nStates+1),error('cog:StateCoverage','Too few assigned observations for fixed K');end
old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
[assigned,centers,sumd]=kmeans(features(selected,:),o.nStates,'Distance',distance,'Replicates',o.nReplicates,'MaxIter',o.maxIterations,'EmptyAction','singleton','Display','off');labels=zeros(nt,1);labels(selected)=assigned;
result=struct('labels',labels,'centers',centers,'features',features,'selectedFrames',selected,'withinClusterDistance',sumd,'options',o,'description',description,'stabilityAssessed',false);if exist('phases','var'),result.phases=phases;end
end
