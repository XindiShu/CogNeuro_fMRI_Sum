function outputs=apply_atlases(p,inverse,reference,out)
%APPLY_ATLASES 调用 SPM Deformations；逆向场 + 目标网格 identity 复合。
% 标签 interp=0，概率 interp=1，mask=0，fwhm=0；不做 Jacobian 调制。
outputs={};if ~p.atlasOptions.enabled,return;end
if isempty(inverse)||~isfile(inverse),error('psy:AtlasInverse','缺少实际逆向形变场');end
ref=spm_vol(reference);ref=ref(1);
for k=1:numel(p.atlases)
    atlas=p.atlases(k);folder=fullfile(out,'atlases',atlas.Name);
    for sourceFile={p.atlasesFile,atlas.Path}
        index=find(strcmp(p.inputFiles,sourceFile{1}),1);
        if isempty(index)||~strcmp(psy.file_sha256(sourceFile{1}),p.hashes{index})
            error('psy:AnatomyChanged','分割期间图谱输入发生变化，拒绝使用未预检版本');
        end
    end
    source=psy.stage_image(atlas.Path,folder);
    b={};b{1}.spm.util.defs.comp{1}.def={inverse};
    b{1}.spm.util.defs.comp{2}.id.space={reference}; % 此菜单筛选 NIfTI 文件，不接收 ,1 帧后缀。
    b{1}.spm.util.defs.out{1}.pull=struct('fnames',{{source}}, ...
        'savedir',struct('saveusr',{{folder}}),'interp',atlas.Interpolation, ...
        'mask',0,'fwhm',[0 0 0],'prefix',p.atlasOptions.prefix);
    job=fullfile(folder,'atlas_deformation_job.mat');psy.spm_step(b,job);
    [~,stem,ext]=fileparts(source);dest=fullfile(folder,[p.atlasOptions.prefix stem ext]);
    v=spm_vol(dest);x=spm_read_vols(v);original=spm_read_vols(spm_vol(source));
    if ~isequal(v.dim,ref.dim)||max(abs(v.mat(:)-ref.mat(:)))>1e-4||any(isinf(x(:)))
        error('psy:AtlasOutput','图谱输出网格/数值不符合目标图');
    end
    % SPM 在图谱/形变场覆盖之外写 NaN；保留覆盖掩膜，背景显式设 0。
    % 工作输出的填零不改原图谱，0 也不代表真实的组织/ROI 标签。
    coverage=isfinite(x);x(~coverage)=0;spm_write_vol(v,x);
    mask=fullfile(folder,'coverage_mask.nii');mv=v;mv.fname=mask;mv.dt=[2 0];mv.pinfo=[1;0;0];spm_write_vol(mv,coverage);
    if strcmp(atlas.Kind,'labels')
        if any(x(:)~=round(x(:)))||~all(ismember(unique(x),[0;unique(original)]))
            error('psy:AtlasOutput','最近邻输出出现新增/非整数标签');
        end
    elseif any(x(:)<-1e-6)||any(x(:)>1+1e-6)
        error('psy:AtlasOutput','概率图线性重采样后超出 0..1');
    end
    record=struct('atlas',atlas,'reference',reference,'inverse',inverse, ...
        'output',dest,'dimensions',v.dim,'affine',v.mat,'inputSha256',psy.file_sha256(atlas.Path), ...
        'coverageMask',mask,'uncoveredVoxels',nnz(~coverage));
    save(fullfile(folder,'ATLAS_COMPLETE.mat'),'record');
    outputs=[outputs,{source,dest,mask,job,fullfile(folder,'ATLAS_COMPLETE.mat')}]; %#ok<AGROW>
end
end
