**插件安装与首次配置：0.1.1**

本教程对应插件0.1.1，内含分析skill0.4.0。三个计算工具包保持独立，放在自己的工具目录中；数据、工作项目和环境档放在插件目录之外。用户可以在没有D盘的机器上配置实际位置。

**准备**

需要支持本地插件来源的Codex客户端、Python3.10+，以及运行所选方法需要的MATLAB/SPM和依赖。工具包当前记录实测MATLAB R2025b、SPM12 revision7771；其他版本按实际路线核对。只有选定方法需要时，再安装FSL、CAT、GIFT、BrainSpace、BCT、PCM、GLHMM或PyDDM等依赖。

建议目录：

```text
E:\NeuroPlugins\cogneuro-fmri-marketplace\   完整插件来源包
E:\NeuroTools\CogNeuro_fMRI_Toolkit\         已有预处理包
E:\NeuroTools\GLM\                          已有GLM包
E:\NeuroTools\Function\                     已有分析方法包
E:\NeuroTools\spm12\                        按路线需要的SPM
E:\Data\Study01\                            研究数据
E:\fMRI_Projects\                           可写工作父目录
```

**安装入口**

下载完整来源ZIP并解压，确认根目录含 `.agents/plugins/marketplace.json`。在本地终端添加这个目录，安装插件：

```powershell
codex plugin marketplace add 'E:\NeuroPlugins\cogneuro-fmri-marketplace'
codex plugin list --marketplace cogneuro-fmri-tools --available --json
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

如果使用客户端插件目录，可在添加来源后从该来源安装。不要把完整插件来源包复制到 `.agents/skills`；那个目录用于独立skill。`cogneuro-fmri-plugin-0.1.1.zip`是单插件组件包，包含直接的 `plugin.json`，面向维护者或已有marketplace的集成；首次用户采用完整来源ZIP。

GitHub发布仓库为 [XindiShu/CogNeuro_fMRI_Sum](https://github.com/XindiShu/CogNeuro_fMRI_Sum)。源码上传到仓库根目录后，可以改用：

```powershell
codex plugin marketplace add XindiShu/CogNeuro_fMRI_Sum
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

2026-10-18核对时仓库仍为空，本轮没有上传；远程命令待源码发布后生效。现在可使用已解压的本地来源目录安装。

**配置**

明确调用 `$cogneuro-setup` 或使用插件提供的配置入口，给出三个包的实际根目录、MATLAB程序、SPM位置和工作父目录。先建立可写工作父目录，例如 `E:\fMRI_Projects`；各次研究的新项目目录以后再由分析skill创建。

```text
请使用 $cogneuro-setup。
预处理包：E:\NeuroTools\CogNeuro_fMRI_Toolkit
GLM包：E:\NeuroTools\GLM
分析方法包：E:\NeuroTools\Function
MATLAB程序：C:\Program Files\MATLAB\R2025b\bin\matlab.exe
SPM目录：E:\NeuroTools\spm12
工作父目录：E:\fMRI_Projects
请把环境档保存为 E:\fMRI_Projects\cogneuro-environment.local.json。
先检查路径和缺项，暂不运行分析。
```

这些位置都是示例。SPM根目录须含 `spm.m`；MATLAB路径须指向程序文件。首次配置会记录实际运行辅助脚本的Python。专用HMM/DDM的Python环境在选择方法时另行确定。

向导不要求用户手工写JSON。它将路径保存为用户选定的新环境档，不覆盖旧环境档，也不改三个包内的正式配置。环境档含本机路径，通常不应提交GitHub。`paths_recorded`表示路径与源码记录已保存，不表示全部方法已可执行。

**开始研究**

```text
请使用 $cogneuro-fmri，先读取 E:\fMRI_Projects\cogneuro-environment.local.json。
数据在 E:\Data\Study01，本次新项目请用 E:\fMRI_Projects\Study01_001。
请先核对环境，询问起止阶段、范式和目标，检查缺项并整理清单和参数，
完整方案确认后调用现有工具包。
```

`Study01_001`须为尚不存在的新目录，并与数据、工具包、插件和SPM目录分开。已有分析项目则让skill读取状态，不重新创建或覆盖。数据可从原始NIfTI、已预处理数据、已估计GLM、beta或方法所需的矩阵/行为文件起步，按实际目标选择路线。

如果新会话没有环境路径，Codex会询问；插件没有把机器路径自动写成全局记忆。新环境或工具包更新后，用配置向导只读复查，原文件发生变化时另存新环境档供审阅。

**常见问题**

| 情况 | 处理 |
| --- | --- |
| 未找到codex命令 | 使用已安装客户端支持的插件来源入口，或配置对应版本的Codex CLI；先查看其帮助。 |
| 看不到插件来源 | 核对选择的是含 `.agents` 的完整根目录；检查命令是否成功，重新打开客户端。 |
| 同名skill出现两份 | 核对插件版与独立版位置，旧版可备份到发现目录之外；不要自动覆盖研究输出。 |
| 找不到MATLAB/SPM | 核对执行机器、目录访问权和实际程序/根目录；插件不会替用户安装或提供MATLAB许可。 |
| 目录或原包文件改变 | 用配置向导复查；报告差异并重审，不直接修改历史环境档。 |
| 只有部分工具包 | 可先记录已安装部分，选定后续路线时补齐相关包；不声称所有路线可运行。 |
| 想从GitHub安装 | 等源码上传到XindiShu/CogNeuro_fMRI_Sum后，按上面的命令添加来源；已有发布tag时可固定版本。 |

插件不需要进入官方公共目录才能通过本地/GitHub来源安装。客户端版本和组织管理策略仍可能影响是否允许第三方来源。依据见 [OpenAI插件来源与安装文档](https://developers.openai.com/plugins/build/plugins)。
