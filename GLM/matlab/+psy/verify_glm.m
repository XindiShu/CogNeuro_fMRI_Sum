function qc=verify_glm(out)
%VERIFY_GLM 核查SPM一级/二级模型的掩膜、估计文件和全部T/F对比。
% 只报告数值/几何完整性；不判断显著性、解剖覆盖是否合理或任务设计是否正确。
p=fullfile(out,'SPM.mat');
if ~isfile(p), error('psy:GLMQC','Missing SPM.mat'); end
s=load(p,'SPM'); SPM=s.SPM;
if ~isfield(SPM,'xX') || ~isfield(SPM.xX,'X') || ~isfield(SPM,'xCon') || isempty(SPM.xCon)
    error('psy:GLMQC','SPM model or contrasts incomplete');
end
if ~isfield(SPM,'Vbeta') || isempty(SPM.Vbeta) || ~isfield(SPM,'VResMS')
    error('psy:GLMQC','Missing beta/variance references');
end
for k=1:numel(SPM.Vbeta)
    if ~isfile(fullfile(out,SPM.Vbeta(k).fname)), error('psy:GLMQC','Missing beta %d',k); end
end
if ~isfile(fullfile(out,SPM.VResMS.fname)), error('psy:GLMQC','Missing residual variance image'); end
maskFile=fullfile(out,'mask.nii');
if ~isfile(maskFile), error('psy:GLMQC','Missing analysis mask'); end
ref=spm_vol(maskFile);
if ~isscalar(ref), error('psy:GLMQC','Expected one 3-D analysis mask'); end
m=spm_read_vols(ref);
if any(~isfinite(m(:))), error('psy:GLMQC','Nonfinite analysis mask'); end
mask=m>0; nMask=nnz(mask);
if nMask<1, error('psy:GLMQC','Empty analysis mask'); end
names=cell(1,numel(SPM.xCon));tRange=NaN(numel(names),2);conRange=tRange;fRange=tRange;
stats=cell(size(names));
for k=1:numel(names)
    stats{k}=SPM.xCon(k).STAT;
    if ~ismember(stats{k},{'T','F'}),error('psy:GLMQC','Only T/F contrasts supported');end
    names{k}=SPM.xCon(k).name;
    if strcmp(stats{k},'T')
        conRange(k,:)=rangeInMask(fullfile(out,sprintf('con_%04d.nii',k)),ref,mask);
        tRange(k,:)=rangeInMask(fullfile(out,sprintf('spmT_%04d.nii',k)),ref,mask);
    else
        rangeInMask(fullfile(out,sprintf('ess_%04d.nii',k)),ref,mask);
        fRange(k,:)=rangeInMask(fullfile(out,sprintf('spmF_%04d.nii',k)),ref,mask);
        if fRange(k,1)<-1e-6,error('psy:GLMQC','Negative F statistic');end
    end
end
qc=struct('nFrames',size(SPM.xX.X,1),'nMaskedVoxels',nMask, ...
    'nBetas',numel(SPM.Vbeta),'nContrasts',numel(names),'contrastNames',{names}, ...
    'contrastRanges',conRange,'tRanges',tRange,'fRanges',fRange,'statistics',{stats}, ...
    'checkScope','all requested contrast/T/F/ESS maps inside SPM analysis mask; file/geometry checks', ...
    'scientificValidation','design, residuals, anatomical coverage, multiplicity require separate review');
f=fopen(fullfile(out,'glm_qc.json'),'w');
if f<0, error('psy:GLMQC','Cannot write QC JSON'); end
c=onCleanup(@()fclose(f)); fprintf(f,'%s',jsonencode(qc,PrettyPrint=true)); clear c;
end

function limits=rangeInMask(file,ref,mask)
if ~isfile(file), error('psy:GLMQC','Missing map: %s',file); end
v=spm_vol(file);
if ~isscalar(v) || ~isequal(v.dim,ref.dim) || max(abs(v.mat-ref.mat),[],'all')>1e-4
    error('psy:GLMQC','Map geometry mismatch: %s',file);
end
a=spm_read_vols(v); values=a(mask);
if any(~isfinite(values)), error('psy:GLMQC','Nonfinite map inside analysis mask: %s',file); end
limits=[min(values) max(values)];
end
