function qc=glmsingle_export(results,plan,mask,reference,out,cfg)
%GLMSINGLE_EXPORT 保留原生结果，输出有明确事件顺序和单位的beta；不伪造T/SPM.mat。
types={'A','B','C','D'};rows=struct([]);pcnum=[];
maskHeader=struct('fname',fullfile(out,'analysis_mask.nii'),'dim',reference.dim, ...
    'mat',reference.mat,'dt',[2 0],'pinfo',[1;0;0],'descrip','GLMsingle explicit mask intersection');
spm_write_vol(maskHeader,double(mask));
units='input intensity units';if cfg.glmsingle.wantPercentBold,units='percent BOLD relative to absolute native meanvol';end
for k=1:numel(results)
    if isempty(results{k}),continue;end
    model=results{k};folder=fullfile(out,['TYPE' types{k}]);mkdir(folder);
    if numel(model.R2)~=nnz(mask)||any(~isfinite(model.R2(:)))
        error('psy:GLMsingleQC','Invalid native model R2');
    end
    mapHeader=maskHeader;mapHeader.dt=[16 0];mapHeader.fname=fullfile(folder,'R2.nii');
    full=NaN(reference.dim);full(mask)=model.R2(:);spm_write_vol(mapHeader,full);
    for field={'meanvol','HRFindex','noisepool','FRACvalue','pcvoxels'}
        if isfield(model,field{1})&&~isempty(model.(field{1}))
            values=model.(field{1});
            if numel(values)~=nnz(mask)||any(~isfinite(values(:))),error('psy:GLMsingleQC','Invalid native summary map');end
            mapHeader.fname=fullfile(folder,[field{1} '.nii']);full=NaN(reference.dim);full(mask)=values(:);spm_write_vol(mapHeader,full);
        end
    end
    if k==1
        values=model.modelmd{2};mapHeader.fname=fullfile(folder,'onoff_beta.nii');full=NaN(reference.dim);full(mask)=values(:);spm_write_vol(mapHeader,full);
    end
    if isfield(model,'pcregressors')
        for r=1:numel(model.pcregressors)
            values=model.pcregressors{r};if any(~isfinite(values),'all'),error('psy:GLMsingleQC','Nonfinite PC regressors');end
            names=cellstr(compose('candidate_PC_%02d',1:size(values,2)));
            writetable(array2table(values,'VariableNames',names),fullfile(folder,sprintf('run_%03d_candidate_PCs.tsv',r)),'FileType','text','Delimiter','\t');
        end
    end
    betaFile='';
    if k>=2
        beta=reshape(model.modelmd,nnz(mask),[]);
        if size(beta,2)~=plan.nEvents||any(~isfinite(beta),'all'),error('psy:GLMsingleQC','Missing/nonfinite event betas');end
        betaFile=fullfile(folder,'event_betas.nii');
        ni=nifti;ni.dat=file_array(betaFile,[reference.dim plan.nEvents],'FLOAT32-LE',352,1,0);
        ni.mat=reference.mat;ni.mat0=reference.mat;ni.descrip=['GLMsingle TYPE' types{k} '; axis 4=beta_index, not acquisition time'];create(ni);
        for t=1:plan.nEvents,frame=NaN(reference.dim,'single');frame(mask)=beta(:,t);ni.dat(:,:,:,t)=frame;end
        mapping=plan.mapping;mapping.beta_file=repmat(string(betaFile),height(mapping),1);
        writetable(mapping,fullfile(folder,'beta_mapping.tsv'),'FileType','text','Delimiter','\t');
        % 回读所有导出的beta，验证轴顺序、有效值与掩膜外NaN。
        v=spm_vol(betaFile);
        if numel(v)~=plan.nEvents,error('psy:GLMsingleQC','Wrong exported event count');end
        for t=1:numel(v)
            frame=spm_read_vols(v(t));
            if ~isequal(single(frame(mask)),single(beta(:,t)))||any(~isnan(frame(~mask)))
                error('psy:GLMsingleQC','Exported beta/mask mismatch');
            end
        end
    end
    if isfield(model,'pcnum'),pcnum=model.pcnum;end
    if isfield(model,'HRFindex')&&(any(~isfinite(model.HRFindex(:)))||any(model.HRFindex(:)<1))
        error('psy:GLMsingleQC','Invalid selected HRF index');
    end
    if isfield(model,'FRACvalue')&&any(~ismembertol(double(model.FRACvalue(:)),double(cfg.glmsingle.fracs),1e-5))
        error('psy:GLMsingleQC','Selected ridge fraction outside candidates');
    end
    row=struct('model',types{k},'nBetas',plan.nEvents*double(k>=2),'beta_file',betaFile, ...
        'r2_file',fullfile(folder,'R2.nii'),'R2_min',min(model.R2(:)),'R2_max',max(model.R2(:)));
    if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
end
expected={'A','B'};if cfg.glmsingle.wantDenoise,expected{end+1}='C';end;if cfg.glmsingle.wantRidge,expected{end+1}='D';end
if ~isequal({rows.model},expected),error('psy:GLMsingleQC','Requested native model types not produced');end
if cfg.glmsingle.wantDenoise&&(~isscalar(pcnum)||~isfinite(pcnum)||pcnum<0||pcnum>cfg.glmsingle.maxPCs)
    error('psy:GLMsingleQC','Invalid cross-validated PC count');
end
writetable(struct2table(rows),fullfile(out,'model_outputs.tsv'),'FileType','text','Delimiter','\t');
qc=struct('modelTypes',{expected},'units',units,'pcnum',pcnum,'nEvents',plan.nEvents,'maskVoxels',nnz(mask), ...
    'checkScope','all model R2 values and event beta exports inside explicit mask; exact native event/identity mapping', ...
    'scientificValidation','engineering execution only; regularized betas are not SPM T tests or classical contrast estimates');
f=fopen(fullfile(out,'glmsingle_qc.json'),'w');cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(qc,PrettyPrint=true));clear cleanup;
if cfg.qc.plot
    fig=figure('Visible','off','Color','w','Position',[100 100 1000 400]);closeFigure=onCleanup(@()close(fig));
    subplot(1,2,1);imagesc(plan.mapping.beta_index',1,plan.mapping.run_index');xlabel('Chronological beta index');yticks([]);title('Run identity for each beta');
    subplot(1,2,2);histogram(results{2}.R2,30);xlabel('R2 (%)');ylabel('Voxels');title('TYPE B model fit; not significance');
    exportgraphics(fig,fullfile(out,'glmsingle_diagnostics.png'),'Resolution',120);clear closeFigure;
end
end
