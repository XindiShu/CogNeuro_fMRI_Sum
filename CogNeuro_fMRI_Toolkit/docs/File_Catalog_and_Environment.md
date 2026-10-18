# 工具包文件目录与本机环境备份

核查日期：2026-10-15。文件范围：`D:\CogNeuro_fMRI_Toolkit` 的当前实际内容。

本页逐项列出 **186 个文件**，包括本文件、发布清单及仍保留的编辑器备份。`D:\IBM` 是独立的 HCP 示例数据目录，不在工具包中；GLM/LSA/LSS 已分离到 `D:\GLM`，不列入此包逐文件清单。

所有 `E:/YOUR_DATA`、`D:/Study/...` 等路径都是占位示例，必须替换为自己的数据。

## 1. 文件夹与建议使用顺序

| 位置         | 当前文件数 | 内容及使用场景                 |
| ---------- | ----- | ----------------------- |
| `根目录`      | 12    | 入口、README 与发布哈希清单。      |
| `config`   | 27    | 参数函数、逐 run 清单和 JSON 模板。 |
| `docs`     | 16    | 步骤文档、总使用指南、路线图与本机环境记录。  |
| `examples` | 14    | 开发示例和旧验证入口，常规预处理无需逐个运行。 |
| `matlab`   | 84    | psy 包的可复用实现，由入口调用。      |
| `scripts`  | 8     | 按需使用的安装、解压、检查与发布工具。     |
| `tests`    | 25    | 单元/接口测试和手动集成验证。         |

常规使用顺序：**阅读路线图和总指南 → 填写清单/JSON → 修改配置 → execute=false 预检 → execute=true 后再运行同一入口 → 查看状态与 QC**。输出目录放在发布目录之外。

## 2. 哪些要改、哪些要手动运行

| 操作类        | 是否手动 Run               | 是否需要修改                                |
| ---------- | ---------------------- | ------------------------------------- |
| 主入口        | 是；一般研究运行 run_toolkit.m | 通常不改入口内部，修改配置和清单                      |
| 可选入口       | 按目的选用，不是必须全部运行         | 修改其对应配置；HCP 入口使用 preprocess_config.m  |
| 配置         | 不把配置函数当脚本 Run          | 根据研究修改参数/路径；toolkit_config.m 是主链主要设置处 |
| 模板         | 不运行                    | 按功能需要复制、填写真实信息并另存；由 TSV/配置关联          |
| 内部函数       | 常规不直接 Run              | 通常不改；开发修改后需验证，研究采集参数不写在此处             |
| 阅读         | 不运行                    | 可按需要维护文档；本页不是实时自动更新的文件浏览器             |
| 示例/验证/测试   | 常规预处理无需运行              | 仅复核对应功能时，按文件头核对数据、参数与外部输出目录           |
| 维护脚本/规则    | 安装、解压或发布时按需使用          | 路径/环境需核对；不作为每名被试的处理步骤                 |
| 自动生成/编辑器备份 | 不运行                    | 不手工改清单哈希；asv 不替代正式配置                  |

**使用统一入口时，不必再改独立的 topup_config.m、bold_unwarp_config.m、qc_config.m。** 对应设置在通用配置的 cfg.sdc.*、cfg.qc.*；只有独立调用相应模块才用那些配置。

发布时正式 toolkit_config.m 与已有 Markdown 默认保留目标字节；文档只有在明确授权的范围内修改。此处“可改参数”是用户使用方式，不表示同步程序会覆盖正式配置。

## 3. 根目录

主入口只有 `run_toolkit.m`；其余入口按目的选择，不要把全部 run_*.m 依次运行。验证脚本可能实际执行分析，先检查其路径和开关。

| 文件（相对于工具包根目录）              | 用途                                                                     | 操作类     |
| -------------------------- | ---------------------------------------------------------------------- | ------- |
| `FILE_MANIFEST.json`       | 发布脚本生成的托管文件大小及 SHA-256 清单；此文件自身不列入自身清单，不手工改哈希。                         | 自动生成    |
| `README.md`                | 工具包简介、推荐入口、步骤文档导航与运行边界。                                                | 阅读      |
| `run_confound_design.m`    | 可选的独立混杂设计矩阵与诊断入口；参数在 design_config.m。                                  | 可选入口    |
| `run_confounds.m`          | 可选的独立组织/头动混杂量提取入口；参数在 confounds_config.m，不由空间主链自动运行。                   | 可选入口    |
| `run_denoise.m`            | 可选的独立时间去噪入口；参数在 denoise_config.m，不代表空间预处理已自动去噪。                        | 可选入口    |
| `run_language_realign.m`   | LANGUAGE 头动估计阶段的限定验证入口，不是一般研究的主入口。                                     | 验证入口    |
| `run_language_smoke.m`     | 100206 LANGUAGE LR 完整 run 的 realign 验证脚本；会执行处理，并非只看输入。                 | 验证入口    |
| `run_language_spatial.m`   | 从已验证头动结果继续空间处理的示例入口；须先核对旧输入、路径和新输出目录。                                  | 验证入口    |
| `run_preprocessing.m`      | HCP 示例入口：读取 preprocess_config.m；一般研究无需运行，保留 HCP 布局时可选用。                | 可选入口    |
| `run_timeseries_qc.m`      | 可选的独立批量时序 QC；参数在 qc_config.m，适配已有工具包的特定输出布局。                           | 可选入口    |
| `run_toolkit.m`            | 通用预处理主入口：读取 toolkit_config.m 和 TSV，启动多被试/会话/run 批处理。                   | **主入口** |
| `validate_preprocessing.m` | 先运行 tests，再按 preprocess_config 调用 HCP 入口；是否真正处理由其 execute 值决定，不是固定只预检。 | 验证入口    |

## 4. `config/` 逐文件

配置函数由相应入口调用，不必直接 Run。模板只在相应功能需要时复制填写；不是所有 JSON 都必须改。正式参数集中在 toolkit_config.m，HCP 与独立模块有各自明确的覆盖范围。

| 文件（相对于工具包根目录）                              | 用途                                                          | 操作类   |
| ------------------------------------------ | ----------------------------------------------------------- | ----- |
| `config/acquisition_template.json`         | BOLD 采集参数 JSON 示例，包括 TR、相位编码方向及读出时间。                        | 模板    |
| `config/anatomy_channels_template.json`    | SPM 多通道结构像模板：显式列出 T1/T2/PD 路径、Volume 与每通道偏置设置。              | 模板    |
| `config/atlases_template.json`             | 标准空间图谱清单模板：声明图谱空间、标签/概率类型及文件，用于逆向场写到原生空间。                   | 模板    |
| `config/bold_unwarp_config.m`              | 独立 BOLD 畸变模块配置；同样不替代统一入口的 cfg.sdc.*。                        | 配置    |
| `config/confounds_config.m`                | 组织/头动混杂量提取参数。                                               | 配置    |
| `config/confounds_runs_template.tsv`       | 混杂量提取的逐 run 输入清单。                                           | 模板    |
| `config/denoise_config.m`                  | 静息态时间去噪参数。                                                  | 配置    |
| `config/denoise_runs_template.tsv`         | 时间去噪的逐 run 输入清单。                                            | 模板    |
| `config/design_config.m`                   | 混杂矩阵回归量、滤波和删帧的参数。                                           | 配置    |
| `config/events_template.tsv`               | 事件 TSV 的列格式示例。                                              | 模板    |
| `config/fieldmaps_hz_template.json`        | SPM FieldMap 使用的预计算 Hz 场图清单示例。                              | 模板    |
| `config/fieldmaps_pepolar_template.json`   | TOPUP 使用的正反相位编码 SE-EPI 场图清单示例。                              | 模板    |
| `config/fieldmaps_phasediff_template.json` | SPM FieldMap 使用的相位差/幅度图清单示例，含 TE 和单位。                       | 模板    |
| `config/fieldmaps_phasemag_template.json`  | SPM 双回波独立相位/幅度输入模板；填写真实弧度相位、TE 与幅度图关联。                      | 模板    |
| `config/fieldmaps_realimag_template.json`  | SPM 双回波实部/虚部输入模板；显式关联两次回波的 real/imag 图及 TE。                 | 模板    |
| `config/fieldmaps_vdm_template.json`       | 已有 VDM 输入模板；单位为 voxel，要求已与当前 EPI 对齐，不再次由 TE/readout 缩放。     | 模板    |
| `config/hcp_language_config.m`             | HCP LANGUAGE 示例分析选择。                                        | 配置    |
| `config/preprocess_config.m`               | HCP 专用预设；继承通用配置后覆盖数据根目录、输出、SPM、execute、SDC 方法及 HCP 采集参数。    | 配置    |
| `config/provenance_template.json`          | 已校正或已预处理输入的来源说明 JSON 示例；原始输入不用填。                            | 模板    |
| `config/qc_config.m`                       | 独立 run_timeseries_qc.m 的输入/输出设置；不控制统一预处理的 cfg.qc.*。         | 配置    |
| `config/runs_extended_template.tsv`        | 推荐的完整逐 run 清单模板；复制、填写真实路径并另存自己的 TSV，一行对应一个 run。             | 模板    |
| `config/runs_segmentation_template.tsv`    | 分割扩展清单示例，演示 anatomy_channels 与 atlases 列；不是另外新增一套 BOLD run。 | 模板    |
| `config/runs_template.tsv`                 | 最简预处理逐 run 清单示例。                                            | 模板    |
| `config/spatial_reuse_template.tsv`        | 已完成 T1 分割结果的跨 run 复用列示例。                                    | 模板    |
| `config/toolkit_config.asv`                | MATLAB 编辑器自动保存的配置备份；当前保留，不参与入口调用，不能当作正式配置或运行入口。             | 编辑器备份 |
| `config/toolkit_config.m`                  | 通用预处理总配置：数据清单、SPM、输出、各阶段参数与运行开关；常规使用主要修改这里的参数。              | 配置    |
| `config/topup_config.m`                    | 独立 TOPUP 模块配置；不控制统一入口，统一入口读取 toolkit_config.m 的 cfg.sdc.*。  | 配置    |

## 5. `docs/` 逐文件

文档与图片用于阅读，不参与计算。下表使用 D 盘当前实际文件名；只说明当前存在的文档。

| 文件（相对于工具包根目录）                           | 用途                                                                    | 操作类 |
| --------------------------------------- | --------------------------------------------------------------------- | --- |
| `docs/Coregistration.md`                | EPI–T1 配准原理与参数；明确当前接口固定 Estimate。                                     | 阅读  |
| `docs/Engineering_QC.md`                | FD、DVARS、tSNR、掩膜、非有限体素及工程检查的解释、输出和适用范围。                               | 阅读  |
| `docs/figures/preprocessing_routes.png` | 路线总图的 PNG 图片，适合直接查看与插入文档。                                             | 阅读  |
| `docs/figures/preprocessing_routes.svg` | 同一总图的 SVG 矢量版，可放大查看；不参与影像计算。                                          | 阅读  |
| `docs/File_Catalog_and_Environment.md`  | 本文件：当前发布文件逐项用途、使用类别和本机环境备份。                                           | 阅读  |
| `docs/HCP_LANGUAGE.md`                  | HCP LANGUAGE 数据获取与示例的背景。                                              | 阅读  |
| `docs/Normalization.md`                 | segmentation、DARTEL、Shooting、群体模板与两种写出方法，以及未开放功能和限制。                  | 阅读  |
| `docs/PREPROCESSING.md`                 | 总使用指南：入口、配置覆盖、输入、预检/正式运行、输出与恢复规则。                                     | 阅读  |
| `docs/PREPROCESSING_ROUTE_MAP.md`       | 预处理路线总图与代码索引；包含可编辑的 SDC 和群体标准化 Mermaid 流程。                            | 阅读  |
| `docs/Realignment.md`                   | 头动估计/重采样、Weighting、Unwarp 与相关参数及限制。                                   | 阅读  |
| `docs/Run_Manifest_Guide.md`            | 开始运行前的清单填写教程：每列含义、真实路径、JSON 关联与逐 run 覆盖。                              | 阅读  |
| `docs/SDC.md`                           | FieldMap、Apply VDM、Unwarp、TOPUP/BOLD 路线、输入和 QC；附录收录独立调用方法与自动 SE 均值交接。 | 阅读  |
| `docs/Segmentation.md`                  | SPM Segment/CAT12、结构通道、组织/偏置/形变输出及逆向图谱。                               | 阅读  |
| `docs/Spatial Smoothing.md`             | 高斯平滑、FWHM、类型/隐式掩模/前缀与普通、原生平滑的兼容条件。                                    | 阅读  |
| `docs/STC_Slice Timing Correction.md`   | STC 原理、五种单带顺序、SPM 参数、时间参考与配置对应。                                       | 阅读  |
| `docs/TOPUP_INSTALL.md`                 | 本机 WSL/FSL TOPUP 安装记录。                                                | 阅读  |

## 6. `examples/` 逐文件

开发示例，常规预处理无需运行或修改。复用时另存到研究目录，替换本机路径和参数，不直接沿用示例中的 execute=true 或旧结果路径。

| 文件（相对于工具包根目录）                                   | 用途                                           | 操作类    |
| ----------------------------------------------- | -------------------------------------------- | ------ |
| `examples/hcp_100206_confounds.tsv`             | HCP 100206 混杂量提取输入示例。                        | 示例数据清单 |
| `examples/hcp_100206_denoise_engineering.tsv`   | 去噪工程验证清单；不是任务 GLM 的推荐输入。                     | 示例数据清单 |
| `examples/hcp_100206_runs.tsv`                  | HCP 100206 原始 run 预处理清单示例。                   | 示例数据清单 |
| `examples/hcp_100206_sdc_confounds.tsv`         | 校正后 HCP 100206 混杂量输入示例。                      | 示例数据清单 |
| `examples/hcp_100206_sdc_runs.tsv`              | HCP 100206 经畸变校正的 run 清单示例。                  | 示例数据清单 |
| `examples/hcp_language_lr_events.tsv`           | LANGUAGE LR 的 story/math 事件示例。               | 示例数据清单 |
| `examples/recover_hcp_sdc_realign_100206.m`     | 已完成头动估计后的数值恢复/QC；避免重跑昂贵估计。                   | 示例脚本   |
| `examples/run_hcp_bold_unwarp_100206.m`         | 将 TOPUP 场应用到 100206 BOLD 的验证。                | 示例脚本   |
| `examples/run_hcp_sdc_confound_design_100206.m` | 校正后混杂矩阵验证。                                   | 示例脚本   |
| `examples/run_hcp_sdc_confounds_100206.m`       | 校正后组织/头动混杂量验证。                               | 示例脚本   |
| `examples/run_hcp_sdc_realign_100206.m`         | 校正后 BOLD 头动估计验证。                             | 示例脚本   |
| `examples/run_hcp_sdc_spatial_100206.m`         | 校正后结果继续 Segment/Coregister/Normalise/Smooth。 | 示例脚本   |
| `examples/run_hcp_topup_100206.m`               | 对 100206 运行独立 TOPUP 验证。                      | 示例脚本   |
| `examples/validate_denoise_engineering.m`       | 去噪工程验证；不作为任务 GLM 科研证据。                       | 示例脚本   |

## 7. `matlab/+psy/` 逐文件

这里是 MATLAB psy 包的实现。常规使用不逐个改、不直接 Run；参数从配置与清单传入。高级独立调用使用 psy.函数名(参数)，不是把函数文件当脚本运行。

| 文件（相对于工具包根目录）                              | 用途                                                                       | 操作类  |
| ------------------------------------------ | ------------------------------------------------------------------------ | ---- |
| `matlab/+psy/apply_atlases.m`              | 调用 SPM Deformations，以逆向场及目标网格将图谱写到原生 T1/BOLD；标签最近邻、概率线性。                 | 内部函数 |
| `matlab/+psy/atlas_options.m`              | 解析图谱开关、来源清单、目标网格与输出前缀。                                                   | 内部函数 |
| `matlab/+psy/bold_unwarp_batch.m`          | 多 run BOLD 场图校正调度。                                                       | 内部函数 |
| `matlab/+psy/bold_unwarp_finalize.m`       | 核验输出并写完成记录。                                                              | 内部函数 |
| `matlab/+psy/bold_unwarp_qc.m`             | 对校正后的影像和配准进行数值 QC。                                                       | 内部函数 |
| `matlab/+psy/bold_unwarp_run.m`            | 将 TOPUP Hz 场配准到 SBRef/BOLD 并校正 4D BOLD。                                  | 内部函数 |
| `matlab/+psy/bold_unwarp_validate.m`       | 检查场图、SBRef、BOLD 及相位编码输入。                                                 | 内部函数 |
| `matlab/+psy/cat12_environment.m`          | 核对 CAT12.9 路径、版本及运行文件；不将未经验证的 CAT26 当作等价后端。                              | 内部函数 |
| `matlab/+psy/cat12_segment.m`              | 调用 CAT12.9 官方 cat_run；保存原生作业与默认值，不使用 SPM Segment 专属参数代替 CAT 控制。          | 内部函数 |
| `matlab/+psy/confound_design.m`            | 构建回归/滤波矩阵并检查秩等数值性质。                                                      | 内部函数 |
| `matlab/+psy/confound_design_batch.m`      | 多 run 混杂矩阵调度。                                                            | 内部函数 |
| `matlab/+psy/confounds_batch.m`            | 多 run 组织/头动混杂量提取调度。                                                      | 内部函数 |
| `matlab/+psy/dartel_job.m`                 | 将六轮 DARTEL 配置映射为官方 Run Dartel 作业；保持组织和被试顺序一致。                            | 内部函数 |
| `matlab/+psy/deformation_field_flags.m`    | 将形变场输出选项转成 SPM Segment 标志。                                               | 内部函数 |
| `matlab/+psy/denoise_batch.m`              | 多 run 时间去噪调度。                                                            | 内部函数 |
| `matlab/+psy/denoise_run.m`                | 分块回归、可选滤波及写出去噪 4D NIfTI。                                                 | 内部函数 |
| `matlab/+psy/discover_hcp.m`               | 在 HCP 解压目录发现原始静息态与任务 run。                                                | 内部函数 |
| `matlab/+psy/dummy_plan.m`                 | 预检删帧数、保留帧数及事件时间基准，不猜扫描仪已删除多少帧。                                           | 内部函数 |
| `matlab/+psy/export_hcp_manifest.m`        | 将 HCP 发现结果导出为通用清单。                                                       | 内部函数 |
| `matlab/+psy/extract_confounds.m`          | 从 BOLD 和组织掩膜提取均值信号与头动列。                                                  | 内部函数 |
| `matlab/+psy/fieldmap_reference.m`         | 从当前 BOLD、SBRef 或显式 EPI 创建私有三维参考；mean 不暗中先额外 Realign。                     | 内部函数 |
| `matlab/+psy/file_sha256.m`                | 流式计算文件 SHA-256，用于来源与完成结果核验。                                              | 内部函数 |
| `matlab/+psy/finalize_realign.m`           | 保留原重采样影像，按固定缺失与覆盖约束另写有限值副本和全时序有效掩膜。                                      | 内部函数 |
| `matlab/+psy/group_deformations.m`         | 调用 SPM 合成最终 MNI 前向/逆向场；不把 DARTEL flow 或模板空间场直接冒充最终 MNI 场。                | 内部函数 |
| `matlab/+psy/group_normalise_write.m`      | 执行群体路线的 native 或 deformations 写出，保存未平滑/平滑 BOLD 与实际输出记录。                  | 内部函数 |
| `matlab/+psy/has_dicom_sources.m`          | 判断逐 run 的 BOLD/T1/SBRef/场图路径是否为 DICOM 目录。                                | 内部函数 |
| `matlab/+psy/import_dicom_series.m`        | 调用 SPM 导入一条明确的 DICOM 序列；需要时按返回顺序合并 BOLD 为 4D。                            | 内部函数 |
| `matlab/+psy/inspect_contract.m`           | 检查输入阶段、场图、来源及事件的契约。                                                      | 内部函数 |
| `matlab/+psy/inspect_dicom_inventory.m`    | 只读核对指定 DICOM 序列目录；不将清单核查当作完整影像预检。                                        | 内部函数 |
| `matlab/+psy/inspect_fieldmaps.m`          | 检查场图清单、单位、角色与文件关联；相位必须有真实弧度说明，VDM 使用 voxel。                              | 内部函数 |
| `matlab/+psy/inspect_run.m`                | 检查 run 的 NIfTI 头、帧数和 TR。                                                 | 内部函数 |
| `matlab/+psy/materialize_dicom_run.m`      | 逐 run 转换显式 DICOM 输入并关联转换后的私有 NIfTI/场图 JSON，继续同一流水线。                      | 内部函数 |
| `matlab/+psy/motion_qc.m`                  | 由 SPM 头动参数计算 FD。                                                         | 内部函数 |
| `matlab/+psy/motion_regressors.m`          | 由 SPM 六参数生成扩展头动回归量。                                                      | 内部函数 |
| `matlab/+psy/nifti_geometry.m`             | 读取 NIfTI 几何及头信息。                                                         | 内部函数 |
| `matlab/+psy/normalise_group_plan.m`       | 将多个 run 映射为唯一 subject 或 subject_session 结构单位，避免重复 T1 对模板加权。              | 内部函数 |
| `matlab/+psy/normalise_group_run.m`        | 集中完成结构分割、群体模板/配准及最终场；核对签名和输出后复用完整结果。                                     | 内部函数 |
| `matlab/+psy/normalise_options.m`          | 解析 segmentation/dartel/shooting 及群体、插值、模板和写出设置。                          | 内部函数 |
| `matlab/+psy/normalise_output_check.m`     | 核对全帧标准化输出的网格、时间和覆盖，属于工程检查。                                               | 内部函数 |
| `matlab/+psy/plot_qc_mask.m`               | 显示信号掩膜及 tSNR 的切片图。                                                       | 内部函数 |
| `matlab/+psy/plot_tissue_masks.m`          | 生成人工审查组织掩膜的切片图。                                                          | 内部函数 |
| `matlab/+psy/prepare_spm_sdc.m`            | 准备 SPM 测量场、已有 VDM、无 VDM Unwarp 或 VDM-only 分支的逐 run 计划。                   | 内部函数 |
| `matlab/+psy/preprocess_batch.m`           | 多被试/session/run 预处理总调度与状态表。                                              | 内部函数 |
| `matlab/+psy/preprocess_group_batch.m`     | DARTEL/Shooting 的批量调度：全批预检→唯一结构→群体准备→逐 run 功能处理。                         | 内部函数 |
| `matlab/+psy/preprocess_hcp.m`             | HCP 适配器入口；复用通用计算。                                                        | 内部函数 |
| `matlab/+psy/preprocess_plan.m`            | 按每个 run 的采集参数确定 STC/畸变校正计划。                                              | 内部函数 |
| `matlab/+psy/process_run.m`                | 执行单 run 主链；调用所选 SDC/STC/头动与空间步骤，保存签名及包含 SE 均值的必需输出。                      | 内部函数 |
| `matlab/+psy/qc_batch.m`                   | 独立 QC 批量发现特定旧 Realign 输出布局；不是任意外部衍生格式的通用读取器。                             | 内部函数 |
| `matlab/+psy/read_events_tsv.m`            | 读取通用事件 TSV 并核对时间信息。                                                      | 内部函数 |
| `matlab/+psy/read_hcp_events.m`            | 读取 HCP EV 文本供 SPM 使用。                                                    | 内部函数 |
| `matlab/+psy/read_manifest.m`              | 读取并验证通用逐 run TSV。                                                        | 内部函数 |
| `matlab/+psy/realign_weight_plan.m`        | 解析全局/逐 run 空间权重图，核查参考 EPI 覆盖并记录来源；不代替解剖对齐审查。                             | 内部函数 |
| `matlab/+psy/reuse_anatomy.m`              | 在旧协议支持的输出集合内，核对来源及配置后复用 T1 分割；不跳过当前 EPI–T1 配准。                           | 内部函数 |
| `matlab/+psy/run_output_dir.m`             | 生成 `sub-.../[ses-...]/run` 输出目录。                                         | 内部函数 |
| `matlab/+psy/sdc_spm_options.m`            | 解析 SPM 场图/Unwarp 扩展菜单，并为旧配置补兼容默认值。                                       | 内部函数 |
| `matlab/+psy/segment_options.m`            | 解析 SPM/CAT、通道、组织输出和图谱参数，兼容旧配置缺失字段。                                       | 内部函数 |
| `matlab/+psy/segment_output_flags.m`       | 把偏置、Native、Imported、Warped 等选择映射为 SPM 原生写出标志。                            | 内部函数 |
| `matlab/+psy/segment_plan.m`               | 预检结构通道、Volume、分割和图谱来源；新增通道不会增加 BOLD run 行数。                              | 内部函数 |
| `matlab/+psy/segment_run.m`                | 分割总接口：调用 SPM/CAT 官方实现，管理输出与适用的旧解剖复用协议。                                   | 内部函数 |
| `matlab/+psy/shooting_defaults.m`          | 按官方公式生成本次 Shooting 参数与 schedule；不修改 SPM 安装默认文件。                          | 内部函数 |
| `matlab/+psy/shooting_run.m`               | 通过私有 defaults 调用官方 Shoot，记录实际设置并在结束后恢复调用环境。                              | 内部函数 |
| `matlab/+psy/slice_timing_plan.m`          | 将采集顺序/时间转为 SPM STC 所需参数。                                                 | 内部函数 |
| `matlab/+psy/smooth_options.m`             | 解析普通 Smooth 类型、隐式掩模和前缀，并检查 native 路线的兼容限制。                               | 内部函数 |
| `matlab/+psy/smooth_record.m`              | 记录平滑请求、实际执行、路径、类型、帧数/TR/网格；不估计 GLM 残差 FWHM。                              | 内部函数 |
| `matlab/+psy/smooth_run.m`                 | 调用 SPM Smooth；对需要的整数 4D 输出采用统一缩放，避免跨帧数值失真。                               | 内部函数 |
| `matlab/+psy/spatial_steps.m`              | 组织分割/图谱、固定 Coregister Estimate、普通标准化或群体写出及平滑。                            | 内部函数 |
| `matlab/+psy/spm_fieldmap_vdm.m`           | 调用官方 FieldMap API 生成/导入 VDM，执行所选匹配及参考 EPI 校正。                            | 内部函数 |
| `matlab/+psy/spm_motion_step.m`            | 按 SDC 路线调用普通 Estimate & Reslice、Realign & Unwarp 或 Estimate + Apply VDM。 | 内部函数 |
| `matlab/+psy/spm_segment_batch.m`          | 将分割计划映射为本机 SPM Segment batch，不自行实现分割算法。                                  | 内部函数 |
| `matlab/+psy/spm_step.m`                   | 保存并执行 SPM `matlabbatch` 作业。                                              | 内部函数 |
| `matlab/+psy/stage_anatomy.m`              | 复制并提取所选结构 Volume 到私有目录，避免向原始 T1 写头信息。                                    | 内部函数 |
| `matlab/+psy/stage_image.m`                | 将影像复制到私有工作目录，避免修改原始文件。                                                   | 内部函数 |
| `matlab/+psy/temporal_basis.m`             | 构建时间滤波用 DCT 基。                                                           | 内部函数 |
| `matlab/+psy/timeseries_qc.m`              | 流式计算 BOLD 时间序列 QC 指标。                                                    | 内部函数 |
| `matlab/+psy/tissue_mask.m`                | 将组织概率图投到 BOLD 网格并构建掩膜。                                                   | 内部函数 |
| `matlab/+psy/topup_batch.m`                | 多 run 反向 PE 场图估计调度。                                                      | 内部函数 |
| `matlab/+psy/topup_qc.m`                   | 核对 SE/场输出、正反编码差异及 SE 时间均值的尺寸、类型、有限值和数值一致性。                               | 内部函数 |
| `matlab/+psy/topup_run.m`                  | 调用 TOPUP 估场后自动调用 FSL 生成三维 float32 SE 均值；通过 QC 后写完成记录。                    | 内部函数 |
| `matlab/+psy/topup_validate.m`             | 核对反向 PE 图像/参数是否满足 TOPUP 要求。                                              | 内部函数 |
| `matlab/+psy/trim_dummy_bold.m`            | 调用 SPM 合并删帧后的 BOLD 副本，原始影像保持不变。                                          | 内部函数 |
| `matlab/+psy/validate_preprocess_config.m` | 在 SPM 运行前检查预处理参数是否合法。                                                    | 内部函数 |
| `matlab/+psy/verify_realign.m`             | 核验头动阶段的输出与工程 QC。                                                         | 内部函数 |
| `matlab/+psy/verify_spatial.m`             | 核验空间输出几何/数值并生成叠加图。                                                       | 内部函数 |
| `matlab/+psy/write_dummy_events.m`         | 保存相对保留首帧的事件副本，不改原始 TSV 或 HCP EV。                                         | 内部函数 |

## 8. `scripts/` 逐文件

辅助安装、解压、检查与发布脚本，不是预处理主入口；仅在对应维护工作中按需执行。

| 文件（相对于工具包根目录）                    | 用途                                                       | 操作类  |
| -------------------------------- | -------------------------------------------------------- | ---- |
| `scripts/audit_hcp_headers.py`   | 审查 HCP NIfTI 头及采集相关元数据。                                  | 维护脚本 |
| `scripts/extract_hcp.py`         | 解压 HCP 下载包并核查内容。                                         | 维护脚本 |
| `scripts/getfsl_official.sh`     | 获取官方 FSL 安装材料的 WSL 辅助脚本。                                 | 维护脚本 |
| `scripts/install_cat12.ps1`      | 按需下载、部署已核对的 CAT12.9；属于安装维护，不是每次预处理都运行。                   | 维护脚本 |
| `scripts/install_topup_wsl.sh`   | 在 WSL 内安装 FSL TOPUP 相关包。                                 | 维护脚本 |
| `scripts/release_layout.json`    | 发布排除规则：GLM 独立文件和永久停用文件；不是研究分析参数或运行脚本。                    | 维护规则 |
| `scripts/sync_final_copy.ps1`    | 将工作区已授权文件发布到 D 盘并核对哈希；默认保护已有 Markdown 和正式配置，支持文档图片与限定路径。 | 维护脚本 |
| `scripts/verify_nifti_stream.py` | 以流式方式核查 NIfTI 数据/压缩内容。                                   | 维护脚本 |

## 9. `tests/` 逐文件

测试文件不属于每次研究的处理链。test_*.m 通过 runtests 调用；manual_*.m 按文件头说明运行，其中部分读取真实 HCP 或调用实际 SPM/FSL。测试输出也应放在发布目录之外。

| 文件（相对于工具包根目录）                            | 用途                                                                              | 操作类     |
| ---------------------------------------- | ------------------------------------------------------------------------------- | ------- |
| `tests/manual_normalisation_routes.m`    | 真实 HCP 三被试/四 run 的低分辨率、短序列 DARTEL/Shooting 工程验证；不是科研默认参数。                       | 手动集成测试  |
| `tests/manual_segmentation_extensions.m` | 真实 HCP T1/T2 的多通道、CAT12、组织输出和图谱扩展验证；不代替整套 BOLD 预处理。                             | 手动集成测试  |
| `tests/manual_spm_fieldmap_fullchain.m`  | 手动运行真实 HCP 前 8 帧 BOLD + 合成场图的两条 SPM 路线到平滑。                                      | 手动集成测试  |
| `tests/manual_spm_fieldmap_smoke.m`      | 用合成影像手动检查 SPM FieldMap batch。                                                   | 手动集成测试  |
| `tests/manual_topup_handoff.m`           | 实际调用 WSL/FSL，生成两个合成被试并验证 TOPUP→自动 SE 均值→BOLD 校正；不读取 HCP。                        | 手动集成测试  |
| `tests/test_bold_unwarp.m`               | BOLD 场图输入、读出时间、命令计划和批次隔离测试；本文件不实际执行 FSL 校正。                                     | 单元/接口测试 |
| `tests/test_confound_design.m`           | 混杂矩阵与秩/滤波验证。                                                                    | 单元/接口测试 |
| `tests/test_confounds.m`                 | 混杂量提取验证。                                                                        | 单元/接口测试 |
| `tests/test_denoise.m`                   | 时间去噪验证。                                                                         | 单元/接口测试 |
| `tests/test_dicom_dummy.m`               | SPM DICOM 导入、初始帧删除、事件时间基准、批量与原始文件保护测试。                                          | 单元/接口测试 |
| `tests/test_finalize_realign.m`          | 头动输出整理及非有限值处理验证。                                                                | 单元/接口测试 |
| `tests/test_hcp_events.m`                | HCP 事件读取验证。                                                                     | 单元/接口测试 |
| `tests/test_input_contract.m`            | 输入阶段、场图单位、来源约束验证。                                                               | 单元/接口测试 |
| `tests/test_manifest.m`                  | 通用 TSV 读取与逐 run 唯一性验证。                                                          | 单元/接口测试 |
| `tests/test_nifti_geometry.m`            | NIfTI 头与几何读取验证。                                                                 | 单元/接口测试 |
| `tests/test_normalisation_interfaces.m`  | 标准化路线、结构去重、原生模板/写出、方向、时间信息与输入保护测试。                                              | 单元/接口测试 |
| `tests/test_preprocessing.m`             | 预处理基础步骤验证。                                                                      | 单元/接口测试 |
| `tests/test_realign_weight.m`            | 全局/逐 run Weighting 的配置、覆盖与输入拒绝测试。                                               | 单元/接口测试 |
| `tests/test_reuse_anatomy.m`             | T1 分割结果复用条件验证。                                                                  | 单元/接口测试 |
| `tests/test_sdc_interfaces.m`            | SPM 场图输入、已有 VDM、动态 Unwarp、参考图、批处理与菜单约束测试。                                       | 单元/接口测试 |
| `tests/test_segmentation_interfaces.m`   | SPM/CAT 参数、4D 结构 Volume、多通道清单、组织/图谱输出和原文件保护测试。                                  | 单元/接口测试 |
| `tests/test_smoothing_interfaces.m`      | 调用 SPM 检查类型、隐式掩模、三轴核、整数缩放、原生平滑及时间/网格保持。                                         | 单元/接口测试 |
| `tests/test_timeseries_qc.m`             | BOLD 时间序列 QC 验证。                                                                | 单元/接口测试 |
| `tests/test_topup.m`                     | TOPUP 输入、命令计划、SE 均值正确性/缺失拒绝、两种 PE 帧数不等及批次隔离测试；实际 FSL 调用另见 manual_topup_handoff。 | 单元/接口测试 |
| `tests/test_unified_preprocessing.m`     | 统一入口的 STC、SDC 分支和参数拒绝测试。                                                        | 单元/接口测试 |

## 10. 开发运行环境

以下为本次从已打开 MATLAB 会话、本机注册表/硬件查询、WSL 可执行程序及 Conda 包记录读取的值。它们是本机备份记录，不是其他电脑必须相同的硬件规格。

| 项目                 | 当前记录                                                                                                                                                                      | 用途或核查方式                                                                                    |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Windows            | NT 10.0.26300.9711；DisplayVersion=26H2；win64                                                                                                                              | 注册表 CurrentBuild/UBR/DisplayVersion；ProductName 原值为 Windows 10 Pro，不以这个旧字段推断系统品牌版本。        |
| CPU / 内存           | AMD Ryzen 7 5700G with Radeon Graphics；8 核/16 逻辑处理器；系统可见内存约 15.3 GiB                                                                                                      | 只读 Win32_Processor/Win32_ComputerSystem；线程数与批量并发需结合资源选择。                                   |
| MATLAB             | **25.2.0.2998904 (R2025b)**；`D:\matlab`                                                                                                                                   | 已打开会话 version / matlabroot / computer('arch')。                                             |
| SPM                | **SPM12，修订 7771**；`D:\matlab\atoolbox\spm12\spm.m`                                                                                                                        | spm('Ver') 与 ver；cfg.spmPath 填含 spm.m 的目录。                                                 |
| CAT12              | **CAT12.9，revision 2577**；`D:\matlab\atoolbox\spm12\toolbox\cat12`                                                                                                        | cat_version；仅选择 CAT 后端时使用，接口按 CAT12.9 核对。                                                  |
| MATLAB 其他可见工具箱     | Image Processing Toolbox 25.2；Statistics and Machine Learning Toolbox 25.2；Signal Processing Toolbox 25.2；Parallel Computing Toolbox 25.2；MATLAB MCP Server Toolbox 0.4.0 | 来自 ver；本机可见不代表每个处理函数都依赖全部工具箱。                                                              |
| WSL                | Ubuntu-24.04；Ubuntu 24.04.5 LTS；x86_64                                                                                                                                    | cfg.sdc.wslDistro 使用发行版名称；Windows D: 路径在 WSL 中通常映射到 /mnt/d/。                               |
| FSL 安装位置           | `/home/bx210/fsl-topup`；所需 topup/applytopup/fslmerge/fslmaths/fugue/flirt/convertwarp/applywarp 均存在                                                                       | 当前是可运行的 FSL 组件环境；不能只由某个组件的版本推断完整 FSL 发行版本。                                                 |
| TOPUP 组件版本         | Conda `fsl-topup 2203.6`，build `hb402069_0`；程序报告 ID `2412.6-dirty`                                                                                                        | conda-meta 包记录与程序帮助头；包版本与二进制构建 ID 是不同字段。                                                   |
| applytopup / FLIRT | applytopup Version 1.0，报告同一 FSL ID；FLIRT version 6.0                                                                                                                      | 当前 topup/applytopup 的 --version 会打印帮助并返回 1，applytopup 提示该选项不存在；此处从帮助头读取，不把退出码 1 当成成功的版本查询。 |
| WSL Python         | 3.14.8；`/home/bx210/fsl-topup/bin/python`                                                                                                                                 | 当前 FSL 环境内解释器，不是 MATLAB 预处理的替代入口。                                                          |
| Windows Python     | 3.12.14；`C:\Users\bx210\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe`                                                                       | 本次用于清单核对、辅助文件及文档图片；Codex 缓存路径不是可移植安装保证。                                                    |
| 文档绘图辅助库            | Pillow 12.3.0                                                                                                                                                             | 本次生成 PNG；SVG 和 Mermaid 是可编辑表示，MATLAB 预处理不依赖 Pillow。                                        |
| PowerShell         | 7.6.5                                                                                                                                                                     | 发布同步/安装辅助脚本使用；影像运算仍由 MATLAB/SPM 与所选 FSL 分支完成。                                              |
| 示例数据               | `D:\IBM`；100206、100307、100408 的已解压目录                                                                                                                                      | 数据仅用于验证，不包含在代码发布包；本次没有重新运行影像处理。                                                            |
| 输出与日志              | cfg.outputRoot，位于发布根目录之外                                                                                                                                                  | 发布根目录有 FILE_MANIFEST.json，统一预处理会拒绝把衍生结果写进发布目录。                                             |

##


