function root=setup_function(spmPath)
%SETUP_FUNCTION 仅添加本包和显式SPM路径，不重置MATLAB搜索路径。
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'matlab'),fullfile(root,'config'));
if nargin>0 && ~isempty(spmPath),addpath(spmPath);end
end
