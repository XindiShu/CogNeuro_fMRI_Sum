**认知神经 fMRI 工具包与 Codex 插件**

本仓库提供已经完成的三个计算工具包，以及调用它们的 Codex skill／本地执行插件。插件负责检查环境、盘点数据、逐步询问研究目标和实验范式、生成清单、确认参数并调用现成入口。MATLAB/SPM 分析计算由原工具包承担。

**目录与下载**

| 内容 | 当前入口 |
| --- | --- |
| 预处理、混杂与 QC | [CogNeuro_fMRI_Toolkit](CogNeuro_fMRI_Toolkit/) |
| GLM、LSA/LSS、结果与 beta 导出等 | [GLM](GLM/) |
| FC、PPI/DCM、预测、解码、RSA 等方法 | [Function](Function/) |
| 插件 0.1.1 完整来源包 | [下载ZIP](CogNeuro_fMRI_Plugin/0.1.1/cogneuro-fmri-marketplace-0.1.1.zip) |
| 插件安装与首次配置 | [安装教程](CogNeuro_fMRI_Plugin/0.1.1/cogneuro-fmri-marketplace/INSTALL_ZH.md) |
| 独立 skill 0.4.0 | [下载ZIP](CogNeuro_fMRI_Skill/cogneuro-fmri-0.4.0.zip) |
| 独立 skill 安装教程 | [详细教程](CogNeuro_fMRI_Skill/INSTALL_AND_FIRST_RUN_ZH_0.4.0.md) |

本次保留提供目录中的历史发行包；首次使用优先选择插件0.1.1或独立skill0.4.0。两者择一安装可避免同名skill重复出现。三个工具包保留各自内部结构，放在用户选择的目录，不要求D盘。

**从本仓库安装插件**

在支持本地插件来源的 Codex CLI 中执行：

```powershell
codex plugin marketplace add XindiShu/CogNeuro_fMRI_Sum
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

本仓库根目录的 `.agents/plugins/marketplace.json` 指向随仓库保存的0.1.1插件。无需进入官方公共目录；客户端版本和组织策略需允许该来源。新增来源未显示时重新打开客户端检查。

安装后明确调用：

```text
请使用 $cogneuro-setup，配置已有的三个工具包、MATLAB/SPM和工作目录，先不运行分析。
```

向导会将实际路径保存到用户选定的插件外环境档。后续研究可使用：

```text
请使用 $cogneuro-fmri，先读取我的环境档，再检查我提供的数据路径。
请逐步询问从哪一步做到哪一步、实验范式和研究目标，检查缺项，
填写真实清单并解释参数，完整方案经我确认后再执行。
```

**运行环境与范围**

skill基础脚本需要Python3.10+，只使用标准库。调用MATLAB入口需要完整MATLAB及所选方法的依赖；现有工具包记录实测MATLAB R2025b、SPM12 revision7771。SPM、FSL/CAT、GIFT、BrainSpace、BCT、PCM、GLHMM、PyDDM等按实际路线核对，不能将来源表中的全部参考项视为必装依赖。插件不附带MATLAB/SPM或这些可选安装。

插件封装检查与工具包科学验证分别记录。插件／skill的完成记录不代替原方法约束、模型收敛和研究质量检查。已有验证边界见各包当前说明和插件中的VALIDATION.json，不因上传而新增数值验证声明。

**本次发布文件与许可状态**

上传使用作者提供的独立副本，保留各工具包、配置和用户文档的当前字节。根目录[PUBLICATION_MANIFEST.json](PUBLICATION_MANIFEST.json)记录本次源码及附件的SHA256；原包已有清单保留原样，其中部分文档和一个已缺失文件与旧清单存在差异，具体列在该新清单的upstream_manifest_notes中，没有恢复旧内容。

项目作者尚未选定自有内容的项目级许可证。本次上传没有代作者添加许可证；现有第三方许可证和来源声明保留在原位置。授权方式确定后可另行补充。
