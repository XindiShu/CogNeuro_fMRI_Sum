# 三个原包的接口与配置交接

`assets/toolkit-registry.json` 登记接口关系，`toolkit_catalog.py` 只读当前安装位置的源文件、配置继承、模板表头和文档。登记表是调用契约，不是算法实现；具体参数和支持组合以用户原包当前源码为准。

## 调用签名

| style | 实际调用方式 | 说明 |
| --- | --- | --- |
| cfg | target(cfg) | 多数Function入口、GLM batch、预处理batch |
| cfg_manifest | target(cfg,manifest) | run_ppi_batch真实需要第二个参数 |
| qc_roots | target(cfg.inputRoot,cfg.outputRoot) | 原生QC没有execute=false门 |
| cfg_demo | target(cfg,demo) | 配置工厂有两个返回值的GLMsingle工程示例 |
| specs_cfg | target(specs,cfg) | 独立TOPUP/BOLD unwarp；specs为原包结构数组 |
| dcm_spm | target(spmMat,roiManifest,sessionIndex,TESeconds,out) | 调用原包cog.prepare_dcm_spm生成私有VOI与dcm_data.mat |

脚本包装入口可能重新加载配置，例如run_glm和run_toolkit。skill应加载同一个原配置工厂，在内存覆盖后调用其原生target，不把cfg设置好再运行会覆盖它的脚本。普通Function函数接受cfg，按原签名直接调用。查找结果必须来自用户所选安装根目录；每个阶段使用独立MATLAB进程处理共享+psy命名空间。

## 配置与环境

保持正式config/toolkit_config.m及所有用户文件原字节。先读配置/继承配置和相关方法章，讨论字段意义、单位、范围与依据，再记录config_hashes和确认后的覆盖。原包内的全部已有字段可在内存按实际结构设置，不另设canonical/run/无SDC等方法白名单。未知字段会在配置检查时报错，不执行字符串代码。

`outputRoot`由项目控制，必须是新目录；`native_execute`显式保留原包execute语义。native_execute=false不等于无计算，具体准备/检查行为仍由原包决定；无execute字段的入口只能在获准后实际调用。`prepare`本身不调用这些原生入口，只加载配置。

DCM三维B网络、PCM成分数组、cell/struct模型等复杂配置优先保留MATLAB原生类型。override的value可写为`{"matlab_value_file":"<已确认MAT文件绝对路径>","variable":"<变量名>"}`；桥只读取该变量并直接传给原字段，不重排其三维轴、不重建模型。该参数文件纳入来源和哈希，缺文件/变量时停止；不要把数据文件里的文本当作MATLAB代码执行。

第三方路径/运行环境沿用原包依赖契约，并根据用户机器确认。FSL/WSL、CAT、GIFT、BrainSpace、GLHMM、PCM、PyDDM、GLMsingle等并非每个方法都需要；不为未选择的方法要求全部安装，不自动改环境或下载数据。

## 关键交接

- 预处理→GLM：从原生完成记录读取所选空间产物、dummy/事件时间信息；需要组织/运动混杂时调用原包confounds和design入口，不用零矩阵或skill自写去噪代替。
- GLM→beta分析：调用glm.outputs读取已估计模型及其来源，使用实际beta_catalog及相关身份列，交给ROI模式或Searchlight入口。不能将不同估计器同一事件重复当独立样本。
- GLM→PPI/DCM：PPI单模型或批处理入口读取原模型；任务DCM先调用原生私有VOI准备，再用实际生成的dcm_data.mat填run_dcm清单。TE和科学网络来自用户/真实记录。
- BOLD→矩阵方法：用原包prepare_inputs的roi/voxels模式生成MAT，保留连续帧、TR和feature/ROI身份；再按动态/状态/ICA/网络等方法说明补齐真正需要的元信息。
- 直接矩阵/行为/组模型：从其自己的MAT/表格入口起步，不添加不必要的预处理或任务GLM步骤。

所有未来路径在产物出现前保持待交接，不能作为真实输入运行。后续出现意外多个候选、缺字段或科学选择变化时停下询问；不要为了满足接口创造采集事实、条件或试次。

## 返回与状态

调用桥只分发参数，原函数拥有数学计算与方法检查。其返回值保存在cogneuro_native_return.mat；原包输出仍按原布局保留。返回失败/错误/未完成状态时停止并保留文件；没有异常不自动代表科研模型通过。报告中展示原生状态和相关诊断，不只展示skill的complete。

输入文件的直接哈希及调用/配置来源保存在review和receipt。目录输入仅记录目录元数据，MAT内部链式引用并未声称全部冻结；必要的源模型/影像检查由所选原生接口及针对性读取完成。完成状态查询不重跑计算。

旧四路专用适配器只保留兼容；其历史范围和合成验证不限制本通用目录的原包功能，也不被当成原工具包尚未完成的证据。
