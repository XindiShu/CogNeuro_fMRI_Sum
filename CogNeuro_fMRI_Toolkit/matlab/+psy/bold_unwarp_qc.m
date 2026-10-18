function qc=bold_unwarp_qc(spec,plan,out,cfg)
%BOLD_UNWARP_QC 配准与输出工程检查；不能替代全脑多层人工 QC。
original=single(niftiread(spec.sbref));
registered=single(niftiread(fullfile(out,'se_registered.nii.gz')));
corrected=single(niftiread(fullfile(out,'sbref_unwarped.nii.gz')));
field=single(niftiread(fullfile(out,'field_sbref_rad.nii.gz')));
for x={original,registered,corrected,field}
    if any(~isfinite(x{1}(:))), error('psy:BoldUnwarpQCValues','3D QC 影像含非有限数值'); end
end
if ~isequal(size(original),size(registered),size(corrected),size(field))
    error('psy:BoldUnwarpQCGeometry','配准/校正图像网格不一致');
end
boldInfo=niftiinfo(fullfile(out,'bold_unwarped.nii.gz'));
d=double(boldInfo.ImageSize);d(end+1:4)=1;
if ~isequal(d(1:3),plan.boldSize)||d(4)~=plan.boldFrames
    error('psy:BoldUnwarpQCGeometry','校正后 BOLD 尺寸或帧数变化');
end
if ~strcmp(boldInfo.Datatype,'single')
    error('psy:BoldUnwarpQCType','4D BOLD 校正结果必须是 float32，避免插值取整');
end
mask=original>0.15*max(original(:)) & registered>0.15*max(registered(:));
if nnz(mask)<100, error('psy:BoldUnwarpQCMask','重叠信号区域太小，配准结果不可用'); end
c=corrcoef(double(original(mask)),double(registered(mask)));
qc=struct('status','engineering_qc_review_required','boldFrames',d(4), ...
    'boldSize',d(1:3),'registrationOverlapVoxels',nnz(mask), ...
    'registeredSeToSbrefCorrelation',c(1,2), ...
    'fieldMinRadPerSecond',double(min(field(:))), ...
    'fieldMaxRadPerSecond',double(max(field(:))));
if cfg.jacobianModulation
    jac=single(niftiread(fullfile(out,'jacobian_raw.nii.gz')));
    if any(~isfinite(jac(:))), error('psy:BoldUnwarpQCValues','Jacobian 含非有限数值'); end
    qc.jacobianMin=double(min(jac(:)));qc.jacobianMax=double(max(jac(:)));
    qc.jacobianNegativeTotalVoxels=nnz(jac(:)<0);
    qc.jacobianNegativeSignalVoxels=nnz(jac(mask)<0);
    qc.jacobianZeroSignalVoxels=nnz(jac(mask)==0);
    qc.jacobianNonPositiveSignalFraction=nnz(jac(mask)<=0)/nnz(mask);
    if qc.jacobianNegativeSignalVoxels>0 || qc.jacobianNonPositiveSignalFraction>0.001
        error('psy:BoldUnwarpJacobian','信号区域 Jacobian 有负值或非正比例超过 0.1%%，需人工检查');
    end
end
fid=fopen(fullfile(out,'bold_unwarp_qc.json'),'w');fprintf(fid,'%s',jsonencode(qc,PrettyPrint=true));fclose(fid);
z=round(size(original,3)/2);
f=figure('Visible','off','Color','w','Position',[50 50 1250 680]);
tiles=tiledlayout(f,2,3,'TileSpacing','compact'); %#ok<NASGU>
images={original(:,:,z),registered(:,:,z),field(:,:,z),corrected(:,:,z), ...
    original(:,:,z)-registered(:,:,z),corrected(:,:,z)-original(:,:,z)};
labels={'原始 BOLD SBRef','配准的模拟畸变 SE','SBRef 空间场 rad/s', ...
    '畸变校正后 SBRef','SBRef-SE 差异','校正引起的 SBRef 变化'};
for k=1:6
    nexttile;imagesc(rot90(images{k}));axis image off;colormap gray;colorbar;title(labels{k});
end
exportgraphics(f,fullfile(out,'bold_unwarp_qc.png'),'Resolution',120);close(f);
end
