% gradient启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=gradient_config;
cfg.manifestFile='E:/my_study/gradient_inputs.tsv';
cfg.outputRoot='E:/my_study/results/gradients_run01';
cfg.brainSpacePath='D:/matlab/atoolbox/BrainSpace_function_20261017/matlab';
cfg.options.approach='dm';
cfg.options.alignment='pa';
cfg.options.nComponents=3;
cfg.spatialNullFile=''; % 有对应marker/空间模型再填写
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_gradients(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
