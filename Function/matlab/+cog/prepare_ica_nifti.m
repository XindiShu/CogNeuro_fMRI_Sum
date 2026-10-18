function data=prepare_ica_nifti(bold,mask,trSeconds,confounds,cleanOptions,maxMatrixGiB,newMatFile)
%PREPARE_ICA_NIFTI 显式NIfTI/共同掩膜→新MAT；不猜数据集、不重复去噪。
if isfile(newMatFile),error('cog:Exists','Prepared data file already exists');end
[y,space]=cog.load_bold(bold,mask,trSeconds,maxMatrixGiB);[y,processing]=cog.clean_timeseries(y,trSeconds,confounds,cleanOptions);
data=struct('y',y,'space',space,'featureIds',string(space.indices(:)),'trSeconds',trSeconds,'processing',processing,'sourceBold',bold,'sourceMask',mask);save(newMatFile,'data','-v7.3');
end
