**认知神经 fMRI 插件：GitHub／本地来源发行版 0.1.0**

包含现有 `cogneuro-fmri` skill 0.4.0 和新的 `cogneuro-setup` 首次配置向导。预处理、GLM、Function三个现成工具包继续独立安装，插件通过用户提供的实际路径调用它们。插件适用于能访问用户文件和启动MATLAB的本地执行环境。

本发行版可从自己的GitHub仓库或本地插件来源安装，无需进入官方公共插件目录。当前版本不包含MATLAB/SPM，不自动下载工具包或第三方依赖，不需要MCP服务器。插件结构依据 [OpenAI官方打包说明](https://developers.openai.com/plugins/build/plugins)，本地执行要求依据 [官方桌面插件说明](https://developers.openai.com/plugins/deploy/desktop-only)。

**本地安装**

下载并解压完整的 `cogneuro-fmri-marketplace-0.1.0.zip`。选择直接包含 `.agents`、`plugins` 和本文件的根目录，例如 `E:\NeuroPlugins\cogneuro-fmri-marketplace`。在支持以下命令的本地Codex CLI中添加来源并安装：

```powershell
codex plugin marketplace add 'E:\NeuroPlugins\cogneuro-fmri-marketplace'
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

也可在客户端插件目录中选择已添加的“认知神经 fMRI 工具包”来源，再安装插件。如果客户端未出现新来源或插件，重新打开客户端后检查。不同客户端版本的命令和界面可能不同；先运行 `codex plugin --help`。当前开发机器CLI提供 `plugin marketplace add` 和 `plugin add`。

如果已安装独立版同名 `cogneuro-fmri` skill，安装插件后请核对选择器中实际使用的副本；可将旧独立版备份到技能发现目录之外，避免重复同名入口。插件封装和安装说明不会自动删除旧版。

**GitHub安装**

维护者将本目录内容放到GitHub仓库根目录，保留隐藏的 `.agents/plugins/marketplace.json` 和 `plugins/cogneuro-fmri`。用户随后可以添加该仓库作为插件来源：

```text
codex plugin marketplace add OWNER/REPO --ref RELEASE_TAG
codex plugin add cogneuro-fmri@cogneuro-fmri-tools
```

`OWNER/REPO` 与 `RELEASE_TAG` 需换成维护者发布后的真实地址和tag。当前发行没有预设GitHub地址，也不宣称已上线。向GitHub上传时应提交解压后的目录内容，而不是只把一个ZIP放进仓库；Release可另外附上两个ZIP和SHA256文件。

**首次配置与使用**

安装后选择插件的配置入口，或明确发送：

```text
请使用 $cogneuro-setup，帮我配置已有的三个工具包、MATLAB/SPM和工作目录。
```

向导会核对用户提供的路径，在插件之外保存环境档，并报告缺项。已有环境档时可以提供其路径重新检查。配置过程只检查文件与源码，不启动研究分析。软件文件存在并不代表MATLAB许可、全部第三方依赖或研究模型已有效。

后续研究可发送：

```text
请使用 $cogneuro-fmri，先读取我的环境档 E:\fMRI_Projects\cogneuro-environment.local.json。
数据路径是 E:\Data\Study01，新项目目录是 E:\fMRI_Projects\Study01_001。
请先询问从哪一步做到哪一步、实验范式和研究目标，完整方案确认后再执行。
```

环境档路径由用户选择，新会话需提供路径。详细说明见 [INSTALL_ZH.md](INSTALL_ZH.md)。完成状态与验证范围见 [VALIDATION.json](VALIDATION.json)。

**交付范围与发布前事项**

插件ZIP含 `plugin.json`、两个skills、配置辅助脚本与验证用例；完整来源ZIP另外含marketplace、安装说明和打包脚本。主分析skill的39个文件与独立0.4.0保持相同字节。不会随包分发研究数据、结果、日志或用户环境档。

项目许可证与权利人尚未由作者确定，本次没有擅自添加许可证或填写虚构作者/仓库信息。三个工具包和已有第三方许可继续按原包处理。作者选择许可证后，再补充相应文件及插件元数据。GitHub来源安装属于客户端支持的分发方式，不代表官方目录审核或背书。
