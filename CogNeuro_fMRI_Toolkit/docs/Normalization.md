# 14. Normalization：标准化

本章说明估计空间变换与写出标准空间影像的区别，并介绍 segmentation-based、DARTEL 和 Geodesic Shooting 三条标准化路线。参数选择应同时考虑结构输入、模板、写出方式和最终网格。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

## 一、Normalization 在做什么？

### 1. 为什么需要标准空间？

每个人的脑大小、脑沟、脑室和局部形态都不同。同一个图像数组位置，在不同人的脑中可能对应不同结构。做逐体素的 group analysis 时，需要先建立可以比较的空间对应关系，常见做法是把个体影像变换到 standard space，例如 MNI space。

**需要空间对应的是跨被试的逐体素比较；不是任何组分析都必须先把全部 BOLD 写到 MNI。**例如，各自在原生空间定义对应 ROI，再比较被试的 ROI 汇总指标，也可以进行组统计。

Normalization 的任务可以理解为寻找一个变换，让“这个人的脑”尽量对应“模板中的脑”。其基本关系是：

$$
\mathbf{x}_{\mathrm{MNI}}=T(\mathbf{x}_{\mathrm{native}})
$$

其中，坐标是毫米单位的物理坐标，不能直接把图像数组中的第几个 voxel 当作 MNI 坐标。

### 2. 为什么不是简单平移和旋转？

Realignment、常规 Coregistration 主要处理整体平移和旋转。Normalization 还允许整体大小、形状及局部结构发生调整，常用的概念分解是：

$$
T=T_{\mathrm{nonlinear}}\circ T_{\mathrm{affine}}
$$

也就是先做整体仿射对齐，再用非线性形变调整局部差异。这个公式是帮助理解的概念分解，实际模块的内部表示和优化顺序以相应算法为准。

| 变换                    | 自由度或作用     | 通俗解释                 |
| --------------------- | ---------- | -------------------- |
| Translation           | 3 个平移      | 把脑移到适当位置             |
| Rotation              | 3 个旋转      | 调整脑的朝向               |
| Scaling               | 3 个缩放      | 调整三个方向的整体大小          |
| Shearing              | 3 个剪切      | 允许坐标轴之间有一定倾斜变化       |
| Nonlinear deformation | 空间上变化的局部变形 | 不同区域可以有不同程度的移动、拉伸或压缩 |

前四类组成常说的 **12 自由度仿射变换**。这与当前 Coregister Estimate 的六自由度刚体配准不是同一件事。

例如，某人的侧脑室更大，某些脑沟更深，单靠整体缩放不能分别对齐这些区域。非线性形变能进一步改善对应关系，但需要正则化约束，避免为追求图像匹配而产生不合理拉伸。

**Normalization 不会把所有人的脑变成完全一样，也不能保证同一个 MNI voxel 在所有人中都是同一个功能区。**它提高解剖对应程度，不能消除真实的脑沟、脑回和功能组织个体差异。

### 3. 为什么通常用 T1 估计，再应用到 EPI？

理论上可以直接把 EPI 配准到标准空间。但常规 EPI 分辨率较低，容易受磁敏感畸变及信号缺失影响；T1 通常分辨率更高，组织边界更清楚。因此常见逻辑是：

```text
EPI 与 T1 建立空间对应关系
        +
T1 与标准模板建立空间对应关系
        ↓
把 T1 的形变关系应用到 EPI，写出标准空间 BOLD
```

这不是要求 T1 和 EPI 的图像矩阵尺寸相同，而是要求它们在物理空间中已经正确配准。否则，T1 的形变场不能正确作用到 EPI。

**代码对应：**当前功能像配准固定为 `Coregister: Estimate`：T1 为 Reference，Mean EPI 为 Source，全部保留 BOLD 为 Other。它把 EPI 的空间矩阵关联到固定 T1。没有 Coregister Reslice/Estimate & Reslice 选择，详见 [COREGISTRATION.md](Coregistration.md)。

### 4. 先分清 Estimation 和 Writing

| 工作                       | 解决的问题            | 完成后是否已有标准空间 BOLD？   |
| ------------------------ | ---------------- | ------------------- |
| Normalization Estimation | 估计个体与模板之间怎样对应    | 不一定；只是得到变换，尚未写出 EPI |
| Normalization Writing    | 应用已有变换，在目标网格重新采样 | 是，前提是实际选择并写出了这些 EPI |

SPM Segment 已经能够估计后续标准化要用的形变场。对已经生成可靠形变场的 T1，通常不需要再单独运行 Normalise: Estimate。

SPM12 中常见的方法和操作如下。表中把“估计方法”和“应用操作”放在一起便于阅读，但它们不属于同一层级的选择：

| 方法或操作                       | 主要原理                     | 典型输出或用途              |
| --------------------------- | ------------------------ | -------------------- |
| Normalise: Estimate         | 利用个体图像、TPM 与统一分割框架估计空间关系 | 前向形变场，例如 `y_T1.nii`  |
| Normalise: Write            | 读取已有形变场，重采样选定影像          | 通常为 `w*.nii`         |
| Normalise: Estimate & Write | 在一个任务中先估计，再应用            | 形变场及标准化影像            |
| Segmentation-based          | 统一分割同时估计组织、偏置及空间关系       | 常规 task-fMRI 的常见路线   |
| Old Normalise               | 较早的模板强度匹配和低频基函数形变        | 复现早期研究，常见 `_sn.mat`  |
| DARTEL / Geodesic Shooting  | 高维微分同胚配准，利用组织图与群体模板      | 常用于 VBM，也可把功能像写到标准空间 |

**代码对应：。**

```matlab
cfg.normalise.method = 'segmentation'; % 配置第282行
```

| 输入值                 | 工具包实际执行                                                          | 选择建议                     |
| ------------------- | ---------------------------------------------------------------- | ------------------------ |
| `'segmentation'`，默认 | SPM Segment 或 CAT12 估计形变，然后 Normalise: Write → Smooth            | 常规 fMRI 的起点，先检查分割与配准质量   |
| `'dartel'`          | SPM Segment → Imported GM/WM → 独立 DARTEL → MNI 写出                | 有明确群体模板或更精细结构配准需求时考虑     |
| `'shooting'`        | SPM Segment → Imported GM/WM → 独立 SPM Geodesic Shooting → MNI 写出 | 同样按研究需要选择，不是所有 EPI 必加的步骤 |

`cfg.normalise.method`（配置第282行） **选择标准化路线，不是选择 Estimate/Write/Estimate & Write 三种操作**。后两条路线要求`cfg.segment.backend='spm'`，并且`cfg.stopAfter='smooth'` 才执行群体配准及功能像标准化。

## 二、SPM 的三种 Normalise 操作

### 1. Normalise: Estimate：只估计变换

SPM 菜单路径为 `SPM → Spatial → Normalise → Estimate`。主要输入是 **Image to Align**，常规 task-fMRI 一般选择高分辨率 T1。

现代 SPM12 的 Estimate 不是单纯把 T1 强度图与另一张 T1 模板做像素匹配。它结合组织概率模板 TPM、偏置场和空间配准模型进行估计。Bias Regularisation、Bias FWHM、Affine Regularisation、Warping Regularisation、Smoothness、Sampling Distance 等概念与 Segment 很接近。

得到 `y_T1.nii` 不代表 EPI 已经变成 MNI 影像；还必须执行 Writing。

**独立 Estimate 的输出：**SPM12 的这一操作固定写前向场，没有选择逆向场的菜单。逆向场可以由 Segment 的相应输出选项或其他形变模块得到，不能把这些能力直接归到独立 Estimate 菜单。

**当前未开放：**本工具包没有独立 `Normalise: Estimate` 操作选择。当前通过 Segment/CAT 或群体配准估计变换；不能填 `cfg.normalise.method='estimate'`。`stopAfter='segment'` 也不等于单独的 Estimate 模块，通用入口在到达该阶段前仍会处理相关 BOLD 步骤。

### 2. Normalise: Write：应用已有变换

SPM 菜单路径为 `SPM → Spatial → Normalise → Write`。它读取已有形变场，不重新估计个体脑与模板的关系。

例如，T1 Segment 得到 `y_T1.nii`，EPI 已与 T1 配准，则可设置：

```text
Deformation Field：y_T1.nii
Images to Write：该被试预处理后的全部 EPI volumes
```

如果一个 run 有 240 帧，可以使用同一套 T1 非线性形变写出这 240 帧。不是每帧重新估计一个 T1 标准化模型；各帧之间的头动应已由此前步骤处理。

SPM 官方 task-fMRI 教程示例采用 `Coregistration → Segmentation → Normalise: Write`。我们的普通路线采用先 Segment 固定 T1、再让 EPI Coreg 到该 T1、最后 Write；关键是**应用时形变场与 EPI 具有正确的空间对应关系**。[SPM 官方 Normalisation 教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/block/preprocessing/normalisation/)

**代码对应：**默认 `segmentation` 路线调用的就是 `Normalise: Write`，自动关联当前分割结果和全部保留 BOLD/均值图。DARTEL/Shooting 选择 `group.writeMethod='deformations'` 时，也在合成最终 MNI 场后调用 Write；选择 `'native'` 时使用相应原生 MNI 写出函数，详见第五部分。

### 3. Normalise: Estimate & Write：估计和应用放在一起

SPM 菜单路径为 `SPM → Spatial → Normalise → Estimate & Write`。例如，T1 尚未分割、没有可用形变场，但功能像已与 T1 对齐，可把 T1 作为 Image to Align，把功能像作为 Images to Write，一次完成估计和写出。

其优势是操作集中，也适合不需要完整组织分类输出的情形。它不是比 `Segment + Write` 更高级的算法，重复运行也不意味着更准确。已经有可靠 Segment 形变场时，再 Estimate & Write 可能只是重复估计。

**当前未开放：**没有独立 Estimate & Write 选项，也没有“只读取任意外部 `y_`，跳过其他预处理，仅做 Normalise”的通用入口。本工具包的“一次运行”指整条已配置流水线自动调度，不表示必须用 SPM 的 Estimate & Write 模块。

## 三、Estimation Options：形变怎样估计？

### 1. 估计模型与参数

可以把形变估计理解为带约束的优化：

$$
E(T)=E_{\mathrm{matching}}(T)+\lambda R(T)
$$

第一项衡量个体与模板匹配得怎样；第二项约束变形是否合理。正则化太弱，可能出现不合理局部拉伸；太强，又可能不能充分匹配真实形态差异。

**Warping Regularisation 不是给最终 EPI 加空间平滑。**它限制估计的形变场；最终 BOLD 平滑是另一个参数。即使最终不做 Smooth，Normalization 的空间插值仍可能改变相邻 voxel 的信号关系。

| SPM Estimation 参数      | 常见初始值              | 它控制什么         |
| ---------------------- | ------------------------ | ------------- |
| Image to Align         | T1                       | 用哪张个体图像估计空间关系 |
| Bias Regularisation    | `0.0001`，独立 Estimate     | 偏置场的正则化约束     |
| Bias FWHM              | `60 mm`                  | 偏置场变化的平滑尺度    |
| Tissue Probability Map | `TPM.nii`                | 标准空间中各组织的概率先验 |
| Affine Regularisation  | `'mni'`                  | 整体仿射变换的先验约束   |
| Warping Regularisation | `[0 0.001 0.5 0.05 0.2]` | 非线性形变的约束      |
| Smoothness             | `0 mm`                   | 估计模型中的图像平滑设置  |
| Sampling Distance      | `3 mm`                   | 估计时的空间采样间隔    |

**模块默认值不能混用。**独立 Normalise: Estimate 的 Bias Regularisation 初始值是 `0.0001`；当前 SPM Segment 默认是 `0.001`。独立 Estimate 在内部还使用非参数组织强度表示等固定设置；不能因为理论相近，就把当前 Segment 调用说成与独立 Estimate 完全一样。

### 2. Image to Align 与 TPM 在当前接口怎样填写？

**代码对应：**主 T1 来自 `runs.tsv` 的 `t1` 列，不是在 Normalise 配置段写一个模板路径。`cfg.segment.inputVolume=1` 选择结构输入文件中的单幅 volume，填写从 1 开始、未超出该文件帧数的整数。普通 3D T1 填 1。

多结构通道由`cfg.segment.channelsFile`（配置第195行） 或逐 run `anatomy_channels` JSON 指定；`cfg.segment.channelAlignment`（配置第197行） 选择通道准备方式。它们影响结构分割输入，不是把多个功能 run 当作 T1 通道。详细候选与 JSON 格式见 [SEGMENTATION.md](Segmentation.md)。

TPM 路径由`cfg.spmPath`（配置第15行） 所指 SPM 安装定位，当前 SPM Segment 使用其固定六类 TPM。**没有独立自定义 TPM 路径选择。**`cfg.normalise.group.templates`（配置第288行） 是 DARTEL/Shooting 的群体模板输入，不是替换 Segment 的 TPM，也不是任意一张 MNI152 强度图。

### 3. Bias Regularisation 与 Bias FWHM

Bias Field 是缓慢变化的强度不均匀，例如同一种组织在脑的一侧更亮。估计时要尽量区分“组织本来不同”与“同组织被线圈照得不均匀”。

**代码对应：。**

```matlab
cfg.segment.biasRegularisation = 0.001; % 配置第201行
```

当前 SPM 菜单候选为 `0`、`1e-5`、`1e-4`、`0.001`、`0.01`、`0.1`、`1`、`10`。数值增加会加强偏置模型约束；`0` 表示不施加这一正则化，**不表示关闭偏置校正**。常规先保留 Segment 默认，不要仅为匹配独立 Estimate 的常见设置而机械改成 `0.0001`。

**代码对应：。**

```matlab
cfg.segment.biasFwhmMm = 60; % 配置第203行
```

候选为 `30、40、50、…、150` mm，以及 `Inf`。较大 FWHM 让偏置场更平滑、变化更慢；`Inf` 在该接口中表示关闭偏置校正。这个 FWHM 不是最终 BOLD 平滑核。多通道 JSON 可以覆盖逐通道偏置设置；应结合扫描质量选择，详见分割文档。

### 4. Affine Regularisation

这是整体仿射配准使用哪种先验，不是选择换一套标准空间模板。

**代码对应：。**

```matlab
cfg.segment.affineRegistration = 'mni'; % 配置第207行
```

| 输入          | 含义                | 建议                   |
| ----------- | ----------------- | -------------------- |
| `'mni'`     | 基于欧洲成人脑的常规仿射先验    | 当前默认，常规成人数据的起点       |
| `'eastern'` | 东亚脑相关仿射先验         | 有人群依据时考虑；不会自动替换 TPM  |
| `'subj'`    | 按个体脑大小设置先验        | 特殊需求时理解后采用           |
| `'none'`    | 仍做仿射配准，但不使用该正则化先验 | 不等于关闭仿射配准            |
| `''`，空字符    | 不做仿射初始化           | 不等于 `'none'`；常规不随意使用 |

这些是当前 SPM 分支选项。CAT 使用自己的结构处理与模板体系，部分共同字段只映射其初始准备阶段，不能把所有 SPM Warp 设置解释成 CAT 内部参数。

### 5. Warping Regularisation

**代码对应：。**

```matlab
cfg.segment.warpRegularisation = [0 0.001 0.5 0.05 0.2]; % 配置第213行
```

填写五个有限、非负的系数，对不同变形能量项施加约束。它不是五种互斥的算法，也不是五个被试各用一个值。常规先保持 SPM 默认；增加或减少某项，需要理解该项约束和实际形变质量。

DARTEL 的六行三列矩阵、Shooting 的五项速度正则化是各自算法的参数，**不能把这三个配置字段互相复制替代**。

### 6. Smoothness 与 Sampling Distance

**代码对应：。**

```matlab
cfg.segment.smoothnessMm = 0; % 配置第222行
```

填有限、非负的毫米值，默认 0。它对应结构估计模型中的 Smoothness，不是的 BOLD Smooth 核，也不是 DARTEL 的模板 LogOdds 平滑。

**代码对应：。**

```matlab
cfg.segment.warpSamplingMm = 3; % 配置第215行
```

填有限、正的毫米值。较小间隔使估计采样更密，通常增加计算量；它不是最终 MNI 输出体素大小。默认 3 mm 可作为常规起点，最终输出体素由另设。

### 7. 估计参数改了，旧形变场会跟着变吗？

不会。Writing 应用的是已经估计好的场。如果只对旧场做 Write，新的 Estimation 参数不会重新塑造那个场。当前工具包的完成恢复要求输入、配置等一致；改变结构估计参数后，应使用新的 `outputRoot` 做新的完整处理。

上述 Bias/Warp/Smoothness/Sampling 参数属于当前 SPM Segment 估计阶段，没有一组独立 `cfg.normalise.eoptions.*`。组织高斯数量、MRF、Cleanup，以及组织输出等属于 Segment 的其他设置，详见 [SEGMENTATION.md](Segmentation.md)。

## 四、Writing Options：怎样生成标准空间影像？

### 1. 写出参数总览

| SPM Writing 参数    | 常见值或示例                        | 作用             |
| ----------------- | ----------------------------- | -------------- |
| Deformation Field | `y_T1.nii`，示例文件               | 指定已有空间变换       |
| Images to Write   | 预处理后的全部 EPI volumes           | 指定实际需要重采样的影像   |
| Bounding Box      | `[-78 -112 -70; 78 76 85]` mm | 标准空间的输出范围      |
| Voxel Sizes       | `[2 2 2]` mm                  | 输出网格的体素尺寸      |
| Interpolation     | `4`，四阶 B-spline               | 怎样估计非整数采样位置的强度 |
| Filename Prefix   | `'w'`                         | 标识标准化写出文件      |

`y_T1.nii` 是示例名称，不是所有被试共同使用的固定文件。Bounding Box、Voxel Sizes、Interpolation 直接影响输出网格与信号采样，不能只看“有没有 w 前缀”判断正确性。

### 2. Deformation Field：形变场是什么？

它不是普通三维强度图，而是描述坐标对应关系的向量场。SPM 形变文件通常保存 X、Y、Z 三个坐标分量，单位为毫米；这些值是空间坐标，不是三个方向的 BOLD 强度，也不能直接当作位移大小。

虽然常把 `y_T1.nii` 称为 Native→MNI 的“正向场”，实际重采样通常采用 **pull（拉回）**：要计算 MNI 某个 voxel 的值，先查它对应原生图像的哪个位置，再在那里取样。因此，要区分“这份场完成哪一个空间转换”和“文件网格上的坐标值朝哪个空间取样”。

形变场必须与待写出的图像处于正确的物理空间关系中。若 T1 场正确，但 EPI 的空间矩阵后来被错误修改，使用同一个场也可能得到错误结果。Coregistration 的意义就在于建立这个对应关系，不能只凭文件名属于同一被试判断。

**代码对应：。**

```matlab
cfg.segment.deformationFields = 'forward'; % 配置第217行
```

| 输入                  | 保存什么                | 是否等于停止估计形变？ |
| ------------------- | ------------------- | ----------- |
| `'none'`            | 不保存 Segment 的前向/逆向场 | 否，分割仍估计空间关系 |
| `'inverse'`         | 只保存逆向场              | 否           |
| `'forward'`，默认      | 只保存前向场              | 否           |
| `'inverse_forward'` | 前向和逆向都保存            | 否           |

四种输入分别映射 SPM 的 `[0 0]`、`[1 0]`、`[0 1]`、`[1 1]`；第一位控制逆向，第二位控制前向。这里双向场的字符串是 `'inverse_forward'`，不要与偏置/组织输出菜单中的 `'both'` 混淆。

**这里控制 Segment 的输出保存，不是手工选择外部 Deformation Field 路径。**默认 segmentation 完整标准化需要前向场，必须选 `'forward'` 或 `'inverse_forward'`；`'none'`/`'inverse'` 在这条路线应停在 segment。图谱反向转换需要逆向场，可以由相应配置要求补齐，但不会自动替用户追加 forward。

DARTEL/Shooting 会另行生成最终群体路线的前向和逆向场，不依赖 Segment 自身保存 forward。它们会自动追加 GM/WM Imported 输出，保留原先请求的 Native 输出。

**当前场的自动关联与未开放部分。**

| 当前路线             | 自动使用的空间关系                   | 注意                                    |
| ---------------- | --------------------------- | ------------------------------------- |
| SPM segmentation | 当前 SPM 分割的前向场               | 不是任意另一个人的 `y_`                        |
| CAT segmentation | 当前 CAT 原生前向场                | CAT 与 SPM 的模板声明不能随意混用                 |
| DARTEL           | flow field、群体模板→MNI 关系及其合成场 | `u_*.nii` 不是普通 Normalise Write 的 `y_` |
| Shooting         | 原生形变、模板→MNI 关系及其合成场         | 原始 `y_` 在群体模板空间，不仅凭前缀认定已经是 MNI        |

群体模块保存 `y_group_forward.nii` 和 `y_group_inverse.nii`。后者虽仍以 `y_` 命名，记录的用途是逆向转换；**不能只看前缀判方向**。

**当前未开放：**统一入口没有任意外部 Deformation Field 的配置路径或 TSV 列，也没有外部 `u_`/`v_`/旧 `_sn.mat` 的通用导入。已有同一 T1 的完成解剖目录复用是受约束的旧功能，不等于“任意外部形变场输入”。因此不能简单说 Deformation Field 整项没实现：自动关联已实现，任意手工选场未开放。

### 3. Images to Write：不要漏掉 4D 时间序列

对一个 240 帧的 run，应该写出全部 240 帧。假设 `arfunc.nii` 是一个 4D 文件，`arfunc.nii,1` 只代表第一帧；普通 SPM Batch 中需要展开 `,1` 到 `,240`。

Normalization 是空间操作，正常情况下不会改变时间采样：

$$
N_{\mathrm{time,out}}=N_{\mathrm{time,in}},\qquad
TR_{\mathrm{out}}=TR_{\mathrm{in}}
$$

变化的是每帧的空间网格及 voxel 数值。

**代码对应：**功能像路径来自清单 `bold` 列，但实际交给标准化的是该 run 已完成前面步骤的工作结果。普通 Write/合成场 Write 自动展开全部保留帧；原生 DARTEL/Shoot 接收整个 4D 文件并在内部处理全部帧。两种方式都写出 Mean EPI。

若此前删除了 dummy scans，这里的 N 是**删除后的保留帧数**。例如 240 帧删除 4 帧后写出 236 帧；不能要求输出仍是 240。240 只是示例帧数，接口按实际保留帧数处理。

**当前未开放：**统一入口不是任意 Images to Write 列表的通用工具。SPM 理论上可应用到 beta、激活图、掩膜、ROI 等，但当前主流程自动写出 BOLD 和均值；图谱反向转换由独立 atlas 配置处理。没有任意追加 beta/mask 列表的配置行。

### 4. Bounding Box：输出到多大范围？

SPM12 的经典设置为：

```matlab
bb = [-78 -112 -70; ...
       78   76  85];
```

单位是毫米，第一行是下界，第二行是上界：

| 轴   | 下界   | 上界  | 常规 MNI 物理坐标方向    |
| --- | ---- | --- | ---------------- |
| X   | -78  | 78  | 负值左侧，正值右侧；0 近似中线 |
| Y   | -112 | 76  | 负值后方，正值前方        |
| Z   | -70  | 85  | 从较下方向较上方         |

这是世界坐标方向；不能据此假定某个 NIfTI 数组的第一维必然按左→右增加，要结合 header 的空间矩阵。

即使两个人都在 MNI 空间，如果 Bounding Box 不同，数组大小和覆盖范围也可能不同。做直接逐体素比较时，还需要一致的输出网格。

**Bounding Box 不是 brain mask。**盒子内仍可能有脑外区域，或没有采集到有效信号的位置。扩大盒子不能恢复额叶/颞叶的信号缺失。

它与体素大小共同决定矩阵大小，近似为：

$$
N_x\approx\frac{x_{\max}-x_{\min}}{v_x}+1,\quad
N_y\approx\frac{y_{\max}-y_{\min}}{v_y}+1,\quad
N_z\approx\frac{z_{\max}-z_{\min}}{v_z}+1
$$

实际还涉及离散网格与边界取整，应读取最终 NIfTI header。本机此前只读核对的普通 Normalise Write，在经典盒子和 2 mm 网格下得到 `79×95×79`；不要把这个数字当作所有模板/写出器都固定相同的结果。

**代码对应：。**

```matlab
cfg.boundingBoxMm = [-78 -112 -70;78 76 85]; % 配置第344行
```

填写有限的 `2×3` 数值矩阵，各轴下界小于上界。当前接口不开放 NaN 自动边界盒。两个群体写出方式都使用该设置；普通研究可先保持默认，再依据模板、覆盖与研究目标决定是否改动。

### 5. Voxel Sizes：更细的输出网格不等于更多原始信息

必须区分：**采集分辨率、输出采样网格、真正的信息分辨率**。

例如原始 EPI 是 `3×3×3 mm`，标准化输出设为 `2×2×2 mm`。新 voxel 由插值得到，不是额外扫描出来的；不能说真实空间信息已经从 3 mm 提升到 2 mm。

| 网格         | 单个 voxel 体积 |
| ---------- | ----------- |
| `3×3×3 mm` | `27 mm³`    |
| `2×2×2 mm` | `8 mm³`     |

同一输出范围内，voxel 数量大致满足：

$$
N_{\mathrm{voxel}}\propto\frac{1}{v_xv_yv_z}
$$

因此，3 mm 改成 2 mm 时，数量比例约为：

$$
\frac{N_{2\mathrm{mm}}}{N_{3\mathrm{mm}}}
\approx\frac{27}{8}=3.375
$$

空间采样点约为原来的 3.4 倍。文件和计算成本通常也会增加，但压缩率、数据类型及算法开销不同，不能保证磁盘占用或运行时间恰好增加 3.375 倍。在 48 名被试、每 run 240 帧的批次中，这个差异会累积得很明显。

| 等方性输出大小 | 主要特点                    | 常见考虑                       |
| ------- | ----------------------- | -------------------------- |
| 1 mm    | 网格细、文件很大，普通 EPI 可能明显过采样 | 高分辨率结构或有明确匹配要求时考虑          |
| 2 mm    | 常见 MNI 网格，便于一些标准图谱/组分析  | 常规 fMRI 可作为起点，但不是所有数据的唯一推荐 |
| 3 mm    | 接近很多 EPI 的采集尺寸，输出较小     | 常规功能分析、部分 ROI/MVPA 方案可考虑   |
| 4 mm    | 输出更小，空间采样更粗             | 有依据的粗尺度分析或工程调试；不适合直接声称精细定位 |

SPM 官方教程也允许原始 EPI 接近 3 mm 时使用 `[3 3 3]`，进一步缩小网格不会创造新的采集信息。[SPM 官方 Normalisation 教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/block/preprocessing/normalisation/)

对于 RSA 和 BNA-246 ROI 分析，输出网格还会影响 ROI 中有多少采样点，以及图谱如何与功能像对齐。一个小 ROI 在 2 mm 网格下可能有 100 个 voxel，在 3 mm 下约 30 个；这不等于前者有三倍独立神经信息，因为插值后的点往往高度相关。

传统组水平激活分析可把 2 mm 作为起点。原始 EPI 为 3 mm 的 ROI/RSA 研究，可以预先比较 2 mm 与接近采集尺寸的方案，但不能为获得显著性而事后挑选分辨率。这里是方法选择讨论，**不表示工具包已实现 RSA/BNA 全部分析**。

**代码对应：。**

```matlab
cfg.voxelSizeMm = [2 2 2]; % 配置第342行
```

填写三个有限、正的毫米值，例如 `[3 3 3]`。允许不同轴不同大小，但应有研究依据；不要与 Segment 的 3 mm Sampling Distance 混淆。原生群体写出要求等方性的是**平滑核**，不是在这里把所有输出网格都强制限制为等方性。

### 6. Interpolation：非整数位置怎样取值？

变换后要取样的位置通常不在原始 voxel 中心。例如某个目标 voxel 对应原图数组坐标 `(31.4, 48.2, 20.7)`，需要根据附近点估计信号。

| 输入数值 | SPM 普通 Write 插值     | 含义及常见用途                     |
| ---- | ------------------- | --------------------------- |
| `0`  | Nearest Neighbour   | 最近邻，保留离散标签编号；标签图、二值 mask 常用 |
| `1`  | Trilinear           | 三线性，利用相邻点线性估计；较快，适用于连续信号    |
| `2`  | 2nd Degree B-spline | 二阶 B-spline                 |
| `3`  | 3rd Degree B-spline | 三阶 B-spline                 |
| `4`  | 4th Degree B-spline | 四阶 B-spline，普通 Write 的常见默认  |
| `5`  | 5th Degree B-spline | 五阶 B-spline，计算通常更重          |
| `6`  | 6th Degree B-spline | 六阶 B-spline，计算通常更重          |
| `7`  | 7th Degree B-spline | 七阶 B-spline，计算通常更重          |

四阶 B-spline 能较连续地估计非整数位置的强度，但也可能出现局部过冲，结果超出邻近原信号范围。不是阶数越高就一定越适合研究。本机普通 Write 的菜单说明还提示 Inf/NaN 会按零值处理，而不是作为缺失观测；因此不能仅凭输出变得有限，就认为原来没有覆盖的位置已经获得真实信号。

对普通连续 EPI/T1，可把普通 Write 的 4 作为起点。对 BNA-246 这类离散图谱，如果邻近点是 ROI 17 与 18，B-spline 可能生成 `17.4`、`17.8` 等没有意义的编号；最近邻保留整数，但边界可能阶梯化。连续概率图则常用线性插值，不能与离散标签混为一谈。

MVPA/RSA 还需注意：**不执行 Smooth，不等于完全保留原始空间模式。**Normalization 的插值本身仍会改变相邻采样点的依赖关系。

**代码对应：。**

```matlab
cfg.normalise.interpolation = 4; % 配置第340行
```

接受整数 `0～7`，但是否生效取决于写出方式：

| 路线                                             | 该行是否控制 BOLD 插值？         |
| ---------------------------------------------- | ----------------------- |
| `method='segmentation'`                        | 是，传给 Normalise Write    |
| DARTEL/Shooting 且 `writeMethod='deformations'` | 是，传给 Normalise Write    |
| DARTEL/Shooting 且 `writeMethod='native'`       | 否，SPM 原生函数固定三线性；实际记录为 1 |

不要为了图谱把整个 BOLD 写出插值改成 0。工具包 atlas 模块会对标签使用最近邻、对概率使用线性，两者分别处理。

### 7. Preserve：是否按局部体积变化调制？

Preserve Concentrations 与 Preserve Amount/Total 的区别如下：

| 选择                      | 含义                      | 常见用途         |
| ----------------------- | ----------------------- | ------------ |
| Preserve Concentrations | 不进行体积调制，保留信号强度的意义       | 常规 BOLD/fMRI |
| Preserve Amount / Total | 考虑形变导致的局部体积变化，使总量意义尽量保留 | VBM 等组织量分析   |

可以用 Jacobian determinant 理解局部体积变化：

$$
J_T(\mathbf{x})=\left|\det\left(\frac{\partial T}{\partial\mathbf{x}}\right)\right|
$$

调制希望在相应空间变换下近似保持积分总量：

$$
\int I_{\mathrm{warped}}(\mathbf{u})\,d\mathbf{u}
\approx\int I_{\mathrm{native}}(\mathbf{x})\,d\mathbf{x}
$$

实际乘除方向取决于变换/拉回表示，不能看到一个 Jacobian 文件就直接乘到 BOLD 上。任务态 BOLD 和 RSA 通常不需要组织量调制；不能机械照搬 VBM 设置。

普通现代 Normalise Write 的有效菜单主要是 bb、vox、interp、prefix。SPM 源码虽然保留 Preserve/Wrapping 的定义，但没有把它们放进该模块的有效 `woptions`；不能只往 batch 加字段就宣称生效。

。**

```matlab
cfg.normalise.group.preserve = 0; % 配置第294行
```

| 输入     | 适用范围                    | 实际前缀         |
| ------ | ----------------------- | ------------ |
| `0`，默认 | 原生群体写出；合成场 Write 也只允许 0 | `w*`、`sw*`   |
| `1`    | 仅 DARTEL/Shooting 的原生写出 | `mw*`、`smw*` |

这个字段不是普通 segmentation Write 的菜单。虽然接口允许原生调制写出，但并不代表已经建成完整 VBM 工具链；本工具包的 BOLD 主流程一般保留 0。

### 8. Wrapping 与 Filename Prefix

Wrapping 控制边界的周期性处理，传统设置常见 `wrap=[0 0 0]`。它可能出现在旧 Normalise 或其他 Reslice 菜单中，不等于 EPI 畸变校正，也不能恢复采集缺失区域。

**当前未开放：**没有 Normalise 专用 Wrapping 配置，普通现代 Write 也没有有效的这一菜单。Realign/Unwarp 的 wrap 设置属于那些模块，不控制 Normalise。

普通前缀变化例子为：

```text
arfunc.nii → warfunc.nii → swarfunc.nii
             Write          Smooth
```

`a` 可能代表 STC，`r` 可能代表 Realignment Reslice，`w` 代表标准化，`s` 代表平滑。不是所有 run 都一定有这些前缀，取决于实际步骤。

**代码对应：**普通 Write 前缀固定 `w`，Smooth 固定 `s`，没有可调 Normalise Prefix 行。原生 Preserve=1 输出 `mw/smw`；后续应读完成记录中的实际路径，不能始终猜 `sw*`。`cfg.sdc.spm.outputPrefix`（配置第132行）、`cfg.atlas.prefix`（配置第255行） 都不是此处的前缀设置。

## 五、其他标准化方法，以及接口

### 1. Old Normalise：旧式模板匹配

Old Normalise 使用较早的仿射配准及低频基函数非线性形变，直接利用模板匹配。它与现代统一分割路线不同，常以 `_sn.mat` 等旧参数文件保存结果。

| 代表性估计参数                    | 经典设置 | 主要作用               |
| -------------------------- | --------- | ------------------ |
| Source Image Smoothing     | 8 mm      | 估计前源图平滑            |
| Template Image Smoothing   | 0 mm      | 估计前模板平滑            |
| Affine Regularisation      | 与人群相关的先验  | 约束整体仿射             |
| Nonlinear Frequency Cutoff | 25 mm     | 控制非线性基函数可表达的空间变化尺度 |
| Nonlinear Iterations       | 16 次      | 非线性优化迭代            |
| Nonlinear Regularisation   | 1         | 限制非线性形变复杂程度        |

较小 cutoff 通常可使用更多基函数，表达更复杂局部变化；不是最终 EPI 平滑 FWHM。迭代次数影响优化，不能与新路线默认迭代直接等价比较。

**当前未开放：**没有 `'oldnorm'` 路线和上述参数字段。它适合有明确需求的早期研究复现，新常规 fMRI 不必因为方法更多就加入旧方法。这些选项用于理解旧式方法，当前配置中没有相应字段。

### 2. DARTEL：利用组织图建立群体对应

DARTEL 全称 **Diffeomorphic Anatomical Registration Through Exponentiated Lie Algebra**。它常从各被试的 DARTEL-imported GM/WM 图，如 `rc1*`、`rc2*` 出发，迭代建立群体模板，估计每个人到模板的高维变换。

可以把它理解为：先粗略对齐灰质/白质分布，再反复更新“群体平均形态”与每个人的配准，让局部对应逐渐更细。微分同胚框架旨在得到平滑、可逆、避免折叠的变换，但算法名称本身不是某次数据已经质量合格的证明。

它尤其常用于 VBM 和结构形态学。功能像也可以沿用结构变换，但质量仍取决于 EPI→T1 配准、畸变与信号覆盖。

**群体模板不自动等于 MNI。**还需要建立模板→MNI 的关系，才能输出标准 MNI 坐标结果。这也是工具包群体阶段的一部分。[SPM DARTEL 官方指南](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/dartelguide/dartelguide/)

**代码对应：设 `'dartel'`，设 `'spm'`。群体程序自动追加 GM/WM Imported；Imported 输出只是输入准备，真正的模板创建/配准由后续 DARTEL 原生函数执行。

#### 2.1 六轮参数是什么意思？

接口固定六个外轮，由较强约束逐渐细化；数组的六项是六个轮次，不是六个被试。

| 字段与配置行                                        | 默认、可选输入                       | 含义与建议                                                                  |
| --------------------------------------------- | ----------------------------- | ---------------------------------------------------------------------- |
| `cfg.normalise.dartel.regularisationForm`（配置第298行） | `0`；可选 `0/1/2`                | 0 线弹性，1 膜能量，2 弯曲能量；先保留默认，切换需理解三列系数意义                                   |
| `cfg.normalise.dartel.innerIterations`（配置第300行）    | `[3 3 3 3 3 3]`；六个 `1～10` 整数  | 各外轮的内部 Gauss-Newton 次数；不是最后求解器的循环数                                     |
| `cfg.normalise.dartel.regularisation`（配置第302行）     | 下表六行三列，有限非负                   | 各轮的形变约束；不是 Segment 五项 Warp 向量                                          |
| `cfg.normalise.dartel.timeSteps`（配置第304行）          | `[0 0 1 2 4 6]`；六个 `0～9` 整数 K | 实际积分步数为 `2^K`；默认最后 64 步，最终 flow→形变也使用最后一项                              |
| `cfg.normalise.dartel.templateSmoothing`（配置第306行）  | `[16 8 4 2 1 0.5]`            | 每项候选 `0/0.5/1/2/4/8/16/32`，模板 LogOdds 平滑参数；只用于 create，不是 BOLD 的毫米 FWHM |
| `cfg.normalise.dartel.lmRegularisation`（配置第308行）   | `0.01`；有限非负                   | Levenberg-Marquardt 优化约束；0 转为 Gauss-Newton，本机原生说明不建议常规这样做              |
| `cfg.normalise.dartel.solverCycles`（配置第310行）       | `3`；整数 `1～8`                  | 多重网格求解循环数，增加通常更慢                                                       |
| `cfg.normalise.dartel.solverIterations`（配置第312行）   | `3`；整数 `1～8`                  | 每个求解循环内部的松弛迭代次数                                                        |

默认矩阵为：

| 外轮  | 第一列  | 第二列   | 第三列      |
| --- | ---- | ----- | -------- |
| 1   | 4    | 2     | 0.000001 |
| 2   | 2    | 1     | 0.000001 |
| 3   | 1    | 0.5   | 0.000001 |
| 4   | 0.5  | 0.25  | 0.000001 |
| 5   | 0.25 | 0.125 | 0.000001 |
| 6   | 0.25 | 0.125 | 0.000001 |

三列并非始终同义。按本机 DARTEL Run 配置说明，线弹性使用 `mu、lambda、id`；膜能量使用 `lambda、未使用、id`；弯曲能量使用 `lambda、id1、id2`。这些决定不同变形能量的权重，不是 x/y/z 三轴体素大小。

常规先用原生默认。减少轮内迭代或积分步只能作为工程调试选择，不能直接认为科研精度足够。

### 3. Geodesic Shooting：另一种高维形变优化

Shooting 同样采用微分同胚理论，通过速度场及其演化描述复杂形变，与 DARTEL 使用不同优化策略。它也常用于高精度结构配准与 VBM，不是普通 task-fMRI 必须再额外运行的一步。

**代码对应：设 `'shooting'`，仍为 `'spm'`。这是独立 SPM Shoot 路线，与 CAT 内部 Shooting 不是同一个调用路径。[SPM Shooting 教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/vbmcourse24/preprocessing/)

#### 3.1 高级参数为什么不是 SPM GUI 菜单？

SPM Shoot 的高级值本来从 `spm_shoot_defaults.m` 读取。接口读取本机 defaults，映射以下字段，在结果目录创建本次私有适配，仅调用期间加入 MATLAB 路径，结束或出错后恢复环境。**不会修改 SPM 安装目录中的 defaults 文件。**

| 字段与配置行                                              | 默认、允许输入                            | 含义与建议                                   |
| --------------------------------------------------- | ---------------------------------- | --------------------------------------- |
| `cfg.normalise.shooting.iterations`（配置第317行）             | `24`；整数 `2～1000`                   | Gauss-Newton 配准总迭代；小值适合工程调试，正式研究先用默认    |
| `cfg.normalise.shooting.regularisation`（配置第319行）         | `[1e-4 0.001 0.2 0.05 0.2]`，五项有限非负 | 官方 `rparam` 速度场正则化；不是 Segment Warp 向量   |
| `cfg.normalise.shooting.templateRegularisation`（配置第321行） | `[0.0001 0.08 0.8]`，三项有限非负         | 官方 `sparam` 模板约束，只用于 create；不是 BOLD 平滑核 |
| `cfg.normalise.shooting.smoothingIterations`（配置第323行）    | `16`；整数 `0～1000`                   | create 中的模板平滑迭代，existing 不使用            |
| `cfg.normalise.shooting.solverCyclesIterations`（配置第325行） | `[2 2]`，两个 `1～100` 整数              | 官方 `cyc_its`，求解循环和内部迭代                  |
| `cfg.normalise.shooting.stepScale`（配置第327行）              | `0.8`；`0<值≤1`                      | 更新步长比例；先保留默认，避免无依据大改                    |
| `cfg.normalise.shooting.maxTimeSteps`（配置第329行）           | `8`；整数 `1～64`                      | 最大积分步数，按原公式逐轮增加；不是 DARTEL 的指数 K         |
| `cfg.normalise.shooting.coarseScale`（配置第331行）            | `32`；有限值 `≥1`                      | 粗到细 schedule 的起始尺度，不是 voxel size        |
| `cfg.normalise.shooting.scheduleDecay`（配置第333行）          | `0.5`；有限正数                         | schedule 的衰减率，最终归一化到 1                  |
| `cfg.normalise.shooting.symmetricTemplate`（配置第335行）      | `false/true`                       | create 时普通/左右对称模板；existing 不改变已有模板      |

工具包保留官方 schedule 公式，只把可选值映射进去。令 n 为迭代数、C 为 coarseScale、λ 为 scheduleDecay：

$$
q_i=(C-1)e^{-\lambda i}+1,\qquad
\mathrm{sched}_i=\frac{q_i}{q_n},\quad i=0,\ldots,n
$$

令 M 为 maxTimeSteps，积分步序列为：

$$
\mathrm{eul\_its}_i=\operatorname{round}\left[
\frac{i(M-0.5001)}{n-1}+1\right],\quad i=0,\ldots,n-1
$$

接口按这些公式生成原生 Shooting 使用的迭代设置，仍调用 SPM 的优化器。的正数在当前校验中还要求不小于 MATLAB 的 `eps`，不能输入任意接近零的小值。未开放的原生项，例如 `bs_args`，保留本机 defaults 并记录，不声称所有内部参数均可选择。

### 4. 建模板还是用已有模板？怎样避免多 run 重复计入？

以下群体设置仅对 DARTEL/Shooting 生效。

**代码对应：。**

```matlab
cfg.normalise.group.mode = 'create'; % 配置第286行
cfg.normalise.group.templates = {}; % 配置第288行
cfg.normalise.group.anatomyUnit = 'subject'; % 配置第290行
```

| 字段                                | 候选与填写方式                          | 意义                                                                |
| --------------------------------- | -------------------------------- | ----------------------------------------------------------------- |
| `cfg.normalise.group.mode`（配置第286行）        | `'create'`，默认                    | 本批唯一结构单位一起建立模板                                                    |
| 同上                                | `'existing'`                     | 配准到已有匹配模板，不重新建立                                                   |
| `cfg.normalise.group.templates`（配置第288行）   | create 留空 `{}`                   | 程序使用新生成的模板                                                        |
| 同上                                | existing 填绝对 `.nii` 路径 cell，按粗到细 | DARTEL 恰好六项 `Template_1～6`；Shoot 至少一项，常规 24 轮常见 `Template_0～4` 序列 |
| `cfg.normalise.group.anatomyUnit`（配置第290行） | `'subject'`，默认                   | 同一被试所有 run 使用一致 T1、volume、通道及参数                                   |
| 同上                                | `'subject_session'`              | 纵向不同 session 可使用不同结构输入；相同解剖内容仍去重                                  |

已有模板必须是匹配的原生多通道模板：DARTEL GM/WM，Shoot GM/WM/背景；Imported 图与模板需要一致且符合算法要求的网格。不是任意 T1 强度图，也不是只要文件名有 MNI 就可用。

例如 24 名被试各两个 run，清单填 **48 行**，默认模板使用 **24 套结构单位**，不会让某人因有更多 run 在模板中被重复计数。相同被试完全相同的 T1 内容副本会去重；同一结构单位的冲突输入会报错，不同被试也不能指向同一个原始 T1 文件。

外部模板先复制到本次工作目录，模板→MNI 缓存只写到副本旁。程序检查模板路径、通道、网格与来源；检查通过不证明模板一定适合研究人群。Imported 图在视野外可能有原生 NaN，程序保留这些缺失值，检查有效概率、无 Inf 与 GM/WM 缺失位置一致，不自行把缺失填成组织概率。

### 5. 两种写出方式：哪些参数生效？

**代码对应：。**

```matlab
cfg.normalise.group.writeMethod = 'native'; % 配置第292行
```

| 选项               | 实际调用                                     | 插值/平滑                      | Preserve |
| ---------------- | ---------------------------------------- | -------------------------- | -------- |
| `'native'`，默认    | `spm_dartel_norm_fun` 或 `spm_shoot_norm` | 固定三线性；原生等方性平滑              | 0 或 1    |
| `'deformations'` | 合成最终 MNI 拉回场 → Normalise Write → Smooth  | 0～7 插值；三轴 Smooth 核 | 只允许 0    |

原生写出采用 SPM 自身的推送/加权实现，未调制的平滑结果涉及原生权重处理；不是“普通拉回 Write 后再做一次 Smooth”的数值复刻。原生函数要求此前功能像已完成头动处理并实际重采样到共同网格，不能把仅修改各帧 header 的 Estimate 当成已完成这一准备。两种方式沿用同一结构配准结果，**不保证采样值与平滑结果相同**。

**代码对应：。**

```matlab
cfg.smoothingFwhmMm = [6 6 6]; % 配置第352行
```

填写三个有限、非负毫米值，`[0 0 0]` 表示不增加平滑。普通 segmentation 与 deformations 可以设置不同轴核；native 要求三项相同，否则在昂贵计算前报错。例如 `[4 4 6]` 需用 deformations。这里保留这行说明以解释群体写出；完整平滑理论属于后续 Smooth 文档。

两种方式都保留未额外平滑 BOLD 和平滑版本，Mean EPI 也标准化。native 不再无条件叠加普通 Smooth；核为 0 时，带 s 的结果是明确副本，不再重复重采样。

### 6. CAT 内部 Shooting 与独立 Shoot 的区别

`cfg.normalise.method='segmentation'`、`cfg.segment.backend='cat12'` 时，CAT 在自己的结构处理流程中使用内部配准/模板，主接口应用 CAT 的最终场。`cfg.segment.cat12.*` 控制 CAT 路径、精度与结构输出，详见分割文档。

不能把的独立 SPM Shooting 参数当成 CAT 内部参数；也不能同时选 CAT 后端再要求独立 DARTEL/Shoot。CAT 与 SPM 模板体系及图谱 Space 声明需匹配，不能仅因都称 MNI 就无条件混用。

### 7. 方法选择的整体建议

| 方法                   | 配准思路            | 常见用途                 | 当前接口与建议        |
| -------------------- | --------------- | -------------------- | -------------- |
| Old Normalise        | 较早的仿射＋低频非线性模板匹配 | 复现早期研究               | 未开放；有复现依据时另行设计 |
| Unified Segmentation | 组织、偏置、配准联合估计    | 常规 task-fMRI、GLM、ROI | 默认路线，先检查数据质量   |
| DARTEL               | 高维群体组织配准        | VBM、较细的群体解剖对应        | 已加入，按模板/研究需要选择 |
| Geodesic Shooting    | 速度场演化的高维微分同胚配准  | 结构配准、VBM             | 已加入独立路线，按需要选择  |

复杂模型不会自动提高 RSA 效应或功能定位准确性。功能区真实个体差异、EPI 分辨率、磁敏感畸变与信号丢失仍然存在。更精细的 T1 配准不能替代 SDC，也不能补回没有采到的 BOLD。

## 六、一次运行、重采样与输出：代码额外做了什么？

### 1. 统一入口的实际顺序

影像路径及逐 run 信息填写在清单，全局参数在 `toolkit_config.m`。`cfg.execute=false` 为预检；核对后改 true，再运行 `run_toolkit.m`。HCP 入口 `run_preprocessing.m` 另有数据发现和部分覆盖配置，不能只改通用配置却忽略 HCP 示例自己的开关。

普通 segmentation 路线沿用逐 run 的空间预处理。DARTEL/Shooting 则需要先准备全批结构关系：

```text
全批输入预检／需要时 DICOM 转换
  → 整理唯一结构单位，检查冲突
  → 每套结构 Segment，生成 Imported GM/WM
  → 建立模板或配准到已有模板
  → 建立模板→MNI 关系，保存最终前向/逆向场
  → 逐 run 执行 dummy、所选时序/畸变/头动步骤
  → EPI Coreg 到固定 T1
  → 全部保留帧标准化／平滑／工程检查
```

结构处理先出现，是为了群体配准准备，不代表在功能像头动处理之前已把 BOLD 标准化。全批预检失败时，不会悄悄丢掉失败被试再用另一个成员集合建模板。纯 DICOM 在转换前的预检只能确认序列清单，不能预先保证转换后模板网格兼容。

`cfg.stopAfter`（配置第25行） 可选 `'realign'`、`'segment'`、`'smooth'`。完整标准化到平滑选 smooth；没有独立 `'normalise'` 停止点。混合清单中的 VDM-only 行不参与模板；全批仅 VDM-only 应用原场图路线。

### 2. 为什么应减少重复重采样？当前做到了哪一步？

每次 interpolation 都会改变信号的空间采样，连续图像可能更模糊，局部模式也可能改变。现代流程的理想策略是先估计 motion、distortion、normalization 等变换，尽量合并后一次重采样。

**当前边界：本工具包尚未把头动、SDC、Coreg、Normalization 的所有空间变换统一成一次最终 BOLD 重采样。**DARTEL/Shooting 的形变合成处理的是结构/群体模板/MNI 之间的关系，不等于整条流水线只插值一次。native 保留两类结果也属于原生写出策略，不能据此宣称所有步骤已经合并。

因此，“使用了 Deformations”与“整个 pipeline 只有一次 resampling”是两件事。原始数据不改动，后续仍需按研究方案评估重采样和模式分析影响。

### 3. 逆向场如何用于图谱？

匹配标准空间的图谱也可写到个体空间：

| 字段与配置行                        | 候选与作用                                                                      |
| ----------------------------- | -------------------------------------------------------------------------- |
| `cfg.atlas.enabled`（配置第247行）       | `false/true`，是否启用逆向图谱转换                                                    |
| `cfg.atlas.manifestFile`（配置第249行）  | 图谱 JSON 路径；也可由逐 run `atlases` 提供                                           |
| `cfg.atlas.target`（配置第251行）        | `'t1'` 或 `'bold'`，写到个体 T1 或 Coreg 后未标准化 BOLD 网格；bold 需要 stopAfter='smooth' |
| `cfg.atlas.ensureInverse`（配置第253行） | `true/false`；普通分割路线是否要求补齐可用逆向场                                             |
| `cfg.atlas.prefix`（配置第255行）        | 个体图谱文件前缀，默认 `'native_'`；字母开头，后续字母/数字/下划线；不控制 BOLD 的 w/s                    |

群体路线使用自身最终逆向场，不误用 Segment 的另一套 `iy_`。标签最近邻、概率线性，不做标签平滑或体积调制。图谱 Space 声明要匹配 `spm_tpm_mni` 或 CAT 对应的 `cat12_mni2009c`；声明匹配不代表人工叠加检查已经通过。格式、覆盖及选项细节见 [SEGMENTATION.md](Segmentation.md)。

### 4. 输出与完成记录在哪里？

输出由用户设置的 `outputRoot` 决定，应放在精简代码发布目录之外。群体路线典型记录如下，尖括号表示按实际方法替换，不是字面文件夹名：

```text
outputRoot/
  normalisation_group/<dartel 或 shooting>/
    GROUP_PLAN.mat
    anatomy_0001/anat/...                每套唯一结构的工作结果
    ...                                 其余结构、模板及配准作业
    GROUP_COMPLETE.mat
```

最终双向场保存在对应结构的 `normalisation_fields/`。原生模板可能位于首个结构的 anat 目录；程序保存实际路径，不能只凭这一示意图猜模板文件位置。原生 registration/写出 `job.mat` 记录 API 参数和执行函数，未必含可直接 `spm_jobman` 重放的 `matlabbatch`。

每个 run 有原有作业和 `COMPLETE.mat`，群体标准化写出 `NORMALISATION_COMPLETE.mat`，记录实际 normalized/smoothed/mean 路径、方法、writeMethod、Preserve、实际插值、网格、帧数、TR 和工程检查。native 平滑作业为 `06_native_smooth.mat`，普通 Write 后 Smooth 为 `06_smooth.mat`；应根据记录定位结果。

群体组织图位于共享结构目录。旧 QC/混杂示例若假定每 run 都有自己的 `anat/c2/c3`，不能直接用于新布局，需要使用记录中的实际结构路径。标准化不会自动执行时间去噪、FC/PPI/DCM 或 GLM 组统计。

### 群体结果的复用条件

复用群体完成结果时会核对结构成员、解剖输入、模板、配置、代码、SPM模块和实际输出哈希。成员或模板改变后应使用新 outputRoot；旧 `anatomy_reuse_dir` 不能作为群体变换入口。`GROUP_COMPLETE.mat` 保存实际模板、结构与最终场的对应关系，不能只凭目录名推断某个 run 使用了哪套变换。
