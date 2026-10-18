function t=glm_contrast_table(contrasts,out,estimated)
%GLM_CONTRAST_TABLE 明确记录每个T/F输出的名称、类型和编号，不把F图当效应图。
n=numel(contrasts);index=(1:n)';name=string({contrasts.name})';stat=string({contrasts.stat})';
kind=string({contrasts.kind})';source_contrast=[contrasts.sourceContrast]';bin=[contrasts.bin]';
effect_path=repmat("",n,1);stat_path=effect_path;
for k=1:n
    if strcmp(contrasts(k).stat,'T')
        effect_path(k)=string(fullfile(out,sprintf('con_%04d.nii',k)));
    end
    stat_path(k)=string(fullfile(out,sprintf('spm%s_%04d.nii',contrasts(k).stat,k)));
end
estimated=repmat(logical(estimated),n,1);
t=table(index,name,stat,kind,source_contrast,bin,effect_path,stat_path,estimated);
end
