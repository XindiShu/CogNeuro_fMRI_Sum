function result=finalize_realign(resliced,meanFile,outDir,options)
%FINALIZE_REALIGN 保留 SPM 原始重采样；另写有限值副本和全程有效信号掩膜。
% SPM realign 的 mask=1 有意把非共同覆盖 FOV 写为 NaN。仅在输入已核实有限
% 且失效体素比例可接受时，把这些 NaN 置零；原始 r*.nii 不被修改。
arguments
    resliced (1,:) char
    meanFile (1,:) char
    outDir (1,:) char
    options.maskFraction (1,1) double {mustBePositive,mustBeLessThan(options.maskFraction,1)} = 0.2
    options.maxNonfiniteFraction (1,1) double {mustBePositive,mustBeLessThan(options.maxNonfiniteFraction,1)} = 0.1
end
if isfolder(outDir), error('psy:FinalizeExists','输出目录已存在: %s',outDir); end
v=spm_vol(resliced); reference=spm_vol(meanFile);
if numel(v)<2 || numel(reference)~=1 || ~isequal(v(1).dim,reference.dim)
    error('psy:FinalizeGrid','需要同网格的 4D realign 输出与 3D mean');
end
for k=1:numel(v)
    if ~isequal(v(k).dim,reference.dim) || max(abs(v(k).mat-reference.mat),[],'all')>1e-4
        error('psy:FinalizeGrid','第 %d 帧与 mean 网格不一致',k);
    end
end
m=spm_read_vols(reference);
if any(~isfinite(m),'all'), error('psy:FinalizeMean','SPM mean 存在非有限值'); end
positive=sort(m(m>0));
if isempty(positive), error('psy:FinalizeMean','SPM mean 没有正信号'); end
anchor=positive(max(1,ceil(0.95*numel(positive))));
signal=m>options.maskFraction*anchor;
allFinite=true(reference.dim); badPerFrame=zeros(numel(v),1); badInSignal=zeros(numel(v),1);
expectedMissing=[];
mkdir(outDir);
cleanFile=fullfile(outDir,'realigned_finite.nii');
for k=1:numel(v)
    image=spm_read_vols(v(k));
    if any(isinf(image),'all'), error('psy:FinalizeInf','第 %d 帧含 Inf，不能视为 SPM 共同视野掩膜',k); end
    bad=isnan(image);
    if k==1
        expectedMissing=bad;
    elseif ~isequal(bad,expectedMissing)
        error('psy:FinalizePattern','第 %d 帧 NaN 位置与第 1 帧不同，不能视为固定共同视野掩膜',k);
    end
    badPerFrame(k)=nnz(bad); badInSignal(k)=nnz(bad & signal);
    if badPerFrame(k)/numel(image)>options.maxNonfiniteFraction
        error('psy:FinalizeCoverage','第 %d 帧非有限比例 %.3f 超过上限',k,badPerFrame(k)/numel(image));
    end
    allFinite=allFinite & ~bad;
    image(bad)=0;
    header=v(k); header.fname=cleanFile; header.dt=[16 0];
    header.pinfo=[1;0;0]; header.descrip='SPM realign; masked NaNs to zero; see valid_mask.nii';
    spm_write_vol(header,image);
end
validSignal=allFinite & signal;
if nnz(validSignal)<100, error('psy:FinalizeCoverage','全程有效信号掩膜不足 100 体素'); end
maskFile=fullfile(outDir,'valid_mask.nii');
header=reference; header.fname=maskFile; header.dt=[16 0]; header.pinfo=[1;0;0];
header.n=[1 1]; header.descrip='Finite in every SPM resliced frame and above signal threshold';
spm_write_vol(header,double(validSignal));
result=struct('status','nonfinite_to_zero_with_common_valid_mask', ...
    'source',resliced,'cleanSeries',cleanFile,'maskFile',maskFile, ...
    'nVolumes',numel(v),'signalMaskVoxels',nnz(signal), ...
    'validSignalVoxels',nnz(validSignal),'unionNonfiniteVoxels',nnz(~allFinite), ...
    'maxNonfiniteFraction',max(badPerFrame)/prod(reference.dim), ...
    'maxNonfiniteWithinSignal',max(badInSignal), ...
    'perFrameNonfinite',badPerFrame,'perFrameWithinSignal',badInSignal, ...
    'interpretation','SPM mask=1 common-FOV NaNs replaced by zero in copy; inspect coverage before scientific use');
save(fullfile(outDir,'finalize_realign.mat'),'result');
fid=fopen(fullfile(outDir,'summary.json'),'w');
fprintf(fid,'%s',jsonencode(rmfield(result,{'perFrameNonfinite','perFrameWithinSignal'}),PrettyPrint=true));
fclose(fid);
end
