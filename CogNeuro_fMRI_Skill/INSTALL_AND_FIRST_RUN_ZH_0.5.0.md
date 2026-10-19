# CogNeuro fMRI v0.2.0：安装、升级与参数确认

本合集包含Plugin 0.2.0、分析Skill 0.5.0。三个计算工具包与v0.1.0逐字节相同；本版升级交互、确认与报告，不重写分析算法。

## 下载

从 https://github.com/XindiShu/CogNeuro_fMRI_Sum/releases/tag/v0.2.0 下载。初次使用选择三个工具包ZIP及cogneuro-fmri-marketplace-0.2.0.zip；已有工具包无需重新下载。独立Skill用户改选cogneuro-fmri-0.5.0.zip，和Plugin择一安装。

## Plugin首次安装

在支持插件的Codex CLI执行：

```powershell
codex plugin marketplace add XindiShu/CogNeuro_fMRI_Sum --ref v0.2.0
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

也可解压完整marketplace ZIP，提供含.agents和plugins的根目录：

```powershell
codex plugin marketplace add 'E:\NeuroPlugins\cogneuro-fmri-marketplace'
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

已有同名来源时先核对它指向哪里。无需进入官方公共插件目录；实际支持以客户端及组织设置为准。

## 从旧Plugin升级

先保留插件外的环境档、数据和项目。结束正在进行的分析后，核对现有安装与来源：

```powershell
codex plugin list --json
codex plugin marketplace list
```

若仍指向旧本地目录或旧固定tag，可仅替换本插件及其专属来源：

```powershell
codex plugin remove cogneuro-fmri@cogneuro-fmri-tools
codex plugin marketplace remove cogneuro-fmri-tools
codex plugin marketplace add XindiShu/CogNeuro_fMRI_Sum --ref v0.2.0
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

这些命令替换插件安装和来源；研究目录与外部环境档继续保留。重启桌面客户端，在新对话中核对插件版本0.2.0，并选择其内置技能。选择器可能显示cogneuro-fmri:cogneuro-setup和cogneuro-fmri:cogneuro-fmri。客户端命令随版本可能不同，先查看本机`codex plugin --help`。

## 独立Skill安装

解压cogneuro-fmri-0.5.0.zip，将含SKILL.md的cogneuro-fmri目录放到`%USERPROFILE%\.codex\skills\cogneuro-fmri`；使用自定义Codex主目录时放到对应skills下。已有旧同名目录时先备份到技能发现目录之外，再换新版。重启并新建对话，明确调用$cogneuro-fmri。Plugin已内置它，无需重复安装独立版。

## 目录与首次配置

工具包位置可自选，例如E:/NeuroTools/CogNeuro_fMRI_Toolkit、E:/NeuroTools/GLM、E:/NeuroTools/Function。需要Python3.10+，以及选定路线实际需要的MATLAB/SPM等依赖；Plugin不提供这些软件。数据、工作父目录与环境档放在插件和工具包之外。

Plugin用户发送：

```text
请使用 $cogneuro-setup。
三个工具包分别在 <实际预处理路径>、<实际GLM路径>、<实际Function路径>。
MATLAB程序是 <实际matlab.exe>，SPM在 <含spm.m的目录>。
工作父目录是 <实际可写目录>，环境档另存到 <新的环境档JSON路径>。
先检查环境，不运行研究分析。
```

已有环境档可继续使用，让新版只读复查，变化时另存。独立Skill直接提供同样的路径信息即可，不含单独的setup技能。

## 新版研究对话

```text
请使用 $cogneuro-fmri，读取环境档 <路径>。
数据是 <数据路径>，本次项目是 <新的项目目录>。
目标是 <分析目标>。请先问清我是否已修改参数，复核或配置本项目参数，
展示全部适用参数及修改对照表，等我确认无误后再执行。
完成后给我完整步骤和参数报告，说明三个包各运行、复用或跳过了什么。
```

1. 未说明参数状态时，先回答“已经修改 / 尚未修改 / 部分修改”以及涉及文件。
2. 已改仍会复核并提出建议；未改会根据文档与资料生成项目配置；缺少真实采集或实验事实仍需补充。
3. 审阅旧值、有效值、修改/保留理由、单位、适用性和依据。提出修改后重新生成方案，直到明确确认。
4. 仅提供“已修改参数”不代表批准执行；系统运行权限提示也不代替参数确认。普通研究不会由Codex自行模拟用户同意。
5. 分析只调用所选原包入口，正式.m配置和原始输入保留。研究可能从已处理数据、已估计模型或矩阵起步，不要求每次三个包都运行。
6. 成功或执行失败后自动生成reports/编号/REPORT_ZH.md、report.json、steps.tsv、parameters.tsv。登记完整工作流时自动汇总子阶段；旧版缺失的确认信息标为未记录。结果解释与图表根据真实方法输出补充。

## 本版验证范围

136项Python连接/兼容/参数与报告检查、11项MATLAB哑入口检查、11项Plugin环境检查通过。新来源经本机原生plugin/read解析；既有LEiDA演示仅用于只读报告验证，没有重复计算。未宣称所有方法/推荐参数通过真实数据研究级验证；未做一次新的完整人类交互安装演示。

本版继续标为预发布。普通研究确认是记录真实回复的来源，不是独立人类身份认证。通用报告不替代方法专属诊断、人工QC或科学推断。
