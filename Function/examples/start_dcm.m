% dcm启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=dcm_config;
cfg.manifestFile='E:/my_study/dcm_runs.tsv';
cfg.outputRoot='E:/my_study/results/spectral_dcm_run01';
cfg.mode='spectral';
cfg.models=struct('id','full_two_node','a',ones(2),'b',[],'c',[]);
% 上例必须对应每个data.y恰好两列，且名称顺序完全相同
cfg.estimate=true;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_dcm(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
