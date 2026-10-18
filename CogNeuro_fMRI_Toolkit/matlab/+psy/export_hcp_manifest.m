function export_hcp_manifest(cfg,destination)
%EXPORT_HCP_MANIFEST 将 HCP 发现结果转换成通用清单，供示例对照验证。
% 不复制或修改任何影像；导出 raw 路径，不把官方衍生图混入原始流程。
runs=psy.discover_hcp(cfg); n=numel(runs);
subject=string({runs.subject})'; session=string({runs.session})'; run=string({runs.name})';
bold=string({runs.bold})'; t1=string({runs.t1})'; input_stage=repmat("raw",n,1); sbref=string({runs.sbref})';
sbref(~isfile(sbref))="";
folder=fileparts(destination); if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
if isfile(destination), error('psy:ManifestExists','Refusing to overwrite an existing manifest'); end
writetable(table(subject,session,run,bold,t1,input_stage,sbref),destination,'FileType','text','Delimiter','\t');
end
