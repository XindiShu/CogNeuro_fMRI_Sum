% extended启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=rest_extended_config;
cfg.manifestFile='E:/my_study/prepared_roi/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/entropy_acf_run01';
cfg.methods={'entropy','timescales'};
cfg.entropy.sampleM=2;
cfg.entropy.toleranceFraction=.2;
cfg.timescales.maxLagSeconds=10;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_rest_extended(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
