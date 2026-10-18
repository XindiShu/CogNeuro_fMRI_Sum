function result=gradients(matrices,o)
%GRADIENTS 原生BrainSpace；节点为行，特征为列，不自动更改FC对角线或符号。
if isempty(which('GradientMaps'))||~iscell(matrices)||isempty(matrices),error('cog:Gradients','BrainSpace and nonempty cell of feature matrices required');end
n=size(matrices{1},1);f=size(matrices{1},2);
for k=1:numel(matrices),a=matrices{k};if ~isnumeric(a)||~isreal(a)||~isequal(size(a),[n f])||any(~isfinite(a),'all')||any(all(a==0,2)),error('cog:Gradients','Finite common node x feature matrices without zero rows required');end,end
if ~ismember(o.kernel,{'na','cs','pearson','spearman','gaussian'})||~ismember(o.approach,{'dm','le','pca'})||~ismember(o.alignment,{'none','pa','joint'})||~isscalar(o.nComponents)||~isfinite(o.nComponents)||o.nComponents<1||o.nComponents>=n-1||o.nComponents~=fix(o.nComponents)||~isscalar(o.sparsityPercent)||~isfinite(o.sparsityPercent)||o.sparsityPercent<0||o.sparsityPercent>=100||~isscalar(o.alpha)||~isfinite(o.alpha)||o.alpha<0||o.alpha>1||~isscalar(o.diffusionTime)||~isfinite(o.diffusionTime)||o.diffusionTime<0||~isscalar(o.alignmentIterations)||~isfinite(o.alignmentIterations)||o.alignmentIterations<1||o.alignmentIterations~=fix(o.alignmentIterations),error('cog:Gradients','Invalid embedding/alignment options');end
if ~isempty(o.reference)&&(~strcmp(o.alignment,'pa')||~isequal(size(o.reference),[n o.nComponents])||any(~isfinite(o.reference),'all')),error('cog:Gradients','Explicit finite reference applies only to PA and must match nodes/components');end
old=rng;cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
gm=GradientMaps('kernel',o.kernel,'approach',o.approach,'alignment',o.alignment,'n_components',o.nComponents,'random_state',o.seed,'verbose',false);
args={'sparsity',o.sparsityPercent,'alpha',o.alpha,'diffusion_time',o.diffusionTime,'niterations',o.alignmentIterations};if ~isempty(o.reference),args=[args {'reference',o.reference}];end
gm=gm.fit(matrices,args{:});raw=gm.gradients;aligned=gm.aligned;selected=aligned;if isempty(selected),selected=raw;end
for k=1:numel(selected),if ~isequal(size(selected{k}),[n o.nComponents])||~isreal(selected{k})||any(~isfinite(selected{k}),'all'),error('cog:Gradients','Invalid native embedding');end,end
if any(cellfun(@(a)any(~isfinite(a),'all'),gm.lambda)),error('cog:Gradients','Nonfinite native eigenvalues');end
result=struct('gradients',{raw},'aligned',{aligned},'selected',{selected},'lambda',{gm.lambda},'options',o,'backend',which('GradientMaps'),'note','Native BrainSpace threshold/kernel semantics; signs/order/rotations require alignment. Eigenvalue scales differ by approach and are not universally variance-explained fractions.');
end
