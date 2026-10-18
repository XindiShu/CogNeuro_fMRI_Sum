# 4. Realignment：头动校正

本章从刚体运动模型开始，说明 SPM 头动估计、重采样、空间权重和 Realign & Unwarp 的原理与设置。运行路线由 sdc.method 统一选择，不需要删除或注释其他参数段。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

## Realignment：为什么需要头动校正？

被试移动时，同一个体素（voxel）在不同时间点可能对应不同脑组织。例如某个位置在 `t1` 采到灰质，在 `t2` 仍是灰质，到 `t3` 却变成了白质。你看到的信号变化就可能来自脑的位置改变，而非神经活动。

标准头动校正通常把头部近似看成刚体，主要考虑平移（左右、前后、上下）和旋转（pitch、roll、yaw），因此每个 volume（每一帧三维图像）有六个运动参数。SPM 常输出 `rp_*.txt`，大致对应三个平移和三个旋转参数。

### Realignment 到底怎么算？

先假设 Volume 1 是参考图像，再为 Volume 2、Volume 3 等寻找一个刚体变换 `T`，让变换后的图像尽可能与参考图像对齐。实际常见流程为：

```text
Estimate：估计运动参数 → Reslice：按变换重采样，进行空间插值
```

SPM 常用入口是 **Realign: Estimate & Reslice**。

### Mean functional image：平均功能像

Realignment 后通常产生 `mean*.nii`，即配准后各帧 EPI 的平均图像：

$$
\mathrm{MeanEPI}=\frac{1}{N}\sum_{i=1}^{N}V_i
$$

这里 `V_i` 表示已经在共同参考空间中对应起来的图像。后续功能像到结构像的配准，通常使用 **Mean EPI → T1**，而非逐张 EPI 单独配到 T1。

### Framewise Displacement：FD 帧间位移

仅看六个运动参数有时还不够。FD 关注当前帧相对于上一帧移动了多少。例如 Volume 50 到 51 突然头动，`FD=0.8 mm`，这一时间点就需要检查。常见研究中的标记阈值包括 `0.2 mm`、`0.3 mm`、`0.5 mm`；后文会说明计算方式。

### 为什么头动特别危险？

因为头动不一定是随机噪声。例如某个实验条件更容易让被试说话，说话时头动增加，BOLD 信号也随之变化，条件效应与运动伪影就可能混在一起。

### Motion regression：运动混杂回归

Realignment 主要解决空间位置变化，头动引起的 BOLD 伪影未必全部消失，所以 GLM 通常还会加入六个运动参数作为混杂回归变量。某些流水线使用 24 列运动扩展模型，例如原始参数、差分及平方项；后文会进一步区分这种形式与经典 Friston-24 的滞后项定义。

## 首先区分三个概念

- **Realignment（运动参数估计与空间对齐）：**估计各帧之间的相对运动。
- **Reslicing（空间重采样）：**根据已估计的运动，通过插值重新计算参考网格上的体素值。
- **Motion regression（运动混杂回归）：**在后续 GLM 等分析中加入运动相关列，控制残余的运动相关信号变化。

三者有关联，但并不是同一件事。完成 Realignment 不代表头动伪影已全部消除。

## Realignment 的基本原理

被试即使只移动 1 mm，也可能让固定图像坐标采到不同组织。这会造成几类问题：

1. **组织混合。**某个体素在 Volume 1 中主要是灰质，Volume 2 中可能混入白质或脑脊液，使时间序列出现与神经活动无关的变化。
2. **运动引起的信号突变。**即使神经活动没变，突然头动也可能造成大范围信号变化。
3. **运动与条件混淆。**例如图片命名任务中，发声可能伴随头部或下颌运动。若只在特定条件下发声，估计的条件效应中就可能同时包含神经活动和运动伪影。

### 基本假设：Rigid-body transformation（刚体变换）

SPM12 标准 Realignment 使用六自由度刚体配准（6-DOF）：把头近似看成不发生形变的整体，只允许三个平移和三个旋转，不允许整体拉伸、压缩或局部变形。

`rp_*.txt` 记录每帧的六个参数，前三列为毫米，后三列为弧度。

### 六个参数如何描述三维空间变换？

假设体素在原始图像中的空间坐标为：

$$
\mathbf{x}=\begin{bmatrix}x\\y\\z\end{bmatrix}
$$

刚体变换可写为：

$$
\mathbf{x}'=\mathbf{R}\mathbf{x}+\mathbf{t},\qquad
\mathbf{t}=\begin{bmatrix}t_x\\t_y\\t_z\end{bmatrix}
$$

`t` 是三个平移量；`R` 是由三个旋转角确定的 `3×3` 旋转矩阵。用齐次坐标还可写成：

$$
\begin{bmatrix}x'\\y'\\z'\\1\end{bmatrix}
=\begin{bmatrix}\mathbf{R}&\mathbf{t}\\\mathbf{0}^{T}&1\end{bmatrix}
\begin{bmatrix}x\\y\\z\\1\end{bmatrix}
$$

也就是一个 `4×4` 变换矩阵。实际使用时，旋转顺序、坐标系和软件实现都会影响具体矩阵，不能只把 `rp_*.txt` 三个旋转角随意代入自己写的旋转公式。

### SPM12 如何估计运动参数？

假设有 240 个 volume。SPM 选择参考图像 `V_ref`，为每个时间点寻找变换 `T_t`，使它与参考图像的信号分布尽可能一致。每轮根据图像差异调整六个参数，让残差减小，这一步是 **Motion parameter estimation**。

得到参数后，再通过空间插值把图像写到共同参考网格，才是 **Reslicing**。因此 SPM 将 Realignment 分为 Estimate 和 Reslice 两个衔接的环节。

## SPM12 常见的四种相关操作

### 1. Realign: Estimate

只估计运动参数，不立即重采样全部 EPI。SPM 保存六个运动参数，并更新图像的 voxel-to-world 空间变换信息。

Estimate 改变的是空间定位信息，不会把完整体素数组重新插值成一套对齐后的 EPI。例如原图值为 100，不会只因 Estimate 就重新计算为 98 或 102。

后续分析必须正确应用已估计的变换，不能把“只执行过 Estimate 的原像素数组”理解为已经完成重采样。

**接口设置：**现有接口仅在 `cfg.sdc.method='spm_fieldmap_applyvdm'` 时，先调用 SPM Estimate，再用 FieldMap 的 Apply VDM 写出序列。`matlab/+psy/spm_motion_step.m` 建立 Estimate 作业。当前没有“只 Estimate 后结束”的独立配置选项。

### 2. Realign: Reslice

根据已经估计的运动参数，把图像重采样到共同空间，通常接在 Estimate 后。

例如第 100 帧相对参考图向右移动 2 mm，Reslice 根据空间变换，估计它在参考网格各位置的信号。如果对应位置落在原始两个体素之间，就需要利用邻近体素做空间插值。

SPM12 常用 B 样条插值，通常生成带 `r` 前缀的文件，如 `rfunc.nii`。它会改变体素信号值，也可能引入一定插值平滑。

**接口设置：**当前没有单独的 `Realign: Reslice` 入口；普通路线把 Estimate 与 Reslice 合成一个 SPM batch。不能通过删除估计代码，直接处理没有正确变换信息的输入。

### 3. Realign: Estimate & Reslice

这是常用入口，把估计和重采样放在一个 batch 中，允许同时设置两组参数。

选择这个模块，不代表一定输出每一帧重采样图像：SPM 的 Reslice Options 还可选 **Mean Image Only**，只产生配准后的平均 EPI，不输出所有带 `r` 前缀的 volume。希望减少重复插值的流程可能使用这种选择。

**接口设置：**`sdc.method='none'` 或 `'fsl_topup'` 时，当前接口固定采用 Estimate & Reslice，输出全部图像加均值。的 `'none'` 只表示不做磁敏感畸变校正，仍会继续做头动校正。`spm_motion_step.m` 生成此作业。

### 4. Realign & Unwarp

它除了刚体头动，还尝试处理 **susceptibility-by-motion interaction**：头的位置改变时，EPI 的磁敏感畸变也可能改变。

普通 Realignment 假设各帧主要由刚体变换相互对应；但实际可能存在随头动变化的非刚体畸变场，单纯平移和旋转无法解释。Unwarp 尝试估计并减小这些动态畸变引起的时序误差。

要区分：普通 Realignment 主要校正刚体位置；Unwarp 处理运动相关动态畸变；FieldMap 利用测量的磁场信息，校正静态或参考状态下的 EPI 几何畸变。只运行 Unwarp，不等于已校正全部静态 EPI 畸变；改善解剖定位通常还需要有效的 FieldMap。

**接口设置：设置 `cfg.sdc.method='spm_fieldmap_unwarp'` 时，当前 `spm_fieldmap_unwarp` 先准备实测/已有 VDM；也可选择 `spm_unwarp` 不提供 VDM，后者不代表静态畸变已校正。下面会详细解释这条路线。

四种操作的区别如下：

| 方法 | 估计运动 | 重采样 | 动态畸变校正 | 典型用途 |
|---|---|---|---|---|
| Estimate | 是 | 否 | 否 | 先估计，后续再应用空间变换 |
| Reslice | 否，使用已有参数 | 是 | 否 | 根据已有变换写出对齐图像 |
| Estimate & Reslice | 是 | 可选择 | 否 | 常规任务态、静息态 EPI 处理 |
| Realign & Unwarp | 是 | 是 | 是，针对其模型可解释的变化 | 处理运动相关磁敏感畸变 |

对普通任务态 fMRI，Estimate & Reslice 是合理的常规起点；选择 Mean Image Only 还是 All Images + Mean Image，要结合后续重采样步骤。

**接口设置：**目前没有把四种 SPM 操作独立做成四选一参数；路线由 `cfg.sdc.method`（配置第71行） 间接决定。`cfg.realign.*` 是共享估计/写出设置，`cfg.unwarp.*` 只在 Unwarp 路线参与，**不用删掉或注释任何一段**。`cfg.stopAfter='realign'` 表示停在现有头动/QC 流程之后，不是“只做 Estimate”。

## Realignment 的核心参数：Estimation Options

在 SPM → Spatial → Realign → Realign: Estimate & Reslice 中，Estimation Options 决定如何寻找每帧与参考图之间的最佳刚体变换。常见设置如下，实际使用值以配置为准：

| 参数 | 常见默认值 | 主要作用 |
|---|---|---|
| Quality | 0.9 | 配准信息与计算速度的权衡 |
| Separation | 4 mm | 估计时的空间采样点间隔 |
| Smoothing（FWHM） | 5 mm | 运动估计时的辅助平滑 |
| Num Passes | Register to Mean | 选择单遍或两遍配准 |
| Interpolation | 2nd Degree B-spline | 估计过程的空间插值 |
| Wrapping | `[0 0 0]` | 是否允许某方向边界周期相连 |
| Weighting | None | 是否使用空间权重图 |

### 1. Quality：质量参数

Quality 控制估计使用的信息与速度的权衡。SPM 不一定把图像中所有体素都用于估计：均匀区域缺乏空间结构，小幅移动后信号可能不变，因此配准信息较少；灰白质边界、脑室边界等强度变化明显的区域，通常提供更多位置变化信息。

SPM 会评估采样点贡献，根据 Quality 减少信息贡献较小的点。**0.9 不是保留 90% 的体素，也不是“准确率达到 90%”。**

| Quality | 特点 |
|---|---|
| 1.0 | 保留更多估计信息，计算较慢 |
| 0.9 | 常见起点，通常用于常规 EPI |
| 0.8 | 可能更快，也可能损失部分估计精度 |
| 更低 | 不宜在未验证效果时随意采用 |

**接口设置：**配置 `cfg.realign.quality=0.9`，可填 `0..1`。它映射到 SPM 的 `eoptions.quality`；通常先保留 0.9，再依据图像和 QC 比较改动。

### 2. Separation：空间采样间隔

表示估计时在参考图中选取采样点的典型间隔，常见 `sep=4`，单位毫米。

若原 EPI 体素为 `3×3×3 mm`，`sep=4` 表示优化约按 4 mm 间隔采样，而非要求每个原始体素都参与。改为 2 mm 会更密，可能使用更多空间细节，也增加耗时；原图本来模糊时，采样加密不能创造新信息。

需要分清：Separation 4 mm 是估计采样间隔；原始 Voxel size 3 mm 是采集分辨率；Normalization voxel size 2 mm 是后续输出网格。

**接口设置： `cfg.realign.separationMm=4`，填正毫米数，映射到 `eoptions.sep`；可先保留默认。

### 3. Smoothing（FWHM）：估计过程中的平滑

这是最容易与最后的 Spatial Smoothing 混淆的一项。

SPM 在估计运动时会对图像匹配信号做一定高斯平滑，减少局部噪声和高频强度变化的影响，让优化更关注稳定的大尺度结构。例如某体素因随机噪声出现异常高值，适度平滑可减少它对匹配的干扰。

**Realignment 中 FWHM=5 mm，不代表输出 EPI 已做 5 mm 最终空间平滑。**它是估计内部的平滑；即使没有最后的 Spatial Smoothing，Reslice 的插值本身也可能改变局部模式。

**接口设置： `cfg.realign.smoothingFwhmMm=5`，填非负毫米数，映射到 `eoptions.fwhm`。最终平滑由后面的 `cfg.smoothingFwhmMm`（配置第352行） 控制，两个参数独立。

### 4. Num Passes：配准次数

**Register to First：**各帧配到第一个参考 volume。计算较快、参考定义明确；若第一帧有运动或信号异常，其余图像会依赖这个异常参考。

**Register to Mean：**两遍法。先对初始参考配准，再基于首次配准的时间序列形成均值参考，进一步估计各帧到均值的变换。这个解释不代表必须先写出一个独立均值 NIfTI，才能执行第二遍优化。

两遍法减少对单帧的依赖，可能使参考更稳定，但更费时，也不能保证所有运动伪影更小，仍需 QC。SPM 中 `rtm=1` 对应 Mean，`rtm=0` 对应 First。

**接口设置： `cfg.realign.registerToMean=true`。`true`→`rtm=1`，`false`→`rtm=0`。这里的第一帧是实际进入头动模块的第一帧；前面若删除 dummy 帧，它就是保留序列的第一帧。

### 5. Interpolation：运动估计时的插值

估计过程需要知道非整数坐标处的信号。例如旋转和平移后对应位置为 `(30.4,41.2,25.7)`，原数据只存整数网格，因此要从邻近体素估计。

| 插值方法 | 特点 |
|---|---|
| Trilinear | 简单、较快，属于一阶插值 |
| 2nd Degree B-spline | 常用于 Estimate，兼顾精度与效率 |
| 3rd Degree B-spline | 更高阶空间插值 |
| 4th Degree B-spline | 常用于 Reslice 写出 |
| 5th-7th Degree B-spline | 阶数更高，计算代价也更大 |

经典 Estimate 设置 `interp=2` 表示二阶 B 样条，**不是二维插值**。估计和 Reslice 的插值是两个独立设置，可以不同。

**接口设置： `cfg.realign.estimateInterpolation=2`，本接口接受整数 `1..7`：1 为三线性，2-7 为相应阶 B 样条。此参数也供 Unwarp 的头动估计使用；本机 Unwarp 菜单还允许 0，但当前共享接口只暴露 `1..7`。

### 6. Wrapping：边界环绕设置

默认 `wrap=[0 0 0]` 表示三个方向都不环绕。Wrapping 决定采样时是否把某侧边界外的位置，与另一侧边界视为周期相连。

背景是 EPI 有时在相位编码方向发生 wrap-around/aliasing，例如视野不足时鼻部信号折叠到另一侧。若明确有这种周期性采样条件，可以核查对应方向；不确定时通常保持全 0。

Wrapping 不是另一种头动校正，也不能修复已经存在的 EPI 几何畸变。

**接口设置： `cfg.realign.wrap=[0 0 0]`，当前估计和写出共用这行。候选为：

| 输入 | 环绕方向 |
|---|---|
| `[0 0 0]` | 无 |
| `[1 0 0]` | X |
| `[0 1 0]` | Y |
| `[0 0 1]` | Z |
| `[1 1 0]` | X、Y |
| `[1 0 1]` | X、Z |
| `[0 1 1]` | Y、Z |
| `[1 1 1]` | X、Y、Z |

这些方向按图像体素轴理解，不能仅凭“鼻子/后脑”的解剖叫法猜设置。

### 7. Weighting：空间权重图

这是可选的高级参数，默认没有权重图。某些位置的信号可能不可靠，例如严重信号缺失区、边缘伪影、发声时的口部非刚体运动或持续局部异常。Weighting Image 可降低这些位置对估计的贡献。

SPM 中权重与预期噪声标准差的倒数有关，不是随意设一个强度阈值就能得到。更稳妥的做法是先检查普通配准、运动参数和残余伪影，再判断是否需要专门的权重图。

**接口设置：**配置如下：

```matlab
cfg.realign.weightImage = ''; % 配置第141行
```

- `''`：默认不加权；旧正式配置缺少此字段时也采用这一默认。
- 三维 `.nii/.nii.gz` 的绝对路径：启用该权重图。
- `'none'`：明确不加权。

不同被试/run 可在 TSV 的 `realign_weight` 列分别指定；相对路径以 TSV 目录为基准，留空继承全局，`none` 单独禁用。权重图要对齐实际参考 EPI，数值须有限、非负，并有采样权重 >0.01 的有效覆盖。它不会自动生成或配准；共同视野 `Masking` 和 FieldMap 的加权平滑是另外两项。详见 [Weighting 使用说明](Realignment.md)。

权重值可以大于 1，不强制归一化到 0～1。SPM 按 NIfTI affine 在参考 EPI 上采样权重，所以不强制同一矩阵大小或体素尺寸，但必须在世界坐标中对齐且有有效覆盖。正式执行会重新核对权重来源，将其复制到 run 的 `realign_weighting/`，并在 `weight_info.mat` 保存记录；权重改变后不会静默复用旧结果。

## Reslice Options：空间重采样参数

前面的参数决定如何估计运动，接下来决定如何按估计结果输出实际重采样影像。常见重采样设置如下：

| 参数 | 常见设置 | 作用 |
|---|---|---|
| Resliced Images | All Images + Mean Image | 输出全套重采样图与均值 |
| Interpolation | 4th Degree B-spline | 写出时的空间插值 |
| Wrapping | `[0 0 0]` | 边界环绕 |
| Masking | Yes | 处理部分帧超出有效视野的位置 |
| Filename Prefix | `r` | 重采样文件名前缀 |

### 1. Resliced Images：输出图像选择

SPM 通常提供四个选项，图片表格转写如下：

| 选项 | 重采样输出 |
|---|---|
| All Images（1..n） | 全部 volume |
| Images 2..n | 除第一张参考 volume 外的其他图像 |
| All Images + Mean Image | 全部 volume 与平均图 |
| Mean Image Only | 只输出平均图 |

**All Images + Mean Image：**假设 `func.nii` 有 240 帧，通常得到 `rfunc.nii`（对齐后的序列）、`meanfunc.nii`（均值）和 `rp_func.txt`（六参数）。4D `rfunc.nii` 可仍含 240 帧，不一定拆成 240 个文件；可直接检查并继续处理。

**Mean Image Only：**某些官方流程会在后续 Coregistration、Normalization 继续使用已经保存的空间变换，以减少重复插值。但是中间模块若需要真实重采样后的强度数据，就不能只给它一个更新过空间头的原数组。

**接口设置：**当前没有配置行选择这四项；`spm_motion_step.m` 固定 `which=[2 1]`，即全部图像加均值。SPM 的四个值为 `[2 0]`、`[1 0]`、`[2 1]`、`[0 1]`，顺序对应上表。现有 QC/后续空间链需要全套序列，不能只把内部数组改为 `[0 1]` 就宣称 Mean Image Only 流程可用。

### 2. Reslice Interpolation

常用 `interp=4`，即四阶 B 样条。它与 Estimate 的二阶插值不同，直接决定最终重采样体素值。高阶方法使用更多邻近信息，也更费时，并可能在局部出现过冲。

连续 EPI 可以先保留四阶插值。二值 ROI 或离散脑区标签不应随意用高阶连续插值，否则可能生成不存在的中间标签；这里处理的是连续 BOLD，标签图像的选择主要影响后续 ROI 变换。

**接口设置： `cfg.realign.writeInterpolation=4`，可选整数 `0..7`：0 最近邻、1 三线性、2-7 相应阶 B 样条。普通 Reslice 和 Unwarp 写出共用；Apply VDM 写出则用 `cfg.sdc.spm.applyVdmInterpolation`（配置第115行）。普通 SPM Reslice 还提供 `Inf`（Fourier），本接口未开放。

Reslice 的 Wrapping 也使用上面，不另设一组参数。

### 3. Masking

通常 `mask=1`。它不是脑提取、GM mask 或组织分割，而是处理各帧采样范围不一致：某位置在 Volume 1 中有效，但 Volume 2 头动后落在原始视野之外，可能没有可用信号。

启用后，SPM 检查哪些位置不能在所有帧中有效采样，并进行一致的无效值处理。这能减少边界变化引起的人为波动，也可能缩小共同有效范围。头动较大时要检查额叶底部、颞叶边缘等脑覆盖，不能只看运动参数。

**接口设置： `cfg.realign.mask=true`，`true`→SPM 1，`false`→0。在支持 NaN 的格式中，共同视野外可能写 NaN；工具包会在相应校正路线检查，并保存有限值工作副本和有效掩膜，不能据此认定已经完成脑提取。

### 4. Filename Prefix

通常 `prefix='r'`，只控制命名，不改变算法。`func.nii` 变为 `rfunc.nii`；STC 后再 Realign 常见 `ra`，反过来可能是 `ar`。

前缀不能独自证明真实顺序或参数，应看保存的 batch 和日志。

**接口设置：**普通 Realign 的前缀仍固定为 `r`；Unwarp/Apply VDM 现在用 `cfg.sdc.spm.outputPrefix`（配置第132行）（默认 u），可自定义。普通均值名是 `mean<估计输入名>`，不是 `meanr<输入名>`。

## 如何理解六个头动参数？

一个 240 帧 run 的 `rp_func.txt` 通常为 `240×6`：前三列 Translation X/Y/Z，后三列 Rotation X/Y/Z。它们是后续 QC 和运动混杂设计的重要输入。

### 1. 为什么 Rotation 用弧度？

SPM 输出弧度，不是角度。换算为：

$$
\theta_{\text{degree}}=\theta_{\text{rad}}\times\frac{180}{\pi}
$$

例如 `0.02 rad≈1.15°`。1.15° 看似小，离旋转中心较远的组织却可能移动不少。若距中心约 50 mm，弧长近似为：

$$
d=r\theta=50\times0.02=1\ \mathrm{mm}
$$

所以不能只看前三列平移判断运动大小。

### 2. 相对于参考图的运动与相邻帧运动

每帧参数描述它相对参考坐标系的位置，例如 X 平移 1.5 mm；相邻帧差分则关注某个 TR 内是否突然变化。

| Volume | X Translation |
|---|---|
| 1 | 0.0 mm |
| 2 | 0.1 mm |
| 3 | 0.2 mm |
| 4 | 0.3 mm |
| 5 | 1.5 mm |
| 6 | 1.6 mm |

Volume 5 的 1.5 mm 不表示它一定比所有帧都差；关键是 Volume 4 到 5 的变化：

$$
\Delta x_5=1.5-0.3=1.2\ \mathrm{mm}
$$

这是一次突然位移，更容易产生明显时序伪影。QC 不能只报告最大平移和最大旋转，还应检查帧间变化。

## 怎样判断 Realignment 是否成功？

SPM 常显示平移和旋转两组曲线。它们是起点，不是全部依据。

### 1. 六参数曲线

希望曲线相对平稳，没有大量尖峰或异常漂移。缓慢漂移也可能改变视野覆盖和磁场环境；突发头动可能影响当前及后续数帧，不会因 Realignment 自动全部消失。低幅运动仍要结合 FD 与实际影像判断。

### 2. Framewise Displacement（FD）

Power FD 将相邻帧平移和旋转变化合为毫米指标：

$$
FD_t=\sum_{i=1}^{3}|\Delta d_{i,t}|+r\sum_{i=1}^{3}|\Delta\theta_{i,t}|
$$

`Δd` 是平移变化；`Δθ` 是弧度旋转变化；`r` 是将旋转近似换算成位移的头半径，常用 50 mm。

例如一个 TR 内三向平移分别变化 0.1、0.2、0.1 mm，旋转换算后总贡献 0.15 mm：

$$
FD=0.1+0.2+0.1+0.15=0.55\ \mathrm{mm}
$$

Power FD 是由运动参数计算的近似指标，不是某个脑区的精确位移。其他软件可能用 Jenkinson FD 等定义，比较阈值时须确认方法一致。各 run 必须分别计算，不能把一个 run 最后帧与下一个 run 第一帧相减。

| FD 阈值 | 常见用途示例 |
|---|---|
| 0.2 mm | 相对严格的运动筛查 |
| 0.3 mm | 一些研究采用的中间值 |
| 0.5 mm | 常见运动异常标记值 |

这些是示例，不是自动适用于所有设计的统一剔除规则。

**接口设置： `cfg.fdRadiusMm=50` 是正毫米半径； `cfg.fdFlagMm=0.5` 是正毫米标记阈值，可依据研究方案改为 0.2、0.3 等。`motion_qc.m` 逐 run 计算并写出 `motion.tsv`，首帧 FD 定义为 0（没有上一帧，不证明首帧无运动）。该阈值只标记，预处理不会自动删帧或做 spike regression。

### 3. DVARS

FD 衡量运动参数变化，DVARS 衡量相邻帧的体素信号变化。即使 `FD≈0.1 mm`，DVARS 突然升高也可能提示射频异常或其他信号伪影。

**接口设置： `cfg.qc.enabled=true/false` 控制头动后的时序 QC。`timeseries_qc.m` 计算掩膜内时间差的均方根 DVARS，单位为原信号单位，第一帧没有差分值。当前信号掩膜不是已完成人工审查的解剖全脑掩膜。

## Realignment 与后续 GLM 的关系

头动校正后，一级 GLM 通常仍加入运动参数作为混杂变量。空间配准减小位置不一致；运动回归则解释剩余的运动相关信号变化。

### 1. 六参数运动回归

最常见做法是将 SPM 的六列参数加入 GLM。

**接口设置：**独立 `config/design_config.m` `cfg.motionModel='6'`；其他选项为 `'none'` 和 `'24'`。这些列不会因运行预处理而自动进入你的统计模型；需使用相应混杂/GLM 入口。

### 2. Friston-24 运动回归模型

经典构成如下，原图片表转为文字：

| 组成 | 数量 |
|---|---|
| 原始六个运动参数 | 6 |
| 原始参数的平方 | 6 |
| 一阶时间延迟的运动参数 | 6 |
| 延迟参数的平方 | 6 |
| 合计 | 24 |

扩展项可以控制部分非线性和时间延迟的运动相关变化。**滞后项与差分项并不相同**：经典 Friston-24 使用原参数、滞后版本及平方；某些现代去噪模型使用原参数、时间差分及平方。二者有关联，Methods 应按实际实现准确说明。

**接口设置：**当前 `motionModel='24'` 的实现为 `rp`、后向差分 `d`、`rp.^2`、`d.^2`（`motion_regressors.m` ）。因此本工具包这组 24 列属于差分形式，不应直接写成经典滞后形式。

### 3. Scrubbing：异常帧回归

若有少数明显运动尖峰，可考虑 spike regression 或 censoring。例如第 125 帧 FD 超阈值，在 GLM 中加入一列，仅第 125 个位置为 1、其他位置为 0，单独解释这一时间点的异常信号。

可写为：

$$
s_t=\begin{cases}1,&t=125\\0,&t\ne125\end{cases}
$$

增加这些列会消耗模型自由度；大量异常帧也可能表示该 run 的有效数据不足，不能无限增加。

**接口设置：**`design_config.m` `cfg.addSpikes=true/false`，`cfg.fdThresholdMm` 指定构建 spike 列的阈值。当前只加指示列，不删除数据行，也不自动扩展到邻帧；这与预处理中的 `fdFlagMm` 是两个不同入口的参数。

## Realign & Unwarp：模型、参数与运行路线

Realign & Unwarp 的原生模型与参数可参照 [SPM12 手册的 Realign & Unwarp 章节](https://www.fil.ion.ucl.ac.uk/spm/doc/spm12_manual.pdf)。

### 1. 为什么刚体配准之后仍有“形状变化”？

EPI 对局部磁场不均匀较敏感，空气与组织交界附近，例如眶额、前颞区域，容易出现位置拉伸、压缩或位移。头部换了姿态，局部磁场及其造成的畸变也可能变化。

可以想象一个区域在某帧被向相位编码方向拉长，另一帧却拉得较少；整体平移和旋转不能同时消除这些局部形状差异。Unwarp 针对的就是**运动与磁敏感畸变相互作用**，不是把所有非神经信号都当作一个可直接消除的“头动噪声”。

普通运动回归把运动相关时间变化作为混杂解释；Unwarp 尝试估计它背后的空间位移变化。这不保证所有任务相关信号都被保留，也不能代替统计模型的混杂检查。

### 2. 静态场、运动相关变化与 Taylor 展开

用 `d(r,p)` 表示位置 `r` 在头部姿态参数 `p` 下的位移。围绕参考姿态 `p0`，原理上可近似为：

$$
d(\mathbf r,\mathbf p)\approx d_0(\mathbf r)
+\sum_j D_j(\mathbf r)\Delta p_j
+\frac12\sum_j\sum_k D_{jk}(\mathbf r)\Delta p_j\Delta p_k
$$

- `d0`：参考状态的静态畸变，相当于零阶项。
- `Dj`：头部某一运动参数改变时，位移改变多少；一阶导数字段。
- `Djk`：这种变化率还怎样随运动改变；二阶项。

公式是解释模型的近似表达，不是让使用者自己写校正算法。SPM 从估计的运动和残余图像变化中估计导数字段。[SPM Unwarp 说明](https://www.fil.ion.ucl.ac.uk/spm/toolbox/unwarp/)解释了静态场与这些变化项的关系。

仅靠时间序列的变化，很难恢复所有帧共有的静态畸变，所以 **Unwarp 单独运行不等于恢复真实几何**。有效测量的 FieldMap 可提供静态项，Unwarp 再估计运动相关变化。

这类空间模型也不能恢复已经因信号脱落而失去的信息，不能代替 STC 或解决所有运动造成的激发历史效应；效果取决于数据是否存在它所建模的问题。

### 3. FieldMap 与 VDM 在其中做什么？

FieldMap 表示局部频率偏移；VDM（Voxel Displacement Map）表示相位编码方向上的体素位移。对相位差场图，一个原理式为：

$$
\Delta f=\frac{\Delta\phi}{2\pi\Delta TE}
$$

相位差为弧度，`ΔTE` 为秒，得到 `Δf` 的单位为 Hz。结合实际读出时间，可以把频率偏移换算为体素位移；方向符号取决于编码极性及软件约定，不能自行猜正负号。

当前 `spm_fieldmap_unwarp` 是这条**组合路线**：

```text
匹配的相位差/幅度图，或已处理的 Hz 场图
→ SPM FieldMap 计算并准备 VDM
→ SPM 估计刚体运动
→ 估计运动相关导数字段
→ 联合应用运动与该模型中的畸变校正，写出序列和均值
```

SPM GUI 本身可以不提供 VDM 而做 Unwarp；`spm_fieldmap_unwarp` 使用实测场或已有 VDM；`spm_unwarp` 可以不提供 VDM，`spm_vdm_only` 仅准备位移图。与 `spm_fieldmap_applyvdm` 的区别是：后者做 Estimate 后应用静态 VDM，没有这套动态导数字段估计。

### 4. 如何在本工具包选择？

配置：

```matlab
cfg.sdc.method = 'spm_fieldmap_unwarp'; % 配置第71行
```

`none`→普通 Realign；`fsl_topup`→先 FSL 校正再普通 Realign；`spm_fieldmap_applyvdm`→Estimate 加静态 VDM；`spm_fieldmap_unwarp`→VDM 加 Realign & Unwarp。通用 TSV 的 `sdc_method` 可逐 run 覆盖，HCP 入口的 `preprocess_config.m` 还会覆盖通用值。选择这一分支时，共享的 `cfg.realign.*` 和额外 `cfg.unwarp.*` 都生效，不需要注释代码。

需要为每个 run 在 TSV 的 `metadata`、`fieldmaps` 列关联采集与场图 JSON，不能只改方法字符串就运行。相位差路线须有已转换为 `[-π,+π] rad` 的三维相位差、幅度图和真实 TE；原始整数相位不能只把 Units 标成 rad。预计算 Hz 场要预先处理并与该 EPI 对齐；当前此类输入要求同网格、同仿射且 `maskBrain=false`。

本机 stock 相位差 batch 会按 min/max 再缩放；接口现已直接使用官方 FieldMap_create 保留真实弧度，并用已知频率场验证幅度。没有改动安装的 SPM。准确后端和记录格式见 [SDC 参数核对](SDC.md)。

编码方向和读出时间要按协议核实。`SPMBlipDirection` 必须是核实的 -1/+1；全局为 0 时只表示未核实，会拒绝运行，场图 JSON 值优先。JSON 的 `TotalReadoutTime` 是秒，内部转换成毫秒；若实际 SPM 读出约定需另填 `SPMTotalReadoutTimeMs`，须为核实值。

本机 SPM 的 Unwarp 模型对相位编码工作轴有要求；官方 FieldMap 说明按 y 方向描述其适用范围。当前接口以 NIfTI 仿射检查近似世界坐标 AP/PA，**仍须核对 SPM 工作坐标中的相位编码轴和影像朝向**，不会自动把任意方向重排成可用输入。HCP 示例 LR/RL 不走此动态分支。[SPM FieldMap 示例](https://www.fil.ion.ucl.ac.uk/spm/data/fieldmap/)也说明其他方向可能需要 Apply VDM；不要把预检方向门槛理解成已经证明所有朝向的 Unwarp 科研适用性。

### 5. Basis Functions：用多少空间基函数表示导数字段？

SPM 用一组平滑空间基函数表示位移变化，而非任意逐体素独立拟合。基函数更多，能表示更细的变化，也更费计算，可能更容易拟合噪声。

**接口设置： `cfg.unwarp.basisFunctions=[12 12]`，对应 `uweoptions.basfcn`。可选 `[8 8]`、`[10 10]`、`[12 12]`、`[14 14]`。两个数是前两维的基函数数量；省略的第三维由 SPM 计算，使各方向空间截止尺度大致一致。不是只有二维校正，也不是切片数或运动参数数。可先保留 `[12 12]`。

### 6. Regularisation 与 Reg. Factor：怎样限制不合理的空间变化？

Unwarp 在减少残余变化的同时，会限制估计场的幅度或空间粗糙程度。这里有两种独立设置：惩罚形式的阶数，以及惩罚强度。

 `cfg.unwarp.regularisationOrder=1`，映射 `regorder`，可选 `0/1/2/3`。它是**空间正则化阶数**：0 对场本身作零阶约束，1 对一阶空间变化约束，2/3 对相应高阶空间变化约束。`0` 不等于关闭全部正则化，也不是前面的运动 Taylor 展开阶数。

 `cfg.unwarp.regularisationWeight=100000`，映射 `lambda`：

| 输入 | 本机 SPM 菜单 | 相对约束强度 |
|---|---|---|
| `1e4` | A little | 较弱 |
| `1e5` | Medium | 中等，当前默认 |
| `1e6` | A lot | 较强 |

更强不等于更准确，可能抑制真实变化；更弱也可能拟合噪声。常规先保留 `regorder=1`、`lambda=1e5`，如改动要比较影像、残余变化与覆盖。

### 7. Jacobian deformations：是否同时考虑压缩/拉伸造成的强度变化？

空间压缩与拉伸可能让信号看起来集中或稀释，Jacobian 调制尝试在这一模型中考虑这些强度效应。它不是另一张 Weighting 图，也不是统计分析的标准化调制选项。

**接口设置： `cfg.unwarp.jacobianModulation=false`，`false/true` 映射 `jm=0/1`，并影响本机 Unwarp 写出时的强度处理。SPM 帮助对此特定问题建议默认不启用，通常先保留 `false`。它与FieldMap 的 `cfg.sdc.spm.jacobianModulation`（配置第93行）、FSL 分支的开关分别属于不同模块，不能视为同一个开关。

### 8. First-order effects：运动哪些方向影响畸变？

虽然刚体运动有六参数，SPM 默认优先建模 Pitch/Roll 对场变化的一阶效应。磁场方向、图像朝向、匀场等因素会影响物理对应，因此不应凭“六参数都有”就全部增加。

**接口设置： `cfg.unwarp.firstOrderEffects=[4 5]`，映射 `fot`：

| 索引 | 运动参数 |
|---|---|
| 1、2、3 | x、y、z 平移 |
| 4、5、6 | 绕 x、y、z 的旋转 |

可填非空的这些索引向量；`[4 5]` 是 SPM 常见起点，`1:6` 表示全部六参数，其他组合为自定义。索引指 SPM 的运动参数约定，不是任意解剖方向。增加参数意味着拟合更多导数字段，应有协议和结果依据。

### 9. Second-order effects：是否估计运动变化的二阶项？

二阶项描述位移对运动的变化率如何进一步改变，可能包含同一参数平方项和不同参数交互项。它与 GLM 的 Friston-24 平方回归列是不同模型。

**接口设置： `cfg.unwarp.secondOrderEffects=[]`，映射 `sot`。`[]` 默认不估计二阶项；可选运动索引向量 `1..6`。输入 `[4 5]` 后，本机 SPM 会展开为 `[4 4]`、`[4 5]`、`[5 5]` 三组二阶效应，`1:6` 则包含全部组合。通常先留空；更多自由度并不保证更好的校正。

### 10. Smoothing for Unwarp：场估计前的平滑

这是估计变形场之前应用于图像的平滑，减少局部噪声影响；与头动估计的 5 mm 平滑、最终空间平滑都不同。

**接口设置： `cfg.unwarp.smoothingFwhmMm=4`，映射 `uwfwhm`，单位毫米。当前接口要求正数；可先保留 4 mm。

### 11. Re-estimate movement params 与 Number of Iterations

刚体运动和畸变变化相互影响，SPM 可以在 Unwarp 迭代时重新估计运动，让两部分交替更新。

 `cfg.unwarp.reestimateMotion=true`，映射 `rem`：`true` 允许每次迭代重新估计，`false` 保持已有运动估计。 `cfg.unwarp.iterations=5`，映射 `noi`，填正整数，表示最大迭代数，不是重复做五次普通 Realign。通常先保留默认；增加次数更费时，也不保证更多真实信息。

### 12. Taylor expansion point：围绕哪个姿态展开？

Taylor 近似需要参考姿态，选择平均姿态或首/末帧姿态可能改变模型的参考状态。它与普通 `Register to Mean/First` 是不同层面的选择。

**接口设置： `cfg.unwarp.expansionPoint='Average'`，映射 `expround`：

| 值 | 参考姿态 |
|---|---|
| `'Average'` | 平均姿态，当前默认 |
| `'First'` | 首帧姿态 |
| `'Last'` | 末帧姿态 |

SPM 帮助认为 Average 通常是合理起点；在有扫描前场图时，First 可能值得评估，但不能仅凭时间上先扫描就推定最佳，还要核查实际头位、场图匹配和匀场状态。

### 13. FieldMap 准备中的设置与 Unwarp 写出

前述十个 `cfg.unwarp` 字段都在 `spm_motion_step.m` 组成 `uweoptions`。前面的 VDM 准备由 `spm_fieldmap_vdm.m` 调用 SPM，相关配置还包括：

| 配置行 | 参数 | 可选/作用 |
|---|---|---|
| 74 | `sdc.spm.blipDirection` | -1/+1 为核实极性；0 只表示未核实，JSON 可覆盖 |
| 75 | `epiBased` | `true/false`，场图是否基于 EPI；常规 GRE 起点为 false |
| 76 | `maskBrain` | `true/false`，FieldMap 是否使用幅度图与模板建立脑掩膜；须检查质量 |
| 77 | `jacobianModulation` | FieldMap 模块自身调制开关，默认 false |
| 78 | `unwrapMethod` | `Mark3D/Mark2D/Huttonish`，相位展开方法 |
| 79-81 | `unwrapFwhmMm`、`unwrapPadding`、`weightedSmoothing` | 场处理平滑（正毫米）、零填充宽度（非负整数）、是否加权平滑（布尔） |
| 82-87 | `maskTemplate`、`maskFwhmMm`、`maskErode`、`maskDilate`、`maskThreshold`、`maskRegularisation` | 脑掩膜模板及匹配/清理：空模板用 SPM FieldMap 自带 T1；平滑非负毫米，腐蚀/膨胀非负整数，阈值 0..1，正则化正数 |
| 88 | `applyVdmInterpolation` | 整数 0..7；**仅 Apply VDM 写出路线**使用，不控制 Realign & Unwarp 写出 |

这些与 Unwarp 的动态场估计分别属于两个 SPM 模块。[SPM FieldMap 手册](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/FieldMap/fieldmap/)说明了 VDM 准备与使用。

Unwarp 写出使用 `cfg.sdc.spm.resliceImages=all_mean/all`，对应 `[2 1]/[2 0]`，前缀用 `outputPrefix`；插值、环绕、共同视野仍使用 `realign.writeInterpolation/wrap/mask`。只有全序列、无均值时必须停在 realign，并明确跳过需要均值的时序 QC。本机 Unwarp 写出菜单只有全部图像、全部图像加均值两类，不直接等同于普通 Reslice 的四项输出菜单。

### 14. 应检查什么，当前验证到哪里？

检查场图与 EPI 是否匹配、校正方向、局部形状、平均 EPI 与 T1 的叠加、运动曲线、有效脑覆盖、FD/DVARS 和异常强度。文件产生或某个 QC 数值变小，不能单独证明模型正确，也不应把实验条件相关的变化消失自动解释为好结果。

当前会保存 `01_fieldmap_calculate_vdm.mat`、`02_realign_unwarp.mat`、`spm_fieldmap/` 中的 VDM、运动参数和输出序列。参数预检通过后，`cfg.execute=true` 才实际运行；只处理到头动/QC 可设 `stopAfter='realign'`。

本项目已对合成场图和短 EPI 运行两条 SPM FieldMap 路线，Weighting 时的 79/79 是先前回归记录，SDC 扩展后新计数见 VALIDATION；还有真实短 HCP BOLD/T1 加合成场图到平滑的接口验证。**没有对三名 HCP 被试用匹配真实场图完成动态 Unwarp 科研验证，也未证明加权改善真实配准质量。**原先真实完整 HCP run 的成功记录属于 FSL TOPUP 后普通 Realign 路线。范围见 [VALIDATION.md](VALIDATION.md)。
