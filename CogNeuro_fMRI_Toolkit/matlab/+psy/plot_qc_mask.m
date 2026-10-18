function plot_qc_mask(meanFile,qcDir)
%PLOT_QC_MASK Inspect the fixed signal mask and tSNR in native voxel slices.
ref=spm_vol(meanFile); m=spm_read_vols(ref);
mask=spm_read_vols(spm_vol(fullfile(qcDir,'qc_mask.nii')));
tsnr=spm_read_vols(spm_vol(fullfile(qcDir,'tsnr.nii')));
positive=sort(m(m>0)); upper=positive(max(1,ceil(0.99*numel(positive))));
finiteTSNR=sort(tsnr(isfinite(tsnr)&tsnr>0));
if isempty(finiteTSNR), tsnrUpper=1; else, tsnrUpper=finiteTSNR(max(1,ceil(0.95*numel(finiteTSNR)))); end
f=figure('Visible','off','Color','w','Position',[100 100 1200 600]); cleanup=onCleanup(@()close(f));
tiledlayout(f,2,4,'TileSpacing','compact');
slices=max(1,min(ref.dim(3),round(linspace(ref.dim(3)*0.2,ref.dim(3)*0.8,4))));
for j=1:4
    z=slices(j); ax=nexttile(j); imagesc(rot90(m(:,:,z)),[0 upper]); colormap(ax,gray); axis image off; hold on;
    contour(rot90(mask(:,:,z)),[0.5 0.5],'r','LineWidth',0.6); title(sprintf('Signal mask, voxel z=%d',z));
    ax=nexttile(j+4); imagesc(rot90(tsnr(:,:,z)),[0 tsnrUpper]); colormap(ax,parula); axis image off; colorbar; title('tSNR, no detrending');
end
sgtitle('Native voxel slices; automatic signal mask is not an anatomical brain mask');
exportgraphics(f,fullfile(qcDir,'mask_tsnr_qc.png'),'Resolution',120);
end
