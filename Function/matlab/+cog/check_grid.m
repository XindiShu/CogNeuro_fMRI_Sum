function check_grid(a,b)
%CHECK_GRID 同时校验尺寸与affine，不因尺寸相同就认为同空间。
if ~isscalar(a)||~isscalar(b)||~isequal(a.dim,b.dim)||max(abs(a.mat-b.mat),[],'all')>1e-5
    error('cog:Grid','Images must share grid/affine; no automatic resampling');
end
end
