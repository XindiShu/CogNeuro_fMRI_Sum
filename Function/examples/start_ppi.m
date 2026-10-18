% ppi启动模板：先另存到自己的study目录，再改E:/my_study路径和理论参数。
addpath('D:/Function');
setup_function('D:/matlab/atoolbox/spm12');
cfg=ppi_config;
cfg.spmMat='E:/my_study/glm/p01/r1/SPM.mat';
cfg.seedMask='E:/my_study/seeds/p01_seed.nii';
cfg.outputRoot='E:/my_study/results/ppi_p01_r1';
cfg.sessionIndex=1;
cfg.mode='gppi';
cfg.conditionIndices=[]; % []选该session全部条件
cfg.estimate=true;
cfg.execute=false; % 第一次仅预检；通过后改下一处开关并重新运行
report=run_ppi(cfg);
disp(report);
% 确认预检和配置后，将上方false改true重新运行。已有结果不覆盖，换outputRoot。
