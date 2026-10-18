function cfg=dcm_group_config
%DCM_GROUP_CONFIG 一被试一已估计DCM的PEB及原生模型缩减/平均。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','dcm_group.tsv'); % [必改] subject/dcm_file清单，可附数值协变量。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_dcm_group'); % [必改] 新绝对目录，不在个体模型目录写结果。
cfg.execute=false; % [可调] false预检所有后验与设计；true估计PEB。
cfg.covariateColumns={}; % [可调] 清单数值列，自动总体中心化；截距始终保留。
cfg.fields={'A'}; % [可调] 后验参数字段，如{'A','B'}；不能混同不同模型类型/区域顺序。
cfg.maxIterations=64; % [可调] PEB最大迭代，正整数。
cfg.reduceAndAverage=true; % [可调] true调用spm_dcm_peb_bmc做BMR/BMA；false仅PEB。
cfg.modelMasks=[]; % [可调] 空用SPM自动缩减搜索；非空为候选模型×所选参数的0/1矩阵。
end
