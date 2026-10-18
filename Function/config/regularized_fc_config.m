function cfg=regularized_fc_config
%REGULARIZED_FC_CONFIG OAS收缩协方差/precision/partial，独立于原严格逆协方差FC。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','regularized_fc_runs.tsv'); % [必改] subject/session/run/data_file；MAT含data.y/featureIds。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_regularized_fc'); % [必改] 新目录。
cfg.execute=false; % [可调] false预检，true计算。
cfg.options.standardize=false; % [可调] true先按该run样本SD标准化；常数特征拒绝；false对原幅度协方差收缩。
cfg.options.maxFeatures=2000; % [可调] 正整数特征上限，O(p^2)内存/O(p^3)求逆，不是全脑体素默认。
end
