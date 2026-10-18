# 预处理最终整合：文件清理候选审阅单

核对日期：2026-10-16。范围为当前实际存在的 `D:\CogNeuro_fMRI_Toolkit` 文件。本次只做清单与引用核查，**没有删除、移动任何已有文件，也没有执行预处理或重估已有结果**。

这里的“可删”指未来可以从干净发布副本移出；开发工作区的源码、测试和历史复现材料建议保留。选择以一般研究的 `run_toolkit.m` 为主，同时保留当前HCP适配入口、独立混杂/QC/去噪模块。

## 1. 审阅结论

当前发布包核对前有185个文件，含FILE_MANIFEST.json，总计1,841,358字节。它已经没有原始HCP影像或分析产物；本次精简的主要收益是减少重复入口和历史示例，而不是腾出大量磁盘空间。

- A类5项：建议优先从发布副本移出，共9,463字节。
- B类17项：仅在正式发布包不再附带HCP获取/历史验证示例时，按组移出，共27,128字节。
- 两类合计22项，36,591字节；所有候选当前均保留。

## 2. A类：优先清理的5项

| 文件 | 字节数 | 为什么可以从发布副本移出 |
| --- | ---: | --- |
| [run_language_realign.m](../run_language_realign.m) | 566 | 固定100206 LANGUAGE LR的早期头动验证入口；当前一般研究和HCP入口均不调用它。默认输出指向发布包内部derivatives，当前统一调度会拒绝这种输出位置。 |
| [run_language_smoke.m](../run_language_smoke.m) | 593 | 与前项同一被试、run及输出根目录，增加旧版头动结果检查；属于早期真实数据验证入口。当前主流程已直接记录和检查结果。 |
| [run_language_spatial.m](../run_language_spatial.m) | 1454 | 从早期language_realign_validation目录复制结果继续空间处理，固定旧文件名和100206路径；不是当前多被试清单入口。其历史复现实例应留在工作区。 |
| [config/hcp_language_config.m](../config/hcp_language_config.m) | 1162 | 早期LANGUAGE分析选项草案，含HRF/高通/ROI等下游设想；当前MATLAB代码中没有发现对它的外部调用。HCP入口实际使用preprocess_config.m。 |
| [scripts/getfsl_official.sh](../scripts/getfsl_official.sh) | 5688 | 预存的完整FSL安装器。当前TOPUP精简安装由install_topup_wsl.sh直接创建micromamba环境，没有调用它；移出发布副本不改变已安装的FSL。 |

这三个run_language脚本保存的是较早的验证方式；不同阶段用途仍有差别，不能说成字节重复。建议保留工作区里的原文件和已有输出，发布副本只保留正式入口。

## 3. B类：可整体移出的HCP示例与材料

| 文件 | 字节数 | 为什么可以从发布副本移出 |
| --- | ---: | --- |
| [docs/HCP_LANGUAGE.md](../docs/HCP_LANGUAGE.md) | 3314 | 早期HCP数据获取计划，保留了下载/访问背景，但结尾仍是尚未进行真实影像验证的历史状态。若正式包只面向一般研究，可移出为开发档案。 |
| [scripts/audit_hcp_headers.py](../scripts/audit_hcp_headers.py) | 1898 | HCP原始头信息与EV的专用离线审查，不在run_toolkit主流程中；保留通用NIfTI检查与运行预检。 |
| [scripts/extract_hcp.py](../scripts/extract_hcp.py) | 4329 | HCP ZIP的MD5核对与解压工具；对已经解压的数据运行预处理不调用它。移出会失去包内HCP解压入口。 |
| [examples/hcp_100206_runs.tsv](../examples/hcp_100206_runs.tsv) | 2285 | 100206的HCP绝对路径清单；通用TSV模板仍保留。 |
| [examples/hcp_100206_sdc_runs.tsv](../examples/hcp_100206_sdc_runs.tsv) | 495 | 100206校正后清单，与run_hcp_sdc_realign_100206.m成组取舍。 |
| [examples/hcp_100206_confounds.tsv](../examples/hcp_100206_confounds.tsv) | 505 | 100206混杂提取示例清单；通用混杂配置和模板仍保留。 |
| [examples/hcp_100206_sdc_confounds.tsv](../examples/hcp_100206_sdc_confounds.tsv) | 479 | 校正后混杂提取示例清单，与run_hcp_sdc_confounds_100206.m成组取舍。 |
| [examples/hcp_100206_denoise_engineering.tsv](../examples/hcp_100206_denoise_engineering.tsv) | 303 | HCP时间去噪工程示例清单，与validate_denoise_engineering.m成组取舍。 |
| [examples/hcp_language_lr_events.tsv](../examples/hcp_language_lr_events.tsv) | 272 | 本包HCP事件演示表。D:\GLM中有独立副本，其GLM示例读取自己的examples目录；本候选仅指预处理包中的这一份。 |
| [examples/recover_hcp_sdc_realign_100206.m](../examples/recover_hcp_sdc_realign_100206.m) | 1526 | 复用旧100206头动输出并修复有限值/QC的历史恢复实例；复现该旧流程需要它，通用finalize_realign函数仍保留。 |
| [examples/run_hcp_bold_unwarp_100206.m](../examples/run_hcp_bold_unwarp_100206.m) | 1537 | 对100206运行独立BOLD畸变模块的验证入口；通用计算与SDC指南附录仍保留。 |
| [examples/run_hcp_sdc_confound_design_100206.m](../examples/run_hcp_sdc_confound_design_100206.m) | 1496 | 100206校正后混杂设计验证入口；run_confound_design及其共享函数仍保留。 |
| [examples/run_hcp_sdc_confounds_100206.m](../examples/run_hcp_sdc_confounds_100206.m) | 2097 | 100206校正后组织/头动混杂提取验证入口；通用提取模块仍保留。 |
| [examples/run_hcp_sdc_realign_100206.m](../examples/run_hcp_sdc_realign_100206.m) | 1206 | 已校正100206 BOLD的独立头动验证入口；不由当前统一预处理入口调用。 |
| [examples/run_hcp_sdc_spatial_100206.m](../examples/run_hcp_sdc_spatial_100206.m) | 2612 | 从旧校正/恢复/结构结果继续空间处理的实例；若保留历史恢复示例，应与其上游脚本一起保留。 |
| [examples/run_hcp_topup_100206.m](../examples/run_hcp_topup_100206.m) | 2139 | 100206的独立TOPUP估场验证入口；当前统一流程与通用topup_run仍保留。 |
| [examples/validate_denoise_engineering.m](../examples/validate_denoise_engineering.m) | 635 | 名称看似通用，但实际读取hcp_100206_denoise_engineering.tsv，属于HCP工程演示。不可只删TSV而留下这个可运行示例。 |

B类适用于决定不随通用发布包附带HCP示例的情况；如果仍希望新使用者复现100206的旧验证过程，应保留相应整组。此类共14个examples文件、2个HCP维护脚本和1份早期数据获取计划。

## 4. 目前应保留的文件

| 文件或范围 | 保留原因 |
| --- | --- |
| `run_toolkit.m`、`config/toolkit_config.m` | 通用主入口与用户定稿的总配置。配置的当前字节和行号保留。 |
| `run_preprocessing.m`、`config/preprocess_config.m`、`matlab/+psy/preprocess_hcp.m`、`discover_hcp.m`、`export_hcp_manifest.m` | 当前HCP适配入口及数据发现/导出工具；它们把HCP命名规则与共享计算隔离，和早期run_language脚本不同。 |
| `matlab/+psy/`全部共享计算函数 | 六条SDC路线、DICOM/dummy、STC、头动、分割、配准、标准化、平滑、QC及公开辅助调用仍需要；不能以默认设置未走到某分支作为删函数理由。 |
| `topup_config.m`、`bold_unwarp_config.m`、`qc_config.m`及对应函数 | 独立模块的正式配置/接口；SDC和QC主指南仍说明其使用，测试也调用它们。 |
| `run_confounds.m`、`run_confound_design.m`、`run_denoise.m`及对应配置、模板、函数 | 独立混杂和时间去噪功能，统一空间预处理不会自动替代；任务GLM仍需符合其输入声明。 |
| 通用TSV/JSON模板与事件读取函数 | 为不同研究/场图/结构处理路线提供接口；不因当前HCP示例没用到而删去。 |
| 八篇预处理/QC主指南、PREPROCESSING、PREPROCESSING_ROUTE_MAP、Run_Manifest_Guide、File_Catalog_and_Environment | 理论、操作、输入、代码定位和主流程说明；本次保持它们的正文。 |
| `docs/figures/preprocessing_routes.png`、`.svg` | 路线图正文实际引用，分别用于预览与矢量查看。 |
| `docs/TOPUP_INSTALL.md`、`scripts/install_topup_wsl.sh`、`scripts/install_cat12.ps1` | 可选依赖的环境记录和安装工具；若移除未采用的getfsl_official.sh，未来只需在对应文档中说明该历史材料已移出。 |
| `scripts/verify_nifti_stream.py` | 通用只读NIfTI检查，不是HCP专用逻辑。 |
| `tests/`的25个文件、`validate_preprocessing.m` | 单元/手工集成验证和验收入口；不影响一般分析的直接运行，但完整可维护工具包建议保留。若将来另发纯运行版，可单独讨论省略这26项。 |
| `scripts/sync_final_copy.ps1`、`scripts/release_layout.json`、`FILE_MANIFEST.json` | 维护发布范围、GLM隔离、用户文档保护和实际文件哈希。 |

## 5. 以后真的删除时，需要一起处理什么

1. 同时更新发布范围，防止未来同步把刚移出的源码/示例再次复制回来；本次没有把候选加进排除表。
2. 获得对应文档的局部编辑授权后，修正目录页对已移出文件的介绍。当前候选仍在，因此本次没有改预处理目录页。
3. A类中的getfsl_official.sh在TOPUP_INSTALL及文件目录有文字提及；B类多项在文件目录中介绍。它们是文档引用，不是主流程运行调用。
4. HCP示例按组处理，尤其去噪脚本与TSV、校正后头动脚本与TSV、旧恢复结果与空间延续脚本。
5. 重新生成并核对发布清单。原始输入、已经成功的影像/模型结果和外部安装目录均不属于清理目标。

## 6. 本次核查的证据与边界

逐项读取候选内容并检查当前包中的文件名引用；从6个保留入口追踪psy命名空间调用和已知配置函数，共覆盖91个MATLAB文件。22个候选均未进入这一保守静态主调用集合。静态检查会保留可能的分支引用，不把缺少调用当成整个文件永远无用的证明；公开独立入口、测试和人工复现用途另行保留或注明。

本次未运行MATLAB/SPM/FSL，不新增数值或真实数据验证结论。历史的config/toolkit_config.asv、已退休的参数索引/生成器、以及旧TOOLKIT_GUIDE和INPUT_CONTRACT在当前D盘包中已不存在，未作为“待删文件”重复列出，也不恢复。
