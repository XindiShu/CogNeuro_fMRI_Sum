function cfg=rsa_ceiling_config
%RSA_CEILING_CONFIG 固定条件空间Pearson RDM噪声天花板及被试bootstrap。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','rsa_ceiling_data.mat'); % [必改] MAT含data.rdms(条件x条件x被试)/subjectIds/conditionIds，可选modelRDMs/modelNames。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_rsa_ceiling'); % [必改] 新目录。
cfg.execute=false; % [可调] false数值预检；true计算并写新目录。
cfg.options.nBootstrap=999; % [可调] 整被试有放回抽样整数>=0；条件固定，不是距离条目的bootstrap。
cfg.options.alpha=.05; % [可调] 边际percentile区间总alpha在(0,1)。
cfg.options.seed=173; % [可调] 重采样种子，退出恢复。
cfg.options.designNote=''; % [必改] 独立被试/家系、RDM估计方法及条件对应来源，不自动证明假设。
end
