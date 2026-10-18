function value=glm_highpass_rank(filters)
%GLM_HIGHPASS_RANK 各run独立高通基的总秩；不能拼接后误当一个run。
value=0;
for k=1:numel(filters),value=value+rank(filters(k).X0);end
end
