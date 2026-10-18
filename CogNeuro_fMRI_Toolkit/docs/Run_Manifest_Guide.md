# 通用预处理清单填写

通用入口 [run_toolkit.m](../run_toolkit.m) 读取 [toolkit_config.m](../config/toolkit_config.m) 中的 `cfg.manifestFile`，默认指向 `config/runs.tsv`。先复制 [runs_extended_template.tsv](../config/runs_extended_template.tsv) 为 `config/runs.tsv`，删掉虚构的 `E:/YOUR_DATA` 示例并填写真实文件。

**一行是一个被试的一个 session 的一个 run**【举例：24 名被试、每人 2 个 run， 应填写 48 行数据】。处理器按表中顺序逐行运行，当前不自动并行。



模板的四行数据演示 S01、S02 各有 `language_run1` 和 `language_run2`。`subject`、`session`、`run` 合起来必须唯一；不同被试可有同名 run。可以用绝对路径（如 `D:/Study/S01/bold_run1.nii.gz`），也可以用相对于 `runs.tsv` 所在文件夹的路径。

**Windows 路径建议在 TSV 中写正斜杠 `/`**；文件必须真实存在。列之间用**制表符 Tab**，不要用空格或逗号；空列仍保留相邻的 Tab。



| 列                 | 含义                          | 示例与要求                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| ----------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `subject`         | 被试编号                        | `S01`；可含英文字母、数字、下划线、连字符，前导零会保留。                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `session`         | 扫描阶段                        | `baseline`；只有一个 session 可留空。                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `run`             | 当前被试、session 内的 run 名       | `language_run1`、`language_run2`；同一被试同一 session 不可重复。                                                                                                                                                                                                                                                                                                                                                                                               |
| `bold`            | 该 run **原始 4D BOLD** 文件路径   | `D:/Study/S01/bold_run1.nii.gz`；接受 `.nii` 或 `.nii.gz`。也接受DICOM ，==注意若是DICOM文件，需填写**只含一条扫描序列的目录**，不能把整场扫描的不同序列混放在一个目录交给它猜==                                                                                                                                                                                                                                                                                                                         |
| `t1`              | 该被试的原始 3D T1 文件路径           | `D:/Study/S01/t1.nii.gz`；同一被试两个 run 可重复填写同一个 T1。==注意若是DICOM文件，需填写**只含一条扫描序列的目录**，不能把整场扫描的不同序列混放在一个目录交给它猜==                                                                                                                                                                                                                                                                                                                                         |
| `input_stage`     | 影像的处理阶段                     | 原始预处理填 **`raw`**。**全表须与 `cfg.inputStage` 一致**；不能把 `raw` 与 `preprocessed` 行混在同一次调用中。可选填写参数：`sdc_corrected` 是已单独完成畸变校正的输入；`preprocessed` 只支持验证，不可设 `execute=true` 再预处理。                                                                                                                                                                                                                                                                              |
| `sbref`           | 当前 run 的单带参考图路径             | `D:/Study/S01/sbref_run1.nii.gz`；**选择 `fsl_topup` 时必填，其他路线可留空。**                                                                                                                                                                                                                                                                                                                                                                                   |
| `metadata`        | 当前 BOLD 的采集 JSON 路径         | `D:/Study/S01/bold_run1.json`；**选择：SPM FieldMap、通用清单的 TOPUP 及 `sliceTiming.mode='metadata'` 会用到**。内容如 `RepetitionTime`（秒）、`PhaseEncodingDirection`（体素轴 `i/i-/j/j-/k/k-`）、`TotalReadoutTime`（秒）；数值须按实际扫描协议填写。                                                                                                                                                                                                                                       |
| `events`          | 当前 run 的事件 TSV 路径           | `D:/Study/S01/events_run1.tsv`；空间预处理不建 GLM，可留空。填写时会检查 `onset`、`duration`、`trial_type` 等事件数据。                                                                                                                                                                                                                                                                                                                                                       |
| `fieldmaps`       | 当前 run 关联的场图清单 JSON 路径      | `D:/Study/S01/fieldmaps_run1.json`；选 TOPUP 时使用 [反向 PE 模板](../config/fieldmaps_pepolar_template.json)【config\fieldmaps_pepolar_template.json】，选 SPM FieldMap时使用[相位差](../config/fieldmaps_phasediff_template.json)【config\fieldmaps_phasediff_template.json】或[预计算 Hz](../config/fieldmaps_hz_template.json)【config\fieldmaps_hz_template.json】模板；若STC 选 `metadata`，且畸变方法为`none`，则留空；若畸变校正 `none`，STC `off`，也留空即可。注意它填的是 **JSON 清单路径**，不是场图 NIfTI 本身。 |
| `provenance`      | 已处理输入的来源说明 JSON             | 若为原始数据，则`raw` 行留空；若是`sdc_corrected` 或 `preprocessed` 则必填，格式见 [provenance_template.json](../config/provenance_template.json)【config\provenance_template.json】。                                                                                                                                                                                                                                                                                      |
| `sdc_method`      | 当前 run 的畸变校正路线              | ==**可选择：`fsl_topup`、`spm_fieldmap_applyvdm`、`spm_fieldmap_unwarp`、`none`**；==留空则使用 `toolkit_config.m` 中的默认 `cfg.sdc.method`。同一张原始数据表可逐行选择不同路线，但不能在相同输出目录重复同一被试/session/run。只想先做无畸变校正的原始预处理，应把该列改为 `none` 或留空并设置总配置为 `none`。                                                                                                                                                                                                                        |
| `discard_volumes` | 当前 run 开头要删除的 BOLD dummy 帧数 | 可选；填非负整数（如 `4`），留空继承 `cfg.discardVolumes`；`0` 不删除。只删 BOLD，至少保留 2 帧；须按采集记录确认。T1、SBRef 和场图不会跟着删。**不同 run 数量不同时，可在 [runs_extended_template.tsv](D:/CogNeuro_fMRI_Toolkit/config/runs_extended_template.tsv) 所示清单中填写可选列** `discard_volumes`，逐行覆盖全局值。                                                                                                                                                                                                   |
| `event_reference` | 删除 dummy 后事件 onset 的时间零点    | 可选；留空继承 `cfg.dummy.eventReference`。当删帧数大于 0 且提供 `events` 时，必须填 `original_first_volume`（onset 减去删除帧数×TR）或 `retained_first_volume`（onset 不变）；原事件文件不改，输出调整后的副本。                                                                                                                                                                                                                                                                                       |



若需构建：

1.`metadata`列不留空，需构建.json文件：

- 复制 `acquisition_template.json` 后逐项替换：第 2 行 TR 秒，第 3 行 NIfTI 轴向编码 i/i-/j/j-/k/k-，第 4 行有效总读出时间秒。这里的方向不是解剖 LR/AP 标签；不能直接由文件名推断。缺少经过核实的值时删去字段，不复制模板数字充当实测值。

- 可添加 SliceTiming 秒数组，长度必须等于 z 层数。`ascending` 等五种预设只适合已核实的单带顺序，多带扫描须用真实逐层时间。JSON TR 与影像头不一致时报错，不静默覆盖。未提供字段会保留为未提供，不认定为已核查齐全。非 z 轴切片采集、变 TR 尚未支持。

- 字段单位与方向定义参考 [BIDS MRI 规范](https://bids-specification.readthedocs.io/en/v1.11.0/modality-specific-files/magnetic-resonance-imaging-data.html)。本工具包不是完整 BIDS 验证器。`



2.`events`列不留空，需构建.tsv文件：

- config/events_template.tsv中修改：第 1 行固定 onset/duration/trial_type；第 2 行起替换任务事件，单位秒，零点为当前 BOLD 第一帧。负 onset 保留；duration 必须为有限非负值；trial_type 必填。本工具包为后续模型要求条件列，比基础 BIDS 事件表更严格。缺失时长 n/a 尚不支持。

- 事件开始在采集结束或之后时报错；尾部超出采集时长只记录 endOverrunSeconds，不裁剪；负 onset 数量单独记录。支持检查，不等同于完成设计矩阵。事件表会随 header.mat 保存。



3.`fieldmaps`列不留空，需修改.json文件：

- fieldmaps_pepolar_template.json 第 5–6 行逐幅替换路径、编码方向和有效总读出时间；要求清单含同轴相反符号的一对。
- [fieldmaps_phasediff_template.json](../config/fieldmaps_phasediff_template.json) 填实际 TE 秒，TE2 必须大于 TE1；相位差图须为 3D 且经 NIfTI 头缩放后数值位于 [-π,+π] rad，预检会读取并拒绝越界图。幅度图可为 3D，或同文件双回波 4D（SPM 使用第 1 帧）。`SPMBlipDirection` 必须由扫描协议核实为 -1/+1，不能从 BIDS `i/j/k` 符号直接推断。
- [fieldmaps_hz_template.json](../config/fieldmaps_hz_template.json) 用于已处理且单位为 Hz 的场图；幅度图可选。本机 SPM FieldMap 对该输入不自动进行 VDM→EPI 匹配/脑掩膜，程序要求它已处理且与 EPI 同网格、同仿射，`maskBrain=false`。未经转换的扫描仪相位整数不能直接声明为 rad；双独立相位图尚未接入统一入口。

`inspect_contract` 的 `inventory_checked_correction_pending` 是**输入清单阶段**状态，并不表示已经做了畸变校正。实际校正在 `psy.process_run` 中按 `cfg.sdc.method` 执行，结果与所选方法记录到每个 run 的 `preprocessing_plan.json`、SPM job 和完成标记。`sdc_corrected` 入口验证已有完成记录和影像路径



如已有本工具包完成的 T1 分割结果，可以自行增加可选列 `anatomy_reuse_dir`，逐行填来源 run 的 `anat` 目录；留空则重新分割。



`metadata` 文件的**结构示例**如下：

```json
{"RepetitionTime":2.0,"PhaseEncodingDirection":"j-","TotalReadoutTime":0.05}
```
