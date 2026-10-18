function hash=file_sha256(path)
%FILE_SHA256 流式读取，不把整幅结构像或图谱加载进内存。
fid=fopen(path,'rb');
if fid<0, error('psy:InputHash','无法读取文件: %s',path); end
c=onCleanup(@()fclose(fid));
d=java.security.MessageDigest.getInstance('SHA-256');
while true
    bytes=fread(fid,1024*1024,'*uint8');
    if isempty(bytes), break; end
    d.update(typecast(bytes,'int8')); % Java byte 有符号；保留 128..255 的原始位型。
end
hash=lower(reshape(dec2hex(typecast(d.digest(),'uint8'),2).',1,[]));
end
