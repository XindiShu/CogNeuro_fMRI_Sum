# 本机 TOPUP 安装记录（2026-10-07）

已安装 WSL2 Ubuntu 24.04，在 Ubuntu 的 Linux 文件系统 `/home/bx210/fsl-topup` 创建了独立 conda 环境。默认 Linux 用户为 `bx210`，不是 root。安装了 FSL 公共频道的 `fsl-topup 2203.6` 和 `fsl-avwutils 2209.8`；这是一套针对 TOPUP 的精简安装，并非完整 FSL 全家桶。

Windows PowerShell 中直接检查：

```powershell
wsl -d Ubuntu-24.04 -- /home/bx210/fsl-topup/bin/topup --help
wsl -d Ubuntu-24.04 -- /home/bx210/fsl-topup/bin/applytopup --help
wsl -d Ubuntu-24.04 -- /usr/local/bin/micromamba list -p /home/bx210/fsl-topup fsl-topup
```

TOPUP 常用配置位于 `/home/bx210/fsl-topup/etc/flirtsch/b02b0.cnf`。实际运行时，影像和参数文件必须使用 WSL 可访问的 Linux 路径，例如 Windows `D:\IBM\...` 对应 `/mnt/d/IBM/...`。读写大型影像通常更适合先把工作副本放到 Linux 文件系统；不要修改 `D:\IBM` 原始数据。

安装脚本为 `scripts/install_topup_wsl.sh`，使用官方 FSL conda 公共频道与 conda-forge；微型包管理器来自 conda-forge。预先下载的 `getfsl_official.sh` 是完整 FSL 安装器，本次精简安装没有运行它。Linux 路径、包版本和安装步骤没有写死在通用影像计算函数中。

已验证可执行文件启动、帮助输出、`applytopup`、`fslmaths` 与配置文件存在。后续已用 HCP 100206 LANGUAGE LR 的真实 SE-EPI 完成 TOPUP 场估计、场图到 SBRef 的配准和 4D BOLD 畸变校正，并在独立分支继续做 SPM 空间处理。当前统一入口的运行与 QC 状态见 [PREPROCESSING.md](PREPROCESSING.md) 和 [VALIDATION.md](VALIDATION.md)；安装成功本身不代表所有真实 run 的校正质量已审查。

从本机 MATLAB 调用 `system('wsl -d Ubuntu-24.04 -- /usr/bin/test -x /home/bx210/fsl-topup/bin/topup')` 返回状态 0，证明 MATLAB 可访问该 WSL 可执行文件。Windows/MATLAB 接收 WSL 的中文提示时可能遇到 UTF-16 输出截断，因此不要把 `topup --help` 的文本回显作为唯一成功判据；实际运行应核查进程退出码和预期输出文件。

依据：[FSL Windows/WSL 安装说明](https://fsl.fmrib.ox.ac.uk/fsl/docs/install/windows.html)、[FSL conda 安装说明](https://fsl.fmrib.ox.ac.uk/fsl/docs/install/conda.html)、[FSL TOPUP 用户指南](https://fsl.fmrib.ox.ac.uk/fsl/docs/diffusion/topup/users_guide/index.html)。
