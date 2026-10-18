function p=glm_absolute_path(p,base)
%GLM_ABSOLUTE_PATH 先按MATLAB目录展开，再用Java规范化；避免Java user.dir与pwd不同。
if nargin<2,base=pwd;end
if ~(ischar(p)||isstring(p))||~isscalar(string(p))||ismissing(string(p))||strlength(string(p))==0
    error('psy:GLMPath','Expected a nonempty scalar path');
end
p=char(p);if ~java.io.File(p).isAbsolute(),p=fullfile(base,p);end
p=char(java.io.File(p).getCanonicalPath());
end
