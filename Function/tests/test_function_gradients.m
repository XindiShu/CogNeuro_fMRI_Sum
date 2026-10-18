function tests=test_function_gradients
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;addpath(genpath('D:/matlab/atoolbox/BrainSpace_function_20261017/matlab'));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testNativeEmbeddingsAndAlignment(t)
x=linspace(-1,1,20)';a=exp(-(x-x').^2/.2);cfg=gradient_config;o=cfg.options;o.nComponents=2;o.sparsityPercent=0;
for approach={'dm','le','pca'},o.approach=approach{1};r=cog.gradients({a,a},o);verifySize(t,r.selected{1},[20 2]);verifyEqual(t,r.selected{1},r.selected{2},'AbsTol',1e-8);end
o.approach='dm';o.alignment='joint';r=cog.gradients({a,a},o);verifySize(t,r.selected{2},[20 2]);verifyEmpty(t,r.gradients);
end
function testMoranPreservesMomentAndSpatialAutocorrelation(t)
n=16;w=diag(ones(n-1,1),1)+diag(ones(n-1,1),-1);y=sin((1:n)'*.2);o=struct('weights',w,'nPermutations',11,'seed',4);r=cog.spatial_association(y,flipud(y),'moran',o);
verifyEqual(t,mean(r.nullMaps,1),repmat(mean(y),1,11),'AbsTol',1e-10);verifyEqual(t,std(r.nullMaps,0,1),repmat(std(y),1,11),'AbsTol',1e-10);verifyEqual(t,r.metadata.moranINull,repmat(r.metadata.moranIObserved,1,11),'AbsTol',1e-10);verifyGreaterThanOrEqual(t,r.pTwoSided,1/12);
end
function testNativeSpinUsesSuppliedVertexOrder(t)
n=60;i=(0:n-1)';z=1-2*(i+.5)/n;theta=pi*(3-sqrt(5))*i;vertices=[sqrt(1-z.^2).*cos(theta) sqrt(1-z.^2).*sin(theta) z];sphere=struct('vertices',vertices,'faces',convhull(vertices));o=struct('spheres',{{sphere,sphere}},'hemisphereSizes',[n n],'surfaceAlgorithm','freesurfer','nPermutations',5,'seed',12);y=[vertices(:,1);vertices(:,2)];r=cog.spatial_association(y,(1:2*n)','spin',o);verifySize(t,r.nullMaps,[2*n 5]);verifyTrue(t,all(ismember(r.nullMaps(1:n,:),y(1:n)),'all'));verifyFalse(t,r.metadata.uniqueAssignment);
end
