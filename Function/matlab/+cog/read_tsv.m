function t=read_tsv(file,required)
%READ_TSV 全部先作为字符串读取，保留前导零与空session。
if nargin<2,required={};end
if ~isfile(file),error('cog:Table','Missing table %s',file);end
o=detectImportOptions(file,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
o=setvartype(o,o.VariableNames,'string');o=setvaropts(o,o.VariableNames,'WhitespaceRule','preserve');
t=readtable(file,o);for j=1:width(t),t.(j)(ismissing(t.(j)))="";end
if ~all(ismember(required,t.Properties.VariableNames)),error('cog:Table','Missing required columns');end
end
