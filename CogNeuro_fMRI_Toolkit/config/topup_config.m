function cfg=topup_config
%TOPUP_CONFIG 通用反向 PE 场图估计配置；run 路径和采集参数在各研究的 spec 中填写。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.outputRoot=fullfile(root,'derivatives','topup_study'); % [必改] 本研究的新输出根目录；不要指向原始数据或已有空间处理结果。
cfg.wslDistro='Ubuntu-24.04'; % [必查] 本机 WSL 发行版；运行 wsl -l -q 核对。
cfg.fslRoot='/home/bx210/fsl-topup'; % [必查] WSL 中 FSL 安装目录，必须含 bin/topup、bin/fslmerge。
cfg.fslConfig='/home/bx210/fsl-topup/etc/flirtsch/b02b0.cnf'; % [可调] TOPUP 配置；奇数维影像选 b02b0_1.cnf。
cfg.threads=4; % [可调] TOPUP 计算线程数，正整数；多被试并行时需按总 CPU 核心数调低。
cfg.affineTolerance=1e-4; % [可调] NIfTI 仿射矩阵元素检查容差；不等于头位配准容差。
cfg.execute=false; % [可调] false=仅验证并生成命令；核查采集元数据后设 true 估计场图。
cfg.applyToBold=false; % [限制] 默认不校正 BOLD；场图与 BOLD 头位配准、读出时间须另行验证。
end
