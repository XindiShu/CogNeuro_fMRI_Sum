function summary = timeseries_qc(series,meanFile,motionFile,out,options)
%TIMESERIES_QC Streaming QC of every frame in an unsmoothed realigned series.
% DVARS = RMS voxelwise temporal difference (native intensity units).
% tSNR = temporal mean / sample SD, without detrending or nuisance regression.
% The automatic intensity mask is NOT an anatomical brain mask.
arguments
    series
    meanFile (1,:) char
    motionFile (1,:) char
    out (1,:) char
    options.maskFile (1,:) char = ''
    options.maskFraction (1,1) double {mustBePositive,mustBeLessThan(options.maskFraction,1)} = 0.2
    options.fdRadiusMm (1,1) double {mustBePositive} = 50
    options.fdFlagMm (1,1) double {mustBePositive} = 0.5
end
if isfolder(out), error('psy:QCExists','QC output already exists; choose a new directory: %s',out); end
v=spm_vol(char(series)); n=numel(v);
assert(n>=2,'At least two frames are required');
ref=spm_vol(meanFile); m=spm_read_vols(ref);
assert(numel(ref)==1 && all(isfinite(m),'all'),'Invalid reference mean');
assert(isequal(ref.dim,v(1).dim) && max(abs(ref.mat-v(1).mat),[],'all')<1e-4,'Reference grid mismatch');
if isempty(options.maskFile)
    positive=sort(m(m>0)); assert(~isempty(positive),'No positive signal in mean');
    anchor=positive(max(1,ceil(0.95*numel(positive))));
    mask=m>options.maskFraction*anchor;
    maskMethod='mean EPI > fraction * positive-voxel 95th percentile; not anatomical';
else
    mh=spm_vol(options.maskFile);
    assert(numel(mh)==1 && isequal(mh.dim,ref.dim) && max(abs(mh.mat-ref.mat),[],'all')<1e-4,'Mask grid mismatch');
    maskData=spm_read_vols(mh); assert(all(isfinite(maskData),'all'),'Nonfinite mask');
    mask=maskData>0; maskMethod='explicit user-supplied mask on identical grid';
end
count=nnz(mask); assert(count>0,'Empty QC mask');
rp=readmatrix(motionFile,'FileType','text');
assert(isequal(size(rp),[n 6]) && all(isfinite(rp),'all'),'Motion must be finite N x 6');
delta=[zeros(1,6);diff(rp)];
fd=sum(abs(delta(:,1:3)),2)+options.fdRadiusMm*sum(abs(delta(:,4:6)),2);
mu=zeros(count,1); ss=zeros(count,1); previous=[];
dvars=nan(n,1); globalSignal=zeros(n,1); zeroFraction=zeros(n,1);
for k=1:n
    assert(isequal(v(k).dim,ref.dim) && max(abs(v(k).mat-ref.mat),[],'all')<1e-4,'Frame grid mismatch');
    image=spm_read_vols(v(k));
    if any(~isfinite(image),'all'), error('psy:NonfiniteFrame','Nonfinite voxel in frame %d',k); end
    x=image(mask); globalSignal(k)=mean(x); zeroFraction(k)=mean(x==0);
    if k>1, dvars(k)=sqrt(mean((x-previous).^2)); end
    difference=x-mu; mu=mu+difference/k; ss=ss+difference.*(x-mu); previous=x;
end
sd=sqrt(max(ss,0)/(n-1)); valid=sd>0;
tsnr=nan(count,1); tsnr(valid)=mu(valid)./sd(valid);
summary=struct('nVolumes',n,'maskVoxels',count,'maskMethod',maskMethod, ...
    'maskOptions',options,'allFrameAllVoxelFinite',true,'meanFDmm',mean(fd), ...
    'maxFDmm',max(fd),'fractionFDFlagged',mean(fd>options.fdFlagMm), ...
    'meanDVARS',mean(dvars(2:end)),'maxDVARS',max(dvars(2:end)), ...
    'medianTSNR',median(tsnr(valid)),'zeroTemporalSDVoxels',sum(~valid), ...
    'maxMaskZeroFraction',max(zeroFraction), ...
    'definitions','DVARS native intensity units, frame 1 undefined; tSNR mean/sample SD without detrending', ...
    'interpretation','engineering QC only; task effects contribute; no automatic censoring or exclusion');
mkdir(out);
q=table((1:n)',fd,fd>options.fdFlagMm,dvars,globalSignal,zeroFraction, ...
    'VariableNames',{'volume','FD_mm','FD_flag','DVARS_native','global_mean','mask_zero_fraction'});
writetable(q,fullfile(out,'timeseries.tsv'),'FileType','text','Delimiter','\t');
write_map(ref,double(mask),fullfile(out,'qc_mask.nii'),'QC mask, inspect before interpretation');
map=zeros(ref.dim); map(mask)=tsnr;
write_map(ref,map,fullfile(out,'tsnr.nii'),'Mean / sample SD; no detrending; outside mask zero');
f=figure('Visible','off','Color','w','Position',[100 100 1100 800]); cleanup=onCleanup(@()close(f));
tiledlayout(f,3,1); nexttile; plot(fd); hold on; yline(options.fdFlagMm,'r--'); ylabel('FD (mm)'); grid on;
nexttile; plot(dvars); ylabel('DVARS (native units)'); grid on;
nexttile; plot(globalSignal); ylabel('Mask mean signal'); xlabel('Volume'); grid on;
sgtitle('Unsmoothed realigned data: no temporal denoising');
exportgraphics(f,fullfile(out,'timeseries_qc.png'),'Resolution',120); clear cleanup;
psy.plot_qc_mask(meanFile,out);
save(fullfile(out,'qc_provenance.mat'),'series','meanFile','motionFile','options','summary');
fid=fopen(fullfile(out,'summary.json'),'w'); assert(fid>=0,'Cannot open summary'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true)); clear cleanup;
save(fullfile(out,'QC_COMPLETE.mat'),'summary');
end

function write_map(reference,data,filename,description)
header=struct('fname',filename,'dim',reference.dim,'dt',[16 0], ...
    'mat',reference.mat,'pinfo',[1;0;0],'n',[1 1],'descrip',description);
spm_write_vol(header,data);
end
