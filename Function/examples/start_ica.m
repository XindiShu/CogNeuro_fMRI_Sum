% ica启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=ica_config;
cfg.manifestFile='E:/my_study/prepared_voxels/prepared_runs.tsv';
cfg.outputRoot='E:/my_study/results/ica_run01';
cfg.giftPath='D:/matlab/atoolbox/gift_minimal_df369a2';
cfg.nComponents=5;
cfg.perRunPca=20;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_ica(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
