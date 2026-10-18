% beta启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=roi_patterns_config;
cfg.catalogFile='E:/my_study/beta_catalog.tsv';
cfg.roiFile='E:/my_study/roi_labels.nii';
cfg.sourceId='lsa'; % 与自己的目录一致
cfg.outputRoot='E:/my_study/results/roi_patterns_run01';
cfg.methods={'beta_series','decode','rsa'};
cfg.partitionColumns={'run'};
cfg.options.decode.task='classification';
cfg.options.rsa.metric='correlation';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_roi_patterns(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
