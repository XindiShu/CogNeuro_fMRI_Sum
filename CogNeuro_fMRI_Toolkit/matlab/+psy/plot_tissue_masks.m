function plot_tissue_masks(meanImage,wm,csf,out)
%PLOT_TISSUE_MASKS 供人工检查；切片是 native voxel z，不冒充标准空间坐标。
positive=sort(meanImage(meanImage>0)); upper=1;
if ~isempty(positive), upper=positive(max(1,ceil(.99*numel(positive)))); end
f=figure('Visible','off','Color','w','Position',[100 100 1200 550]); cleanup=onCleanup(@()close(f)); %#ok<NASGU>
tiledlayout(f,2,4,'TileSpacing','compact');
for k=1:2
    mask=wm; label='WM'; if k==2, mask=csf; label='CSF'; end
    counts=squeeze(sum(sum(mask,1),2)); occupied=find(counts>0);
    zs=occupied(max(1,round(linspace(1,numel(occupied),4))));
    for j=1:4
        z=zs(j); ax=nexttile; imagesc(rot90(meanImage(:,:,z)),[0 upper]); colormap(ax,gray); axis image off; hold on;
        contour(rot90(mask(:,:,z)),[.5 .5],'r','LineWidth',.7);
        title(sprintf('%s; native voxel z=%d',label,z));
    end
end
sgtitle('Tissue masks: inspect alignment, coverage and partial volume before regression');
exportgraphics(f,fullfile(out,'tissue_masks_qc.png'),'Resolution',120);
end
