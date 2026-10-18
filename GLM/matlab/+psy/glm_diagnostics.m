function diagnostics=glm_diagnostics(out,cfg,estimated)
%GLM_DIAGNOSTICS 高通设计诊断与确定性采样残差ACF；不作显著性判定。
p=load(fullfile(out,'SPM.mat'),'SPM');SPM=p.SPM;
x=SPM.xX.X;filtered=spm_filter(SPM.xX.K,x);task=find(contains(string(SPM.xX.name),'*bf('));
taskEnergy=sum(x(:,task).^2,1);retained=sum(filtered(:,task).^2,1)./taskEnergy;
retained(taskEnergy==0)=NaN;
sampleColumns=unique(round(linspace(1,size(x,2),min(128,size(x,2)))));
centered=filtered(:,sampleColumns)-mean(filtered(:,sampleColumns),1);
columnNorm=sqrt(sum(centered.^2,1));scaled=centered./max(columnNorm,eps);
correlation=scaled'*scaled;
undefined=columnNorm<=max(size(centered))*eps(max(columnNorm));
correlation(undefined,:)=NaN;correlation(:,undefined)=NaN;
singular=svd(filtered,'econ');
diagnostics=struct('scope','session-partitioned first-level design; sampled residuals only; not scientific approval', ...
    'nFrames',size(x,1),'nColumns',size(x,2),'filteredDesignRank',rank(filtered), ...
    'highpassBasisRank',psy.glm_highpass_rank(SPM.xX.K),'taskColumnIndices',task, ...
    'taskColumnNames',{SPM.xX.name(task)},'taskEnergyFractionAfterHighpass',retained, ...
    'filteredDesignSingularValues',singular,'correlationColumnIndices',sampleColumns, ...
    'undefinedCorrelationColumnIndices',sampleColumns(undefined), ...
    'residualEstimated',logical(estimated),'nResidualVoxels',0, ...
    'residualScope','not estimated');
if estimated
    mv=spm_vol(fullfile(out,'mask.nii'));mask=spm_read_vols(mv)>0;ids=find(mask);
    chosen=ids(unique(round(linspace(1,numel(ids),min(cfg.qc.maxResidualVoxels,numel(ids))))));
    [i,j,k]=ind2sub(mv.dim,chosen);xyz=[i';j';k'];
    vy=SPM.xY.VY;vb=SPM.Vbeta;
    for b=1:numel(vb)
        if ~java.io.File(vb(b).fname).isAbsolute(),vb(b).fname=fullfile(out,vb(b).fname);end
    end
    y=spm_get_data(vy,xyz);beta=spm_get_data(vb,xyz);
    raw=y-x*beta;
    whitened=spm_filter(SPM.xX.K,SPM.xX.W*raw);
    if any(~isfinite([raw(:);whitened(:)])),error('psy:GLMDiagnostics','Nonfinite sampled residuals');end
    maxLag=min(10,min(arrayfun(@(s)numel(s.row),SPM.Sess))-2);
    acfBefore=[];acfAfter=[];perRun=struct([]);
    for session=1:numel(SPM.Sess)
        rows=SPM.Sess(session).row;
        before=acf(raw(rows,:),maxLag);after=acf(whitened(rows,:),maxLag);
        perRun(session).sessionIndex=session;
        perRun(session).rawMedian=median(before,2,'omitnan');
        perRun(session).filteredWhitenedMedian=median(after,2,'omitnan');
        acfBefore=[acfBefore before];acfAfter=[acfAfter after]; %#ok<AGROW>
    end
    diagnostics.residualAcfPerRun=perRun;
    diagnostics.nResidualVoxels=numel(chosen);
    diagnostics.residualVoxelIndices=chosen;
    diagnostics.residualScope='deterministic samples; ACF computed within each run, never across boundaries; median across run/voxel samples';
    diagnostics.rawResidualAcfMedian=median(acfBefore,2,'omitnan');
    diagnostics.filteredWhitenedResidualAcfMedian=median(acfAfter,2,'omitnan');
    diagnostics.degenerateResidualVoxelCount=sum(all(isnan(acfAfter),1));
    diagnostics.spmEffectiveResidualDF=SPM.xX.erdf;
end
save(fullfile(out,'model_diagnostics.mat'),'diagnostics','correlation');
f=fopen(fullfile(out,'model_diagnostics.json'),'w');
if f<0,error('psy:GLMDiagnostics','Cannot write diagnostic JSON');end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(diagnostics,PrettyPrint=true));clear cleanup;
if cfg.qc.plot
    figureHandle=figure('Visible','off','Color','w','Position',[100 100 1100 750]);
    closeFigure=onCleanup(@()close(figureHandle));
    subplot(2,2,1);imagesc(filtered./max(sqrt(sum(filtered.^2,1)),eps));title('High-pass design (column-normalized)');xlabel('Column');ylabel('Volume');
    subplot(2,2,2);im=imagesc(correlation,[-1 1]);set(im,'AlphaData',isfinite(correlation));set(gca,'Color',[.8 .8 .8]);
    colorbar;title('Sampled column correlation (gray = undefined)');xlabel('Sampled column');ylabel('Sampled column');
    subplot(2,2,3);bar(retained);ylim([0 1.05]);title('Task energy after high-pass / original');xlabel('Task/basis column');ylabel('Squared norm ratio');
    subplot(2,2,4);
    if estimated
        plot(1:maxLag,diagnostics.rawResidualAcfMedian,'o-',1:maxLag,diagnostics.filteredWhitenedResidualAcfMedian,'o-');
        legend('Raw residual','Filtered + whitened');xlabel('Lag (volumes)');ylabel('Median lag correlation');title(sprintf('Residual samples: %d voxels',numel(chosen)));
    else
        text(.1,.5,'Residuals not estimated');axis off;
    end
    exportgraphics(figureHandle,fullfile(out,'model_diagnostics.png'),'Resolution',120);clear closeFigure;
end
end

function result=acf(values,maxLag)
result=NaN(maxLag,size(values,2));
for lag=1:maxLag
    first=values(1:end-lag,:);second=values(1+lag:end,:);
    first=first-mean(first,1);second=second-mean(second,1);
    denominator=sqrt(sum(first.^2,1).*sum(second.^2,1));valid=denominator>eps;
    result(lag,valid)=sum(first(:,valid).*second(:,valid),1)./denominator(valid);
end
end
