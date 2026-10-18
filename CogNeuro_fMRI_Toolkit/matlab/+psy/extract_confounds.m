function summary=extract_confounds(run,cfg,out)
%EXTRACT_CONFOUNDS 从未平滑、已 realign/coreg 的 BOLD 提取组织均值和头动项。
% 输入 WM/CSF 必须与 BOLD 处于同一世界坐标系；不等同于数组尺寸相同。
% 不做回归/滤波/删帧；FD 和标记列不得直接全部作为回归设计矩阵。
if isfolder(out), error('psy:ConfoundsExists','Output already exists: %s',out); end
if ~(isscalar(cfg.minVoxels)&&isfinite(cfg.minVoxels)&&cfg.minVoxels>=1&&mod(cfg.minVoxels,1)==0) || ...
        ~(isscalar(cfg.fdFlagMm)&&isfinite(cfg.fdFlagMm)&&cfg.fdFlagMm>=0)
    error('psy:ConfoundParameters','Invalid minVoxels or FD threshold');
end
v=spm_vol(run.bold); n=numel(v); if n<2, error('psy:ImageShape','Need 4-D BOLD'); end
for i=2:n
    if ~isequal(v(i).dim,v(1).dim) || max(abs(v(i).mat-v(1).mat),[],'all')>1e-5
        error('psy:ConfoundGrid','Frames differ in geometry; use resliced series');
    end
end
rp=readmatrix(run.motion,'FileType','text');
if size(rp,1)~=n, error('psy:MotionLength','Motion rows must match BOLD frames'); end
[motion,names,fd]=psy.motion_regressors(rp,cfg.fdRadiusMm);
[wm,~]=psy.tissue_mask(run.wm,v(1),cfg.wmThreshold,cfg.erosionMm);
[csf,~]=psy.tissue_mask(run.csf,v(1),cfg.csfThreshold,cfg.erosionMm);
overlap=wm & csf; wm(overlap)=false; csf(overlap)=false;
if min(nnz(wm),nnz(csf))<cfg.minVoxels, error('psy:SmallTissueMask','WM %d / CSF %d voxels; check registration and settings',nnz(wm),nnz(csf)); end
signals=zeros(n,2); meanImage=zeros(v(1).dim);
for i=1:n
    a=spm_read_vols(v(i));
    if any(~isfinite(a(:))), error('psy:Nonfinite','Nonfinite BOLD in frame %d',i); end
    signals(i,:)=[mean(a(wm)),mean(a(csf))]; meanImage=meanImage+a/n;
end
if any(std(signals,0,1)==0), error('psy:ConstantTissueSignal','Constant tissue time series; inspect masks/data'); end
mkdir(out);
writetable(array2table([motion,signals,fd,double(fd>cfg.fdFlagMm)],'VariableNames', ...
    [names,{'white_matter','csf','framewise_displacement','motion_outlier'}]), ...
    fullfile(out,'confounds.tsv'),'FileType','text','Delimiter','\t');
for name={'wm','csf'}
    mask=wm; if strcmp(name{1},'csf'), mask=csf; end
    target=v(1); target.fname=fullfile(out,[name{1} '_mask.nii']); target.dt=[2 0]; target.pinfo=[1;0;0]; target.n=[1 1];
    target.descrip='Thresholded/eroded tissue mask on BOLD grid'; spm_write_vol(target,double(mask));
end
summary=struct('nVolumes',n,'wmVoxels',nnz(wm),'csfVoxels',nnz(csf), ...
    'overlapRemoved',nnz(overlap),'meanFDmm',mean(fd),'maxFDmm',max(fd), ...
    'flaggedFrames',sum(fd>cfg.fdFlagMm),'status','confounds_extracted_not_regressed', ...
    'tissueSignals','Unweighted means; original intensity units; no detrending/filtering', ...
    'motionConvention','SPM translations mm, rotations radians; backward differences; first difference/FD=0', ...
    'motionColumns',strjoin(names,','),'warning','FD/outlier are diagnostics; do not regress all columns automatically');
f=fopen(fullfile(out,'summary.json'),'w'); c=onCleanup(@()fclose(f)); fprintf(f,'%s',jsonencode(summary,PrettyPrint=true)); clear c;
psy.plot_tissue_masks(meanImage,wm,csf,out);
save(fullfile(out,'COMPLETE.mat'),'summary','cfg','run');
end
