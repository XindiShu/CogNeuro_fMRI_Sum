function info=nifti_geometry(path)
%NIFTI_GEOMETRY 只读 NIfTI 尺寸/仿射矩阵；兼容 MATLAB 不识别的 FSL intent code。
try
    info=niftiinfo(path);
    return;
catch err
    if ~contains(err.message,'意图代码') && ~contains(lower(err.message),'intent code')
        rethrow(err);
    end
end
if ~endsWith(lower(path),'.nii.gz')
    raw=path; cleanup=[];
else
    tmp=tempname;mkdir(tmp);
    files=gunzip(path,tmp);
    raw=files{1};cleanup=onCleanup(@()cleanupFolder(tmp));
end
fid=fopen(raw,'r','ieee-le');
if fid<0, error('psy:NiftiHeader','无法读取 NIfTI 头: %s',path); end
closeFile=onCleanup(@()fclose(fid));
h=fread(fid,348,'*uint8');
if numel(h)~=348 || val(h,1,'int32')~=348
    error('psy:NiftiHeader','当前兼容分支仅支持 little-endian NIfTI-1');
end
d=typecast(h(41:56),'int16');n=double(d(1));
if n<3||n>4, error('psy:NiftiHeader','当前仅支持 3D/4D NIfTI'); end
sz=double(d(2:n+1))';
sform=val(h,255,'int16');
if sform<=0
    error('psy:NiftiHeader','无法识别 intent 的影像须有有效 sform');
end
sx=double(typecast(h(281:296),'single'));sx=sx(:)';
sy=double(typecast(h(297:312),'single'));sy=sy(:)';
szrow=double(typecast(h(313:328),'single'));szrow=szrow(:)';
t=[sx;sy;szrow;0 0 0 1]';
if any(~isfinite(t(:))) || abs(det(t(1:3,1:3)))<1e-8
    error('psy:NiftiHeader','NIfTI sform 无效');
end
info=struct('ImageSize',sz,'Transform',struct('T',t));
clear closeFile cleanup
end
function value=val(h,start,type)
if strcmp(type,'int32'), bytes=4; else, bytes=2; end
value=typecast(h(start:start+bytes-1),type);
end
function cleanupFolder(folder)
if isfolder(folder), rmdir(folder,'s'); end
end
