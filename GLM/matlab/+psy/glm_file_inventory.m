function t=glm_file_inventory(files)
%GLM_FILE_INVENTORY 唯一路径的实际字节数和流式SHA256；用于只读后处理核查。
files=string(files);files=files(:);files(strlength(files)==0)=[];
for k=1:numel(files),files(k)=psy.glm_absolute_path(files(k));end
files=unique(files,'stable');bytes=zeros(numel(files),1);sha256=strings(numel(files),1);
for k=1:numel(files)
    entry=dir(char(files(k)));if numel(entry)~=1||entry.isdir,error('psy:GLMInput','Missing file: %s',files(k));end
    bytes(k)=entry.bytes;sha256(k)=psy.file_sha256(char(files(k)));
end
t=table(files,bytes,sha256,'VariableNames',{'path','bytes','sha256'});
end
