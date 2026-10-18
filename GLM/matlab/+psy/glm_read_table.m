function t=glm_read_table(file,columns)
%GLM_READ_TABLE 以文本保留ID和空字段；列集合必须明确，数值由调用层转换。
o=detectImportOptions(file,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
if nargin>1&&(~all(ismember(columns,o.VariableNames))||any(~ismember(o.VariableNames,columns)))
    error('psy:GLMColumns','Unexpected/missing columns in %s',file);
end
o.DataLines=[2 Inf];o.ConsecutiveDelimitersRule='split';o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string');t=fillmissing(readtable(file,o),'constant',"");
if isempty(t),error('psy:GLMInput','Empty table: %s',file);end
end
