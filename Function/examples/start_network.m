% network启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=network_config;
cfg.manifestFile='E:/my_study/network_runs.tsv';
cfg.outputRoot='E:/my_study/results/network_run01';
cfg.bctPath='D:/matlab/atoolbox/BCT_function_20261017/2019_03_03_BCT';
cfg.options.negativePolicy='drop';
cfg.options.densities=[.2 .3 .4];
cfg.nbsDataFile=''; % 需要NBS再提供独立单位矩阵
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_network(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
