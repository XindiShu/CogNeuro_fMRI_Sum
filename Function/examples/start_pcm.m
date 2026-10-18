% pcm启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=pcm_config;
cfg.manifestFile='E:/my_study/pcm_subjects.tsv';
cfg.outputRoot='E:/my_study/results/pcm_run01';
cfg.pcmPath='D:/matlab/atoolbox/pcm_toolbox-master/pcm_toolbox-master';
cfg.conditionLabels={'A','B','C'}; % 必须与数据和模型顺序一致
cfg.models={struct('name','independent','type','fixed','Gc',eye(3))};
cfg.options.mode='individual';
cfg.options.allowEngineeringNoise=false;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_pcm(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
