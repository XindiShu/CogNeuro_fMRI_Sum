% encoding启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=encoding_config;
cfg.dataFile='E:/my_study/encoding_data.mat';
cfg.outputRoot='E:/my_study/results/encoding_run01';
cfg.options.method='ridge';
cfg.options.lambdaCandidates=[.1;1;10;100];
cfg.options.sampleKind='event_estimates';
cfg.options.lagsFrames=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_encoding(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
