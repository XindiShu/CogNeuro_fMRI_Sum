function qc = motion_qc(rpFile, radiusMm, thresholdMm, outputDir)
%MOTION_QC Power-style FD from SPM translations (mm), rotations (radians).
rp=readmatrix(rpFile,'FileType','text');
if size(rp,2)~=6 || any(~isfinite(rp),'all')
    error('psy:Motion','Expected finite SPM N x 6 motion parameters');
end
delta=[zeros(1,6);diff(rp,1,1)];
fd=sum(abs(delta(:,1:3)),2)+radiusMm*sum(abs(delta(:,4:6)),2);
qc=struct('nVolumes',size(rp,1),'meanFDmm',mean(fd),'maxFDmm',max(fd), ...
    'flagThresholdMm',thresholdMm,'fractionFlagged',mean(fd>thresholdMm));
writetable(table((1:numel(fd))',fd,fd>thresholdMm,'VariableNames', ...
    {'volume','FD_mm','flagged'}),fullfile(outputDir,'motion.tsv'),'FileType','text','Delimiter','\t');
f=fopen(fullfile(outputDir,'motion_summary.json'),'w');
c=onCleanup(@()fclose(f)); fprintf(f,'%s',jsonencode(qc,PrettyPrint=true));
end
