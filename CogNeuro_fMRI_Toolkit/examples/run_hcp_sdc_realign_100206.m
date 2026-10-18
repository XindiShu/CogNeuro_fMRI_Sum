%RUN_HCP_SDC_REALIGN_100206 从已校正的 BOLD 重新估计头动，独立新分支。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'matlab'),fullfile(root,'config'));
cfg=toolkit_config;
cfg.manifestFile=fullfile(root,'examples','hcp_100206_sdc_runs.tsv'); % [示例] 本例 TSV；其他研究复制并替换各 run 的影像/T1/完成记录路径。
cfg.outputRoot=fullfile(root,'derivatives','hcp_sdc_realign_validation'); % [示例] 新的 SPM 输出目录，不能沿用未校正分支。
cfg.spmPath='D:\matlab\atoolbox\spm12'; % [必查] 本机 SPM12 安装目录，其他电脑替换。
cfg.inputStage='sdc_corrected'; % [限制] 清单每行须匹配 sdc_corrected，且仅含畸变校正后、头动校正前影像。
cfg.distortionCorrection='already_applied'; % [限制] 只有完成记录/provenance 与输入影像匹配才声明已校正。
cfg.stopAfter='realign'; % [可调] 首次验证停在头动+QC；核查后可在新输出目录改 smooth。
cfg.execute=true; % [示例] 对已经通过校正 QC 的示例执行真实 SPM；先检查可设 false。
cfg.continueOnError=false;
report=psy.preprocess_batch(cfg);
disp(struct2table(report,'AsArray',true));
