function [x,meta,space]=load_betas(catalogFile,maxGiB)
%LOAD_BETAS 读取明确估计单元目录；兼容现有GLM统一beta目录，不重估模型。
required={'estimate_id','subject','session','run','condition','image_path','volume_index','mask_path'};
meta=cog.read_tsv(catalogFile,required);base=fileparts(catalogFile);
if isempty(meta)||numel(unique(meta.estimate_id))~=height(meta),error('cog:Betas','Nonempty unique estimate IDs required');end
ref=[];mask=[];
for k=1:height(meta)
    meta.image_path(k)=string(cog.resolve_path(meta.image_path(k),base));meta.mask_path(k)=string(cog.resolve_path(meta.mask_path(k),base));
end
maskFiles=unique(meta.mask_path,'stable');
for k=1:numel(maskFiles)
    v=spm_vol(char(maskFiles(k)));if ~isscalar(v),error('cog:Mask','3D mask required');end
    if isempty(ref),ref=v;mask=true(ref.dim);end
    cog.check_grid(v,ref);d=spm_read_vols(v);if any(~isfinite(d(:))|d(:)<0),error('cog:Mask','Invalid beta mask');end;mask=mask&d>0;
end
if ~any(mask(:)),error('cog:Mask','Empty beta mask intersection');end
if ~isscalar(maxGiB)||~isfinite(maxGiB)||maxGiB<=0||height(meta)*nnz(mask)*8/2^30>maxGiB,error('cog:Memory','Invalid/exceeded beta matrix budget');end
x=zeros(height(meta),nnz(mask));
for k=1:height(meta)
    v=spm_vol(char(meta.image_path(k)));i=str2double(meta.volume_index(k));
    if ~isfinite(i)||i~=fix(i)||i<1||i>numel(v),error('cog:Betas','Invalid image volume index');end
    cog.check_grid(v(i),ref);d=spm_read_vols(v(i));a=d(mask);if any(~isfinite(a)),error('cog:Nonfinite','Nonfinite beta in fixed common mask');end;x(k,:)=a';
end
indices=find(mask);[i,j,k]=ind2sub(ref.dim,indices);space=struct('reference',ref,'mask',mask,'indices',indices,'ijk',[i j k]);
end
