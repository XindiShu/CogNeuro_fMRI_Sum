function result=spatial_association(map,marker,method,o)
%SPATIAL_ASSOCIATION 单图Pearson关联的双侧空间零模型，不作普通标签置换。
map=double(map(:));marker=double(marker(:));n=numel(map);
if n<5||numel(marker)~=n||~isreal(map)||~isreal(marker)||any(~isfinite(map)|~isfinite(marker))||std(map)==0||std(marker)==0||~isscalar(o.nPermutations)||~isfinite(o.nPermutations)||o.nPermutations<1||o.nPermutations~=fix(o.nPermutations),error('cog:SpatialNull','Finite variable aligned maps and positive integer repetitions required');end
old=rng;cleanup=onCleanup(@()rng(old)); %#ok<NASGU>
switch method
    case 'moran'
        w=o.weights;if ~isequal(size(w),[n n])||any(~isfinite(w),'all')||any(w<0,'all')||norm(w-w','fro')>1e-8||any(diag(w)~=0)||any(sum(w,2)<=0)||numel(unique(conncomp(graph(w))))>1,error('cog:SpatialWeights','Explicit symmetric nonnegative connected zero-diagonal spatial weights required');end
        mem=compute_mem(w,'spectrum','all');nullMaps=moran_randomization(map,mem,o.nPermutations,'procedure','singleton','random_state',o.seed);nullMaps=reshape(nullMaps,n,o.nPermutations);metadata=struct('method','Moran singleton','weights',w,'moranIObserved',moranI(map,w),'moranINull',arrayfun(@(k)moranI(nullMaps(:,k),w),1:o.nPermutations));
    case 'spin'
        sizes=o.hemisphereSizes(:);if any(~isfinite(sizes)|sizes<4|sizes~=fix(sizes))||sum(sizes)~=n||numel(sizes)>2||numel(sizes)<1||~iscell(o.spheres)||numel(o.spheres)~=numel(sizes),error('cog:SpatialSphere','Explicit one/two spheres and ordered hemisphere sizes required');end
        for k=1:numel(sizes),s=convert_surface(o.spheres{k});vertices=s.coord';r=sqrt(sum(vertices.^2,2));if ~isequal(size(vertices),[sizes(k) 3])||any(~isfinite(vertices),'all')||any(r<=0)||max(abs(r/median(r)-1))>.05,error('cog:SpatialSphere','Origin-centered sphere coordinates with consistent radius and exact vertex count required');end,end
        data=mat2cell(map,sizes,1);permuted=spin_permutations(data,o.spheres,o.nPermutations,'surface_algorithm',o.surfaceAlgorithm,'random_state',o.seed);nullMaps=[];for k=1:numel(sizes),nullMaps=[nullMaps;reshape(permuted{k},sizes(k),o.nPermutations)];end %#ok<AGROW>
        metadata=struct('method','BrainSpace nearest-neighbor sphere rotation','uniqueAssignment',false,'hemisphereSizes',sizes,'surfaceAlgorithm',o.surfaceAlgorithm);
    otherwise,error('cog:SpatialNull','Method must be moran or spin');
end
if any(~isfinite(nullMaps),'all')||any(std(nullMaps,0,1)<=eps),error('cog:SpatialNull','Invalid surrogate map');end
observed=corr(map,marker);null=corr(nullMaps,marker);p=(1+nnz(abs(null)>=abs(observed)))/(1+o.nPermutations);
result=struct('correlation',observed,'pTwoSided',p,'nullCorrelations',null,'nullMaps',nullMaps,'metadata',metadata,'note','Single association, absolute-correlation two-sided Monte Carlo p. Spatial model validity depends on supplied geometry/weights and node mapping; no automatic multiple comparison or population inference.');
end
function value=moranI(y,w)
z=y-mean(y);value=numel(y)/sum(w,'all')*(z'*w*z)/(z'*z);
end
