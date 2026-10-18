function qc=verify_spm_model(file)
%VERIFY_SPM_MODEL 只读核验估计后beta、方差、对比图的网格与mask内有限值。
s=load(file,'SPM');spm=s.SPM;base=fileparts(file);m=spm.VM;m.fname=cog.resolve_path(m.fname,base);mask=spm_read_vols(m)>0;
if ~any(mask(:)),error('cog:ModelQC','Empty analysis mask');end
images=[spm.Vbeta(:);spm.VResMS(:)];
for k=1:numel(spm.xCon)
    if ~isfield(spm.xCon(k),'Vcon')||isempty(spm.xCon(k).Vcon),error('cog:ModelQC','Unestimated contrast');end
    images=[images;spm.xCon(k).Vcon(:);spm.xCon(k).Vspm(:)]; %#ok<AGROW>
end
for k=1:numel(images)
    v=images(k);v.fname=cog.resolve_path(v.fname,base);cog.check_grid(v,m);y=spm_read_vols(v);if any(~isfinite(y(mask))),error('cog:ModelQC','Nonfinite estimated output: %s',v.fname);end
end
qc=struct('nVoxels',nnz(mask),'nImages',numel(images),'nContrasts',numel(spm.xCon),'designRank',rank(full(spm.xX.X)),'nRegressors',size(spm.xX.X,2),'nScans',size(spm.xX.X,1),'status','passed');
end
