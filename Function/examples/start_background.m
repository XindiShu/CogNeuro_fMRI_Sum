% background启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=background_config;
cfg.spmMat='E:/my_study/glm/p01/r1/SPM.mat';
cfg.maskFile='E:/my_study/mask.nii';
cfg.roiFile='E:/my_study/roi_labels.nii';
cfg.outputRoot='E:/my_study/results/background_p01_r1';
cfg.temporalState='unfiltered_unregressed';
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_background_fc(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
