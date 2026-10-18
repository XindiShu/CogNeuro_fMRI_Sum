function [y,space]=load_bold(bold,maskFile,tr,maxGiB)
%LOAD_BOLD 同网格3D掩膜内[时间×体素]double；逐帧读，不修改输入。
if ~endsWith(lower(string(bold)),'.nii'),error('cog:Format','Stage an uncompressed NIfTI working copy');end
v=spm_vol(char(bold));m=spm_vol(char(maskFile));
if numel(v)<4||~isscalar(m),error('cog:Shape','Need >=4 BOLD frames and a 3D mask');end
for k=1:numel(v),cog.check_grid(v(k),m);end
mask=spm_read_vols(m);if any(~isfinite(mask(:))|mask(:)<0),error('cog:Mask','Invalid mask');end
mask=mask>0;if ~any(mask(:)),error('cog:Mask','Empty mask');end
if ~isscalar(tr)||~isfinite(tr)||tr<=0||~isscalar(maxGiB)||~isfinite(maxGiB)||maxGiB<=0,error('cog:Options','Invalid TR/budget');end
ni=nifti(char(bold));if ~isfield(ni.timing,'tspace')||abs(ni.timing.tspace-tr)>max(1e-5,tr*1e-5),error('cog:TR','Declared TR disagrees with NIfTI seconds');end
gib=numel(v)*nnz(mask)*8/2^30;if gib>maxGiB,error('cog:Memory','Matrix needs %.3f GiB',gib);end
y=zeros(numel(v),nnz(mask));
for k=1:numel(v)
    d=spm_read_vols(v(k));a=d(mask);if any(~isfinite(a)),error('cog:Nonfinite','Nonfinite inside fixed mask at frame %d',k);end
    y(k,:)=a';
end
indices=find(mask);[i,j,k]=ind2sub(m.dim,indices);xyz=m.mat*[i';j';k';ones(1,numel(i))];
space=struct('reference',m,'mask',mask,'indices',indices,'ijk',[i j k],'xyz',xyz(1:3,:)','trSeconds',tr,'nFrames',numel(v),'matrixGiB',gib);
end
