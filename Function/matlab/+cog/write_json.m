function write_json(file,value)
%WRITE_JSON UTF-8、临时文件完成后替换；仅用于新输出/本包状态。
tmp=[file '.writing'];f=fopen(tmp,'w','n','UTF-8');
if f<0,error('cog:Write','Cannot open %s',tmp);end
c=onCleanup(@()fclose(f));fprintf(f,'%s\n',jsonencode(value,PrettyPrint=true));clear c;
[ok,msg]=movefile(tmp,file,'f');if ~ok,error('cog:Write','%s',msg);end
end
