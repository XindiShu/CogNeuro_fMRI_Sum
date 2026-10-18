function qc = verify_realign(out)
%VERIFY_REALIGN Verify outputs and generate engineering QC without exclusion.
input=load(fullfile(out,'input_info.mat'));
means=dir(fullfile(out,'mean*.nii'));
motion=dir(fullfile(out,'rp_*.txt'));
if numel(means)~=1 || numel(motion)~=1
    error('psy:QCFiles','Expected exactly one mean and one motion file');
end
stem=extractAfter(means(1).name,'mean');
realigned=fullfile(out,['r' char(stem)]);
v=spm_vol(realigned);
rp=readmatrix(fullfile(out,motion(1).name),'FileType','text');
assert(numel(v)==input.info.nVolumes && size(rp,1)==numel(v),'Volume/motion count mismatch');
assert(all(isfinite(rp),'all'),'Nonfinite motion parameters');
sampleFrames=unique([1 ceil(numel(v)/2) numel(v)]);
ranges=zeros(numel(sampleFrames),2);
for j=1:numel(sampleFrames)
    img=spm_read_vols(v(sampleFrames(j)));
    assert(all(isfinite(img),'all'),'Nonfinite voxels in sampled frame');
    ranges(j,:)=[min(img(:)),max(img(:))];
    assert(ranges(j,2)>ranges(j,1),'Constant sampled image');
end
meanVolume=spm_vol(fullfile(out,means(1).name));
m=spm_read_vols(meanVolume);
assert(all(isfinite(m),'all') && max(m(:))>0,'Invalid mean image');
qc=struct('subject',input.run.subject,'run',input.run.name,'nVolumes',numel(v), ...
    'sampledFrames',sampleFrames,'sampledIntensityRanges',ranges,'meanDimensions',size(m), ...
    'finiteChecks','sampled BOLD frames and all mean voxels; not every BOLD voxel', ...
    'distortionCorrection','not performed','registrationQC','native EPI only; T1/MNI not assessed');
f=fopen(fullfile(out,'output_checks.json'),'w'); cleanup=onCleanup(@()fclose(f));
fprintf(f,'%s',jsonencode(qc,PrettyPrint=true)); clear cleanup;
motionTable=readtable(fullfile(out,'motion.tsv'),'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
fig=figure('Visible','off','Color','w','Position',[100 100 1100 760]);
figCleanup=onCleanup(@()close(fig));
tiledlayout(fig,3,1);
nexttile; plot(rp(:,1:3)); ylabel('Translation (mm)'); legend('x','y','z'); grid on;
title(sprintf('%s / %s - SPM realignment',input.run.subject,input.run.name),'Interpreter','none');
nexttile; plot(rp(:,4:6)*180/pi); ylabel('Rotation (degrees)'); legend('x','y','z'); grid on;
nexttile; plot(motionTable.FD_mm); hold on; yline(input.cfg.fdFlagMm,'r--');
ylabel('FD (mm)'); xlabel('Volume'); grid on;
exportgraphics(fig,fullfile(out,'motion_qc.png'),'Resolution',130);
clear figCleanup;
fig=figure('Visible','off','Color','w','Position',[100 100 1100 600]);
figCleanup=onCleanup(@()close(fig));
positive=sort(m(m>0)); limits=[0 positive(max(1,round(0.99*numel(positive))))];
tiledlayout(fig,2,4,'TileSpacing','compact');
slices=round(linspace(size(m,3)*0.15,size(m,3)*0.85,8));
for z=slices
    nexttile; imagesc(rot90(m(:,:,z)),limits); axis image off; colormap gray;
    title(sprintf('Voxel slice z=%d',z));
end
sgtitle('Native mean EPI: voxel slices, not anatomical L/R labels');
exportgraphics(fig,fullfile(out,'mean_epi_qc.png'),'Resolution',130);
end
