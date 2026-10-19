**认知神经 fMRI 工具包与 Codex 插件**

本仓库提供已经完成的三个计算工具包，以及调用它们的 Codex skill／plugin插件。MATLAB/SPM 分析计算由对应工具包承担，在此处不提供额外下载与包装。

本版新增参数“已改/未改/部分改”问询、逐项参数审阅与确认检查、完整工作流步骤/参数报告。三个分析工具包保持原样。

[新版Release与安装升级说明](https://github.com/XindiShu/CogNeuro_fMRI_Sum/releases/tag/v0.2.0)。

**目录与下载**

| 内容 | 当前入口 |
| --- | --- |
| 预处理、 QC | [CogNeuro_fMRI_Toolkit](CogNeuro_fMRI_Toolkit/) |
| 各类GLM | [GLM](GLM/) |
| FC、PPI/DCM、预测、解码、RSA 等具体方法 | [Function](Function/) |
| 插件 0.2.0 完整包 | [下载ZIP](CogNeuro_fMRI_Plugin/0.2.0/cogneuro-fmri-marketplace-0.2.0.zip) |
| 插件安装与配置教程 | [安装教程](CogNeuro_fMRI_Plugin/0.2.0/cogneuro-fmri-marketplace/INSTALL_ZH.md) |
| 独立 skill 0.5.0 | [下载ZIP](CogNeuro_fMRI_Skill/cogneuro-fmri-0.5.0.zip) |
| 独立 skill 安装教程 | [详细教程](CogNeuro_fMRI_Skill/INSTALL_AND_FIRST_RUN_ZH_0.5.0.md) |



**从本仓库安装插件**

在支持本地插件来源的 Codex CLI 中执行：

```powershell
codex plugin marketplace add XindiShu/CogNeuro_fMRI_Sum
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

本仓库根目录的 `.agents/plugins/marketplace.json` 指向随仓库保存的0.2.0插件。无需进入官方公共目录；客户端版本和组织策略需允许该来源。新增来源未显示时重新打开客户端检查。

安装后明确调用：

```text
请使用 $cogneuro-setup，配置已有的三个工具包、MATLAB/SPM和工作目录，先不运行分析。
```

向导会将实际路径保存到用户选定的插件外环境档。后续研究可使用：

```text
请使用 $cogneuro-fmri，先读取我的环境档，再检查我提供的数据路径。
请逐步询问从哪一步做到哪一步、实验范式和研究目标，检查缺项，
先询问我是否已修改参数，复核或配置后展示逐项对照表，等我确认再执行，最后生成完整步骤与参数报告。
```

**运行环境**

skill基础脚本需要Python3.10+，只使用标准库。调用MATLAB入口需要完整MATLAB及所选方法的依赖；现有工具包记录实测MATLAB R2025b、SPM12 revision7771无问题。
