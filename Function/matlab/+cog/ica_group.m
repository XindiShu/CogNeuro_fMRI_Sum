function result=ica_group(runs,o)
%ICA_GROUP 时间×空间矩阵，逐run降维后时序拼接；不是完整GIFT GUI分析管线。
if ~iscell(runs)||isempty(runs)||isempty(which('icatb_fastICA')),error('cog:ICA','Cell of runs and official GIFT FastICA backend required');end
k=o.nComponents;p=o.perRunPca;
if ~isscalar(k)||~isfinite(k)||k<1||k~=fix(k)||~isscalar(p)||~isfinite(p)||p<k||p~=fix(p)||~isscalar(o.maxIterations)||~isfinite(o.maxIterations)||o.maxIterations<1||o.maxIterations~=fix(o.maxIterations)||~isscalar(o.tolerance)||~isfinite(o.tolerance)||o.tolerance<=0,error('cog:ICA','Invalid component/PCA/iteration/tolerance options');end
reduced=cell(size(runs));prepared=cell(size(runs));retained=zeros(numel(runs),1);
for r=1:numel(runs)
    y=double(runs{r});if ~ismatrix(y)||~isreal(y)||size(y,1)<p+2||size(y,2)<p+2||any(~isfinite(y),'all')||(r>1&&size(y,2)~=size(runs{1},2)),error('cog:ICA','Finite common-feature matrices with sufficient dimensions required');end
    y=y-mean(y,1);sd=std(y,0,1);if any(sd<=eps),error('cog:ICA','Constant feature in input; specify common valid mask');end
    if o.voxelVarianceNormalize,y=y./sd;end
    [~,s,v]=svd(y,'econ');values=diag(s);if values(p)<=max(size(y))*eps(values(1)),error('cog:ICA','Requested per-run PCA exceeds numerical rank');end
    retained(r)=sum(values(1:p).^2)/sum(values.^2);reduced{r}=s(1:p,1:p)*v(:,1:p)';prepared{r}=y;
end
cat=vertcat(reduced{:});cat=cat-mean(cat,2);[u,s,~]=svd(cat,'econ');if s(k,k)<=max(size(cat))*eps(s(1,1)),error('cog:ICA','Group data rank insufficient');end
groupScores=u(:,1:k)'*cat;old=rng;cleanup=onCleanup(@()rng(old));rng(o.seed); %#ok<NASGU>
[components,mixing,separating]=icatb_fastICA(groupScores,'approach','symm','numOfIC',k,'g','tanh','maxNumIterations',o.maxIterations,'epsilon',o.tolerance,'verbose','off','displayMode','off');
if ~isequal(size(components),[k size(cat,2)])||any(~isfinite(components),'all')||rank(components')~=k,error('cog:ICA','ICA did not return a complete finite independent component set');end
maps=components';maps=maps-mean(maps,1);maps=maps./std(maps,0,1);
% 符号本来不可识别；最大绝对体素置正，只用于同一次结果的确定性展示。
for j=1:k,[~,i]=max(abs(maps(:,j)));if maps(i,j)<0,maps(:,j)=-maps(:,j);end,end
dual=cell(size(runs));for r=1:numel(runs),dual{r}=cog.dual_regression(prepared{r},maps,o.normalizeStage2Timecourses);end
result=struct('groupMaps',maps,'dual',{dual},'mixing',mixing,'separating',separating,'perRunPcaVarianceFraction',retained,'groupPcaVarianceFraction',sum(diag(s(1:k,1:k)).^2)/sum(diag(s).^2),'backend',which('icatb_fastICA'),'componentStabilityAssessed',false,'options',o);
end
