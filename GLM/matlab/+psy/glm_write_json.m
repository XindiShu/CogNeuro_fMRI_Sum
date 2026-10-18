function glm_write_json(file,value)
%GLM_WRITE_JSON 新输出目录中的UTF-8 JSON；不用于改写源模型或用户文档。
f=fopen(file,'w','n','UTF-8');if f<0,error('psy:GLMOutput','Cannot write JSON');end
cleanup=onCleanup(@()fclose(f));fprintf(f,'%s',jsonencode(value,PrettyPrint=true));clear cleanup;
end
