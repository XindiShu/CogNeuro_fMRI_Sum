function cfg = qc_config
%QC_CONFIG 独立批量质控入口。适用于本工具包生成的 realign 目录。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.spmPath=fileparts(which('spm')); % [必查] 自动寻找 SPM，必要时改为安装目录。
cfg.inputRoot=fullfile(root,'derivatives','my_study_preproc'); % [必改] 已完成头动校正的批次目录，含各 run 的 input_info.mat。
cfg.outputRoot=fullfile(root,'derivatives','my_study_qc'); % [必改] 新的 QC 目录；不能等于或位于 inputRoot 内。
% FD 半径/阈值及信号掩膜比例沿用每个 run 的 input_info.mat 配置。
end
