function record=cat12_environment(path)
%CAT12_ENVIRONMENT 本接口固定验证 CAT12.9；不把升级后的 CAT26 默认为等价算法。
if ~isfolder(path)||~isfile(fullfile(path,'cat12.m'))||~isfile(fullfile(path,'cat_version.m'))
    error('psy:CATInstall','未找到 CAT12，请设置 segment.cat12.path 或运行 scripts/install_cat12.ps1');
end
addpath(path);resolved=fileparts(which('cat12'));
if ~strcmpi(char(java.io.File(resolved).getCanonicalPath()),char(java.io.File(path).getCanonicalPath()))
    error('psy:CATInstall','MATLAB 路径存在冲突的 CAT 安装');
end
cat_defaults;cat_get_defaults('extopts.send_info',0);
[version,revision,date]=cat_version;
if isempty(regexp(version,'CAT12[._]9|CAT12\.9','once'))
    error('psy:CATVersion','本接口已核对 CAT12.9；当前 %s 需要另行兼容验证',version);
end
record=struct('version',version,'revision',revision,'date',date,'path',path,'defaultsSha256',psy.file_sha256(fullfile(path,'cat_defaults.m')), ...
    'runnerSha256',psy.file_sha256(fullfile(path,'cat_run.m')));
install=fullfile(path,'psy_installation.json');
if isfile(install),record.installation=jsondecode(fileread(install));end
% 恢复签名还包含模板和当前平台核心 MEX 的实际字节，不只依赖版本名称。
templates=dir(fullfile(path,'templates_MNI152NLin2009cAsym','Template_*.nii'));
files=cellfun(@(d)fullfile(d.folder,d.name),num2cell(templates),'UniformOutput',false);
for name={'cat_amap','cat_sanlm','cat_vol_median3'}
    mex=fullfile(path,[name{1} '.' mexext]);if isfile(mex),files{end+1}=mex;end %#ok<AGROW>
end
record.runtimeFiles=files;record.runtimeSha256=cellfun(@psy.file_sha256,files,'UniformOutput',false);
end
