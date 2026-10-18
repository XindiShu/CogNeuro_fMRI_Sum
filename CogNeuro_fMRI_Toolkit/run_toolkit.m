% RUN_TOOLKIT 通用入口：先复制 config/runs_extended_template.tsv 为 config/runs.tsv，
% 每行填写一个 run 的 BOLD/T1 等真实文件路径；此入口脚本本身不填写数据路径。
% 在 config/toolkit_config.m 修改 manifestFile/outputRoot/方法与参数。
% execute=false 只预检；核对 batch_status.tsv 后设为 true 再运行本脚本。
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=toolkit_config; % [可调] 可替换为你复制保存的研究配置函数；计算函数不必修改。
report=psy.preprocess_batch(cfg);
disp(struct2table(report,'AsArray',true));
