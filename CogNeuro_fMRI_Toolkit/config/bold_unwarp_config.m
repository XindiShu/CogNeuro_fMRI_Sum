function cfg=bold_unwarp_config
%BOLD_UNWARP_CONFIG 用已估计的 TOPUP Hz 场校正原始 BOLD；每个 run 的文件见 spec。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.outputRoot=fullfile(root,'derivatives','bold_unwarp_study'); % [必改] 新输出目录；不得与原始数据或旧预处理目录重合。
cfg.wslDistro='Ubuntu-24.04'; % [必查] 本机 WSL 发行版名称，可用 wsl -l -q 核对。
cfg.fslRoot='/home/bx210/fsl-topup'; % [必查] 包含 fslmaths、fugue、flirt、convertwarp、applywarp 的 FSL 环境。
cfg.affineTolerance=1e-4; % [可调] BOLD/SBRef 和场图/SE 参考各自的 NIfTI 仿射矩阵元素容差。
cfg.registrationSearchDegrees=10; % [可调] SE 模拟畸变图配准到 SBRef 的旋转搜索范围 ±角度；较大头位差可调高。
cfg.jacobianModulation=true; % [可调] 是否乘畸变场的 Jacobian；默认保持局部强度/体积调制。
cfg.execute=false; % [可调] false=仅检查并生成命令；确认元数据后设 true 执行真实校正。
end
