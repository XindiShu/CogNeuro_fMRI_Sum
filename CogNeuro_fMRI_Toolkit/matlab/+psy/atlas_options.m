function a=atlas_options(cfg)
%ATLAS_OPTIONS 逆向场把已声明标准空间的图谱写到被试原生 T1/EPI 网格。
a=struct('enabled',false,'manifestFile','','target','t1','ensureInverse',true,'prefix','native_');
if isfield(cfg,'atlas')
    for n=fieldnames(cfg.atlas)', a.(n{1})=cfg.atlas.(n{1}); end
end
for n={'enabled','ensureInverse'}
    if ~isscalar(a.(n{1}))||~ismember(a.(n{1}),[0 1]), error('psy:AtlasConfig','%s 应为 0/1',n{1}); end
end
if ~ismember(a.target,{'t1','bold'})||isempty(regexp(a.prefix,'^[A-Za-z][A-Za-z0-9_]*$','once'))
    error('psy:AtlasConfig','target=t1/bold；prefix 须为安全文件名前缀');
end
if a.enabled && (~ismember(cfg.stopAfter,{'segment','smooth'}) || ...
        (strcmp(a.target,'bold') && ~strcmp(cfg.stopAfter,'smooth')))
    error('psy:AtlasConfig','图谱需要分割；bold 目标还需要 smooth 阶段中的 EPI→T1 配准');
end
end
