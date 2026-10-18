% reliability启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=reliability_config;
cfg.dataFile='E:/my_study/reliability_data.mat';
cfg.outputRoot='E:/my_study/results/icc_run01';
cfg.method='icc';
cfg.options.designNote='请改为实际的人/测量场合/项目及依赖设计';
cfg.options.nBootstrap=0;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_reliability(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
