function [summary,files]=glm_roi_extract(values,catalog,space,manifest,opt)
%GLM_ROI_EXTRACT 固定共同体素集合上的等权ROI均值；不根据统计结果选ROI。
manifest=psy.glm_absolute_path(manifest);t=psy.glm_read_table(manifest,{'roi','mask_file','label'});
if numel(unique(t.roi))~=height(t),error('psy:GLMROI','ROI names must be unique');end
files=string(manifest);summary=table;
for k=1:height(t)
    file=psy.glm_absolute_path(t.mask_file(k),fileparts(manifest));v=spm_vol(file);ref=space.reference;
    if ~isscalar(v)||~isequal(v.dim,ref.dim)||max(abs(v.mat-ref.mat),[],'all')>1e-5,error('psy:GLMROI','ROI must match beta/effect geometry; resample labels explicitly before use');end
    data=spm_read_vols(v);label=str2double(t.label(k));
    if any(~isfinite(data(:))|data(:)<0)||~isfinite(label)||label<0||fix(label)~=label,error('psy:GLMROI','Finite nonnegative mask and integer label required; 0 means all positive voxels');end
    roi=data>0;if label>0,roi=data==label;end
    selected=roi(space.linearIndices);count=nnz(selected);status="ok";meanValue=NaN(height(catalog),1);standardDeviation=meanValue;
    if count<opt.minVoxels
        status="insufficient_voxels";
        if strcmp(opt.emptyPolicy,'error'),error('psy:GLMROI','ROI %s has too few common voxels',t.roi(k));end
    else
        meanValue=mean(double(values(:,selected)),2);standardDeviation=std(double(values(:,selected)),0,2);
    end
    row=table(catalog.estimate_id,repmat(t.roi(k),height(catalog),1),meanValue,standardDeviation,repmat(count,height(catalog),1), ...
        repmat(nnz(roi),height(catalog),1),repmat(status,height(catalog),1), ...
        'VariableNames',{'estimate_id','roi','mean','spatial_std','n_common_voxels','n_roi_voxels','status'});
    if ismember('units',catalog.Properties.VariableNames),row.units=catalog.units;end
    if isempty(summary),summary=row;else,summary=[summary;row];end %#ok<AGROW>
    files(end+1)=string(file); %#ok<AGROW>
end
end
