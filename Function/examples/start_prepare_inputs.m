% prepare_inputs启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=prepare_inputs_config;
cfg.manifestFile='E:/my_study/analysis_runs.tsv';
cfg.outputRoot='E:/my_study/prepared_roi';
cfg.mode='roi'; % 供滑窗/状态/熵/OAS；ICA体素输入改voxels并换目录
cfg.clean.bandHz=[];
cfg.requireCommonFeatures=true;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_prepare_inputs(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
