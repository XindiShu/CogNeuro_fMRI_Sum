**认知神经 fMRI 工具包：用户安装、首次配置与使用教程**

适用交付：`cogneuro-fmri` skill 0.4.0，以及与该版本配套发布的预处理、GLM、Function 三个工具包。核对日期：2026-10-18。本文以 Windows 本地 Codex 为主；其他系统的安装路径见后文，未据此宣称完成跨平台分析验证。

skill 负责盘点数据、分轮提问、确认研究方案、生成清单和调用现成工具包。分析计算由三个工具包完成。安装 skill 不会同时安装 MATLAB、SPM 或其他第三方软件。

本文中的 `E:`、用户名、MATLAB 版本和文件夹都是路径示例，请换成自己的实际位置。使用者不需要具有 D 盘，也不需要复制作者的数据目录。

**1．需要下载哪些内容**

从维护者 GitHub 仓库的 Releases 页面下载同一套兼容版本中的以下内容：

| 内容 | 用途 | 解压后应保留的目录 |
| --- | --- | --- |
| `cogneuro-fmri-0.4.0.zip` | Codex 的交互向导和接口调用层 | `cogneuro-fmri` |
| 预处理工具包 ZIP | 预处理、混杂与 QC 等现成入口 | `CogNeuro_fMRI_Toolkit` |
| GLM 工具包 ZIP | GLM、LSA/LSS、结果与 beta 导出等现成入口 | `GLM` |
| 分析方法工具包 ZIP | FC、PPI/DCM、预测、解码、RSA 等现成入口 | `Function` |
| 本教程、校验文件、版本与许可证说明 | 安装、版本配对和使用条件 | 放在便于查阅的位置 |

三个工具包 ZIP 的准确文件名和版本号以维护者该次 Release 为准；0.4.0 是 skill 版本，不自动代表三个工具包也使用这个版本号。只运行部分分析时，实际需要的工具包取决于选定路线；首次安装完整系统可下载三个包。

GitHub 自动生成的 `Source code (zip)` 是仓库在对应 tag 的源码快照，和维护者手工上传的四个发行附件应分别辨认。优先按该 Release 的下载说明选择。[GitHub Releases 说明](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

**2．安装前准备软件**

| 软件 | 何时需要 | 本发布记录与配置要点 |
| --- | --- | --- |
| 能运行本地命令并访问本地文件的 Codex | 使用此 skill 时 | 使用本地项目；执行环境须能看到自己的工具包和数据路径 |
| Python 3.10 或以上 | skill 的扫描、规划和执行调度 | 基础脚本只用 Python 标准库；本机交付检查使用 Python 3.14，其他小版本按实际环境检查 |
| MATLAB | 调用 MATLAB 工具包时 | 当前工具包记录实测 R2025b；其他版本需检查相应函数与依赖兼容性 |
| SPM | SPM 预处理、GLM、PPI/DCM、SPM 图像读取等路线 | 当前工具包记录实测 SPM12 revision 7771；部分纯矩阵方法按原包要求判断 |

软件安装可参考 [Python Windows 下载](https://www.python.org/downloads/windows/)、[MATLAB 官方安装说明](https://www.mathworks.com/help/install/ug/install-products-with-internet-connection.html)和 [SPM 官方安装说明](https://www.fil.ion.ucl.ac.uk/spm/docs/installation/)。SPM 官网默认版本可能与当前包的实测版本不同，选择版本时以本次 Release 的兼容说明为准。

安装 Python 后，在 PowerShell 输入：

```powershell
python --version
python -c "import sys; print(sys.executable)"
```

记录第二条输出的 Python 可执行文件路径。若 `python` 不可用，可尝试系统已配置的 `py -3`，或使用 Python 程序的完整路径；之后的命令保持使用同一个解释器。

MATLAB 应能够正常启动并使用相应许可。在 MATLAB 中检查 SPM 时，可以运行以下几行，把示例路径换成自己的路径：

```matlab
addpath('E:/NeuroTools/spm12'); % 本机SPM根目录；应直接包含spm.m
which spm -all                % 检查实际发现的SPM，避免同时混用多个版本
spm('Ver')                   % 查看实际版本；不运行影像分析
```

本 skill 通过本地 MATLAB 程序启动独立进程。仅安装 MATLAB Runtime 或 SPM Standalone，不能直接视为已满足当前调用方式。使用 skill 本身不要求另外安装 MATLAB MCP；第三方方法是否需要其他 MATLAB 工具箱，由选定入口的原包说明决定。

**3．把三个工具包放在哪里**

三个工具包是普通代码目录，可以放在自己选择的磁盘上。建议放在一个稳定的工具目录下，保持每个包内部结构完整。例如：

```text
E:\NeuroTools\
  CogNeuro_fMRI_Toolkit\
    run_toolkit.m
    config\toolkit_config.m
    matlab\+psy\...
    docs\...
  GLM\
    run_glm.m
    config\glm_config.m
    matlab\+psy\...
    external\glmsingle\...
  Function\
    run_function.m
    config\function_config.m
    matlab\+cog\...
    DEPENDENCIES.tsv
  spm12\
    spm.m
```

确认提供给 Codex 的是直接包含对应 `run_*.m` 和 `config` 的包根目录。解压产生双层文件夹时，选择内层实际根目录；外层文件夹叫什么不影响调用。

不要把三个包的 `matlab`、`config` 合并成一个目录。预处理和 GLM 都含 `+psy` 名称空间，skill 按阶段使用独立 MATLAB 进程选择当前包。初次配置无需把三个包同时用 `addpath(genpath(...))` 永久加入 MATLAB。

使用 skill 时，数据清单、输出路径和研究参数在项目方案中绑定，并在内存中覆盖选定原生配置。一般不需要先手工修改安装包内的正式配置，也不需要照抄作者配置注释中的本机路径。示例默认路径不是你的真实数据。

**4．安装 skill：推荐手动安装完整文件夹**

当前 OpenAI 官方文档列出的个人 skill 位置是 `~/.agents/skills`，项目位置是 `.agents/skills`。本文新用户采用个人目录安装。[官方本地 skill 目录与加载说明](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills)

Windows 操作步骤：

1. 解压 `cogneuro-fmri-0.4.0.zip`。
2. 找到解压后的 `cogneuro-fmri` 文件夹，确认里面直接有 `SKILL.md`。
3. 在资源管理器地址栏输入 `%USERPROFILE%\.agents\skills`。目录不存在时先创建 `.agents`，再在其下创建 `skills`。
4. 将整个 `cogneuro-fmri` 文件夹放进去。

最终结构应为：

```text
C:\Users\你的用户名\.agents\skills\cogneuro-fmri\
  SKILL.md
  agents\openai.yaml
  assets\toolkit-registry.json
  scripts\fmri_project.py
  scripts\toolkit_catalog.py
  matlab\cogneuro_toolkit_dispatch.m
  references\...
  tests\...
  VALIDATION.json
  PACKAGE_MANIFEST.json
```

要安装完整文件夹，不能只复制 `SKILL.md`。以下双层结构需要调整：

```text
...\skills\cogneuro-fmri\cogneuro-fmri\SKILL.md
```

偏好 PowerShell 的用户也可以直接解压到个人 skill 父目录。下面的命令假定 ZIP 位于下载目录，且此前没有安装同名 skill；请先核对路径：

```powershell
# ZIP的位置；如果下载到了别处，修改这一行。
$fmriSkillZip = Join-Path $env:USERPROFILE 'Downloads\cogneuro-fmri-0.4.0.zip'
# 当前官方文档中的个人skill父目录。
$fmriSkillsParent = Join-Path $env:USERPROFILE '.agents\skills'
$fmriSkillDestination = Join-Path $fmriSkillsParent 'cogneuro-fmri'
if (Test-Path -LiteralPath $fmriSkillDestination) {
    throw '同名skill已存在：请先核对版本，将旧版本备份到skills目录之外，再安装。'
}
New-Item -ItemType Directory -Path $fmriSkillsParent -Force | Out-Null
Expand-Archive -LiteralPath $fmriSkillZip -DestinationPath $fmriSkillsParent
Test-Path -LiteralPath (Join-Path $fmriSkillDestination 'SKILL.md')
```

最后应输出 `True`。需要核对下载完整性时，执行以下命令，将结果与该 Release 提供的 SHA256 文件比较：

```powershell
Get-FileHash -LiteralPath $fmriSkillZip -Algorithm SHA256
```

本教程对应 ZIP 的 SHA256 为：

```text
7f0e60823679c83c73f433945fe6e176c3d0616a2d068ed9e89bc8be6d7a1458
```

作者当前机器的安装器仍将技能安装到 `$CODEX_HOME/skills`，默认是 `C:\Users\用户名\.codex\skills`，现有 0.4.0 已安装在该位置。若你的 Codex 安装器也返回此目录，并且已能识别 skill，可继续使用它；不要为跟随教程另装一个同名副本。以自己的 Codex 实际识别结果为准，无法识别时优先使用当前官方目录并检查禁用配置。

**5．让 Codex 识别 skill**

安装后在下一次交互检查 skill 选择器，寻找 `cogneuro-fmri` 或显示名“认知神经 fMRI 工具包向导”。Codex CLI/IDE 可使用 `/skills` 或输入 `$` 查找；本地界面布局随版本变化，以实际选择器为准。如果没有出现，重启 Codex 后再检查。[官方调用与更新说明](https://learn.chatgpt.com/docs/build-skills)

此 skill 设置为明确调用才启用。开始研究时，在提示词中写 `$cogneuro-fmri`。仅输入“帮我分析这些 fMRI 数据”，不应据此假定已经启用该 skill。

如果仍然找不到，请核对：当前登录的操作系统账户、`SKILL.md` 的层级、同名副本，以及 `~/.codex/config.toml` 中是否有针对该 skill 的 `enabled = false`。不要为了让 skill 出现而修改模型或关闭安全设置。

**6．数据、项目和工具包分开放置**

例如：

```text
E:\NeuroTools\...                  安装的三个工具包与第三方软件
E:\Data\Study01\...                已有研究数据
E:\fMRI_Projects\Study01_001\...    本次skill建立的新项目和结果
```

数据目录可以是原始 NIfTI、已预处理数据、已估计的 GLM 输出，或某种方法需要的 MAT/行为数据。只有实际方法需要 BOLD 时才要求 BOLD；仅有矩阵或行为文件不等于必须从预处理开始。

本次项目目录须为新的、尚不存在的目录，并位于数据目录、工具包、skill 和 SPM 目录之外。先在 Codex 打开可写的工作父目录，例如 `E:\fMRI_Projects`，再让 skill 创建 `Study01_001`。不要预先在这个新项目目录中放文件。已有 skill 项目再次使用时，提供原项目路径，让 Codex读取状态，避免再次扫描到同一个已有目录。

本地运行环境必须能读取工具包和数据，并能在项目目录写入。若 Codex 提示某个外部目录不可访问，按当前客户端支持的方式授予该目录访问或调整工作目录。纯云端环境看不到本机 `E:\...`，需要实际执行机器具备这些路径。

**7．首次配置：直接向 Codex 提供路径**

复制下面文字，改好路径后发送。MATLAB 可执行文件通常是安装目录下的 `bin\matlab.exe`，应提供程序文件路径；SPM 则提供直接包含 `spm.m` 的目录。

```text
请使用 $cogneuro-fmri。

这是我的首次使用，请先检查环境、工具包目录和数据，再逐步询问我。

预处理工具包：E:\NeuroTools\CogNeuro_fMRI_Toolkit
GLM工具包：E:\NeuroTools\GLM
分析方法工具包：E:\NeuroTools\Function
MATLAB程序：C:\Program Files\MATLAB\R2025b\bin\matlab.exe
SPM目录：E:\NeuroTools\spm12
数据目录：E:\Data\Study01
本次新项目目录：E:\fMRI_Projects\Study01_001

请先判断数据可能处于哪一步，并询问我希望从哪一步做到哪一步、
实验范式和最终研究目标。根据真实文件报告缺项，填写项目内清单，
解释并确认相关参数。先做到完整方案供我审阅，等我确认后再执行。
```

不知道 MATLAB/Python 位置时，可让 Codex 先查找候选位置并核对。不要把多个候选安装默认视为同一版本；确认实际要调用的版本。

首次需要提供比单独数据路径更多的环境信息。项目建立后，答案会保存在项目的计划修订与审阅记录中，后续可从该项目恢复。0.4.0 没有另设一个全机器共享的工具包路径配置安装器；新研究或新对话可以重复提供上述路径，也可提供已有项目供读取。

**8．Codex 会询问什么，用户需要提供什么**

| 类别 | 典型问题 | 可提供的依据 |
| --- | --- | --- |
| 当前阶段与终点 | 从原始数据预处理？已有预处理结果直接 GLM？已有 beta 做 RSA？ | 已有文件、处理记录及你的选择 |
| 实验范式 | 任务/静息、条件、事件或组块、被试/session/run 对应 | 实验设计、采集说明、行为日志 |
| 时间与单位 | TR、TE、onset/duration 单位、事件时间零点、删帧历史 | NIfTI/JSON 元数据、扫描协议、刺激程序日志 |
| 研究目标 | 哪个对比、预测变量、ROI、连接或模型比较 | 研究假设、预注册或已确定的分析计划 |
| 科学参数 | GLM 设置、混杂策略、ROI/模型结构、CV 分组等 | 当前原包选项、数据特点及你确认的选择 |
| 缺失材料 | 事件表、T1、场图、协变量、ROI、已估计 SPM 等 | 原始记录或现成文件的真实路径 |

Codex 应只问当前路线需要的信息；已有答案继续沿用。推荐参数应解释依据和适用范围。缺少真实事件时间、被试分组或 DCM 网络选择时，需要补充依据；不能用模板示例假造实验内容。

你可以提供原始日志，由 Codex 在确认列含义、时间单位、时间零点和条件映射后生成项目副本。现成 TSV 也可直接引用。用户不需要手工编写内部 `answers.json`、`native_config` 或接口登记文件。

文件名可以辅助发现候选，但不能证明数据已经正确完成去噪、空间配准或模型估计。需要结合来源与原包记录确认。

**9．按方法补充第三方依赖**

首次无需把所有可选依赖一起安装。确定方法后，由 Codex 读取该入口及当前包说明，核对需要的依赖和路径，补齐后继续。

| 所选路线 | 需要核对的额外内容 | skill 中的配置方式 |
| --- | --- | --- |
| SPM 预处理、经典 GLM、PPI/DCM | SPM 及路线需要的文件 | 准备时提供 SPM 根目录，核对解析后的 `spmPath` |
| FSL TOPUP/applytopup | 原包支持的 FSL 调用环境；Windows 路线涉及 WSL 与发行版/程序位置 | 核对当前预处理 `sdc` 配置与原包 `docs/TOPUP_INSTALL.md` |
| CAT 分割 | 与当前 MATLAB/SPM 兼容的 CAT 安装 | 确认 `segment.cat12.path` 和路线参数 |
| GLMsingle | GLM 包内已附带的固定版本及其原许可证 | 保留完整 `GLM/external/glmsingle`，核对原包 `glmsingle.path` |
| GIFT ICA | 官方 GIFT 中的所需 MATLAB 函数 | 确认 `giftPath` |
| BrainSpace 梯度/空间零模型 | BrainSpace MATLAB 目录 | 确认 `brainSpacePath` |
| BCT 网络方法 | 选定方法需要的 BCT 函数 | 确认 `bctPath` |
| PCM | 原生 PCM MATLAB 工具箱 | 确认 `pcmPath` |
| GLHMM HMM | 兼容的独立 Python 环境及 GLHMM | 确认该环境的 `pythonExecutable` |
| PyDDM DDM | 兼容的独立 Python 环境及 PyDDM | 确认该环境的 `pythonExecutable` |

上述名称是当前包原生字段，skill 在经确认的项目配置中设置它们。不要直接把作者注释里的路径作为自己的配置。Function 的详细来源、实测版本与是否随包提供，以 `Function/DEPENDENCIES.tsv` 为准；其部分条目只是方法参考或测试依据，不能把整张表当作必装清单。GLHMM/PyDDM 的专用 Python 环境与运行 skill 基础脚本的 Python 可以不同。

**10．审阅方案、执行与恢复**

方案形成后，Codex 会展示所选原生方法、纳入数据、实验信息、清单内容、相关参数与依据、依赖位置、输出目录和后续步骤。你应核对实际方案，再明确表示同意执行。初次试用可以先要求“只检查与规划，停止在待确认”。

需要区分两层准备：skill 通用 `prepare` 只加载配置并绑定输入，不调用原分析入口；若选择调用工具包自己的 `execute=false` 分支，那仍是一次需要确定范围的原包调用，可能进行该包自己的检查或准备。不能把配置读取成功理解为数据内部、模型和依赖都已通过。

当前每次调用会创建新的执行目录；典型可查阅记录包括：

```text
Study01_001\
  inventory.json
  revisions\...
  execution\0001\
    review.md
    review.json
    inputs\...
    results\...
```

清单草稿保存在计划修订内，执行使用本次确认的输入。实际文件以项目内容为准；不是每个方法都产生相同类型的结果。多阶段任务由 Codex 按 skill 的说明读取真实产物、填写下游清单并依次调用原包。0.4.0 并未把任意研究目标转成一个无需解释的固定单命令流程。

后续可以这样恢复：

```text
请使用 $cogneuro-fmri，读取项目 E:\fMRI_Projects\Study01_001。
先报告最新计划和执行状态，保留已完成结果，再判断还缺什么。
```

报错时先读取失败记录与原包返回信息，保留输出；确认修复后使用新尝试。不要把成功分析覆盖重跑当作恢复状态的方法。工程上的完成状态不代替模型诊断或科学结论。

**11．可选：只读检查安装接口，不启动 MATLAB 分析**

通常交给 Codex 完成即可。需要手工排查时，在 PowerShell 中运行下面两条命令；三包位置需要修改，`--output` 必须是一个新的文件名：

```powershell
$fmriInstalledSkill = Join-Path $env:USERPROFILE '.agents\skills\cogneuro-fmri'
python -X utf8 "$fmriInstalledSkill\scripts\fmri_project.py" --help
python -X utf8 "$fmriInstalledSkill\scripts\toolkit_catalog.py" --preprocessing-root 'E:\NeuroTools\CogNeuro_fMRI_Toolkit' --glm-root 'E:\NeuroTools\GLM' --function-root 'E:\NeuroTools\Function' --output 'E:\fMRI_Projects\toolkit-catalog-first-check.json'
```

如果实际安装在 `.codex\skills`，只修改第一行的安装目录。0.4.0 对当前三包登记 40 个接口：36 个分析入口、1 个准备入口、2 个示例和1个开发校验入口。这个数字不等于40种独立算法；开发校验不作为研究分析路线，示例须明确选择。

接口目录主要核对源文件、签名、配置与模板关系。它不会据此证明每个方法数值正确、第三方依赖齐全或当前研究已满足模型约束。本版本已通过119项 Python 检查和10项模拟调用测试，通用接口未逐方法重新执行真实数据分析；详细边界见 skill 的 `VALIDATION.json`。

**12．常见问题**

| 问题 | 处理方式 |
| --- | --- |
| 没有 D 盘可以用吗？ | 可以。三包根目录由用户提供；示例磁盘不是安装要求。 |
| 解压在下载目录能用吗？ | 保持完整结构时可提供实际路径；长期使用建议放稳定目录，避免后续移动导致项目记录失效。 |
| skill 必须和三个包放一起吗？ | 不需要。skill 放 Codex 可发现的目录，三包放工具目录，数据和项目另放。 |
| 下载ZIP后可以直接上传聊天窗口安装吗？ | 本教程采用本地解压到skill目录；不把上传附件当作安装步骤。 |
| 在普通网页聊天中给本地路径能运行吗？ | 执行端须实际能看到该路径并运行 MATLAB；仅写路径不会把本机磁盘传给云端。 |
| 提示未找到 MATLAB/SPM？ | MATLAB 提供程序文件，SPM 提供含 `spm.m` 的根目录，核对执行端与权限及实际版本。 |
| 已预处理数据还会重做预处理吗？ | 应先确认来源和目标，再选择直接 GLM 或相应方法；由用户确认起止阶段。 |
| 缺少事件表，能自动生成吗？ | 有真实日志和映射依据时可转换；没有真实时序时需要补充。 |
| 后续能更换工具包位置吗？ | 可以，但旧项目的已记录路径/哈希会受影响；让 Codex 重新核对并建立新方案，不直接篡改旧审阅记录。 |
| 如何升级skill？ | 保留项目和结果，将旧skill备份到发现目录之外，再安装新版本并检查是否识别；避免同时保留多个同名副本。 |
| 可使用macOS/Linux吗？ | skill 文件可放 `~/.agents/skills/cogneuro-fmri`，三包可放自选目录；MATLAB程序、依赖、FSL调用方式要按系统核对，当前交付检查不代表全部跨平台路线已验证。 |

**13．维护者附录：GitHub具体发布什么**

四个 ZIP 可以组成手工安装的核心发行物。为了便于查看源码、定位问题和管理版本，建议同时在 GitHub 仓库保留可浏览的源码，而非只提交四个二进制附件。一个仓库可以采用下列布局；下面是建议结构，不是本教程已经替你创建的线上仓库：

```text
<repository>/
  README.md
  LICENSE
  INSTALL_AND_FIRST_RUN_ZH_0.4.0.md
  skills/cogneuro-fmri/...
  toolkits/CogNeuro_fMRI_Toolkit/...
  toolkits/GLM/...
  toolkits/Function/...
```

在对应 Git tag 的 Release 附加四个有明确版本的 ZIP、校验文件，并注明三包与 skill 的版本配对、实测环境、已验证范围和已知限制。教程可以放仓库并在 Release 链接。仓库名称、账号和实际 Release 下载地址应由维护者在发布时填入；本教程没有预设一个尚不存在的下载网址。

如果希望支持 `$skill-installer` 从 GitHub 直接安装，应提交解压后的 `skills/cogneuro-fmri/SKILL.md` 及完整配套文件，而不是只放一个 ZIP。发布后用户可以把真实仓库路径提供给安装器，例如：

```text
请使用 $skill-installer，从 <OWNER>/<REPO> 的 <RELEASE_TAG> 安装
skills/cogneuro-fmri。请告知实际安装目录，并检查当前Codex能否识别。
```

`<OWNER>`、`<REPO>`、`<RELEASE_TAG>` 都是占位符，发布时替换。这条指令只安装 skill，不会同时安装 MATLAB/SPM，也不会自动获取放在 Release 附件中的三个工具包。安装器实际返回目录可能与手工安装路径不同，用户应只保留一个有效同名安装。[官方安装器说明](https://learn.chatgpt.com/docs/build-skills#install-curated-skills-for-local-use)

当前 ZIP 是独立 skill 文件夹，不是插件安装包。它可以按本文手工安装。OpenAI 当前建议面向广泛用户分发时采用 plugin；若以后希望插件目录中的安装体验，可另外封装插件，仍调用同一套原包入口，无需重写分析方法。[官方分发建议](https://learn.chatgpt.com/docs/build-skills#distribute-skills-with-plugins)

对当前目录的只读核对发现：skill 与三个工具包根目录尚未提供项目级 `LICENSE`；GLM 包包含 GLMsingle/fracridge 的原有许可证。发布前需要项目作者确定自有代码的许可证，并保留已有第三方许可证与来源说明。本文没有代作者选择许可证，也没有更改已有工具包内容。

打包来源应为已核对的发行目录及skill目录，保留所需模板、原包文档和已附带依赖。不要把整个开发工作区、HCP数据、其他受试者数据、研究输出、日志、缓存或作者本机的第三方安装目录混入发行包。已有整理说明中尚待审核的文件，先按原有约定处理，不因写本教程而删除。额外依赖按各自上游来源安装，不应假定作者磁盘上的安装也已随 ZIP 发布。

本教程为独立新增文档。原三个工具包文档、正式配置、skill 0.4.0 ZIP和其哈希未因编写教程而改写。
