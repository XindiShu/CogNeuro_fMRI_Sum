function record=reuse_anatomy(stagedT1,sourceAnat,cfg)
%REUSE_ANATOMY 只复用已完成且 T1 字节完全相同的 SPM 分割结果。
% stagedT1 是本 run 的私有工作副本；sourceAnat 必须是另一个已完成 run 的 anat 目录。
if ~isfolder(sourceAnat), error('psy:AnatomyReuse','来源解剖目录不存在: %s',sourceAnat); end
marker=fullfile(fileparts(sourceAnat),'SPATIAL_COMPLETE.mat');
if ~isfile(marker), marker=fullfile(fileparts(sourceAnat),'COMPLETE.mat'); end
if ~isfile(marker), error('psy:AnatomyReuse','来源缺少已完成空间处理标记'); end
prior=load(marker);
if ~isfield(prior,'status') || ~contains(prior.status,'spatial_pipeline')
    error('psy:AnatomyReuse','来源状态不是已完成空间处理');
end
% 旧独立分支把 cfg 存在 SPATIAL_COMPLETE；统一入口的 COMPLETE 只存签名，
% 真正的配置保存在同目录 input_info.mat。两种记录都核查，不能凭文件名复用。
if ~isfield(prior,'cfg') && isfile(fullfile(fileparts(sourceAnat),'input_info.mat'))
    metadata=load(fullfile(fileparts(sourceAnat),'input_info.mat'),'cfg');
    prior.cfg=metadata.cfg;
end
if ~isfield(prior,'cfg') || ~isfield(prior.cfg,'spmPath') || ~strcmp(prior.cfg.spmPath,cfg.spmPath)
    error('psy:AnatomyReuse','来源与目标的 SPM 安装目录不同');
end
if isfield(prior.cfg,'segment') && isfield(cfg,'segment') && ...
        ~isequal(prior.cfg.segment,cfg.segment)
    error('psy:AnatomyReuse','来源与目标的 Segment 参数不同，不能复用');
end
[targetDir,stem,ext]=fileparts(stagedT1);
if ~strcmpi(ext,'.nii'), error('psy:AnatomyReuse','当前仅复用已解压的 .nii T1'); end
sourceT1=fullfile(sourceAnat,[stem ext]);
if ~isfile(sourceT1) || ~samebytes(stagedT1,sourceT1)
    error('psy:AnatomyReuse','来源 T1 与当前 T1 的解压文件字节不一致');
end
names={['c1' stem '.nii'],['c2' stem '.nii'],['c3' stem '.nii'], ...
    ['y_' stem '.nii'],['m' stem '.nii'],[stem '_seg8.mat']};
for k=1:numel(names)
    src=fullfile(sourceAnat,names{k});
    if ~isfile(src), error('psy:AnatomyReuse','来源缺少必要分割输出: %s',src); end
    if isfile(fullfile(targetDir,names{k})), error('psy:AnatomyReuse','目标已存在，拒绝覆盖: %s',names{k}); end
end
for k=1:numel(names)
    copyfile(fullfile(sourceAnat,names{k}),fullfile(targetDir,names{k}));
end
record=struct('status','reused_completed_anatomy_same_t1_bytes','sourceAnat',sourceAnat, ...
    'sourceMarker',marker,'stagedT1',stagedT1,'files',{names},'spmPath',cfg.spmPath);
fid=fopen(fullfile(targetDir,'ANATOMY_REUSE.json'),'w');
fprintf(fid,'%s',jsonencode(record,PrettyPrint=true));fclose(fid);
end

function equal=samebytes(a,b)
sa=dir(a);sb=dir(b);equal=false;
if sa.bytes~=sb.bytes, return; end
fa=fopen(a,'rb');fb=fopen(b,'rb');
if fa<0||fb<0, error('psy:AnatomyReuse','无法读取 T1 作逐字节比较'); end
ca=onCleanup(@()fclose(fa));cb=onCleanup(@()fclose(fb)); %#ok<NASGU>
while true
    x=fread(fa,1024*1024,'*uint8');y=fread(fb,1024*1024,'*uint8');
    if ~isequal(x,y), return; end
    if isempty(x), equal=true; return; end
end
end
