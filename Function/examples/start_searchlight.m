% searchlight启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=searchlight_config;
cfg.catalogFile='E:/my_study/beta_catalog.tsv';
cfg.sourceId='lsa';
cfg.outputRoot='E:/my_study/results/searchlight_run01';
cfg.options.mode='decode';
cfg.options.radiusMm=6;
cfg.options.nPermutations=0; % 先查输入和分数；置换需另填假设说明
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_searchlight(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
