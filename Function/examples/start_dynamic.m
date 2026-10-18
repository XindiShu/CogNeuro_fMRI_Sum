% dynamic启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=dynamic_fc_config;
cfg.manifestFile='E:/my_study/prepared_roi/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/dynamic_fc_run01';
cfg.options.windowSeconds=[30 60 90];
cfg.options.stepSeconds=3;
cfg.options.taper='gaussian';
cfg.options.nSurrogates=0; % 0只做描述，确认输入后另设次数与新输出
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_dynamic_fc(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
