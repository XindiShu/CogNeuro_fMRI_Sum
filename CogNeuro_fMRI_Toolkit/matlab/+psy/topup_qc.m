function qc=topup_qc(outputDir,negativeVolumes,positiveVolumes)
%TOPUP_QC 检查真实 TOPUP 场和 SE-EPI 前后差异；数值改善不等于科学质量合格。
before=single(niftiread(fullfile(outputDir,'se_pair.nii.gz')));
after=single(niftiread(fullfile(outputDir,'se_unwarped.nii.gz')));
field=single(niftiread(fullfile(outputDir,'field_hz.nii.gz')));
% 先核对交给 BOLD 模块的 SE 参考；缺失或错误的均值不能标记 TOPUP 完成。
referenceFile=fullfile(outputDir,'se_unwarped_mean.nii.gz');
if ~isfile(referenceFile)
    error('psy:TopupQCReference','缺少校正后 SE 时间均值: %s',referenceFile);
end
referenceHeader=niftiinfo(referenceFile);
reference=single(niftiread(referenceHeader));
count=negativeVolumes+positiveVolumes;
if size(before,4)~=count || ~isequal(size(before),size(after)) || ...
        ~isequal(size(before,1:3),size(field,1:3)) || ...
        ~isequal(size(after,1:3),size(reference,1:3)) || size(reference,4)~=1
    error('psy:TopupQCGeometry','TOPUP 输出尺寸或帧数与输入不一致');
end
if any(~isfinite(before(:))) || any(~isfinite(after(:))) || ...
        any(~isfinite(field(:))) || any(~isfinite(reference(:)))
    error('psy:TopupQCValues','TOPUP 影像包含非有限数值');
end
if ~strcmp(referenceHeader.Datatype,'single')
    error('psy:TopupQCType','SE 时间均值必须为 float32，不能使用整数影像取整');
end
% 校验而非重做估场：应对所有帧等权平均，不能取首帧或将两组均值再等权平均。
expectedReference=mean(after,4);
referenceError=double(max(abs(reference(:)-expectedReference(:))));
referenceTolerance=max(32,count)*double(eps('single'))* ...
    max(1,double(max(abs(expectedReference(:)))));
if referenceError>referenceTolerance
    error('psy:TopupQCReference','SE 参考不是校正后全部帧的时间均值，最大误差 %.6g',referenceError);
end
negBefore=mean(before(:,:,:,1:negativeVolumes),4);
posBefore=mean(before(:,:,:,negativeVolumes+1:end),4);
negAfter=mean(after(:,:,:,1:negativeVolumes),4);
posAfter=mean(after(:,:,:,negativeVolumes+1:end),4);
mask=(negBefore+posBefore)>0.2*max(negBefore(:)+posBefore(:));
if nnz(mask)<100, error('psy:TopupQCMask','正信号区域过小，无法计算配对差异'); end
d0=abs(negBefore-posBefore); d1=abs(negAfter-posAfter);
qc=struct('status','engineering_qc_not_visual_approval','imageSize',size(before,1:3), ...
    'negativeVolumes',negativeVolumes,'positiveVolumes',positiveVolumes, ...
    'fieldMinHz',double(min(field(:))),'fieldMaxHz',double(max(field(:))), ...
    'seReferenceFile',referenceFile,'seReferenceDatatype',referenceHeader.Datatype, ...
    'seReferenceMaxAbsError',referenceError,'seReferenceTolerance',referenceTolerance, ...
    'maskVoxels',nnz(mask),'meanOppositeDifferenceBefore',double(mean(d0(mask))), ...
    'meanOppositeDifferenceAfter',double(mean(d1(mask))));
fid=fopen(fullfile(outputDir,'topup_qc.json'),'w');
fprintf(fid,'%s',jsonencode(qc,PrettyPrint=true)); fclose(fid);
z=round(size(before,3)/2);
f=figure('Visible','off','Color','w','Position',[50 50 1200 700]);
tiles=tiledlayout(f,2,3,'TileSpacing','compact'); %#ok<NASGU>
images={negBefore(:,:,z),posBefore(:,:,z),field(:,:,z),negAfter(:,:,z),posAfter(:,:,z),d0(:,:,z)-d1(:,:,z)};
labels={'SE 负向：校正前','SE 正向：校正前','场图 Hz','SE 负向：校正后','SE 正向：校正后','反向差异减少量'};
for k=1:6
    nexttile; imagesc(rot90(images{k})); axis image off; colormap gray; colorbar; title(labels{k});
end
exportgraphics(f,fullfile(outputDir,'topup_qc.png'),'Resolution',120); close(f);
end
