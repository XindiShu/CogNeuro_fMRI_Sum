function cfg=glm_outputs_config
%GLM_OUTPUTS_CONFIG 已估计模型的结果导出、统一beta目录与ROI读取；不重新拟合。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.mode='results'; % [可调] results/betas/both；均只读取已完成模型，不涉及连接分析。
cfg.spmPath=fileparts(which('spm')); % [必查] SPM安装目录；需可调用统计分布及spm_clusters。
cfg.outputRoot=fullfile(tempdir,['glm_outputs_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]); % [可调] 必须为新目录；不要把运行结果放入干净发布目录。
cfg.results.manifestFile=fullfile(root,'config','glm_results.tsv'); % [结果必改] id/spm_mat/contrast_index；参考glm_results_template.tsv。
cfg.results.correction='fwe'; % [可调] none=未校正；fwe=SPM体素/峰高FWE；fdr=体素BH-FDR；每个对比单独一个检验族。
cfg.results.alpha=0.05; % [可调] 概率，0<值<0.5；不自动校正多个模型/对比/ROI之间的多重性。
cfg.results.tail='positive'; % [可调] T:positive/negative/two_sided；F仅positive（上尾）；双侧FWE每侧alpha/2。
cfg.results.minClusterVoxels=0; % [可调] 非负整数；仅簇大小显示过滤，不是簇水平校正。
cfg.results.connectivity=18; % [可调] 6/18/26邻接；双侧T的正负簇分别标记。
cfg.results.backgroundFile=''; % [可调] 可选同空间3D背景图；仅绘图时按affine采样，不配准或改写输入；空用模型mask背景。
cfg.results.plot=true; % [可调] 保存三正交切面PNG；空结果也生成明确的无过阈值结果图。
cfg.results.writeVoxelTable=false; % [可调] true额外输出所有保留体素的坐标/统计量/p/q；大图可能很大。
cfg.results.roiManifestFile=''; % [可调] 空跳过ROI效应提取；否则roi/mask_file/label清单，提取未阈值化con效应，F不提供效应。
cfg.betas.manifestFile=fullfile(root,'config','glm_beta_sources.tsv'); % [beta必改] id/engine/source_dir/variant；framework、single_trial、glmsingle。
cfg.betas.writeMatrix=true; % [可调] true保存[估计单元×共同掩膜体素]single矩阵及坐标；不跨run自动平均。
cfg.betas.maxMatrixGiB=1; % [可调] single矩阵大小上限，GiB，>0；不保证峰值内存仅有这一份矩阵。
cfg.betas.roiManifestFile=''; % [可调] 空跳过ROI；否则同网格ROI清单；矩阵与ROI均使用所有估计单元掩膜交集。
cfg.roi.emptyPolicy='nan'; % [可调] nan=无足够体素时输出NaN及状态；error=明确报错；不补零、不插补。
cfg.roi.minVoxels=1; % [可调] 每ROI交集内最少体素数，正整数；ROI由使用者预先指定。
end
