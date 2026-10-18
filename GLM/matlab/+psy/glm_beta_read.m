function [values,space]=glm_beta_read(catalog,maxGiB)
%GLM_BETA_READ 统一[估计单元×共同有效体素]single矩阵；不平均、不重采样、不统一单位。
if nargin<2,maxGiB=1;end
if ischar(catalog)||isstring(catalog),catalog=psy.glm_read_table(catalog);catalog.volume_index=str2double(catalog.volume_index);end
required={'estimate_id','image_path','volume_index','mask_path'};
if isempty(catalog)||~all(ismember(required,catalog.Properties.VariableNames))||numel(unique(catalog.estimate_id))~=height(catalog)
    error('psy:GLMBetaRead','Nonempty unique catalog required');
end
if ~isnumeric(maxGiB)||~isscalar(maxGiB)||~isfinite(maxGiB)||maxGiB<=0,error('psy:GLMBetaRead','Positive memory budget required');end
if any(strlength(string(catalog.image_path))==0|strlength(string(catalog.mask_path))==0)|| ...
        ~all(isfile(string(catalog.image_path)))||~all(isfile(string(catalog.mask_path)))
    error('psy:GLMBetaRead','All image/mask files must exist');
end
ref=[];mask=[];headers=cell(height(catalog),1);maskFiles=unique(string(catalog.mask_path),'stable');
for k=1:numel(maskFiles)
    v=spm_vol(char(maskFiles(k)));if ~isscalar(v),error('psy:GLMGrid','Analysis mask must be one 3-D volume');end
    if isempty(ref),ref=v;mask=true(ref.dim);end
    checkGrid(v,ref);m=spm_read_vols(v);if any(~isfinite(m(:))|m(:)<0),error('psy:GLMBetaRead','Invalid analysis mask');end
    mask=mask&m>0;
end
if ~any(mask(:)),error('psy:GLMBetaRead','Empty mask intersection');end
imageFiles=unique(string(catalog.image_path),'stable');volumes=cell(numel(imageFiles),1);
for k=1:numel(imageFiles),volumes{k}=spm_vol(char(imageFiles(k)));end
[~,imageIndex]=ismember(string(catalog.image_path),imageFiles);
for k=1:height(catalog)
    v=volumes{imageIndex(k)};frame=catalog.volume_index(k);
    if ~isnumeric(frame)||~isscalar(frame)||~isfinite(frame)||frame<1||fix(frame)~=frame||frame>numel(v),error('psy:GLMBetaRead','Invalid beta volume index');end
    checkGrid(v(frame),ref);headers{k}=v(frame);
end
gib=height(catalog)*nnz(mask)*4/2^30;if gib>maxGiB,error('psy:GLMBetaRead','Beta matrix exceeds maxMatrixGiB');end
values=zeros(height(catalog),nnz(mask),'single');
for k=1:height(catalog)
    data=spm_read_vols(headers{k});if any(~isfinite(data(mask))),error('psy:GLMBetaRead','Nonfinite beta inside common mask; no data-dependent voxel deletion');end
    values(k,:)=single(data(mask))';
end
indices=find(mask);[i,j,k]=ind2sub(ref.dim,indices);xyz=ref.mat*[i';j';k';ones(1,numel(i))];
space=struct('mask',mask,'reference',ref,'linearIndices',indices,'voxelIJK',[i j k],'worldXYZ',xyz(1:3,:)', ...
    'matrixGiB',gib,'rowMeaning','catalog estimate_id order','columnMeaning','fixed intersection mask in linear voxel order');
end
function checkGrid(v,ref)
if ~isscalar(v)||~isscalar(ref)||~isequal(v.dim,ref.dim)||max(abs(v.mat-ref.mat),[],'all')>1e-5,error('psy:GLMGrid','All beta images and masks must share geometry; no auto resampling');end
end
