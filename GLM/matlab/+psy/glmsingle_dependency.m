function info=glmsingle_dependency(root)
%GLMSINGLE_DEPENDENCY 校验随包固定版本及实际文件哈希，只暂时添加所需MATLAB路径。
root=char(java.io.File(char(root)).getCanonicalPath());
for name={'SOURCE.json','DEPENDENCY_MANIFEST.json','matlab/GLMestimatesingletrial.m'}
    if ~isfile(fullfile(root,name{1})),error('psy:GLMsingleDependency','Missing bundled dependency file: %s',name{1});end
end
info=jsondecode(fileread(fullfile(root,'SOURCE.json')));
if ~strcmp(info.commit,'1ab54a65edd3ea41a6133d4b4ecb78a9c7296684')||~strcmp(info.fracridgeCommit,'1ac49cae092cca3efa083451808c26989d17a3b5')
    error('psy:GLMsingleDependency','This adapter was validated with the bundled fixed commits only');
end
files=jsondecode(fileread(fullfile(root,'DEPENDENCY_MANIFEST.json')));
for k=1:numel(files)
    file=char(java.io.File(fullfile(root,files(k).path)).getCanonicalPath());
    if ~startsWith(lower(file),lower([root filesep]))||~isfile(file)||~strcmpi(psy.file_sha256(file),files(k).sha256)
        error('psy:GLMsingleDependency','Dependency hash/path mismatch: %s',files(k).path);
    end
end
addpath(fullfile(root,'matlab'),fullfile(root,'matlab','utilities'),fullfile(root,'matlab','fracridge','matlab'));
if ~strcmpi(which('GLMestimatesingletrial'),fullfile(root,'matlab','GLMestimatesingletrial.m'))
    error('psy:GLMsingleDependency','Another function shadows the verified GLMsingle implementation');
end
info.root=root;info.verifiedFiles=numel(files);
end
