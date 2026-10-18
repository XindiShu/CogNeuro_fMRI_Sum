function summary=denoise_run(run,cfg,out)
%DENOISE_RUN 分片读写 4D NIfTI，所有体素处理；不删帧，不加回均值。
% 任务数据仅允许 purpose=engineering 验证，输出不供任务 GLM/PPI。
if ~ismember(run.purpose,{'rest','engineering'}), error('psy:DenoisePurpose','Use rest or engineering; task joint GLM not implemented'); end
if ~strcmp(run.temporal_state,'unfiltered_unregressed'), error('psy:DenoiseState','Require explicit unfiltered_unregressed input declaration'); end
if isfolder(out), error('psy:DenoiseExists','Choose a new output directory'); end
if ~endsWith(run.bold,'.nii'), error('psy:DenoiseFormat','Use uncompressed .nii working copy'); end
v=spm_vol(run.bold); n=numel(v); if n<3, error('psy:ImageShape','Need 4-D series'); end
for j=2:n
    if ~isequal(v(j).dim,v(1).dim)||max(abs(v(j).mat-v(1).mat),[],'all')>1e-5
        error('psy:DenoiseGrid','Frames must share a resliced grid');
    end
end
h=niftiinfo(run.bold); tr=h.PixelDimensions(4);
switch lower(h.TimeUnits)
    case 'second'
    case 'millisecond', tr=tr/1000;
    case 'microsecond', tr=tr/1e6;
    otherwise, error('psy:TimeUnits','Unknown time units');
end
design=psy.confound_design(run.confounds,cfg.design);
if design.nFrames~=n, error('psy:DenoiseLength','BOLD/confounds row mismatch'); end
model=psy.temporal_basis(design.matrix,tr,cfg);
mkdir(out); output=fullfile(out,'residual_bold.nii');
% 用全长 4D file_array 一次创建，保留 affine/TR，仅输出 float32 残差。
ni=nifti; ni.dat=file_array(output,[v(1).dim n],'FLOAT32-LE',352,1,0);
ni.mat=v(1).mat; ni.mat0=v(1).mat; ni.mat_intent='Aligned'; ni.mat0_intent='Aligned';
ni.timing=struct('toffset',0,'tspace',tr); ni.descrip='Joint nuisance+DCT residual; no mean restoration'; create(ni);
peakProjection=0; sumBefore=0; sumAfter=0;
for z=1:v(1).dim(3)
    y=zeros(n,prod(v(1).dim(1:2)));
    for j=1:n
        slice=spm_slice_vol(v(j),spm_matrix([0 0 z]),v(j).dim(1:2),0);
        y(j,:)=slice(:)';
    end
    if any(~isfinite(y),'all'), error('psy:Nonfinite','Nonfinite BOLD at slice %d',z); end
    residual=y-model.Q*(model.Q'*y);
    peakProjection=max(peakProjection,max(abs(model.Q'*residual),[],'all'));
    sumBefore=sumBefore+sum((y-mean(y,1)).^2,'all'); sumAfter=sumAfter+sum(residual.^2,'all');
    ni.dat(:,:,z,:)=reshape(residual',[v(1).dim(1:2) 1 n]);
end
summary=rmfield(model,'Q'); summary.purpose=run.purpose;
summary.status='temporally_projected_spatial_limitations_unchanged';
summary.maxAbsProjectionBeforeFloat32=peakProjection;
summary.residualToCenteredEnergyRatio=sumAfter/max(sumBefore,eps);
summary.meanRestored=false; summary.framesDeleted=0;
summary.note='All voxels, no anatomical masking. Residual dimensions are not inferential degrees of freedom. Task engineering output is not a task GLM input.';
f=fopen(fullfile(out,'summary.json'),'w'); c=onCleanup(@()fclose(f)); fprintf(f,'%s',jsonencode(summary,PrettyPrint=true)); clear c;
save(fullfile(out,'COMPLETE.mat'),'summary','model','design','run','cfg');
end
