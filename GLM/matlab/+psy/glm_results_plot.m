function glm_results_plot(ref,stat,selected,backgroundFile,file,titleText,modelMask,statisticKind)
%GLM_RESULTS_PLOT 三正交切面；背景仅按affine采样，不配准、不改源图。
if nargin<8,statisticKind='T';end
background=double(modelMask);kind='model-mask grid';
if ~isempty(backgroundFile)
    v=spm_vol(backgroundFile);if ~isscalar(v),error('psy:GLMBackground','Background must be 3-D');end
    [i,j,k]=ndgrid(1:ref.dim(1),1:ref.dim(2),1:ref.dim(3));
    xyz=v.mat\(ref.mat*[i(:)';j(:)';k(:)';ones(1,numel(i))]);
    background=reshape(spm_sample_vol(v,xyz(1,:),xyz(2,:),xyz(3,:),1),ref.dim);kind='affine-sampled background';
end
background(~isfinite(background))=0;
if any(selected(:))
    score=abs(stat);score(~selected)=-Inf;[~,index]=max(score(:));[i,j,k]=ind2sub(ref.dim,index);center=[i j k];
else
    center=round((ref.dim+1)/2);
end
fig=figure('Visible','off','Color','w','Position',[80 80 1100 420]);closeFigure=onCleanup(@()close(fig));
lims=[min(background(:)) max(background(:))];if lims(2)<=lims(1),lims=lims(1)+[0 1];end
maximum=max(abs(stat(selected)));if isempty(maximum)||maximum==0,maximum=1;end
cmap=[linspace(0,1,128)' linspace(0,1,128)' ones(128,1);ones(128,1) linspace(1,0,128)' linspace(1,0,128)'];
minimum=-maximum;if strcmp(statisticKind,'F'),minimum=0;cmap=cmap(129:end,:);end
for plane=1:3
    switch plane
        case 1,b=squeeze(background(center(1),:,:))';s=squeeze(stat(center(1),:,:))';a=squeeze(selected(center(1),:,:))';label='I plane';
        case 2,b=squeeze(background(:,center(2),:))';s=squeeze(stat(:,center(2),:))';a=squeeze(selected(:,center(2),:))';label='J plane';
        case 3,b=squeeze(background(:,:,center(3)))';s=squeeze(stat(:,:,center(3)))';a=squeeze(selected(:,:,center(3)))';label='K plane';
    end
    ax=subplot(1,3,plane);rgb=repmat(min(1,max(0,(b-lims(1))/(lims(2)-lims(1)))),1,1,3);image(ax,rgb);axis(ax,'image');axis(ax,'off');set(ax,'YDir','normal');hold(ax,'on');
    colorIndex=1+round((size(cmap,1)-1)*min(1,max(0,(s-minimum)/(maximum-minimum))));colorIndex(~isfinite(colorIndex))=1;
    colors=reshape(cmap(colorIndex(:),:),[size(s) 3]);h=image(ax,colors);set(h,'AlphaData',.8*double(a));title(ax,sprintf('%s = %d',label,center(plane)));
    colormap(ax,cmap);clim(ax,[minimum maximum]);if plane==3,bar=colorbar(ax);bar.Label.String=statisticKind;end
end
note='No voxels survive';if any(selected(:)),note=sprintf('%d displayed voxels; peak statistic %.3g',nnz(selected),stat(index));end
sgtitle(sprintf('%s\n%s; %s',titleText,note,kind),'Interpreter','none');exportgraphics(fig,file,'Resolution',140);clear closeFigure;
end
