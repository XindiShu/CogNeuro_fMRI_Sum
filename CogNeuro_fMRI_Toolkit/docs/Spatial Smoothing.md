# 22. Spatial Smoothing：空间平滑

本章说明高斯空间平滑的原理、FWHM 与采样网格的关系，以及平滑对统计分析和空间模式的影响。普通 SPM Smooth 与 DARTEL/Shooting 原生写出的菜单不同，应先确定标准化路线再选择平滑参数。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

## 一、Smoothing 在做什么？

### 1. 空间加权平均，而不是再次配准

Spatial Smoothing 主要把一个 voxel 与邻近 voxel 的信号做空间加权平均。SPM12 常规 Smooth 使用 Gaussian kernel（高斯核），常见宽度有 4、6、8 mm；它们是同一种方法的不同核宽，不是三个不同算法。

例如，中心 voxel 为 120，附近几个 voxel 是 100、105、110、115。平滑后，中心的新值同时受自己和周围信号影响。距离近的点通常权重大，距离远的点权重小，不是把邻居全部等权相加。

它与前面的空间处理有一个区别：Realignment、Coregistration、Normalization 需要估计或应用图像间的空间变换；普通 Smooth 不估计配准关系，直接改变 voxel 的信号值和空间相关性。

这样可能降低局部随机噪声、增强连续区域的信号，也可能让邻近脑区的信号混在一起。更平滑不等于更高分辨率，或者所有分析都更准确。

### 2. 高斯核怎样表示？

一维高斯核为：

$$
G(x)=\frac{1}{\sqrt{2\pi}\sigma}
\exp\left(-\frac{x^2}{2\sigma^2}\right)
$$

x 是相对中心的空间距离，σ 是高斯标准差，决定权重随距离下降得多快。

三维形式为：

$$
G(x,y,z)=\frac{1}{(2\pi)^{3/2}\sigma_x\sigma_y\sigma_z}
\exp\left[-\frac{1}{2}\left(
\frac{x^2}{\sigma_x^2}+\frac{y^2}{\sigma_y^2}+\frac{z^2}{\sigma_z^2}
\right)\right]
$$

σx、σy、σz 分别控制三个方向的宽度。三者相等是各向同性，不相等是各向异性。

对图像 I 做平滑，本质是三维卷积：

$$
I_{\mathrm{smooth}}(\mathbf r)=
\int_{\mathbb R^3}I(\mathbf r')G(\mathbf r-\mathbf r')\,d\mathbf r'
$$

离散 MRI 图像中可写为：

$$
I_{\mathrm{smooth}}(v)=\sum_{u\in\mathcal N(v)}w(v,u)I(u)
$$

w(v,u) 是邻近点 u 对中心 v 的贡献。核权重归一化后总和为 1。这里说的是核的归一化，不是任意 brain mask 内的重新归一化；体积边界、背景和缺失值的影响还需要另看。

**代码对应：**这些计算由 SPM 的 `spm_smooth` 及底层卷积执行。工具包通过 `smooth_run.m` 调用 SPM，用户不用修改这些公式，也不需要在配置里另填权重矩阵。

### 3. 它改变什么，不改变什么？

| 项目 | 普通空间平滑的作用 |
|---|---|
| voxel 信号值 | 改变，每个点混合邻近点的信息 |
| 空间相关性 | 改变，邻近信号通常更相似 |
| 时间维度 | 不沿时间轴平均，逐帧执行三维平滑 |
| TR 与帧数 | 不应因空间平滑而改变 |
| 坐标系与网格 | 普通 Smooth 不负责换空间；Native 仍为 Native，MNI 仍为 MNI |
| 精细空间分辨能力 | 通常降低，不能把模糊理解成采集分辨率提高 |

一个 run 若有 240 帧，SPM 分别平滑这 240 个三维 volume，不把第 1、2、3 帧在时间上平均。DARTEL/Shooting 的原生组合写出同时包含标准化，但不能把其中的空间变化归因于普通 Gaussian Smooth。

### 4. 为什么可能提高信噪比？

可以把某个 voxel 的时间序列简化为：

$$
Y_v(t)=S_v(t)+\varepsilon_v(t)
$$

S 是任务相关信号，ε 是噪声。如果邻近点包含共同信号、噪声彼此独立，平均能够让共同信号保留下来，而随机波动部分抵消。

在 n 个点信号相同、噪声独立同方差、等权平均的理想例子中，噪声标准差变为：

$$
\mathrm{SD}_{\mathrm{new}}=\frac{\mathrm{SD}_{\mathrm{old}}}{\sqrt n}
$$

于是有：

$$
\mathrm{SNR}_{\mathrm{new}}\approx\sqrt n\,\mathrm{SNR}_{\mathrm{old}}
$$

这只是理解平均效应的理想近似。高斯核不是等权平均，真实 fMRI 噪声也存在空间相关，邻近位置的神经信号未必相同，不能据此预测实际增加多少 SNR。

如果激活区域很小，周围大部分点没有相同信号，平滑还可能降低该区域的峰值。所以收益取决于信号尺度和噪声特征，不是核越大越好。

### 5. 为什么群体分析常用平滑？

即使 48 名被试都已到 MNI，脑沟、脑回和功能区位置仍有残余差异。适当平滑可以让位置略有偏移的共同激活更容易重叠。

代价是空间特异性下降：原本边界清楚的区域 A 与 B，平滑后边界附近可能混入对方信号。它不能替代正确标准化，也不能消除所有真实功能个体差异。

## 二、平滑方式与处理顺序

### 1. 各向同性和各向异性

| 方式 | 示例 FWHM | 含义 |
|---|---|---|
| Isotropic，各向同性 | `[6 6 6]` mm | 三个方向宽度相同 |
| Anisotropic，各向异性 | `[6 6 4]` mm | 前两方向 6 mm，第三方向 4 mm |

它们都属于三维高斯卷积。各向异性可用于有明确方向性需求的数据，但不会修复某方向原本较低的采集分辨率；也不表示较小核的方向完全不损失细节。

各向异性的三轴核仍不等于 Surface-based Smoothing。普通体积平滑根据三维距离混合信号，表面平滑则利用皮层表面的邻接关系；处理空间和输入要求不同。

**代码对应：。**

```matlab
cfg.smoothingFwhmMm = [6 6 6]; % 配置第352行
```

这一行已经控制两种方式，不需要再选另一个算法名字：三项相同就是各向同性，不同就是各向异性。输入必须是三个有限、非负实数，可为小数；不能填单个 `6`、列向量、负值、Inf 或 NaN。

当前 `segmentation` 和群体 `deformations` 写出支持各向异性。DARTEL/Shooting 的 `native` 写出只允许三项相同；具体原因与选择见第四部分。表面平滑尚未接入。

### 2. 为什么通常在 Normalization 后平滑？

常规 task-fMRI 的概念顺序为：

```text
Realignment → Coregistration → Normalization → Smoothing → GLM
```

STC、SDC 等根据采集条件和所选路线安排。先变到共同空间，再使用统一毫米核，便于说明不同被试在共同坐标系中施加了怎样的平滑。

如果先在 Native space 平滑，再非线性标准化，形变会改变局部空间尺度，最终 MNI 中的平滑不一定仍是同一个均匀核。因此两种顺序通常不等价。

对传统激活分析，Normalization → Smoothing → First-level GLM 是常见方案；对 MVPA/RSA，是否在 GLM 前平滑需要另作决定，不能一律套用 6～8 mm。

**代码对应：**普通路线在 `spatial_steps.m` 中 Normalise Write 后调用 Smooth；群体 deformations 同样如此。native 使用原生组合标准化/平滑函数，保留其特有实现，不额外再叠加一个普通 Smooth。

`cfg.stopAfter='smooth'` 选择完整空间链。它不会自动运行后续 GLM；GLM/单试次模型是另外的入口。当前也没有切换为 Native-space 先平滑的配置。

## 三、SPM Smooth 的参数与代码对应

### 1. Images to Smooth：平滑哪些影像？

SPM 菜单路径为 `SPM → Spatial → Smooth`，也可在 Batch Editor 中选择 Smooth。

常规输入是完成前面步骤的功能像，例如 `warfunc.nii`。如果文件有 240 帧，需要处理全部时间点，不能只选 `warfunc.nii,1`，否则只处理第一帧。

**代码对应：**原始输入来自清单 `bold` 列，实际平滑对象由流水线自动关联到当前 run 的标准化 BOLD。普通调用把整个 4D 文件传给 SPM，由 SPM 逐帧处理；native 函数也遍历全部帧。

240 只是例子。若先删除 4 帧 dummy，标准化和平滑应保留 236 帧。当前程序记录并检查平滑前后帧数、TR 和网格一致，不需要手工在函数中写 `1:240`。

Mean EPI 只标准化，不额外写平滑均值；T1、组织图和图谱也不会自动跟随 BOLD 平滑。主入口没有任意外部图像列表或独立 smoothing-only 模式；SPM 可平滑 beta/组织图的普遍能力与当前主接口的输入范围应分开。

### 2. FWHM：最核心的核宽参数

FWHM 是 Full Width at Half Maximum，半高全宽。高斯曲线在中心最高，降到峰值一半时左右两个位置之间的距离就是 FWHM。

它与标准差的关系为：

$$
\mathrm{FWHM}=2\sqrt{2\ln2}\,\sigma\approx2.3548\sigma
$$

因此：

$$
\sigma=\frac{\mathrm{FWHM}}{2.3548}
$$

6 mm FWHM 对应：

$$
\sigma\approx\frac{6}{2.3548}\approx2.55\ \mathrm{mm}
$$

**6 mm 不是半径。**在连续高斯曲线上，距中心 3 mm 的位置权重为峰值一半。高斯理论上继续向远处衰减，不会在半径 6 mm 突然归零；实际程序为有限计算截断核。

| FWHM | σ，约值 | 相对常见 task-fMRI 设置的描述 |
|---|---|---|
| 2 mm | 0.85 mm | 很轻 |
| 4 mm | 1.70 mm | 较轻 |
| 6 mm | 2.55 mm | 中等 |
| 8 mm | 3.40 mm | 较强 |
| 10 mm | 4.25 mm | 更强 |
| 12 mm | 5.10 mm | 非常强 |

“轻/强”是定性描述，实际影响仍取决于输入分辨率和信号空间尺度。SPM stock Smooth 默认 `[8 8 8]`，官方示例也使用 `[6 6 6]`；本工具包当前默认为 **6 mm**，不需要为匹配 SPM stock 默认而改成 8。[SPM 官方 Smoothing 教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/block/preprocessing/smoothing/)

**代码对应：仍填写 FWHM，不填 σ。**

| 配置示例 | 含义与建议 |
|---|---|
| `[6 6 6]` | 当前默认；常规分析可作为初始方案，再结合目标尺度评估 |
| `[4 4 4]`、`[8 8 8]` | 其他核宽，不是切换算法；应事先确定依据 |
| `[2 2 2]` | 可用于有研究依据的轻度平滑方案，不保证模式分析一定更好 |
| `[6 6 4]` | 各向异性，需支持的写出路线与明确理由 |
| `[0 0 0]` | 不增加此高斯核，仍保留完整空间链及相应输出记录 |

没有只允许 2、4、6、8 的菜单限制，也没有“自动选最优核”的程序。若需要没有额外平滑的数据，通常直接使用已保留的那套结果，不必仅为获取它而再次运行前面的预处理。

### 3. FWHM 与 Voxel Size：毫米和采样点数是两件事

核宽常从约 1.5～2 倍 voxel size 的量级考虑，SPM 示例采用约两倍作为起点。比如原始 `3×3×3 mm` EPI，6 mm FWHM 约为两个原始 voxel 的宽度。这是起点，不是所有数据必须遵守的规定，更不是统计效能保证。

若 3 mm EPI 被标准化到 2 mm，6 mm 仍是 6 mm；不能因为输出变成 2 mm，就机械地把核改为 4 mm。

| 当前被平滑图像的 voxel size | 6 mm FWHM 相当于几个 voxel 的宽度？ |
|---|---|
| 2 mm | 3 个 |
| 3 mm | 2 个 |

SPM 根据空间矩阵换算毫米到 voxel 单位。输出网格变细也没有创造新的采集信息，平滑核选择还应考虑原始有效分辨率和目标结构尺度。

**代码对应：`cfg.voxelSizeMm`（配置第342行） 控制标准化网格，`cfg.smoothingFwhmMm`（配置第352行） 控制额外平滑核。**二者独立填写，代码不会根据改后的 voxel size 自动换核。

### 4. 输入核不等于最终有效平滑度

原始 EPI 已有空间点扩散，头动、SDC、Normalization 的插值也可能改变空间相关。若原有点扩散与额外核都近似高斯，可近似写成：

$$
\mathrm{FWHM}_{\mathrm{effective}}\approx
\sqrt{\mathrm{FWHM}_{\mathrm{intrinsic}}^2+
\mathrm{FWHM}_{\mathrm{applied}}^2}
$$

例如，原来近似 4 mm，再施加 6 mm：

$$
\mathrm{FWHM}_{\mathrm{effective}}\approx\sqrt{4^2+6^2}
\approx7.21\ \mathrm{mm}
$$

真实点扩散未必高斯或处处一致，不能用这个例子代替残差平滑估计。填写的是额外施加的核，不是要求最终残差必须等于 6 mm 的目标。

### 5. Data Type：怎样存储平滑后的数值？

加权平均通常产生非整数。整数存储需要缩放和量化，浮点可更直接表示连续结果。SPM Smooth 的 SAME 默认尽量沿用输入类型。

**代码对应：。**

```matlab
cfg.smooth.dataType = 'same'; % 配置第356行
```

| SPM 名称 | SPM 编码 | 当前配置填写 | 含义与建议 |
|---|---|---|---|
| SAME | 0 | `'same'` | 普通路线沿用输入类型，当前默认；先确认输入存储适合连续信号 |
| UINT8 | 2 | `'uint8'` | 8 位无符号整数，存在量化，不适合含负值的连续 BOLD，通常不优先选 |
| INT16 | 4 | `'int16'` | 16 位有符号整数，保留 SPM 兼容选择，注意量化 |
| INT32 | 8 | `'int32'` | 32 位有符号整数，仍是整数存储 |
| FLOAT32 | 16 | `'float32'` | 32 位浮点，连续 BOLD 常用，可按需求选择 |
| FLOAT64 | 64 | `'float64'` | 64 位浮点，存储更大；不会恢复 FLOAT32 原本没有的信息 |

编码不是存储位数。配置填名称，不直接填 `16` 或 `64`；接受字符行/标量字符串，类型名称大小写会归一化。

**4D 整数缩放。**本机 stock Smooth 在转整数时按帧选择缩放。不同帧强度范围不同，单个 4D 头不能表达多套缩放，实际测试出现不兼容警告。因此，当前普通路线遇到多帧整数目标时，先由 SPM Smooth 写 FLOAT64 中间结果，再调用 `spm_file_merge` 统一缩放写所选整数 4D。

`same` 且输入为整数的多帧数据也如此处理。卷积和合并都调用 SPM，不另写算法，避免中间重复整数化；仍存在最后的量化误差和 NIfTI 缩放头精度限制。

作业中可能看到 Smooth 的实际 dtype 为 64，以及额外的 `06_smooth_merge.mat`；最终输出仍为请求的整数类型。中间 `*float64_*.nii` 位于本次分析目录，完成记录保存实际路径和处理方式，不放入精简代码发布目录。

**路线限制：**群体 native 没有普通 dtype 菜单，只允许 `'same'` 这个兼容值；它表示沿用原生规则，Preserve=1 时仍写 FLOAT32，不能理解成所有 native 输出都强制等于原输入类型。详见第四部分。

### 6. Implicit Masking：保留无效位置，不等于 ROI 内平滑

SPM 的隐式掩模使用特殊数值表示无效位置：整数图通常为 0，浮点图通常为 NaN。浮点图中的普通 0 不自动等于无效。

例如：

```text
100  105  110  0  0
有效脑信号     背景
```

将背景 0 当普通信号卷积，可能拉低脑边缘信号；脑内信号也可能扩散到原背景位置。但要分清**平滑后恢复无效边界**与**只在有效区域内重新归一化卷积**。

普通 SPM 的 Implicit Masking=Yes 主要在平滑后恢复输入的无效位置。它不能保证不跨组织混合，也不能阻止邻近 ROI 之间泄漏。

**代码对应：。**

```matlab
cfg.smooth.implicitMasking = false; % 配置第358行
```

| 输入 | SPM 映射 | 实际含义与建议 |
|---|---|---|
| `false`，默认 | `im=0`，No | 不追加恢复输入隐式掩模；常规可先保留默认，并检查边缘 |
| `true` | `im=1`，Yes | 平滑后恢复输入隐式无效位置；浮点输出对应 NaN，整数输出对应 0 |

也接受标量 0/1，不接受 `'yes'` 之类字符串。大量 NaN、零背景或边界异常时，要检查数据值与覆盖含义；不能认为打开此项就完成了 masked smoothing。

工具包的整数 4D 合并保留相应零位置。核查程序区分合法隐式位置与意外非有限值，不把“输出没有 NaN”作为适用于所有设置的唯一标准。

native 只接受 false 兼容值，实际采用原生权重处理。它没有普通 im 菜单，记录中 `effectiveImplicitMasking=[]` 表示不适用；这与普通 `im=0/1` 不是同一操作。

### 7. Filename Prefix：输出怎样命名？

SPM 常用前缀为 s，例如：

```text
warfunc.nii → swarfunc.nii
```

4D 输出仍可保留全部时间点。不要把已平滑的结果再次作为常规平滑输入，除非有意追加平滑；两次各 6 mm 的高斯核近似合成为：

$$
\mathrm{FWHM}_{\mathrm{combined}}\approx\sqrt{6^2+6^2}
\approx8.49\ \mathrm{mm}
$$

它不会“仍然只有 6 mm”。这个合成关系也依赖高斯近似。

**代码对应：。**

```matlab
cfg.smooth.prefix = 's'; % 配置第360行
```

| 设置 | 普通示例输入 | 结果 |
|---|---|---|
| `'s'`，默认 | `warfunc.nii` | `swarfunc.nii` |
| `'sm6_'` | `warfunc.nii` | `sm6_warfunc.nii` |
| `'sm4_'` | `warfunc.nii` | `sm4_warfunc.nii` |

前缀只负责命名，叫 sm4_ 不会自动施加 4 mm，核仍由控制。必须非空、英文字母开头，后续只含字母、数字、下划线；禁止路径分隔符、点号等。`cfg.atlas.prefix`（配置第255行） 和 SDC 前缀不控制平滑结果。

native 的原生默认结果是 `sw*` 或调制的 `smw*`，接口可仅重命名本次新结果。例如对 `mwfunc.nii` 选 `'sm6_'`，得到 `sm6_mwfunc.nii`，不额外再平滑。自定义目标已存在时明确报错。

**零核的命名：**`[0 0 0]` 也保留命名和完成流程。native 从未额外平滑结果复制后命名；普通路线仍调用零核 Smooth，指定类型时可能转换/量化。因此，s 前缀不是非零平滑证据，也不能要求全部零核结果与输入字节相同。

## 四、DARTEL/Shooting：平滑参数在哪条路线生效？

三条标准化路线并非都通过普通 Smooth 写出。

| 当前路线 | 实际执行 | FWHM | 类型/隐式掩模 | 前缀 |
|---|---|---|---|---|
| segmentation，使用 SPM 或 CAT 的场 | Normalise Write → 普通 Smooth | 任意有效三轴核 | 全菜单 | 可改 |
| dartel/shooting + deformations | 合成最终场 → Normalise Write → 普通 Smooth | 任意有效三轴核 | 全菜单 | 可改 |
| dartel/shooting + native | 原生 MNI 标准化/加权/平滑函数 | 仅三项相同 | 只允许 same/false 兼容默认 | 可改，写出后命名 |

**代码对应：`cfg.normalise.method`（配置第282行） 选 `'segmentation'`、`'dartel'`、`'shooting'`；`cfg.normalise.group.writeMethod`（配置第292行） 为群体路线选 `'native'` 或 `'deformations'`。

独立 DARTEL/Shooting 要求`cfg.segment.backend='spm'`。CAT 内部的 Shooting 属于 CAT 自己的结构流程，不是这里的独立 SPM Shoot；CAT 分割后使用其场的普通 BOLD 写出仍可用第一行菜单。

native 使用 `spm_dartel_norm_fun` / `spm_shoot_norm`，固定三线性采样和等方性 FWHM。其未调制结果涉及原生加权处理，与普通 Write 后 Smooth 不是数值上完全相同的替代，不能为统一菜单而忽略这些区别。

`cfg.normalise.group.preserve`（配置第294行）：0 不做组织量调制，常规 BOLD 通常保持 0；1 为原生组织量调制，主要用于 VBM，输出 `mw*`，平滑默认 `smw*`。开放调制写出并不代表完整 VBM 工具链已经建好。deformations 只允许 0。

如果需要各向异性、FLOAT32/FLOAT64 显式选择或隐式掩模，群体路线可以这样配置：

```matlab
cfg.segment.backend = 'spm'; % 配置第191行
cfg.normalise.method = 'dartel'; % 可换 'shooting' % 配置第282行
cfg.normalise.group.writeMethod = 'deformations'; % 配置第292行
cfg.normalise.group.preserve = 0; % 配置第294行
cfg.smoothingFwhmMm = [6 6 4]; % 配置第352行
cfg.smooth.dataType = 'float32'; % 配置第356行
cfg.smooth.implicitMasking = true; % 配置第358行
cfg.smooth.prefix = 'sm_'; % 配置第360行
```

若选择 native 却填写不兼容项，程序会在昂贵计算前报错，不自动改算法、不静默忽略。程序也不会先普通 Smooth 再叠加 native 平滑。

## 五、平滑对 GLM、统计推断和模式分析的影响

### 1. 传统单变量 GLM

Mass-univariate GLM 在各 voxel 分别建模：

$$
\mathbf Y_v=\mathbf X\boldsymbol\beta_v+\boldsymbol\varepsilon_v
$$

在 GLM 前平滑，意味着某点的新时间序列是附近序列的空间组合：

$$
\mathbf Y'_v=\sum_u w(v,u)\mathbf Y_u
$$

因此，平滑会影响之后的估计和统计，而不只是把最终 t 图看起来画得更连续。

对连续激活区域，可能降低噪声、缓解被试间的小偏移，增强共同激活的检测。但也会改变峰值与范围：某处较高的 β 可能被邻近较低响应拉低，周围位置被抬高，最后可能出现范围更广、峰值更低的激活。

同一数据使用 4 mm 和 8 mm 时，peak coordinates、peak t-values、cluster extent 可能不同。簇更大不代表活动更强，也不能根据哪种核更显著，事后挑参数。

### 2. Gaussian Random Field Theory 与 Resel

SPM 的传统随机场推断用到空间相关性，用于评估大量 voxel-wise 检验中，峰值或簇在零假设下偶然出现的概率。

Resel（Resolution Element）可理解为给定有效平滑度下搜索区域中的空间分辨单元；它不是严格等于一组相互独立的 voxel 或独立检验数。

三维、均匀平滑的粗略近似是：

$$
N_{\mathrm{resel}}\approx
\frac{V_{\mathrm{search}}}
{\mathrm{FWHM}_x\mathrm{FWHM}_y\mathrm{FWHM}_z}
$$

体积与宽度的单位要一致。例如三轴有效宽度都近似 6 mm，一个近似分辨单元的体积尺度是：

$$
6\times6\times6=216\ \mathrm{mm}^3
$$

真正的 SPM 推断还涉及搜索区形状、边界、自由度和残差空间相关，不是用这一除法就能重建全部 FWE 结果。

尤其要区分：**指定的 Gaussian 核宽度**与**模型残差估计出的有效平滑度**。SPM 的 `spm_est_smoothness` 根据标准化残差的空间导数等信息估计，不能直接拿的 `[6 6 6]` 代替。

更大的核可能减少近似 resel 数，也可能削弱小尺度真实信号；自由度、阈值、搜索空间、信号和噪声变化仍影响结果。因此，不存在“核越大就越容易通过 FWE”的简单规则。

**代码对应：**平滑配置没有目标残差 FWHM、目标 Resel 或自动迭代调核的字段。当前 `SMOOTHING_COMPLETE.mat` 的 FWHM 是请求核，帧数/网格检查也不等于残差平滑估计。后续 SPM 模型估计的机制属于统计分析阶段。

### 3. ROI 平均与空间信号泄漏

假设要从 LIFG 提取平均 β 或 BOLD。先做 8 mm 全脑平滑，再用 LIFG mask 提取，ROI 内部分点可能已经混入邻近额叶区域或白质信号，这就是 Spatial Signal Leakage。

即使最后用严格 ROI mask 排除了所有 ROI 外 voxel，也不能倒退消除已经混进来的成分。因此：

```text
先平滑全脑 → 提取ROI
先在未额外平滑数据中提取ROI → 分析
```

两者不等价。较大且内部信号一致的 ROI 可能从适度平滑受益；小 ROI、复杂边界或区分相邻区域的研究，更需注意空间特异性。

普通体积高斯核不知道脑沟/脑回的解剖边界。位于脑沟两侧、属于不同脑回的点，只要三维距离近，也可能相互影响；各向异性核和 Implicit Masking 都不能自动解决这一问题。

**代码对应：**图谱输出、GLM 掩模与隐式掩模都不是 ROI 内限制卷积。当前尚未实现表面平滑或任意 ROI/组织边界内重新归一化的平滑接口。

### 4. MVPA/RSA 关注多体素模式

单变量分析主要关注逐点或区域的响应强度，MVPA/RSA 还关心多个 voxel 之间的联合模式。两种语言的 ROI 均值接近，并不代表模式相同。

用一个**仅用于理解、并非实际数据或 SPM 输出**的数值例子说明：

| 条件 | voxel 1 | voxel 2 | voxel 3 | voxel 4 | 均值 |
|---|---|---|---|---|---|
| 语言 A | 2 | 0 | 2 | 0 | 1 |
| 语言 B | 0 | 2 | 0 | 2 | 1 |

两者均值相同，排列模式不同。极端地，如果把四点全部混为同一个均值，两者都会变成 `[1 1 1 1]`，该差异消失。这不是说普通 6 mm 核必然把这个例子变成同一个模式，只用于说明混合会改变模式信息。全常数模式的相关距离本身未定义，不能把它算作“相关距离变成 0”。

也不能断言所有 MVPA/RSA 都一定因平滑变差。Op de Beeck 的研究，在其测试范式中没有观察到多变量分析敏感性因平滑下降；它不能外推为全部任务都不受影响。该文 **2009 年在线发表、2010 年正式刊出**。[原研究记录](https://pubmed.ncbi.nlm.nih.gov/19285144/)

影响取决于信号空间尺度、噪声、分析方法和使用的信息。某些细尺度差异可能被削弱，较粗模式或较低噪声又可能对检测有利，需要结合具体设计。

### 5. 不同 RSA 距离的变化不一定同向

相关距离的一种常见形式为：

$$
d_{\mathrm{corr}}(i,j)=1-\operatorname{corr}
(\boldsymbol\beta_i,\boldsymbol\beta_j)
$$

平滑改变 voxel 的权重和相关性，会影响模式间关系及 RDM。相关距离、Euclidean distance、crossnobis distance 的定义和噪声处理不同，不能直接断言平滑后全部距离都会变小，或者全部试次的相似性排序保持不变。

对 trial-wise β 的 RSA，还要考虑平滑在什么时候做。用平滑 EPI 估计出的 β，本身已经受这种混合影响；后来再选“未平滑 β 文件名”，不能恢复先前被混合的输入信息。

### 6. 语言 RSA 研究的输入选择

对于语言身份、切换状态和跨阶段表征连续性的研究，可保留不增加额外 Gaussian Smooth 的 BOLD，用于估计 trial-wise β。若需要考察 SNR 与空间尺度，可将 2～4 mm 轻度核作为**事先规定**的敏感性分析，而不是把传统 8 mm 作为唯一方案，或根据显著性再挑核。

“Unsmoothed”通常只表示没有再施加这一步 Gaussian Smooth。数据仍可能经过头动、SDC、Normalization 的插值，不能称为完全未经空间处理。

**代码对应：**当前同时保留未额外平滑和配置核的 BOLD。独立 GLM/单试次入口通过各自 TSV 的 `bold` 列选择真实路径，不会自动替用户决定用哪套。已有 LSA/LSS 说明见 [SINGLE_TRIAL_GLM.md](../../GLM/docs/SINGLE_TRIAL_GLM.md)；完整 RSA/MVPA 分析及多核自动比较尚未实现。

## 六、批量接口、结果与使用边界

### 1. 最少需要改哪里？

路径与逐 run 信息在数据清单，平滑主要改四行：

| 字段 | 当前配置行 | 作用 |
|---|---|---|
| `cfg.smoothingFwhmMm`（配置第352行） | 352 | 三轴毫米核；相同/不同决定各向同性/各向异性 |
| `cfg.smooth.dataType`（配置第356行） | 356 | 请求的输出类型 |
| `cfg.smooth.implicitMasking`（配置第358行） | 358 | 普通 Smooth 的隐式掩模开关 |
| `cfg.smooth.prefix`（配置第360行） | 360 | 平滑输出前缀 |

`cfg.execute=false` 先预检，确认输入和选项后改 true 再运行入口；stopAfter 选 smooth 才走完整空间链，realign/segment 在更早阶段结束。VDM-only、已处理输入有各自跳过/退出规则，不能只看阶段名字推断所有输入都重新平滑。

通用 `run_toolkit.m` 依据清单自动处理多被试/session/run，不手选每个人或每帧。HCP 的 `run_preprocessing.m` 另有示例数据发现和覆盖设置；其他研究不要复制 HCP 的协议假设。

### 2. 不要与其他“平滑”参数混淆

| 字段 | 当前行号 | 实际控制 |
|---|---|---|
| `cfg.realign.smoothingFwhmMm`（配置第147行） | 147 | 头动估计时预平滑 |
| `cfg.unwarp.smoothingFwhmMm`（配置第174行） | 174 | Unwarp 场估计相关平滑 |
| `cfg.segment.biasFwhmMm`（配置第203行） | 203 | 偏置场变化尺度 |
| `cfg.segment.smoothnessMm`（配置第222行） | 222 | 结构分割/形变估计的 Smoothness |
| `cfg.coreg.smoothingFwhmMm`（配置第270行） | 270 | 历史名称易误解，实际是联合强度直方图平滑；两个值，不是毫米影像核 |
| `cfg.normalise.dartel.templateSmoothing`（配置第306行） | 306 | 模板 LogOdds 参数 |
| `cfg.normalise.shooting.templateRegularisation`（配置第321行） | 321 | Shooting 模板平滑约束 |
| `cfg.normalise.shooting.smoothingIterations`（配置第323行） | 323 | Shooting 模板平滑迭代 |
| `cfg.smoothingFwhmMm`（配置第352行） | 352 | 本文讨论的最终 BOLD 核 |

不要为改变最终核而把 Coreg 的 `[7 7]` 改成 `[6 6 6]`。这些阶段的单位、对象和目的各不相同。

### 3. 输出与记录

| 文件 | 内容 |
|---|---|
| `06_smooth.mat` | 普通 Smooth 的真实 SPM batch |
| `06_smooth_merge.mat` | 需要整数 4D 时的合并输入/输出、类型、TR 与执行函数 |
| `06_native_smooth.mat` | 原生 DARTEL/Shoot 的 job 与执行函数 |
| `SMOOTHING_COMPLETE.mat` | 平滑真实路径、FWHM、请求类型/掩模、实际类型、有效掩模、前缀、帧数/TR/网格 |
| `NORMALISATION_COMPLETE.mat` | 群体路线的标准化记录，其中追加 smoothing 信息 |
| `COMPLETE.mat` | 整个 run 的完成与必要结果关联 |

结果位于配置的 outputRoot 内，不放入精简代码发布目录。后续读取完成记录中的实际路径，不能始终硬编码 `sw*.nii`，也不能单靠 s 前缀判断核宽。

请求值与实际值明确区分：same 的实际存储类型见 `effectiveDataTypeCode`；native 的普通 im 菜单不适用，不伪造为已经执行了 Yes/No。

### 旧研究配置与实际掩模记录

旧配置没有 smooth 分支时，接口按 `same / false / s` 兼容。native 的 `effectiveImplicitMasking=[]` 表示普通 Smooth 的 im 菜单不适用，并非漏存或关闭所有原生权重。后续程序应读实际完成记录，不能把请求值当作每条路线都采用了同一种算法。

### 4. QC 与恢复机制

平滑检查核对时间帧数、TR、网格；新群体分支还检查输出信号、Inf 与非有限覆盖。旧 `verify_spatial` 在原有逐 run SPM 组织布局中按记录定位自定义前缀，并核对合法隐式位置及 dummy 后帧数；不能据此宣称已经支持任意外部/CAT/共享群体结构布局。

这些工程检查不等于有效残差 FWHM 估计，也不等于全面解剖审查。一个被试也能检查空间覆盖、配准和输出，不是只有组样本足够才能做 QC。

改核、类型、掩模、前缀或计算代码后使用新的 outputRoot，保存旧成功结果。恢复只复用一致的已完成处理，不直接覆盖半成品。当前没有任意现成影像的独立平滑界面、表面/ROI 限制卷积、目标残差平滑度自动调节或一次自动跑全部核的功能。
