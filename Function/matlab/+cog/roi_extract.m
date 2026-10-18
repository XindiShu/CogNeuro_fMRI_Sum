function [r,info]=roi_extract(y,space,labelFile,minVoxels)
%ROI_EXTRACT 整数标签图均值；固定mask交集，不填补空ROI。
v=spm_vol(char(labelFile));cog.check_grid(v,space.reference);d=spm_read_vols(v);
if any(~isfinite(d(:))|d(:)<0|d(:)~=fix(d(:))),error('cog:ROI','Expected nonnegative integer labels');end
labels=unique(d(d>0));if isempty(labels),error('cog:ROI','No positive labels');end
if ~isscalar(minVoxels)||minVoxels<1||minVoxels~=fix(minVoxels),error('cog:ROI','Invalid minimum coverage');end
selected=d(space.indices);r=zeros(size(y,1),numel(labels));counts=zeros(numel(labels),1);total=counts;
for k=1:numel(labels)
    use=selected==labels(k);counts(k)=nnz(use);total(k)=nnz(d==labels(k));
    if counts(k)<minVoxels,error('cog:ROICoverage','Label %g has only %d mask voxels',labels(k),counts(k));end
    r(:,k)=mean(y(:,use),2);
end
info=table(labels,counts,total,counts./total,'VariableNames',{'label','n_voxels','n_atlas_voxels','coverage_fraction'});
end
