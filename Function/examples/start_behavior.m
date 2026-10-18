% behavior启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=behavior_config;
cfg.manifestFile='E:/my_study/behavior_runs.tsv';
cfg.outputRoot='E:/my_study/results/rw_run01';
cfg.method='rw_softmax'; % DDM改为ddm并填写Python路径
cfg.actionLabels={'left','right'};
cfg.pythonExecutable='D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_behavior(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
