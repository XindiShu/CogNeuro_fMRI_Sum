% linear_decode启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=linear_decode_config;
cfg.dataFile='E:/my_study/linear_decode_data.mat';
cfg.outputRoot='E:/my_study/results/svm_run01';
cfg.options.estimator='svm';
cfg.options.dependencyNote='请改为真实cvGroups定义及上游估计依赖';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_linear_decode(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
