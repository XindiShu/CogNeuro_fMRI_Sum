function cfg=dcm_config
%DCM_CONFIG 任务bilinear或静息spectral DCM；调用SPM原生估计，不自动猜网络。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.manifestFile=fullfile(root,'config','dcm_runs.tsv'); % [必改] subject/session/run/data_file；data_file内需data结构，见新DCM说明。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_dcm'); % [必改] 新绝对结果目录，禁止覆盖。
cfg.execute=false; % [可调] false校验数据和网络；true写准备文件并按estimate估计。
cfg.estimate=true; % [可调] false仅准备DCM；true实际原生反演并检查后验。
cfg.mode='task'; % [可调] task=确定性单状态bilinear；spectral=静息交叉谱。
cfg.models=struct('id',{},'a',{},'b',{},'c',{}); % [必改] 每个模型明确id/A/B/C二值掩膜；A行=接收节点、列=发送节点，必须包括自连接。
cfg.options.maxIterations=128; % [可调] 正整数；工程低迭代并不等同充分收敛。
cfg.options.arOrder=8; % [可调] spectral多变量AR阶数，正整数且至少4倍阶数的时间点。
cfg.options.centerInputs=true; % [可调] task输入是否中心化；实际值随模型保存。
cfg.continueOnError=false; % [可调] true逐run记录失败继续，false保留已完成模型后停止。
end
