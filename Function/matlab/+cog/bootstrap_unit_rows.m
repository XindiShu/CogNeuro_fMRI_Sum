function rows=bootstrap_unit_rows(unitIds)
%BOOTSTRAP_UNIT_ROWS 独立单位有放回抽样，其内部全部行一起保留。
unitIds=string(unitIds(:));units=unique(unitIds,'stable');if isempty(units)||any(ismissing(unitIds)|unitIds==""),error('cog:BootstrapUnits','Explicit nonempty independent unit IDs required');end
chosen=randi(numel(units),numel(units),1);rows=[];for k=1:numel(chosen),rows=[rows;find(unitIds==units(chosen(k)))];end %#ok<AGROW>
end
