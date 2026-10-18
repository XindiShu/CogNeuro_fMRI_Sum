% multivariate启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=multivariate_config;
cfg.dataFile='E:/my_study/multivariate_data.mat';
cfg.outputRoot='E:/my_study/results/pls_run01';
cfg.method='pls_covariance';
cfg.options.nComponents=1;
cfg.options.crossValidate=false; % 有明确cvGroups再true
cfg.options.nPermutations=0;
cfg.options.nBootstrap=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_multivariate(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
