function record=normalise_output_check(source,files,nVolumes,voxelSize)
%NORMALISE_OUTPUT_CHECK 全帧工程检查：时长/网格/覆盖。不是解剖配准合格证明。
input=nifti(source);record=struct('files',{files},'nonfiniteFractions',{{}}, ...
    'dimensions',[],'affine',[],'nVolumes',nVolumes,'trSeconds',input.timing.tspace);
reference=spm_vol(files{1});reference=reference(1);
for k=1:numel(files)
    v=spm_vol(files{k});expected=nVolumes;if k==2,expected=1;end
    if numel(v)~=expected,error('psy:NormaliseOutput','标准化输出帧数错误');end
    h=nifti(files{k});
    if k~=2 && abs(h.timing.tspace-record.trSeconds)>1e-6
        error('psy:NormaliseOutput','标准化输出 TR 改变');
    end
    fractions=zeros(1,numel(v));
    for j=1:numel(v)
        if ~isequal(v(j).dim,reference.dim)||max(abs(v(j).mat(:)-reference.mat(:)))>1e-4 || ...
                max(abs(sqrt(sum(v(j).mat(1:3,1:3).^2))-voxelSize))>1e-4
            error('psy:NormaliseOutput','标准化输出网格不一致');
        end
        x=spm_read_vols(v(j));fractions(j)=nnz(~isfinite(x))/numel(x);
        if any(isinf(x(:)))||~any(isfinite(x(:))&x(:)~=0)
            error('psy:NormaliseOutput','标准化输出含 Inf 或完全没有有效非零信号');
        end
    end
    record.nonfiniteFractions{k}=fractions;
end
record.dimensions=reference.dim;record.affine=reference.mat;
end
