# 10. Susceptibility Distortion Correction：磁敏感畸变校正

本章说明磁场不均匀如何造成 EPI 畸变，以及 GRE 场图、已有 VDM、Apply VDM、Realign & Unwarp 和 FSL TOPUP 的输入、参数与处理路线。配置决定计算方式，逐 run 的 JSON 描述真实采集信息。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

## 一、磁敏感畸变校正做什么？

EPI 有一个很明显的问题：主磁场 **B₀ 不均匀**时，脑组织在图像中的位置可能发生局部偏移。比较容易受影响的区域包括眶额皮层（orbitofrontal cortex）、下颞叶（inferior temporal cortex）和颞极（temporal pole），因为它们靠近空气与组织的交界。

Susceptibility Distortion Correction，简称 **SDC**，主要纠正这种空间几何畸变（geometric distortion）。它与头动校正 Realignment 的任务不同：头动校正处理头部整体的平移、旋转；SDC 处理图像中的局部拉伸、压缩和位置偏移。

常见思路有两类：

- **FieldMap：**额外采集相位和幅度图，估计局部 B₀ 偏差，生成体素位移图 VDM，再利用 VDM 校正 EPI。
- **反向相位编码：**例如采集 AP、PA 两套方向相反的 EPI，用 FSL TOPUP 估计畸变场。这是现代 fMRI 流程中常用的一类方案。

在 SPM 中，还要区分 **Calculate VDM、Apply VDM、Realign & Unwarp**：第一项准备位移信息，第二项应用静态位移，第三项建模运动相关动态畸变，并可同时使用实测 VDM。TOPUP 则属于 FSL，不是 SPM FieldMap 菜单里的一个普通选项。

## 二、为什么 EPI 会发生畸变？

### 1. 磁敏感性与局部磁场不均匀

MRI 依赖主磁场 B₀，例如 3 T。理想情况下，扫描范围内的磁场应尽可能均匀。但不同物质对磁场的响应不同，这种属性叫作 **magnetic susceptibility，磁敏感性**。

在人脑中，空气与脑组织之间的磁敏感性差异比较典型，尤其是鼻窦附近的眶额皮层、颞叶底部、颞极、下颞叶，以及颞骨附近的部分区域。局部磁场可以写成：

$$
B(\mathbf r)=B_0+\Delta B_0(\mathbf r)
$$

其中，`r` 表示空间位置，`ΔB₀(r)` 表示该位置相对于主磁场的偏差。按照拉莫尔关系，它会带来共振频率偏移：

$$
\Delta f(\mathbf r)=\frac{\gamma}{2\pi}\Delta B_0(\mathbf r)
$$

对于质子：

$$
\frac{\gamma}{2\pi}\approx42.58\ \mathrm{MHz/T}
$$

也就是说，磁场只发生很小的变化，也可能产生几十 Hz 甚至更大的频率偏移。

### 2. 为什么 EPI 对磁场不均匀特别敏感？

EPI（Echo-Planar Imaging）为了快速获得一张二维切片，在一次激发后连续读取大量 k-space 数据。它沿**相位编码方向的有效带宽通常较低**，所以局部频率偏移容易被误认为位置变化。

结果是：组织的真实位置与它在 EPI 中显示的位置不一致。常见表现包括：

| 表现 | 通俗解释 |
|---|---|
| Geometric displacement：空间位移 | 某块组织的信号被显示到了别的位置 |
| Stretching：拉伸 | 原本较窄的区域被展开得更宽 |
| Compression：压缩 | 原本较宽的区域被挤进很小的空间 |
| Signal pile-up：信号堆积 | 多处组织的信号挤到少量体素里，局部强度可能异常 |

这些问题会影响 EPI 与 T1 的配准，也可能使标准化后的功能信号落在不准确的解剖位置。

### 3. 几何畸变与信号丢失不是同一件事

磁敏感效应还可能造成局部去相位，尤其是层厚方向的去相位（through-slice dephasing），表现为 **signal dropout，信号丢失**。

假设一个眶额皮层体素本来有 BOLD 信号，但扫描时因为严重去相位，几乎没有收到有效信号。即使 FieldMap 很准确，也无法凭空恢复没有被测量到的神经信号。

因此，SDC 主要纠正空间编码错误。采集阶段的 TE、体素大小、相位编码方向、并行采集加速和局部场均匀性仍然重要，不能指望后处理解决所有信号缺失。

## 三、几种校正路线的核心区别

先建立整体框架，再看参数：

| 方法 | 需要的数据 | 主要处理对象 | SPM/FSL 中的位置 |
|---|---|---|---|
| GRE FieldMap → VDM | 双回波 GRE 场图、参考 EPI | 准备静态几何位移信息 | SPM FieldMap Toolbox / Calculate VDM |
| Apply VDM | 已计算且匹配的 VDM、EPI | 静态几何畸变，可合并已估计的刚体变换 | SPM FieldMap → Apply VDM |
| Realign & Unwarp | EPI 时间序列；VDM 可选 | 运动相关动态畸变；带 VDM 时还加入静态畸变 | SPM Spatial → Realign & Unwarp |
| AP/PA 等反向编码 + TOPUP | 可匹配的反向编码 EPI、真实采集参数 | 常规运行中以静态或参考状态畸变估计为主 | FSL TOPUP |

最需要记住的关系是：

```text
FieldMap → VDM → Apply VDM 或 Realign & Unwarp → 校正后的 EPI
```

FieldMap 并不等于整段 BOLD 已校正。SPM 官方提供 Apply VDM 和带 VDM 的 Realign & Unwarp 两条应用路线，前者处理静态场，后者还建模运动相关变化。[SPM 官方 FieldMap 说明](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/FieldMap/fieldmap/)

### 一行选择整条路线

配置：

```matlab
cfg.sdc.method = 'none'; % 配置第71行
```

| 填写值 | 当前接口的实际工作 | 选择建议 |
|---|---|---|
| `'none'` | 不做 SDC，继续普通 SPM Realign 和所选后续步骤 | 没有合适场图或暂时做对照时使用；不代表畸变不存在 |
| `'fsl_topup'` | 反向 SE-EPI 估场 → 配准到 SBRef → 应用到 BOLD → SPM 后续 | 有合适反向编码图和 SBRef 时考虑 |
| `'spm_fieldmap_applyvdm'` | Realign: Estimate → 生成/导入 VDM → Apply VDM | 有适配该 run 的静态场图或已有 VDM 时考虑 |
| `'spm_fieldmap_unwarp'` | 生成/导入 VDM → Realign & Unwarp | 同时处理实测静态场和运动相关变化 |
| `'spm_unwarp'` | 不提供 VDM，直接 Realign & Unwarp | 可建模动态变化，但不能据此宣称静态解剖畸变已经消除 |
| `'spm_vdm_only'` | 只生成或准备 VDM，并按开关写单幅参考校正图 | 先核查场图、方向和位移，再决定应用路线 |

TSV 的 `sdc_method` 列可以逐 run 覆盖全局选择，留空则继承。不同被试和 run 不需要删改处理函数。

只准备 VDM 时，当前批量接口仍用**至少两帧、有有效时间头信息的 4D BOLD**标识 run；T1 可以留空。它不执行 STC、头动、时序 QC 或后续空间步骤。单幅参考 EPI 可以另选，但不能把批量清单的 `bold` 改成任意一张 3D 图就当作支持独立单图入口。

 `cfg.distortionCorrection='not_applied'` 是已有处理状态标记，不是操作路线开关。原始输入保持这个值；已校正数据的输入阶段与来源按通用清单规则填写，不要再次选择新的 SDC。

## 四、方法一：基于 GRE FieldMap 的磁敏感畸变校正

### 1. FieldMap 的基本思想

既然 EPI 畸变来自局部 B₀ 偏差，就先测量每个位置的场偏差，再结合 EPI 采集参数估计位置偏移，最后重新采样图像。

```text
双回波 GRE 相位/幅度数据
    ↓ 计算相位差、相位解缠绕
频率偏移图 FieldMap，单位 Hz
    ↓ 结合 EPI 读出时间与相位编码极性
体素位移图 VDM，单位 voxel
    ↓ Apply VDM 或 Realign & Unwarp
几何畸变校正后的 EPI
```

VDM（voxel displacement map）描述的是每个位置沿相位编码方向的位移量，而不是频率。**Hz 场图和 voxel 位移图不能互换。**

### 2. 为什么需要两个 Echo Time？

传统 GRE FieldMap 利用两个不同回波时间的相位，估计局部频率偏移。例如短回波 `TE₁=10 ms`，长回波 `TE₂=12.36 ms`，差值 `ΔTE=2.36 ms`。这是用于说明单位的 SPM 示例，不能代替实际采集值。

局部频率偏移会使相位随 TE 改变：

$$
\phi(\mathbf r,TE)=\phi_0(\mathbf r)+2\pi\Delta f(\mathbf r)TE
$$

两个回波之间的相位差为：

$$
\Delta\phi(\mathbf r)=\phi(\mathbf r,TE_2)-\phi(\mathbf r,TE_1)
$$

消除相位缠绕等问题后，可计算：

$$
\Delta f(\mathbf r)=\frac{\Delta\phi(\mathbf r)}{2\pi(TE_2-TE_1)}
$$

这里相位用弧度，TE 用**秒**，所得频率偏移才是 Hz。

例如 `Δφ=0.5 rad`，`ΔTE=0.00236 s`：

$$
\Delta f=\frac{0.5}{2\pi\times0.00236}\approx33.7\ \mathrm{Hz}
$$

它告诉我们这个位置相对于参考磁场的频率偏移约为 33.7 Hz，还不能直接告诉我们 EPI 中偏移了几毫米，需要继续结合 EPI 读出参数。

**接口设置：**短、长 TE 放在每个 run 关联的场图 JSON 中，使用 `EchoTime1`、`EchoTime2`，单位秒。例子应写 `0.010` 和 `0.01236`；程序转换为 SPM 使用的毫秒。它们必须来自 **FieldMap 自身的扫描协议**，不能填任务 BOLD 的 TE。长 TE 必须大于短 TE；已有 Hz 场图和已有 VDM 不再依靠两幅相位的 TE 差重新计算频率。

### 3. Phase Unwrapping：为什么必须相位解缠绕？

MRI 相位通常以 `−π` 到 `+π` 的主值表示。真实相位可以超过这个范围，例如 `1.2π` 可能记录为 `−0.8π`，因为相差 `2π` 的相位在测量中等价。这叫作 **phase wrapping，相位缠绕**。

如果直接把缠绕相位用于计算，就可能把平滑变化的磁场误判成突然跳变。相位解缠绕要估计连续的相位分布：

$$
\phi_{\mathrm{unwrapped}}(\mathbf r)=\phi_{\mathrm{wrapped}}(\mathbf r)+2\pi k(\mathbf r),\qquad k(\mathbf r)\in\mathbb Z
$$

`k(r)` 是每个位置需要补回多少个完整的 `2π`。

| SPM 方法 | 含义 | 使用特点 |
|---|---|---|
| `Mark3D` | 三维相位解缠绕 | FieldMap 经典默认方案 |
| `Mark2D` | 二维相位解缠绕 | 按二维空间处理相位 |
| `Huttonish` | 工具箱中的另一种解缠绕方案 | 特殊情况下可比较，不能仅凭名字判断更优 |

常规三维场图先保留 `Mark3D`；若出现明显解缠错误，再结合相位质量、掩膜和数据条件比较其他方法。

**接口设置：：

```matlab
cfg.sdc.spm.unwrapMethod = 'Mark3D'; % 配置第95行
```

可选字符串只有 `'Mark3D'`、`'Mark2D'`、`'Huttonish'`。已有 Hz 场图或 VDM 不重新进行相位解缠绕，改这一行不会让这些输入重新变成原始相位。

### 4. 从 FieldMap 到 VDM：如何计算实际位移？

设频率偏移为 `Δf(r)`，有效总读出时间为 `T_readout`，沿相位编码方向的位移可概念性地写成：

$$
d_{\mathrm{voxel}}(\mathbf r)=s\,\Delta f(\mathbf r)T_{\mathrm{readout}},\qquad s\in\{-1,+1\}
$$

`s` 包含方向极性及软件的坐标约定；`T_readout` 用秒，频率偏移用 Hz，结果是 voxel。

例如 `Δf=40 Hz`、`T_readout=0.032 s`：

$$
|d_{\mathrm{voxel}}|=40\times0.032=1.28\ \mathrm{voxels}
$$

如果相位编码方向的体素大小是 3 mm：

$$
|d_{\mathrm{mm}}|=1.28\times3=3.84\ \mathrm{mm}
$$

这个例子说明位移大小的换算关系。实际的正负号、场图所在空间和反向映射过程依软件约定确定，不能理解为把所有体素简单平移 3.84 mm。严重压缩时，不同真实位置可能挤到同一采样位置，原空间信息也未必能完整恢复。

**接口设置：**计算 VDM 时，接口读取 BOLD 采集 JSON 的 `TotalReadoutTime`，以及经过核实的 SPM blip 极性。本机对应处理在 `prepare_spm_sdc.m` 和 `spm_fieldmap_vdm.m`；公式用于理解，实际估计与位移生成调用官方 SPM 函数。

## 五、SPM FieldMap 的常见输入方式

SPM Batch Editor 中通常位于 `SPM → Tools → FieldMap → Calculate VDM`。接口支持下列场图输入，也可直接导入已对齐的 VDM。

### 1. Presubtracted Phase and Magnitude Data：相位差与幅度

这是扫描仪已经完成两个回波相位相减时的常见形式。

| SPM 输入 | 文件示例 | 含义 |
|---|---|---|
| Phase Image | `phasediff.nii` | 两个 TE 之间的相位差 |
| Magnitude Image | `magnitude1.nii` | 幅度图，用于场图处理及配准 |

这里必须是真正的**双回波相位差**，不能随便拿一张单回波相位代替。若有两张幅度图，通常优先短 TE 幅度图，因为信号往往更强。

**接口设置：**使用 `config/fieldmaps_phasediff_template.json`，设置 `Type='phasediff'`、`Units='rad'`；`Images` 的角色分别为 `phasediff` 和 `magnitude`。TSV 的 `fieldmaps` 列填这个 JSON 的路径，而不是 NIfTI 路径。

### 2. Phase and Magnitude Data：分别输入两回波相位与幅度

如果没有扫描仪生成的相位差，而是有两个回波各自的相位和幅度：

| SPM 输入 | 文件示例 | 工具包 Role |
|---|---|---|
| Short Echo Phase Image | `phase1.nii` | `phase1` |
| Short Echo Magnitude Image | `magnitude1.nii` | `magnitude1` |
| Long Echo Phase Image | `phase2.nii` | `phase2` |
| Long Echo Magnitude Image | `magnitude2.nii` | `magnitude2` |

SPM 根据两组图像计算相位差，再解缠绕并估计频率偏移。必须核实相位的单位、缩放和方向约定；有些厂商原始相位并不是弧度，不能仅改文件名就使用。

**接口设置：**使用 `config/fieldmaps_phasemag_template.json`，`Type='phase_magnitude'`、`Units='rad'`，填写上面的四个角色及两回波 TE。接口要求四幅图同空间网格、同仿射，不自动猜测它们如何配准。

当前相位输入必须是已按真实厂商标定转换的 `[-π,+π]` 弧度主值，允许少量数值容差。通过范围检查不等于已经确认单位正确。本接口不会用图像最小值、最大值推断厂商缩放。

### 3. Real and Imaginary Data：实部与虚部

有些序列输出复数 MRI 信号的实部与虚部，例如 `real1.nii`、`imaginary1.nii`、`real2.nii`、`imaginary2.nii`。复数信号可写为：

$$
S(\mathbf r)=\operatorname{Re}S(\mathbf r)+i\operatorname{Im}S(\mathbf r)
$$

由此得到相位和幅度：

$$
\phi(\mathbf r)=\operatorname{atan2}\big(\operatorname{Im}S(\mathbf r),\operatorname{Re}S(\mathbf r)\big)
$$

$$
M(\mathbf r)=\sqrt{\big(\operatorname{Re}S(\mathbf r)\big)^2+\big(\operatorname{Im}S(\mathbf r)\big)^2}
$$

之后进入同类 FieldMap 计算。它与相位/幅度输入的物理思路一致，主要区别是输入格式。

**接口设置：**使用 `config/fieldmaps_realimag_template.json`，`Type='real_imaginary'`，角色为 `real1`、`imaginary1`、`real2`、`imaginary2`，并填 `EchoTime1/2`。四幅图同网格同仿射，实部和虚部的幅度标定要一致；相位与幅度转换由官方 SPM 完成。

### 4. Precalculated FieldMap (in Hz)：预计算 Hz 场图

若其他软件已经生成 Hz 频率偏移图，例如 `fieldmap_Hz.nii`，就不需要再计算相位差或解缠绕。它仍需结合待校正 EPI 的读出时间、极性生成 VDM。

| 输入类型 | 数值单位 | 能否直接当作 Hz 场图？ |
|---|---|---|
| Raw phase | 弧度或厂商缩放值 | 不能 |
| Phase difference | 弧度 | 不能 |
| Field in Hz | Hz | 可以 |
| Angular frequency | rad/s | 需先除以 `2π` |
| VDM | voxel displacement | 已是位移，不能当作 Hz 场图 |

将 rad/s 当成 Hz 会产生约 `2π` 倍的缩放错误。

**接口设置：**使用 `config/fieldmaps_hz_template.json`，`Type='fieldmap_hz'`、`Units='Hz'`，角色 `fieldmap_hz`，可以额外提供 `magnitude`。有幅度图时可在适用的 y 轴路线做匹配；没有幅度图或关闭匹配时，Hz 场图必须已与当前 BOLD 同网格、同仿射。Hz 输入的 `maskBrain` 必须为 `false`，需要的场图掩膜应在此前完成。

### 5. 直接导入已有 VDM

已有 VDM 已记录体素位移，不需要再用 TE、读出时间或 blip 重新缩放。

使用 `config/fieldmaps_vdm_template.json`，填写 `Type='vdm'`、`Units='voxel'`（也接受 `'voxels'`）、`Role='vdm'` 和文件路径。它必须对应当前 run、已经对齐当前 EPI，且同网格同仿射；已有 VDM 不自动匹配。

程序把导入文件复制到工作目录并以 `vdm5_imported.nii` 保存，以符合本机 SPM 的文件筛选。原始 VDM 不改动。文件名、同尺寸、同仿射都不能单独证明它来自正确被试、正确头位与正确读出协议。

### 6. 一份 JSON 应怎样填写？

下面使用一组 TE 示例，**数值、极性和路径都必须替换为你自己的真实采集信息**：

```json
{
  "Type": "phasediff",
  "Units": "rad",
  "EchoTime1": 0.010,
  "EchoTime2": 0.01236,
  "SPMBlipDirection": -1,
  "Images": [
    {"Role": "phasediff", "Path": "D:/Study/S01/fieldmap/phasediff.nii"},
    {"Role": "magnitude", "Path": "D:/Study/S01/fieldmap/magnitude1.nii"}
  ]
}
```

在 TSV 的 `fieldmaps` 列填写这份 JSON 的路径。`Path` 可以是绝对路径，或相对于这份 JSON 所在目录的路径。各被试可使用不同 JSON；同一个场图只有确认适用于几个 run 时，才可以被它们共享引用。

```matlab
cfg.sdc.spm.magnitudeVolume = 1; % 配置第126行
```

这是幅度图文件内部的**一基帧编号**，不是 TE 毫秒，也不是相位编码方向。3D 幅度图只能选 `1`；当前允许双回波 4D 幅度图选 `1` 或 `2`，但必须确认哪一帧是短 TE。一般先选短 TE；双独立幅度文件也需确认所选帧与各角色对应。实虚部输入没有独立幅度帧可选。

## 六、FieldMap 的核心参数：逐项解释

这些参数可分为采集参数、场图处理参数、VDM 计算参数和配准参数。参数总览如下：

| 参数 | 示例或常见选择 | 作用 |
|---|---|---|
| Echo times | `[10 12.36] ms`，仅示例 | 将相位差换算为频率偏移 |
| Mask brain | Yes，可考虑 | 生成脑 mask，减少脑外不可靠相位 |
| Blip direction | `+1` 或 `−1` | 决定位移方向 |
| Total EPI readout time | 例如 32 ms | 决定位移尺度 |
| EPI-based field map | No，常规 GRE | 判断场图自身是否存在 EPI 畸变 |
| Jacobian modulation | No | 考虑拉伸、压缩带来的强度变化 |
| Unwrapping method | Mark3D | 选择相位解缠算法 |
| FieldMap FWHM | 常见 10 mm | 平滑估计的场图 |
| Padding | 常见 0，必要时调整 | 处理有效场图边界 |
| Weighted smoothing | Yes / No | 按相位可靠性加权平滑 |
| Match VDM to EPI | 核查后决定 | 将 VDM 匹配到当前 EPI |
| EPI Sessions | 每 run 一个代表 EPI | 建立各 run 的空间对应 |
| Write unwarped EPI | 可选 | 写单幅校正图供质量检查 |

**示例不等于通用默认。**特别是 TE、读出时间和极性，应以每次扫描的元数据为准。

### 1. Echo Times：短 TE 和长 TE

SPM GUI 使用 `[TE1 TE2]`，单位毫秒。它们来自场图扫描，不是 BOLD 的 TE。

**接口设置：**本接口不把 TE 写死在 `toolkit_config.m`。按上文在场图 JSON 填 `EchoTime1/2` 秒；计算时自动乘 1000。24 名被试、每人两个 run 的 TE 不一定相同，可以各自指定，不必改共享函数。

### 2. Total EPI Readout Time：有效总读出时间

先区分：

```text
TR ≠ TE ≠ Total EPI readout time
```

TR 是连续 volume 间的重复时间，TE 是激发至回波中心的时间，总读出时间与 EPI 沿相位编码方向有效读完 k-space 的时间范围有关。

BIDS 常用定义为：

$$
T_{\mathrm{readout}}=(\mathrm{ReconMatrixPE}-1)\times\mathrm{EffectiveEchoSpacing}
$$

例如重建相位编码矩阵为 64，有效回波间隔为 0.5 ms：

$$
T_{\mathrm{readout}}=63\times0.5=31.5\ \mathrm{ms}=0.0315\ \mathrm{s}
$$

SPM FieldMap GUI 用毫秒；BIDS JSON 的 `TotalReadoutTime` 通常用秒。[BIDS 采集字段定义](https://bids-specification.readthedocs.io/en/stable/modality-specific-files/magnetic-resonance-imaging-data.html#in-and-out-of-plane-spatial-encoding)

需要留意：SPM 传统文档与 BIDS/FSL 对“总读取时间”的表述可能有差异，例如回波数与回波间隔数的区别。应核实扫描仪输出字段及当前算法需要的定义，不能仅把原始矩阵大小乘任意 Echo Spacing。

遇到 GRAPPA 等面内加速、Partial Fourier、phase oversampling、不同重建矩阵或特殊读出方案时，更要使用确认过的**有效**读出参数。`TR=2000 ms` 绝不能直接作为读出时间，否则位移可能被严重放大。

**接口设置：**在 TSV 的 `metadata` 所指 BOLD 采集 JSON 中填写：

```json
{
  "RepetitionTime": 2.0,
  "PhaseEncodingDirection": "j-",
  "TotalReadoutTime": 0.0315
}
```

这个示例中的 TR、方向与读出值都须核实。当前 SPM 新建 VDM 分支要求 `TotalReadoutTime` 为 `(0,1)` 秒内的正数，并转换成毫秒。若经过协议核查，确实需要另一个 SPM 约定值，可额外填本工具包字段 `SPMTotalReadoutTimeMs`，单位毫秒，正数；它覆盖传给 SPM 的值，但不替代基础 `TotalReadoutTime`，也不影响 FSL 分支。接口不会仅凭 TR 或矩阵自动猜出真实读出时间。

已有 VDM 不重新使用读出时间；无 VDM 的动态 Unwarp 不要求这个参数。不同输入路径的“必填”要求并不相同。

### 3. Blip Direction：相位编码极性

SPM FieldMap 使用 `+1` 或 `−1` 表示 blip 极性，决定由频率偏移计算的位移方向。

例如 `40 Hz × 32 ms` 给出位移大小 `1.28 voxel`，但向哪一边移动还取决于极性与坐标约定。

BIDS 的 `i/i-/j/j-/k/k-` 指的是 **NIfTI 轴及其正负方向**；SPM 传统 blip 还涉及其自身的梯度与空间约定。因此，不能未经核实就把 `j-` 翻译成 SPM `−1`。

**接口设置：：

```matlab
cfg.sdc.spm.blipDirection = 0; % 配置第87行
```

| 输入 | 含义 |
|---|---|
| `0` | 尚未核实；需要生成 VDM 且没有逐 run 覆盖时会报错 |
| `-1` | 核实后的负 blip 极性 |
| `1` | 核实后的正 blip 极性 |

场图 JSON 的 `SPMBlipDirection` 优先于这行全局值。建议按 run 记录协议确认值，再查看校正方向。已有 VDM 不再次乘 blip，也不要为了“修方向”随意反转一个来源不明的 VDM。

### 4. EPI-based Field Map：场图自身是否由 EPI 采集？

它问的是 **FieldMap 的采集方式**，不是“待校正 BOLD 是不是 EPI”。常规双回波 GRE 场图通常选 No；若场图自身由 EPI 采集，它也可能已有几何畸变，需要对应处理，包括必要的位移场反演。

**接口设置：：

```matlab
cfg.sdc.spm.epiBased = false; % 配置第89行
```

`false` 对应 No，`true` 对应 Yes。常规 GRE 保留 `false`；只有确认场图确实是该类 EPI 场图时才设 `true`。反向 SE-EPI 的 `pepolar` 输入应选 TOPUP，不是把这里改成 `true` 就进入 TOPUP。

### 5. Mask Brain：场图处理的脑掩膜

它决定是否借助幅度图估计脑组织掩膜，并用于场图处理。脑外或低信号区域的相位往往不可靠，因此可以考虑生成掩膜。

但自动掩膜也可能漏掉下额叶或颞极，特别是在信号已经很弱时。要检查是否覆盖完整脑组织、额叶底部或颞叶有没有被过度删除、场图边缘是否出现不合理的截断。

**接口设置：：

```matlab
cfg.sdc.spm.maskBrain = false; % 配置第91行
```

`false` 为不启用这项基于分割的脑掩膜；`true` 为启用。默认使用 `false`，是否启用应依据幅度图和处理结果决定；关闭它不意味着相位解缠与噪声估计完全不使用有效区域处理。它也不是最终全脑掩膜开关，更不是 BOLD 去噪。

#### 六项脑掩膜参数

这些设置传给 SPM FieldMap 的 `mflags`。主要在 `maskBrain=true` 时使用，与后面的 T1 统一分割配置不是同一组参数。

| 配置行与字段 | 当前起始值 | 可填内容与含义 | 选择建议 |
|---|---|---|---|
| 103：`cfg.sdc.spm.maskTemplate`（配置第103行） | `''` | 空字符串使用当前 SPM 安装的 `toolbox/FieldMap/T1.nii`；或填写合适的 3D 模板路径 | 先使用安装自带模板；自定义模板要核实类型与适用性 |
| 105：`cfg.sdc.spm.maskFwhmMm`（配置第105行） | `5` | 非负毫米数，脑 mask 处理中的平滑宽度 | 先保留 5，避免把它当作最终 BOLD 平滑 |
| 107：`cfg.sdc.spm.maskErode`（配置第107行） | `2` | 非负整数，腐蚀次数；越多通常越收缩 | 掩膜漏掉脑边缘时，先检查输入，再考虑减少 |
| 109：`cfg.sdc.spm.maskDilate`（配置第109行） | `4` | 非负整数，膨胀次数；越多通常越扩张 | 注意扩张后有没有包含明显脑外组织 |
| 111：`cfg.sdc.spm.maskThreshold`（配置第111行） | `0.5` | `[0,1]`，掩膜阈值 | 不能只为“覆盖更大”任意调低；对照解剖检查 |
| 113：`cfg.sdc.spm.maskRegularisation`（配置第113行） | `0.02` | 正数，场图掩膜分割的正则化；不是 Unwarp 的 Reg. Factor | 通常先保留，较大值可影响分割的约束与收敛 |

Hz 输入需要先做好场图处理，本机该分支不支持再次调用这项 Mask Brain；已有 VDM 也不重新执行相位/幅度分割。

### 6. FieldMap FWHM：平滑场图

经典常见值是 10 mm。它平滑解缠绕后估计的场图，以降低局部相位噪声对 VDM 的影响。

| 平滑参数 | 处理对象 | 主要目的 |
|---|---|---|
| Realignment FWHM | 用来估计运动的图像 | 提高刚体配准稳定性 |
| FieldMap FWHM | 解缠后的场图 | 降低场估计噪声 |
| Spatial Smoothing FWHM | 实际输出的功能像 | 改变 BOLD 的空间平滑程度 |

因此，FieldMap FWHM 为 10 mm，不等于后续 RSA 使用的 BOLD 被平滑了 10 mm。但它会影响估计畸变场的细节：过度平滑可能抹去空气与组织交界处的快速变化，平滑不足又可能把相位噪声变成不稳定的位移。

**接口设置： `cfg.sdc.spm.unwrapFwhmMm=10`，本接口接受正毫米值。先保留 10，结合场图连续性和校正后 EPI 检查再调。头动预平滑是 `cfg.realign.smoothingFwhmMm`（配置第147行）；最终 BOLD 平滑由 `cfg.smoothingFwhmMm`（配置第352行） 控制，不能互相代替。

### 7. Padding 与 Weighted Smoothing

Padding 处理有效场图边缘附近的扩展问题，以减少边界缺少可靠信息的影响。Weighted smoothing 按相位可靠性进行加权平滑；低信噪比区域的相位通常较不可靠，其影响应较小。

高分辨率场图的加权平滑可能比较耗时，某些情况下可比较普通平滑与合适的 Padding。但对新数据，应先确认 TE、readout、极性和相位单位，不要先大改这些高级选项。

**接口设置：**

| 行 | 配置 | 可选值与解释 | 建议 |
|---|---|---|---|
| 99 | `cfg.sdc.spm.unwrapPadding=0` | 非负整数；0 为不额外 padding，正值传给 SPM padding kernel | 默认 0；不是毫米，也不是对整个 BOLD 补零 |
| 101 | `cfg.sdc.spm.weightedSmoothing=true` | `true` 加权平滑，`false` 普通平滑 | 通常保留 true，按实际场图质量和耗时比较 |

这里的加权与相位可靠性/噪声估计有关，不能把它与头动估计的 `cfg.realign.weightImage`（配置第141行） 空间权重图混为一谈。

### 8. Jacobian Modulation：形变相关的强度调制

空间拉伸或压缩不仅改变位置，也可能改变局部强度。例如本来占 10 个体素的组织被压到 6 个体素，其信号分布可能变得更集中。Jacobian modulation 根据位移场的空间变化考虑这种强度变化。

对单方向位移，相关因子涉及位移场沿相位编码方向的空间导数。它不是恢复 dropout，也不能因为开启了它就认为信号更真实。

在常规 SPM fMRI FieldMap 处理中先保留 No，避免场图噪声或误差引入额外强度改变。它与 VBM 的体积调制也有不同处理目标和统计含义。

**接口设置：：

```matlab
cfg.sdc.spm.jacobianModulation = false; % 配置第93行
```

`false` 对应 No，`true` 对应 Yes。这里传给 FieldMap 的 `ajm`，涉及适用 y 轴 FieldMap **参考 QC 图**的处理，**不是全序列 Apply VDM 的总调制开关**。当不写参考图时，不要据此宣称全部输出 BOLD 已调制。

另外两个同名但不同模块的开关是：

| 行与参数 | 对应模块 | 当前起始值 |
|---|---|---|
| 169：`cfg.unwarp.jacobianModulation`（配置第168行） | Unwarp 场估计的 `jm` | `false` |
| 85：`cfg.sdc.jacobianModulation`（配置第85行） | FSL 分支对校正后 BOLD/SBRef 的强度调制 | `true` |

这三个开关不能互相替代。已有 VDM 或非 y 轴的参考图由 Apply VDM 写出，本机没有上述 FieldMap 参考调制菜单；接口会拒绝相应不支持的组合。

### 9. Match VDM to EPI：场图和 EPI 怎样对齐？

场图采集时与 BOLD 的头位可能不同，也可能使用不同的空间网格。VDM 必须在正确的空间对应关系下应用。SPM 可借助幅度/参考 EPI 做匹配，建立各 run 的 VDM 对应。

**接口设置：：

```matlab
cfg.sdc.spm.matchVdm = true; % 配置第118行
```

- `true`：对新生成且满足条件的场图调用官方 MatchVDM。
- `false`：不自动匹配，应提供已经可靠对齐的场图。

本机 MatchVDM 按 y 轴模型工作；其他轴的新场图需预先对齐，并关闭匹配。已有 VDM 不自动匹配；Hz 无幅度图也不能用幅度信息匹配，要求先对齐。自动匹配成功不等于解剖对应正确，仍要检查脑边界。

### 10. EPI Sessions：每个 run 使用什么代表 EPI？

EPI Sessions 是为各 run 选择代表 EPI，不是把多个被试放到同一个运动参考里。本接口每行 TSV 对应一个 run，独立准备参考。

**接口设置：和：

```matlab
cfg.sdc.spm.referenceEpi = 'first'; % 配置第122行
cfg.sdc.spm.referenceVolume = 1; % 配置第124行
```

| referenceEpi 输入 | 代表 EPI 来源 | 如何选择 |
|---|---|---|
| `'first'` | 当前保留 BOLD 的首帧 | 默认起点；首帧要有效，不是已删掉的 dummy |
| `'volume'` | `referenceVolume` 指定的保留帧 | 填从 1 开始的正整数，不能超出删 dummy 后的帧数 |
| `'mean'` | SPM 根据当前影像头求出的均值 | 不暗中加一遍 Realign；Apply VDM 路线已 Estimate，Unwarp 前尚未 Estimate，均值含义不同 |
| `'sbref'` | 当前 run 的 SBRef | TSV 的 `sbref` 须提供有效单幅 3D 图 |
| `'manifest'` | TSV `fieldmap_epi` 列中的单幅 3D EPI | 自己提供并核实代表图，尤其要确认它与待处理序列的空间关系 |

`referenceVolume` 只在 `'volume'` 时使用；例如删除前 4 帧后设为 1，选的是原序列第 5 帧。SBRef/显式参考 EPI 要是有效 3D 图；程序不会替你猜测未对齐外部参考的变换。

### 11. Write unwarped EPI：单幅校正参考图

这项用于比较一张参考 EPI 校正前后的几何形状。它与对所有时间点应用校正是两件事。

**接口设置：：

```matlab
cfg.sdc.spm.writeReferenceEpi = false; % 配置第120行
```

`false` 不额外写参考校正图；`true` 写单幅图供检查。第一次核查新场图时可以开启，尤其配合 `spm_vdm_only`；但有一张 `u` 参考图并不代表整段 BOLD 完成了校正。

### 12. 为什么这里直接调用官方 FieldMap API？

本机原生 `FieldMap_Run` 的部分输入分支会按图像 min/max 将相位重新拉伸到 `[-π,+π]`。对已经是真实弧度、但没有覆盖整个区间的相位，这会改变物理幅度。

当前接口直接调用官方 **FieldMap_create**，再按选项调用 **MatchVDM、UnwarpEPI 或 Apply VDM**，保留真实弧度数值。它没有重写解缠绕或场估计算法，也没有修改 SPM 安装文件。

计算记录 `01_fieldmap_calculate_vdm.mat` 保存实际 API 参数、执行说明和供审查的 batch 结构。重放应使用工具包入口/API，不能把这份审查 batch 交给原 stock runner，就认为与原处理完全等价。

真实相位噪声、幅度图背景、掩膜和信噪比仍可能使原生估计失败。程序会记录真实错误；不会通过把相位极值拉满来掩盖输入问题。

### FieldMap 作业的重放与来源核对

`01_fieldmap_calculate_vdm.mat` 记录实际 execution、API defaults 与作业结构。场图通过官方 `FieldMap_create` 及匹配/应用函数生成；不能把保存的审查结构直接交给 stock `FieldMap_Run` 并当作等价重放，否则真实弧度相位可能被按另一种缩放规则处理。需要复现时，应使用同一工具包入口与匹配配置。

## 七、方法二：SPM Apply VDM

### 1. 工作原理与推荐流程

FieldMap 主要完成“相位 → 频率场 → VDM”；Apply VDM 才是利用位移图重新计算 EPI 采样位置的步骤之一。

若某个位置沿相位编码方向偏了 1.5 个体素，VDM 记录这个偏移，Apply VDM 按它重新采样。它可以同时利用已经估计的刚体变换，所以不必先写出一套插值后的 `r` 图像，再额外插值一次。

典型处理路线为：

```text
Realign: Estimate：估计刚体运动，暂不重采样整个序列
    ↓
FieldMap: Calculate VDM：生成并匹配 VDM
    ↓
Apply VDM：合并刚体与静态畸变信息，写出校正 EPI
```

它主要解决静态几何畸变，不额外估计运动相关的场导数。

**接口设置：选 `'spm_fieldmap_applyvdm'`。共享的 `cfg.realign.*` 用于 Estimate；`cfg.sdc.spm.applyVdmInterpolation`（配置第115行） 用于真正 Apply VDM 写出，不能用普通 Realign 的写出插值冒充这项设置。

### 2. Apply VDM 的核心参数

| SPM 参数 | 作用与选择建议 | 当前接口对应 |
|---|---|---|
| Images | 待校正 run 的 EPI 时间序列 | 当前 run 保留的工作 BOLD，自动传入 |
| Fieldmap (vdm file) | 已计算且匹配的 VDM | 同 run 新建或按 `Type='vdm'` 导入 |
| Distortion direction | 与真实相位编码轴一致 | `distortionAxis` |
| Reslice which images | 常用全部图像 + 均值 | `resliceImages` |
| Interpolation | 常用较高阶 B-spline | `applyVdmInterpolation` |
| Wrapping | 没有明确依据时 No | `cfg.realign.wrap`（配置第155行） |
| Masking | 通常 Yes | `cfg.realign.mask`（配置第157行） |
| Filename Prefix | 区分输出文件 | `outputPrefix` |

#### Distortion direction：方向轴

SPM Apply VDM 可以沿单一 X、Y 或 Z 图像轴应用位移；这与经典 Unwarp 的方向限制不同。

**接口设置：：

```matlab
cfg.sdc.spm.distortionAxis = 'metadata'; % 配置第128行
```

| 可选值 | 对应 |
|---|---|
| `'metadata'` | 读取 BOLD JSON 的 `PhaseEncodingDirection`，取 i/j/k 轴 |
| `'i'` | NIfTI 第 1 个空间维度，传给 Apply VDM 的轴编号 1 |
| `'j'` | NIfTI 第 2 个空间维度，轴编号 2 |
| `'k'` | NIfTI 第 3 个空间维度，轴编号 3 |

这里选择**轴**，并不取代 SPM blip 极性的正负号。i/j/k 不必总是解剖左右/前后/上下，要看仿射方向；手填与已有 JSON 冲突会被拒绝。一般优先真实 metadata；其他轴采用已对齐的场图，并注意上文 MatchVDM 的限制。

#### Reslice which images：写出哪些图像？

**接口设置：：

```matlab
cfg.sdc.spm.resliceImages = 'all_mean'; % 配置第130行
```

| 输入 | SPM 原生值 | 实际输出与接口限制 |
|---|---|---|
| `'all_mean'` | `[2 1]` | 全部校正帧 + 均值，可继续完整空间链 |
| `'all'` | `[2 0]` | 仅全部校正帧；当前要求 `cfg.stopAfter='realign'`，跳过依赖均值的时序 QC |

这两项也用于 Unwarp 写出。本机这两个模块没有普通 Realign 的 Mean Only 菜单，不能填 `'mean_only'`。完整预处理一般用 `'all_mean'`；`'all'` 会保存时序 QC 跳过记录，不能把它理解为全部 QC 通过。

#### Interpolation：重采样插值

**接口设置：：

```matlab
cfg.sdc.spm.applyVdmInterpolation = 4; % 配置第115行
```

整数 `0..7` 中，`0` 为最近邻，`1` 为线性，`2..7` 为相应阶数的 B-spline。BOLD 是连续强度图，通常先保留 4；最近邻一般不适合连续功能像的几何校正，高阶也不代表必然更准确，并会增加计算成本。

Unwarp 的最终插值使用 `cfg.realign.writeInterpolation`（配置第153行），不是这一行。FieldMap y 轴参考 QC 图使用原生 UnwarpEPI 的采样方式；不要把 Apply VDM 插值选项理解为控制所有参考图分支。

#### Wrapping：边界环绕

**接口设置： `cfg.realign.wrap=[0 0 0]`。三个位置依次表示图像 x/y/z，0 不环绕，1 环绕。

允许八种组合：`[0 0 0]`、`[1 0 0]`、`[0 1 0]`、`[0 0 1]`、`[1 1 0]`、`[1 0 1]`、`[0 1 1]`、`[1 1 1]`。一般保留全 0；不是看见脑边缘缺失就开环绕，也不是解缠绕算法。

#### Masking：重采样后的共同有效视野

**接口设置： `cfg.realign.mask=true`，`true` 对应 Mask images，`false` 不应用该共同视野处理。它避免有效覆盖不一致处被当作正常信号，但可能在边缘产生非有限值，后续会核查。

这不是 FieldMap 的 Mask Brain，也不是把颈部、头皮都自动去掉的脑提取。

#### Filename Prefix：输出前缀

**接口设置：：

```matlab
cfg.sdc.spm.outputPrefix = 'u'; % 配置第132行
```

可用 `'u'`、`'corr_'` 等字母开头、仅含字母/数字/下划线的非空字符串。它控制 SPM SDC/Unwarp 的序列输出及相关参考图命名，不改变原文件；普通 Realign 仍使用自身输出命名。默认的 `u` 便于识别，但仅靠前缀不能确认方法或质量，要看 run 记录。

### 3. Apply VDM 的局限性

固定 VDM 假设它能代表这段扫描的畸变。若头部姿态改变，局部磁场分布也可能变化：

$$
D_{t=0}(\mathbf r)\ne D_{t=200}(\mathbf r)
$$

Apply VDM 可以结合头动变换处理空间对应，但不会另外估计畸变随运动变化的导数场。因此，静态校正后仍可能有运动相关残余，不能把它当作动态 Unwarp 的同义词。

## 八、方法三：Realign & Unwarp

### 1. 为什么普通 Realignment 不够？

六自由度刚体配准假定图像之间主要是整体旋转和平移。但头部旋转会改变组织边界相对于主磁场的方向，局部磁场也可能改变。

例如，被试轻微俯仰（pitch）后，即使刚体配准把脑的位置对齐，眶额皮层附近的局部变形仍可能不同。这叫作 **susceptibility-by-motion interaction，磁敏感畸变与运动的交互效应**。Unwarp 正是尝试建模这种剩余变化。

### 2. 核心数学原理

设参考姿态的畸变场为 `D₀(r)`，时间 t 的运动参数为 `m_t`，相对参考姿态的变化为 `Δm_i,t`。一阶 Taylor 展开为：

$$
D(\mathbf r,\mathbf m_t)\approx D_0(\mathbf r)+\sum_{i=1}^{6}\frac{\partial D(\mathbf r)}{\partial m_i}\Delta m_{i,t}
$$

其中 `∂D/∂m_i` 是**畸变导数场**：某个运动参数变化一点时，各位置的畸变会怎样变化。

还可以加入二阶项：

$$
\frac{1}{2}\sum_{i,j}\frac{\partial^2D(\mathbf r)}{\partial m_i\partial m_j}\Delta m_{i,t}\Delta m_{j,t}
$$

| 模型项 | 表示什么 |
|---|---|
| 零阶 `D₀` | 参考姿态的静态畸变 |
| 一阶项 | 畸变对运动参数变化的线性响应 |
| 二阶项 | 非线性响应和运动参数间交互 |

SPM 根据时间序列中的运动与影像变化估计导数场。**没有实测 VDM 时，仅靠时间变化通常不能确定零阶真实静态畸变。**所以独立 Unwarp 主要建模动态变化；要同时校正静态几何位置，可以结合适配的实测 FieldMap/VDM。

### 3. 基本流程与代码路线

```text
原始/所选工作 EPI 时间序列
    ↓ 初始六自由度 Realignment
根据运动与图像变化估计畸变导数场
    ↓ 修正运动相关变形
按选项重估运动并迭代
    ↓
输出校正序列；有实测 VDM 时加入静态场
```

**接口设置：选 `'spm_fieldmap_unwarp'`（带 VDM）或 `'spm_unwarp'`（不带 VDM）。两条路线都使用 `cfg.unwarp.*`；无需删注释或删除另一组参数。

本机经典 SPM Unwarp 要求 **NIfTI j 工作轴且近似解剖 AP/PA**。当前接口同时检查轴和仿射方向，不自动重排图像。HCP 的 LR/RL 反向 SE-EPI 不能仅靠改一个开关变成 GRE VDM，也不能在不满足方向条件时直接套用这条路线。其他轴的静态应用可考虑 Apply VDM 或合适 TOPUP 流程。[SPM Unwarp 说明](https://www.fil.ion.ucl.ac.uk/spm/toolbox/unwarp/)

### 4. Unwarp Estimation Options：参数总览

SPM 菜单通常在 `SPM → Spatial → Realign & Unwarp`。除了普通 Realign 的估计选项，还包括：

| 参数 | 常见值或选择 | 主要作用 |
|---|---|---|
| Basis Functions | `[12 12]`，第三维推导 | 控制导数场的空间表示 |
| Regularisation | 1st-order derivative | 约束导数场的空间复杂度 |
| Reg. Factor | Medium | 控制正则化强度 |
| Jacobian deformations | No | 在场估计中考虑强度调制 |
| First-order effects | `[4 5]` | 建模 pitch、roll 两类旋转 |
| Second-order effects | None | 是否加入二阶项 |
| Smoothing for unwarp | 毫米，按配置 | 估计形变场前的辅助平滑 |
| Re-estimate movement params | Yes | 迭代时重新估计刚体运动 |
| Number of iterations | 当前设置值 | 最大迭代次数 |
| Taylor expansion point | First / Last / Average | 定义展开参考姿态 |

### 5. Basis Functions：空间基函数

Unwarp 不给每个体素独立拟合一个完全自由的函数，因为参数太多，容易追随噪声。它用空间基函数表示较平滑的导数场：

$$
\frac{\partial D(\mathbf r)}{\partial m_i}\approx\sum_k c_{ik}B_k(\mathbf r)
$$

`B_k` 是空间基函数，`c_ik` 是待估计系数。经典 `[12 12]` 指前两个维度的基函数数目，第三维由程序推导。数量多通常更灵活、计算也更多；数量少通常更平滑，但可能漏掉局部变化。

**接口设置： `cfg.unwarp.basisFunctions=[12 12]`。本接口按本机 SPM 菜单接受 `[8 8]`、`[10 10]`、`[12 12]`、`[14 14]`。先保留 `[12 12]`，不要直接填任意第三维或把最大值当作最佳方案。

### 6. Regularisation 与 Reg. Factor

正则化限制估计场过于复杂。其概念性目标是：

$$
E=\|Y-\widehat Y\|^2+\lambda R(D)
$$

前一项衡量数据拟合误差，`R(D)` 衡量导数场的不规则程度，`λ` 控制约束力度。越强通常越平滑、越少追随噪声，但太强可能低估真实局部变化。

常见起点是正则化阶数1，即约束一阶空间导数；强度为Medium。

**接口设置：**

| 行 | 配置 | 可选值与对应 |
|---|---|---|
| 165 | `cfg.unwarp.regularisationOrder=1` | `0/1/2/3`，分别使用场的零/一/二/三阶空间导数对应的惩罚；0 不是关闭正则化 |
| 167 | `cfg.unwarp.regularisationWeight=100000` | `10000` = A little；`100000` = Medium；`1000000` = A lot |

阶数与强度是两件事，也不能把空间正则化“二阶”与下面的运动二阶效应混淆。一般先保留 `1` 和 `100000`，在明确比较中再调整。

### 7. Jacobian deformations

这一项问的是：估计运动相关场时，要不要同时考虑几何变形造成的强度稀释、集中。理论上有意义，但场估计误差也可能使额外强度模型不稳定。

**接口设置： `cfg.unwarp.jacobianModulation=false`，可选 `false/true`，对应 No/Yes，传入 Unwarp 的 `jm`。通常先保留 false；它与 FieldMap `ajm`、FSL BOLD 调制不同。

### 8. First-order Effects：为什么默认 `[4 5]`？

六个运动参数的索引是：

| 索引 | 运动分量 |
|---|---|
| 1 | x 平移 |
| 2 | y 平移 |
| 3 | z 平移 |
| 4 | x 旋转 |
| 5 | y 旋转 |
| 6 | z 旋转 |

在简化模型下，某些旋转会明显改变组织磁敏感边界相对于主磁场的方向。SPM 经典选择 `[4 5]`，通常称为 pitch、roll。它不是“4 mm、5 mm”，而是运动参数编号。

可以建模全部 `[1:6]`，但更多参数不一定更准确。例如一段 240 帧时间序列中，某些运动很小或参数彼此高度相关，更多导数场可能难以稳定估计。

**接口设置： `cfg.unwarp.firstOrderEffects=[4 5]`。可填非空的 `1..6` 参数索引向量，如 `[4 5]`、`[1:6]` 或经过判断的子集。一般保留 `[4 5]`；不要把低运动也自动理解为应增加模型项。

### 9. Second-order Effects：二阶运动效应

它允许畸变与运动间存在非线性。选择 `[4 5]` 会展开为 `(4,4)`、`(4,5)`、`(5,5)`，对应：

$$
\Delta m_{4,t}^2,\qquad\Delta m_{4,t}\Delta m_{5,t},\qquad\Delta m_{5,t}^2
$$

二阶项需要更多参数，也需要足够的姿态变化才能稳定估计。一般低运动任务数据不建议缺乏证据就加入大量二阶项。

**接口设置： `cfg.unwarp.secondOrderEffects=[]`。`[]` 对应 None；`[4 5]` 加上述三项；`[1:6]` 对应全部六参数的二阶组合。一般先保留 `[]`，不要用布尔 `true` 代替运动索引。

### 10. Smoothing for Unwarp：估计形变场前的平滑

它对用于形变场估计的图像做辅助平滑，提升估计稳定性；不是宣布最终 BOLD 被同样宽度平滑。

**接口设置： `cfg.unwarp.smoothingFwhmMm=4`，本接口接受正毫米值。一般先保留 4。它与头动估计预平滑、FieldMap 场图平滑、最终空间平滑分别作用于不同对象。

### 11. Re-estimate Movement Parameters：重新估计运动

初始图像含局部畸变，刚体估计也可能受影响。初步处理动态畸变后，再估计运动可能改善两者的一致性，形成：

```text
估计运动 → 估计 Unwarp 场 → 重新估计运动 → 继续迭代
```

**接口设置： `cfg.unwarp.reestimateMotion=true`，可选 `true/false`。true 对应 Yes，在 unwarping 迭代中重估；false 不重估。一般保留 true，是否改善仍需看结果。

### 12. Number of Iterations：最大迭代次数

这是允许的最大迭代次数，不能简单理解为次数越多就越好。

**接口设置： `cfg.unwarp.iterations=5`，可填正整数。一般先保留 5；遇到估计问题先检查方向、输入和模型条件，不要只加迭代。

### 13. Taylor Expansion Point：围绕什么姿态展开？

它定义模型的参考姿态。Average 通常用于减少平均运动相关残差；若场图在功能扫描前采集、头位仍接近起始姿态，First 可能有合理性。应结合采集时间与实际头位，不要脱离实验条件选择。

**接口设置：：

```matlab
cfg.unwarp.expansionPoint = 'Average'; % 配置第180行
```

| 输入 | 意义 | 建议 |
|---|---|---|
| `'Average'` | 平均姿态 | 一般起点 |
| `'First'` | 首帧姿态 | 场图与序列开始头位接近时可比较 |
| `'Last'` | 末帧姿态 | 有相应采集或比较依据时使用 |

### 14. Unwarp 仍会用到哪些 Realign 设置？

当前 `cfg.realign.*` 的共享参数，不需要为 Unwarp 再复制一套。

| 行与配置 | 可选内容 | 在这里的含义和建议 |
|---|---|---|
| 140：`cfg.realign.weightImage`（配置第141行） | `''` 不加权，或有效已对齐 3D 权重图路径；逐 run TSV `realign_weight` 可覆盖，`none` 禁用 | 空间加权刚体估计；不能把场图幅度图直接当作权重而不核实 |
| 142：`cfg.realign.quality`（配置第143行） | `[0,1]`，当前 0.9 | 估计质量与耗时折中；一般保留 0.9 |
| 144：`cfg.realign.separationMm`（配置第145行） | 正毫米数，当前 4 | 运动估计空间采样间隔 |
| 146：`cfg.realign.smoothingFwhmMm`（配置第147行） | 非负毫米数，当前 5 | 刚体估计预平滑 |
| 148：`cfg.realign.registerToMean`（配置第149行） | `true/false` | 传入 SPM register-to-mean 估计选项；当前 true |
| 150：`cfg.realign.estimateInterpolation`（配置第151行） | 本接口为整数 `1..7`，当前 2 | 运动估计插值；与写出不同 |
| 152：`cfg.realign.writeInterpolation`（配置第153行） | 整数 `0..7`，当前 4 | **Unwarp** 最终写出插值 |
| 154：`cfg.realign.wrap`（配置第155行） | 三个 0/1 | 环绕选项，一般 `[0 0 0]` |
| 156：`cfg.realign.mask`（配置第157行） | `true/false` | 重采样共同视野处理，一般 true |

最终写出集合和前缀使用 `cfg.sdc.spm.resliceImages/outputPrefix`，选项见前面的 Apply VDM 段。`cfg.sdc.spm.applyVdmInterpolation` 不控制 Unwarp 的写出。Weighting 的详细条件见 [头动文档](Realignment.md)和[权重图说明](Realignment.md)。

## 九、方法四：反向相位编码校正——AP/PA 等 + TOPUP

### 1. 基本原理

TOPUP 是 FSL 的方法。如果其他预处理使用 SPM，可以先调用 FSL 完成畸变处理，再送入 SPM。

设两套 EPI 具有可匹配的空间覆盖与相关采集设置，但相位编码极性相反。例如 AP（Anterior → Posterior）与 PA。相同局部场通常会使它们向相反方向变形：一张中被拉伸的区域，在另一张中可能表现为压缩或相反位移。

两套反向编码图提供互补信息，算法据此估计共同场，并生成校正图和场图。

**不是把 AP、PA 简单平均就能完全消除畸变。**概念上可写成：

$$
Y_{\mathrm{AP}}=\mathcal W_{+D}(Y_{\mathrm{true}}),\qquad
Y_{\mathrm{PA}}=\mathcal W_{-D}(Y_{\mathrm{true}})
$$

`W` 是空间变换算子，`D` 是待估位移。这个示意假设相反极性且可比较的读出条件；真实 TOPUP 还考虑不同采集参数、运动、强度变化和正则化，不仅是这两行公式。

### 2. TOPUP 需要什么数据？

典型文件例如 `sub01_dir-AP_epi.nii.gz`、`sub01_dir-PA_epi.nii.gz`。通常至少有一对相反极性的可匹配 EPI volume，以及准确的方向和有效读出时间。

JSON 可能包含：

```json
{
  "PhaseEncodingDirection": "j-",
  "TotalReadoutTime": 0.032
}
```

方向必须根据真实 NIfTI 轴与采集协议确认，文件名中写 AP 不意味着它一定对应 `[0 -1 0]`。

**接口设置：**当前统一入口每 run 接收**恰好一对反向 SE-EPI 文件**，并要求当前 run 的原始 SBRef。填写 `config/fieldmaps_pepolar_template.json`，`Type='pepolar'`，每个 Images 对象写 Path、PhaseEncodingDirection、TotalReadoutTime。BOLD 自身的方向和读出时间写到 BOLD metadata JSON；SE 与 BOLD 的读出值不要混用。当前模板的数值只是占位。

该路线不使用 SPM `blipDirection/epiBased/unwrapMethod` 等选项，选择 `fsl_topup` 不需要再手动调用 Linux 命令。

### 3. TOPUP 的常见命令参数

| 参数 | 主要作用 | 当前统一接口怎样提供 |
|---|---|---|
| `--imain` | 反向 EPI 输入 | 从 fieldmaps JSON 找到两文件，自动合并并传入 |
| `--acqp` / `--datain` | 方向和读出时间 | 按核实的 JSON 自动生成 `acqparams.txt` |
| `--config` | 非线性场估计配置 | `cfg.sdc.fslConfig`（配置第77行） 指向 Linux `.cnf` |
| `--out` | 输出模型结果 | 程序在当前 run 的独立目录生成 |
| `--fout` | 输出 off-resonance field | 当前保存 `field_hz.nii.gz`，单位 Hz |
| `--iout` | 输出校正后的输入 EPI | 当前保存 `se_unwarped.nii.gz`；它是 SE 输入的校正图，不是所有 BOLD |

`acqparams.txt` 示例为：

```text
0  1  0  0.032
0 -1  0  0.032
```

前三列是图像轴方向向量，最后一列是有效总读出时间，单位秒。实际正负号和图像顺序必须一致；当前程序按自身负/正输入顺序写表，不需要照抄上述行序。[FSL TOPUP 输入与输出说明](https://fsl.fmrib.ox.ac.uk/fsl/docs/diffusion/topup/users_guide/index.html)

得到 TOPUP 模型并不等于整段 BOLD 已校正，还要把变换用于真实序列。

### 4. FSL 分支的全部集中配置

选择：

```matlab
cfg.sdc.method = 'fsl_topup'; % 配置第71行
```

| 行与参数 | 当前起始值 | 可填内容、意义和建议 |
|---|---|---|
| 73：`cfg.sdc.wslDistro`（配置第73行） | `'Ubuntu-24.04'` | 本机实际 WSL 发行版名；用 `wsl -l -q` 核实，不是随意填 Ubuntu |
| 75：`cfg.sdc.fslRoot`（配置第75行） | `'/home/bx210/fsl-topup'` | WSL 内 FSL 安装根目录；其他机器改为实际路径 |
| 77：`cfg.sdc.fslConfig`（配置第77行） | `'/home/bx210/fsl-topup/etc/flirtsch/b02b0.cnf'` | 有效 TOPUP 配置路径；改变估场参数需选择合适 cnf |
| 79：`cfg.sdc.threads`（配置第79行） | `4` | 正整数线程数；按机器资源和并发量选择 |
| 81：`cfg.sdc.affineTolerance`（配置第81行） | `1e-4` | 仿射比较容差；也用于部分 SPM 输入网格检查，不是配准质量分数 |
| 83：`cfg.sdc.registrationSearchDegrees`（配置第83行） | `10` | `0..90` 度，SE→SBRef 六自由度配准的 ±旋转搜索范围；通常先保留 10 |
| 85：`cfg.sdc.jacobianModulation`（配置第85行） | `true` | `true/false`，是否对 FSL 校正 BOLD/SBRef 应用 Jacobian 强度调制；不控制 SPM |

Linux 的 `/home/...` 路径与 Windows 的 `D:\...` 是两种写法，不能直接互换。

TOPUP 内部的 `warpres`（位移模型分辨率）、`subsamp`（下采样）、`fwhm`（估计阶段平滑）、`miter`（迭代）、`lambda`（正则强度）等在 `.cnf` 中。它们不是 `toolkit_config.m` 各自的一行 MATLAB 参数；要修改时，保存一份新 cnf，改 `fslConfig` 指向它。若任一空间维度为奇数，需使用兼容的 `b02b0_1.cnf`；其他配置也有尺寸约束。[FSL 官方配置说明](https://fsl.fmrib.ox.ac.uk/fsl/docs/diffusion/topup/users_guide/config_files.html)

当前完成签名没有单独对 WSL 内 cnf 内容取哈希。因此修改 cnf 后，应改用新的配置文件路径和新的输出目录，不能只改同名文件内容就期待恢复机制识别全部变化。

### 5. 当前接口怎样把 TOPUP 场用于 BOLD？

```text
反向 SE-EPI → TOPUP 估计 Hz 场
    ↓ 按 BOLD 读出条件准备位移
模拟对应畸变、将 SE/场配准到原始 SBRef
    ↓ 在 SBRef 空间重建 BOLD 变换
校正 BOLD；按开关应用 Jacobian
    ↓
可选 STC → 普通 SPM Realign → 所选后续空间步骤
```

具体调用包括 FUGUE、FLIRT、convertwarp、applywarp。TOPUP 的 Hz 输出在 FUGUE 使用前按需求转为 rad/s，程序处理单位转换。它不是直接把 SE 校正图当作 BOLD，也不是默认走独立模块的 direct applytopup。

独立 `topup_config.m` 的直接 applytopup 模式另有对齐及读出限制，不控制 `run_toolkit.m` 的这条流程。TOPUP 常规静态估计也不会自动等于逐时间点的动态 Unwarp。

这两个环节在统一入口中由 `cfg.sdc.*` 调度：先估计场，再将场用于当前 run 的 BOLD；无需分别执行两套独立入口。BOLD 模块采用以下处理约定：

| 处理项 | 当前实现与解释 |
|---|---|
| 场图单位 | TOPUP 输出 Hz；交给 FUGUE 前乘以 `2π` 转为 rad/s |
| BOLD 有效 echo spacing | `TotalReadoutTime / (N_PE - 1)`，其中 `N_PE` 为 BOLD 的相位编码轴重建体素数；时间单位均为秒 |
| SE 与 SBRef 的关系 | 先按 BOLD 读出条件模拟 SE 畸变，与原始 SBRef 做六自由度配准，再在 SBRef 空间重新计算 BOLD 变形 |
| 输出数据类型 | BOLD/SBRef 畸变重采样明确输出 float32，避免沿用原始 int16 造成插值结果取整 |
| Jacobian | 默认开启；保留 `jacobian_raw.nii.gz` 供检查，应用时将负值截为零。出现异常值仍需检查形变，截零不代表质量合格 |
| 校正范围 | 此处仅完成磁敏感畸变校正，输出仍在头动校正之前；未把每帧头动、T1 配准和标准化合成一次重采样 |

TOPUP 模块会在估场成功后调用 `fslmaths -Tmean -odt float`，自动生成 `se_unwarped_mean.nii.gz`。它是后续 BOLD 模块的三维 SE 参考；统一入口和独立接口都使用这一步，不需要额外配置。缺少文件、数值非有限、类型或尺寸错误，或内容不符合全部校正后 SE 帧的时间均值时，不能写入 TOPUP 完成记录。统一入口也将该均值纳入 run 的必需输出，恢复时会检查文件存在性。具体规则见附录 A.3。

独立接口、输入结构、输出文件和与 SPM 的交接方式，集中见[附录 A](#附录-a独立调用-topup-与-bold-畸变校正)。FSL 安装与路径检查见 [TOPUP_INSTALL.md](TOPUP_INSTALL.md)。


### 6. TOPUP 与 GRE FieldMap 的比较

| 维度 | GRE FieldMap | 反向编码 + TOPUP |
|---|---|---|
| 原始信息 | 双回波相位差 | 反向 EPI 的几何差异 |
| 常见输入 | 相位 + 幅度 | AP/PA 等相反方向 EPI |
| 主要估计对象 | off-resonance field | off-resonance field / deformation |
| 与 EPI 的空间匹配 | 通常需要额外匹配 | 通常更直接，仍需核实头位与网格 |
| 额外采集 | GRE 场图 | 反向编码 EPI |
| SPM 经典原生支持 | 有 | 通常通过 FSL 等外部软件 |
| 运动相关动态畸变 | 单张静态场图通常不足 | 常规静态 TOPUP 也不自动解决全部动态畸变 |

不能简单说哪一种总是更好。对于已经采集的数据，应先确定有哪些可靠输入，以及它们是否适配当前 run，再选方法。

## 十、如何判断畸变校正是否成功？

程序运行结束只说明完成了计算，并不证明场图在物理上或解剖上一定正确。

### 1. 检查 FieldMap 本身

查看新计算产生的 `fpm_*.nii` 等 Hz 场图，关注空间连续性、异常跳变、大片噪声或极端值。磁敏感边界附近确实可能有很大的场梯度，不能只因变化快就判断错误。

异常时检查相位解缠绕、掩膜、单位及缩放。预计算 Hz 或已有 VDM 输入不一定生成`fpm_*` 文件，要按实际输入路线和执行记录找输出。

### 2. 检查 VDM

查看 `vdm5_*.nii`，关注位移大小和方向。若整图位移异常大，优先检查 TE 单位、读出时间、场图单位、blip，以及场图是否来自正确被试、正确 run 和相近头位。

TOPUP 默认输出 Hz 场和自己的场系数，不要求生成 SPM 的 `vdm5_*`。不能因缺少 SPM 文件名就判断 FSL 路线失败。

### 3. 检查校正前后 EPI 与 T1 的解剖对应

对照未校正均值 EPI 与 T1、校正后均值 EPI 与 T1，重点观察：

- 额叶底部、眶额皮层与额叶下缘的边界。
- 颞极、下颞叶与内侧颞叶的形状。
- 脑室及周围灰白质边界。
- 全脑轮廓，是否有某处改善但别处明显变坏。

比较应在一致的空间关系下进行，不能把不同头位、不同后续标准化结果直接叠加下结论。理想结果是易畸变区更符合解剖，同时没有明显新形变；但图像相似性提高也不能成为唯一判据。

### 4. 检查信号丢失与覆盖

校正后仍几乎没有 BOLD 信号，可能是扫描时信息已丢失，不一定表示几何校正失败。因此分别评估 **geometric fidelity，几何位置**，以及 **signal quality / coverage，信号质量和覆盖**。

### 5. 检查时间序列与额外噪声

尤其对 Unwarp，要检查校正后的时间序列。一种常用指标是时间信噪比 tSNR：

$$
\mathrm{tSNR}(\mathbf r)=\frac{\mu_t(\mathbf r)}{\sigma_t(\mathbf r)}
$$

分子是该位置时间平均信号，分母是时间标准差。tSNR 提高不单独证明校正更准确，因为平滑等处理也可能改变它；比较时应保持其他处理条件一致。

### 6. 自动检查能够证明到哪里？

接口检查文件、网格、方向、单位声明、数值范围、输出存在性及相应 QC，并记录实际方法。但范围合规不能证明厂商相位标定正确，网格相同不能证明场图头位正确，匹配成功不能证明每个脑区都改善。

`writeReferenceEpi=true` 可提供额外单幅几何检查图；`spm_vdm_only` 只准备场，不做时序 QC。`resliceImages='all'` 跳过依赖均值的时序 QC，并保存 `TIMESERIES_QC_SKIPPED.mat`；不能把跳过当作通过。

FSL 阶段另有两组自动检查：

| 阶段 | 自动检查的主要内容 | 仍需人工判断 |
|---|---|---|
| TOPUP 场估计 | SE 输入/输出尺寸与帧数、全图有限值、场的范围、反向 PE 差异；额外检查三维 SE 均值的尺寸、float32 类型、有限值及数值一致性；保存 `topup_qc.json/png` | 校正后的局部形状是否合理、其他切片是否异常、场图是否适配本 run |
| BOLD 畸变应用 | 网格与帧数、场/Jacobian 有限值、模拟畸变 SE 与 SBRef 的信号区域相关及中心层图像；保存 `bold_unwarp_qc.json/png` | 配准是否正确、易畸变区是否改善、信号丢失和覆盖、后续每帧头动处理质量 |

反向 PE 差异减小或相关提高，只是检查线索。命令退出码为 0、完成记录存在、中心层看起来正常，都不能单独替代逐 run 的图像审核。


本次 TOPUP→BOLD 交接修复的 **15 项针对性 MATLAB 测试全部通过**，覆盖 TOPUP、BOLD 接口及统一预处理的相关检查；另用两个合成被试实际调用 WSL/FSL，均完成估场、自动 SE 均值和 BOLD 校正，输入文件哈希保持不变。这验证了此次交接和批次隔离，不等于全部参数组合、三名 HCP、后续 SPM 全流程或真实解剖质量都已重新验证。可复用的实际后端测试为 `tests/manual_topup_handoff.m`；其短迭代配置仅用于合成接口测试。

## 十一、把这一阶段放回完整“一次运行”流程

### 1. 配置里的排列顺序，不等于实际执行顺序

当前实际分支是：

| 选择 | 当前处理顺序 |
|---|---|
| `none` | 可选 DICOM 导入 → 可选删除 dummy → 可选 STC → 普通 Estimate & Reslice |
| `fsl_topup` | 可选导入/删除 dummy → TOPUP 及 BOLD 畸变应用 → 可选 STC → 普通 Estimate & Reslice |
| `spm_fieldmap_applyvdm` | 可选导入/删除 dummy → 可选 STC → Estimate → 生成/导入 VDM → Apply VDM |
| `spm_fieldmap_unwarp` | 可选导入/删除 dummy → 可选 STC → 生成/导入 VDM → Realign & Unwarp |
| `spm_unwarp` | 可选导入/删除 dummy → 可选 STC → 无 VDM 的 Realign & Unwarp |
| `spm_vdm_only` | 可选导入/删除 dummy → 生成/导入 VDM及可选单幅参考图 → 结束 |

需要继续空间链的分支再按 `stopAfter` 执行后续处理。Unwarp 内部包含运动估计，不需要在它前面额外对全序列 Reslice 一次；当前 FSL 流程也没有把全部运动、畸变和标准化合成最终一次插值。

### 2. 输入与算法参数分别填在哪里？

| 内容 | 填写位置 |
|---|---|
| 被试、session、run、BOLD/T1/SBRef 路径 | 每行一个 run 的 TSV |
| 每 run 的 TR、相位编码方向、读出时间 | TSV `metadata` 关联的采集 JSON |
| 场图类型、场图文件、相位单位、双回波 TE、核实 blip | TSV `fieldmaps` 关联的场图 JSON |
| 显式代表 EPI | 可选 TSV `fieldmap_epi`；并选 `referenceEpi='manifest'` |
| 方法和本章各算法选项 | D 盘正式 `config/toolkit_config.m`；部分选择可逐 run 覆盖 |
| 正式输出位置 | `cfg.outputRoot`（配置第17行）；放在纯代码发布文件夹之外 |

JSON 是真实数据说明，不是每次运行都要任意重写一遍的“调参文件”。协议和关联都已经正确时，重复运行不用再改；换数据或发现信息错误时才修正对应内容。

### 3. 怎样开始批量运行？

先填写清单和实际路径，在 D 盘正式配置里选方法与参数；`cfg.execute=false` 时运行 D 盘 `run_toolkit.m` 做预检。检查 `batch_status.tsv` 等记录后，设 `cfg.execute=true`，再次运行**同一个入口**正式处理全部选中 run。

24 名被试每人两 run，应有 **48 行**数据，而不是一行自动代表两个 run。每个 run 有独立输出目录，方法允许按行覆盖。

改动已执行过的算法参数时使用新输出目录。恢复机制只复用输入、配置和代码一致的完整成功 run，不覆盖既有成功结果，也不是自动补写任意半成品。

### 4. 当前文档与代码文件在哪里？

- 正式配置：[toolkit_config.m](../config/toolkit_config.m)。
- 通用运行入口：[run_toolkit.m](../run_toolkit.m)。
- 本章对应实现：`matlab/+psy/prepare_spm_sdc.m`、`spm_fieldmap_vdm.m`、`fieldmap_reference.m`、`spm_motion_step.m`；FSL 路线为 `topup_run.m` 与 `bold_unwarp_run.m`。


## 附录 A：独立调用 TOPUP 与 BOLD 畸变校正

### A.1 什么时候使用独立接口？

一般批量预处理使用 `run_toolkit.m`，在通用配置中选择 `cfg.sdc.method='fsl_topup'`。只有需要单独估计场、检查中间输出或自行组织处理链时，才使用本附录。

| 环节 | 配置文件 | 只验证输入，不建输出目录 | 单 run / 多 run |
|---|---|---|---|
| TOPUP 场估计 | `config/topup_config.m` | `psy.topup_validate(spec,cfg)` | `psy.topup_run(spec,cfg)` / `psy.topup_batch(specs,cfg)` |
| BOLD 畸变校正 | `config/bold_unwarp_config.m` | `psy.bold_unwarp_validate(spec,cfg)` | `psy.bold_unwarp_run(spec,cfg)` / `psy.bold_unwarp_batch(specs,cfg)` |

两份独立配置不控制统一入口。统一入口从 `toolkit_config.m` 的 `cfg.sdc.*` 创建所需模块配置；HCP 入口还会应用 `preprocess_config.m` 中的覆盖值。

独立模块的 `execute=false` 与统一入口预检不同：`*_run` 会创建该 run 的输出目录并写出 `plan.mat`、Shell 脚本，但不执行 FSL。正式运行时应换一个新输出根目录，**不能将 `execute` 改为 true 后直接复用这个计划目录**；已有目录会被拒绝。若只想先检查输入，可调用上表中的 `*_validate`。

### A.2 TOPUP：填写每个 run 的 `spec`

| 字段 | 示例 | 说明 |
|---|---|---|
| `subject` / `session` / `run` | `'S01'` / `'01'` / `'language_01'` | 用于输出目录；无会话时 `session=''`，仍保留字段 |
| `negative` / `positive` | `'D:\Study\S01\se_neg.nii.gz'` 等 | 一对反向 PE 的 SE-EPI，可为 3D 或多帧 4D |
| `negativeDirection` / `positiveDirection` | `'j-'` / `'j'` | 必须同轴反向；可填 `i/i-/j/j-/k/k-`。字段名不代表固定左右解剖方向 |
| `negativeReadoutSeconds` / `positiveReadoutSeconds` | `0.05`（仅占位） | 各自核实的总读出时间，秒；当前校验要求 `0 < T < 1` |
| 可选 `bold` / `boldDirection` / `boldReadoutSeconds` | BOLD 路径、方向、总读出时间 | 一旦提供 `bold`，需同时提供另两项，且检查 BOLD 与 SE 网格一致；普通场估计可不填 |

两组 SE-EPI 的空间网格和仿射必须一致。`b02b0.cnf` 要求三个空间维度均为偶数；奇数维图像改选兼容的 `b02b0_1.cnf`，不能靠放宽仿射容差解决尺寸问题。

独立 TOPUP 配置的全部字段如下；本机路径均可替换。

| 字段 | 当前起始值 | 用途 |
|---|---|---|
| `outputRoot` | 工具包下 `derivatives/topup_study` | 运行前改成工具包外的新目录 |
| `wslDistro` / `fslRoot` | `'Ubuntu-24.04'` / `'/home/bx210/fsl-topup'` | 实际 WSL 发行版和 Linux 内 FSL 根目录 |
| `fslConfig` | 上述 FSL 下的 `etc/flirtsch/b02b0.cnf` | TOPUP 配置文件；估场参数在 cnf 内调整 |
| `threads` | `4` | 正整数计算线程数 |
| `affineTolerance` | `1e-4` | 输入网格仿射检查容差，不代替头位配准 |
| `execute` | `false` | 仅写计划；改为 true 才执行 FSL |
| `applyToBold` | `false` | 保持 false，只做场估计；特殊直接应用模式见 A.6 |

单 run 示例中的路径、方向和时间都需替换为真实信息：

```matlab
root = 'D:\CogNeuro_fMRI_Toolkit';
addpath(fullfile(root,'matlab'), fullfile(root,'config'));
tc = topup_config;
tc.outputRoot = 'D:\fMRI_Results\topup_plan';
tc.execute = false;

s.subject = 'S01'; s.session = '01'; s.run = 'language_01';
s.negative = 'D:\Study\S01\se_neg.nii.gz';
s.positive = 'D:\Study\S01\se_pos.nii.gz';
s.negativeDirection = 'j-';    % 示例，必须核实 NIfTI 体素轴方向
s.positiveDirection = 'j';
s.negativeReadoutSeconds = 0.05; % 示例秒数，必须换成真实总读出时间
s.positiveReadoutSeconds = 0.05;
plan = psy.topup_validate(s,tc); % 纯验证，不创建该 run 的输出目录
preview = psy.topup_run(s,tc);   % 写 plan.mat、acqparams.txt、run_topup.sh
```

检查参数和脚本后，换新输出目录正式运行：

```matlab
tc.outputRoot = 'D:\fMRI_Results\topup_final';
tc.execute = true;
top = psy.topup_run(s,tc);       % top.outputDir 是本 run 的 TOPUP 结果目录
```

`acqparams.txt` 每行对应一帧 SE 输入，顺序为 negative 的全部帧，再接 positive 的全部帧；四列是 PE 向量三个分量及总读出时间（秒）。每个方向 3 帧时，共生成 6 行，不是一对文件只填两行。

多被试/多 run 时，将每个 run 的完整信息填入结构数组 `specs`，调用 `rows=psy.topup_batch(specs,tc)`。所有元素须有相同字段、不同的被试/会话/run 组合；每行分别记录成功或失败。单 run 和 batch 是两种调用方式，不要对同一输出目录重复调用。

### A.3 自动生成并检查 SE 均值

`psy.topup_run` 在 TOPUP 估场后自动调用 FSL，对 `se_unwarped.nii.gz` 的**全部时间帧等权平均**，写出三维 float32 的 `se_unwarped_mean.nii.gz`。这个参考不是 BOLD 均值，也不是第一帧 SE；两个 PE 方向帧数不等时，不能把两组均值再等权平均。

正常调用顺序为：**TOPUP → FSL 时间平均 → 输出/QC 检查 → `TOPUP_COMPLETE.json` → BOLD 模块**。上述步骤在同一次调用内完成，独立用户也不需要到 WSL 手动生成均值。

| 检查项 | 规则与记录 |
|---|---|
| 文件与尺寸 | 均值必须存在，是与校正后 SE 空间尺寸一致的单幅三维图；BOLD 输入检查还核对场与 SE 参考的网格和仿射 |
| 类型与数值 | 必须为 float32、全部有限，并在浮点舍入容差内等于全部校正后 SE 帧的时间均值 |
| 浮点容差 | `max(32, SE总帧数) × eps(single) × max(1, 期望均值的最大绝对值)`；仅用于数值一致性检查，不是科研剔除阈值 |
| QC JSON | `seReferenceFile`、`seReferenceDatatype`、`seReferenceMaxAbsError`、`seReferenceTolerance` 记录参考路径、类型、最大误差和容差 |
| 完成记录 | 均值列入 `TOPUP_COMPLETE.json.outputs`；统一入口同时列入 run 的 `COMPLETE.mat.requiredOutputs` |

FSL 命令失败、输出缺失或 QC 失败时不写 TOPUP 完成标记，批处理记录该 run 失败。`execute=false` 仍只写计划和命令，不实际生成均值或完成记录。

旧版结果和半成品不会被本次更新自动改写。旧 TOPUP 目录若缺少该参考，仍不能直接交给 BOLD 模块；验证新版本时使用新的输出目录重新运行，不在旧成功结果上补写，也不将其视为自动逐步骤恢复。

### A.4 BOLD：输入与调用

| `spec` 字段 | 含义与要求 |
|---|---|
| `subject` / `session` / `run` | 本 run 的输出标识，与前面的场图关联核对一致 |
| `topupDir` | 已正常完成的 TOPUP 目录，含 A.3 自动生成的 SE 参考 |
| `sbref` | 本 run 的原始三维 SBRef；与 BOLD 网格和仿射一致 |
| `bold` | 原始四维 BOLD，至少两帧；不填官方完整预处理数据 |
| `boldDirection` | NIfTI `i/i-/j/j-/k/k-`，不是直接填写 AP/PA 等解剖标签 |
| `boldReadoutSeconds` | BOLD 自己的总读出时间，秒；当前要求 `0 < T < 1`，不直接照抄 SE 的值 |

Hz 场与 SE 均值必须同网格；SBRef 与 BOLD 必须同网格。SE 到 SBRef 的头位配准由模块执行，仍需检查配准结果。

| 独立 BOLD 配置字段 | 当前起始值 | 用途 |
|---|---|---|
| `outputRoot` | 工具包下 `derivatives/bold_unwarp_study` | 改成工具包外的新输出目录 |
| `wslDistro` / `fslRoot` | `'Ubuntu-24.04'` / `'/home/bx210/fsl-topup'` | 需要 `fslmaths`、`fugue`、`flirt`、`convertwarp`、`applywarp` |
| `affineTolerance` | `1e-4` | 检查场/SE、SBRef/BOLD 各自的网格仿射 |
| `registrationSearchDegrees` | `10` | SE 模拟畸变图到 SBRef 配准的 ±搜索角度，可填 `0..90` 度 |
| `jacobianModulation` | `true` | 对校正 BOLD/SBRef 应用 Jacobian 强度调制；false 则不应用 |
| `execute` | `false` | 验证并写计划；true 执行真实校正 |

A.2 的 TOPUP 正式运行成功后，均值已自动准备好，可继续：

```matlab
bc = bold_unwarp_config;
bc.outputRoot = 'D:\fMRI_Results\bold_plan';
bc.execute = false;
b.subject = s.subject; b.session = s.session; b.run = s.run;
b.topupDir = top.outputDir;
b.sbref = 'D:\Study\S01\bold_SBRef.nii.gz';
b.bold = 'D:\Study\S01\bold.nii.gz';
b.boldDirection = 'j-';       % 替换为该 BOLD 的真实 NIfTI PE 方向
b.boldReadoutSeconds = 0.05; % 替换为该 BOLD 的真实总读出时间，秒
plan = psy.bold_unwarp_validate(b,bc);
preview = psy.bold_unwarp_run(b,bc); % 只写 plan.mat、run_bold_unwarp.sh
```

检查后换新目录执行：

```matlab
bc.outputRoot = 'D:\fMRI_Results\bold_final';
bc.execute = true;
result = psy.bold_unwarp_run(b,bc);
```

批量调用为 `rows=psy.bold_unwarp_batch(specs,bc)`；这里的 `specs` 是 BOLD 输入结构数组，不是 A.2 的 SE 输入数组。每个 run 必须关联自己的 TOPUP 结果、SBRef、BOLD 和采集参数。两个 batch 函数返回逐 run 状态，不自动替使用者保存一份批次 TSV。

### A.5 读懂输出，并交给后续 SPM

独立模块的每个 run 都写到 `outputRoot/sub-<subject>/[ses-<session>/]<run>/`。统一入口将这些目录放在该 run 的 `fsl_topup/`、`fsl_bold_unwarp/` 阶段子目录内；实际完整路径以返回的 `outputDir` 为准。

| 阶段 | 文件 | 含义 |
|---|---|---|
| TOPUP | `acqparams.txt`、`plan.mat`、`run_topup.sh`、`fsl.log` | 采集参数、计划、实际命令和执行日志；未执行时没有运行日志 |
| TOPUP | `topup_fieldcoef.nii.gz`、`topup_movpar.txt` | TOPUP 场模型系数与 SE 输入的运动估计结果；不是 BOLD 的运动参数 |
| TOPUP | `field_hz.nii.gz` | Hz 单位的估计场 |
| TOPUP | `se_unwarped.nii.gz` | 校正后的 SE 输入序列；**不能作为校正后的 BOLD** |
| TOPUP → BOLD | `se_unwarped_mean.nii.gz` | 自动生成的三维 float32 SE 时间均值，BOLD 模块直接读取，见 A.3 |
| TOPUP | `topup_qc.json/png`、`TOPUP_COMPLETE.json` | 工程检查和场估计完成记录 |
| BOLD | `se_to_sbref.mat`、`field_sbref_rad.nii.gz`、`bold_warp.nii.gz` | SE→SBRef 刚体矩阵、SBRef 空间中的 rad/s 场、BOLD 专用变形 |
| BOLD | `bold_unwarped.nii.gz`、`sbref_unwarped.nii.gz` | 未做 Jacobian 调制的畸变校正结果，仍在头动校正之前 |
| BOLD，开启调制时 | `jacobian_raw.nii.gz`、`jacobian.nii.gz` | 原始 Jacobian 与应用时使用的非负版本 |
| BOLD，开启调制时 | `bold_unwarped_jac.nii.gz`、`sbref_unwarped_jac.nii.gz` | 应用 Jacobian 调制后的结果；默认后续选择此版本 |
| BOLD | `bold_unwarp_qc.json/png`、`BOLD_UNWARP_COMPLETE.json`、`provenance.json` | 工程检查、完成记录和来源说明；`provenance.OutputFile` 记录所选 BOLD |

将独立校正结果交给统一 SPM 入口时：

1. 新建 TSV 清单；`bold` 只填一种 BOLD 输出。开启 Jacobian 时选择 `_jac` 版本，不要将两种版本当作两个 run。
2. TSV 的 `input_stage` 填 `sdc_corrected`，`provenance` 指向本模块生成的 `provenance.json`，T1 等其余字段照常填写。
3. 在 `toolkit_config.m` 设置 `cfg.inputStage='sdc_corrected'`、`cfg.distortionCorrection='already_applied'`、`cfg.sdc.method='none'`；逐行 `sdc_method` 留空或设 `none`，避免重复静态校正。
4. 选择新的统一预处理输出目录，先预检，再正式运行 `run_toolkit.m`。程序从校正后的 BOLD 重新估计头动，按 `stopAfter` 继续空间步骤。

更换 BOLD 输入分支后，不能沿用未校正影像的头动参数或已有分析结果。来源 JSON 是处理记录，不表示全部 QC 已合格；后续有限值掩膜、FD 和时序检查见 [工程质量检查](Engineering_QC.md)。

### A.6 受限的直接 `applytopup` 模式

`topup_config.m` 的 `cfg.applyToBold=true` 会让 TOPUP 模块直接对所提供的 `spec.bold` 调用 `applytopup`。它不是 A.4 的 SBRef 配准路线，启用前必须满足当前实现的全部条件：

1. 提供 `bold`、`boldDirection`、`boldReadoutSeconds`；BOLD 与 SE 网格/仿射一致，方向与 SE 的某一方向一致。
2. 独立核实 BOLD 与 SE 的头位确实对齐，并显式填写 `spec.alignmentConfirmed=true`；仅网格相同不够。
3. BOLD 与两组 SE 的有效总读出时间一致；当前允许的绝对差不超过 `1e-6` 秒。

该模式不估计 BOLD 每帧头动，不做场到 SBRef 的配准，也不组合后续空间变换。普通使用保留 `applyToBold=false`。统一入口固定使用先估场、再由 BOLD 模块配准和应用的路线，不读取这个独立开关。

参考：[FSL TOPUP 用户指南](https://fsl.fmrib.ox.ac.uk/fsl/docs/diffusion/topup/users_guide/index.html)、[HCP 官方 BOLD 场图配准与畸变校正脚本](https://github.com/Washington-University/HCPpipelines/blob/master/fMRIVolume/scripts/DistortionCorrectionAndEPIToT1wReg_FLIRTBBRAndFreeSurferBBRbased.sh)。这里只对应关键顺序，未实现完整 HCP 官方流水线。
