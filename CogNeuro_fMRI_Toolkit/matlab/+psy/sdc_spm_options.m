function options=sdc_spm_options(cfg)
%SDC_SPM_OPTIONS 为旧配置补默认值；新菜单集中在配置，计算层不修改参数。
options=struct('matchVdm',true,'writeReferenceEpi',false, ...
    'referenceEpi','first','referenceVolume',1,'magnitudeVolume',1, ...
    'distortionAxis','metadata','resliceImages','all_mean','outputPrefix','u');
names=fieldnames(options);
for k=1:numel(names)
    if isfield(cfg.sdc.spm,names{k}), options.(names{k})=cfg.sdc.spm.(names{k}); end
end
for name={'referenceEpi','distortionAxis','resliceImages','outputPrefix'}
    options.(name{1})=char(string(options.(name{1})));
end
end
