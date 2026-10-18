function [mask,probability]=tissue_mask(tissueFile,reference,threshold,erosionMm)
%TISSUE_MASK 已配准组织概率 -> BOLD 网格；仅采样，不估计配准。
% SPM affine 定义 voxel -> world；这里逆变换到组织图 voxel 后三线性采样。
if ~(isscalar(threshold)&&isfinite(threshold)&&threshold>0.5&&threshold<=1) || ...
        ~(isscalar(erosionMm)&&isfinite(erosionMm)&&erosionMm>=0)
    error('psy:MaskParameters','Threshold must be (0.5,1], erosion must be >=0 mm');
end
v=spm_vol(tissueFile); if numel(v)~=1, error('psy:TissueShape','Expected 3-D probability image'); end
a=spm_read_vols(v);
if any(~isfinite(a(:))) || any(a(:)<-1e-5 | a(:)>1+1e-5), error('psy:TissueProbability','Expected finite probabilities in [0,1]'); end
[x,y,z]=ndgrid(1:reference.dim(1),1:reference.dim(2),1:reference.dim(3));
xyz=(v.mat\reference.mat)*[x(:)';y(:)';z(:)';ones(1,numel(x))];
probability=reshape(spm_sample_vol(v,xyz(1,:),xyz(2,:),xyz(3,:),1),reference.dim);
mask=isfinite(probability) & probability>=threshold;
if erosionMm>0
    % 使用完整 affine 的毫米距离，兼容斜切/各向异性网格。
    A=reference.mat(1:3,1:3); bound=ceil(erosionMm/min(svd(A)));
    [dx,dy,dz]=ndgrid(-bound:bound); mm=A*[dx(:)';dy(:)';dz(:)'];
    kernel=reshape(sum(mm.^2,1)<=erosionMm^2+1e-8,size(dx));
    mask=convn(double(mask),double(kernel),'same')==nnz(kernel);
end
end
