function qc = verify_spatial(out)
%VERIFY_SPATIAL Numeric checks and registered mean EPI/tissue overlays.
loaded=load(fullfile(out,'input_info.mat')); cfg=loaded.cfg;
options=psy.smooth_options(cfg);reference=[];
complete=fullfile(out,'SMOOTHING_COMPLETE.mat');
if isfile(complete)
    saved=load(complete);smoothed=saved.record.output;
    if options.implicitMasking,reference=spm_vol(saved.record.input);end
else
    % 历史结果没有新记录时，按当时配置恢复前缀；仍只支持原有逐run SPM组织布局。
    files=dir(fullfile(out,'**',[options.prefix 'w*.nii']));
    assert(numel(files)==1,'Expected one smoothed series');smoothed=fullfile(files(1).folder,files(1).name);
end
v=spm_vol(smoothed);expected=loaded.info.nVolumes;
if isfield(loaded,'plan')&&isfield(loaded.plan,'dummy'),expected=loaded.plan.dummy.retainedVolumes;end
assert(numel(v)==expected,'Volume count mismatch');
assert(all(abs(sqrt(sum(v(1).mat(1:3,1:3).^2))-cfg.voxelSizeMm)<1e-4),'Unexpected voxel size');
samples=unique([1 ceil(numel(v)/2) numel(v)]);
for k=1:numel(v)
    d=spm_read_vols(v(k));
    if options.implicitMasking
        assert(numel(reference)==numel(v),'Implicit masking QC requires SMOOTHING_COMPLETE input reference');
        input=spm_read_vols(reference(k),1);invalid=isnan(input);
        assert(~any(isinf(d),'all') && all(~isnan(d)|invalid,'all'),'Unexpected nonfinite output frame %d',k);
        if spm_type(v(k).dt(1),'nanrep')
            assert(all(isnan(d(invalid))),'Implicit NaN mask was not preserved');
        else
            assert(all(d(invalid)==0),'Implicit integer zero mask was not preserved');
        end
        values=d(isfinite(d));assert(~isempty(values)&&max(values)>min(values),'Invalid output frame %d',k);
    else
        assert(all(isfinite(d),'all') && max(d(:))>min(d(:)),'Invalid output frame %d',k);
    end
end
gm=dir(fullfile(out,'anat','c1*.nii')); wm=dir(fullfile(out,'anat','c2*.nii'));
assert(numel(gm)==1 && numel(wm)==1,'Missing tissue maps');
tissues={fullfile(gm.folder,gm.name),fullfile(wm.folder,wm.name)};
volumes=zeros(1,2);
for j=1:2
    h=spm_vol(tissues{j}); d=spm_read_vols(h);
    assert(all(isfinite(d),'all') && min(d(:))>=-1e-5 && max(d(:))<=1.0001,'Invalid probabilities');
    volumes(j)=sum(d(:))*abs(det(h.mat(1:3,1:3)))/1000;
end
qc=struct('nVolumes',numel(v),'dimensions',v(1).dim,'voxelSizeMm',cfg.voxelSizeMm, ...
    'sampledFrames',samples,'nativeGMandWMmillilitres',volumes, ...
    'finiteCheckScope','all BOLD frames; full GM/WM maps', ...
    'scientificValidation','visual review required; gradient distortion correction not assessed');
qc.implicitMasking=options.implicitMasking;
if options.implicitMasking
    qc.finiteCheckScope='all BOLD frames; NaN only at recorded implicit input mask; full GM/WM maps';
end
if isfield(loaded,'plan') && isfield(loaded.plan,'sdc') && ...
        isfield(loaded.plan.sdc,'method') && ~strcmp(loaded.plan.sdc.method,'none')
    % 统一入口把本次选择的校正方法保存在 input_info.mat；此处只报告来源，
    % 不以空间影像存在与否反推畸变校正已经执行。
    qc.susceptibilityCorrection=['performed by unified preprocessing: ' loaded.plan.sdc.method];
elseif isfield(cfg,'inputStage') && strcmp(cfg.inputStage,'sdc_corrected')
    qc.susceptibilityCorrection='declared in upstream provenance; not repeated here';
else
    qc.susceptibilityCorrection='not performed in this branch';
end
fid=fopen(fullfile(out,'spatial_checks.json'),'w'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(qc,PrettyPrint=true)); clear cleanup;
native=dir(fullfile(out,'mean*.nii')); normalized=dir(fullfile(out,'wmean*.nii'));
overlay(fullfile(native.folder,native.name),tissues{1},fullfile(out,'native_coreg_qc.png'),'Mean EPI with native GM contour (p=0.3)');
overlay(fullfile(normalized.folder,normalized.name),[fullfile(cfg.spmPath,'tpm','TPM.nii') ',1'],fullfile(out,'mni_qc.png'),'Normalized mean EPI with SPM GM prior contour (p=0.3)');
end

function overlay(epi,reference,output,titleText)
e=spm_vol(epi); r=spm_vol(reference);
[cx,cy,cz]=ndgrid([1 r.dim(1)],[1 r.dim(2)],[1 r.dim(3)]);
corners=r.mat*[cx(:)';cy(:)';cz(:)';ones(1,numel(cx))];
lo=floor(min(corners(1:3,:),[],2)/2)*2; hi=ceil(max(corners(1:3,:),[],2)/2)*2;
[x,y]=ndgrid(lo(1):2:hi(1),lo(2):2:hi(2)); slices=[-30 -10 10 30 50 70];
f=figure('Visible','off','Color','w','Position',[100 100 1100 750]); cleanup=onCleanup(@()close(f));
tiledlayout(f,2,3,'TileSpacing','compact');
for z=slices
    world=[x(:)';y(:)';repmat(z,1,numel(x));ones(1,numel(x))];
    ve=e.mat\world; vr=r.mat\world;
    a=reshape(spm_sample_vol(e,ve(1,:),ve(2,:),ve(3,:),1),size(x));
    b=reshape(spm_sample_vol(r,vr(1,:),vr(2,:),vr(3,:),1),size(x));
    nexttile; imagesc(x(:,1),y(1,:),a'); axis image xy; colormap gray; hold on;
    contour(x(:,1),y(1,:),b',[0.3 0.3],'r','LineWidth',0.5);
    xlabel('x (world mm)'); ylabel('y (world mm)'); title(sprintf('z = %d mm',z));
end
sgtitle(titleText); exportgraphics(f,output,'Resolution',120);
end
