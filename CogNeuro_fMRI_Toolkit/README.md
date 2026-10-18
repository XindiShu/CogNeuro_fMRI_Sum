# fMRI 预处理工具包



## 开始使用

1. 将 [扩展清单模板](config/runs_extended_template.tsv) 复制为 config/runs.tsv，填写实际文件路径和逐 run 元数据。每行是一个 run；24 名被试各两个 run 填48行。填写方法见 [清单指南](docs/Run_Manifest_Guide.md)。
2. 在 [toolkit_config.m](config/toolkit_config.m) 修改路径、方法和参数。输出目录必须放在本工具包文件夹之外。不同研究或不同参数版本使用不同输出目录。
3. 保持 cfg.execute=false 运行 [run_toolkit.m](run_toolkit.m)，检查输入报告。确认后设为 true，再次运行该入口。
4. 查看每个 run 的状态、质量指标、掩膜和空间叠加。完成标记不替代人工质量检查。

[run_preprocessing.m](run_preprocessing.m) 是 HCP 数据发现示例，使用 [preprocess_config.m](config/preprocess_config.m) 的数据根目录和被试/run选择；一般研究使用通用清单入口。两个入口调用同一批量计算层。

## 各步骤说明

| 步骤           | 说明                                                                  |
| ------------ | ------------------------------------------------------------------- |
| 流程与输入        | [预处理工作流程](docs/PREPROCESSING.md)、[数据清单](docs/Run_Manifest_Guide.md) |
| Slice Timing | [采集顺序、参考时间与Microtime](<docs/STC_Slice Timing Correction.md>)        |
| 头动           | [Realignment与Unwarp](docs/Realignment.md)                           |
| 磁敏感畸变        | [SPM FieldMap、Apply VDM和FSL TOPUP](docs/SDC.md)                     |
| 功能与结构配准      | [Coregistration](docs/Coregistration.md)                            |
| 结构分割         | [SPM Segment、CAT12与图谱反变换](docs/Segmentation.md)                     |
| 标准化          | [Segmentation-based、DARTEL和Shooting](docs/Normalization.md)         |
| 平滑           | [Spatial Smoothing](<docs/Spatial Smoothing.md>)                    |
| 质量检查         | [FD、DVARS、tSNR和缺失值](docs/Engineering_QC.md)                         |

配置行号直接标在各步骤说明中，不再维护单独的逐行参数索引。



开发测试环境：MATLAB R2025b（25.2.0.2998904）；

SPM12（工具箱版本 7771）；

WSL为 发行版 Ubuntu-24.04，系统 Ubuntu 24.04.5 LTS，x86_64；

FSL/TOPUP Conda 包 fsl-topup 2203.6；topup --version 输出构建 ID 2412.6-dirty，applytopup --version 输出 1.0；

FLIRT 输出6.0。详细环境见：docs\FILE_CATALOG_AND_ENVIRONMENT.md


