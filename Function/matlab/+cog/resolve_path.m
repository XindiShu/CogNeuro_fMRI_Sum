function p=resolve_path(value,base)
%RESOLVE_PATH 相对清单目录解析；不搜索HCP或任何固定数据集目录。
value=char(value);if isempty(value),p='';return;end
if ~isAbsolute(value),value=fullfile(base,value);end
p=char(javaFreeAbsolute(value));
end
function yes=isAbsolute(p)
yes=startsWith(p,'/')||startsWith(p,'\')||~isempty(regexp(p,'^[A-Za-z]:[/\\]','once'));
end
function p=javaFreeAbsolute(p)
[ok,a]=fileattrib(p);if ok,p=a.Name;else,error('cog:Path','Missing input %s',p);end
end
