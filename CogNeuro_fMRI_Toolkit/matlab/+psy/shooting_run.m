function result=shooting_run(job,n,folder,mode)
%SHOOTING_RUN 原生 Shoot 调用；私有 defaults 适配仅在调用期间进入路径。
% SPM GUI 的 Shoot 没有高级数值菜单，官方要求自定义 defaults 函数。
% 此处记录实际完整 defaults，用私有适配文件实现；不改 toolbox/Shoot 文件。
defaults=psy.shooting_defaults(n);adapter=fullfile(folder,'shoot_defaults_adapter');
if ~isfolder(adapter),mkdir(adapter);end
save(fullfile(adapter,'defaults.mat'),'defaults');
fid=fopen(fullfile(adapter,'spm_shoot_defaults.m'),'w');
if fid<0,error('psy:ShootDefaults','无法写私有 defaults 适配');end
fprintf(fid,'function d=spm_shoot_defaults\ns=load(fullfile(fileparts(mfilename(''fullpath'')),''defaults.mat''),''defaults'');\nd=s.defaults;\nend\n');
fclose(fid);
oldPath=path;oldFolder=pwd;boundary=spm_diffeo('boundary');
cleanup=onCleanup(@()restore(oldPath,oldFolder,boundary));
cd(folder);addpath(adapter,'-begin');clear spm_shoot_defaults;
execution='spm_shoot_template';if strcmp(mode,'existing'),execution='spm_shoot_warp';end
save(fullfile(folder,'shoot_registration_job.mat'),'job','defaults','execution');
result=feval(execution,job);
end
function restore(oldPath,oldFolder,boundary)
cd(oldFolder);path(oldPath);clear spm_shoot_defaults;
spm_diffeo('boundary',boundary);
end
