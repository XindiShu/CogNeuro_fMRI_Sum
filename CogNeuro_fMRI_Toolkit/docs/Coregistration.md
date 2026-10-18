# 11. Coregistration：功能像和结构像配准

本章说明功能像与结构像的空间对应、SPM 配准目标函数和参数选择。当前接口固定使用 Coregister: Estimate，以原生 T1 为固定参考，将平均 EPI 与全部工作 BOLD 帧一起关联到 T1；没有独立 Reslice 或 Estimate & Reslice 开关。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

**当前接口的范围：固定使用 `Coregister: Estimate`，没有 `Reslice`、`Estimate & Reslice` 的选择，也没有 Coreg 专用的 Reslice 参数入口。**本文保留这两类操作的理论介绍，但会在对应位置标清“SPM 支持、当前工具包未开放”，不能把理论中的原生选项当作已经可在配置里运行的功能。

## 一、为什么需要 Coregistration？

一次 fMRI 研究通常包含低分辨率的 EPI 功能像和高分辨率的 T1 结构像。它们的坐标和头部位置可能不同，需要建立准确的空间对应关系。

常规任务态研究中，典型对象是 **Realignment 后的平均 EPI 与 T1-weighted MRI**。平均 EPI 是一段功能时间序列的代表图像，T1 提供更清楚的解剖结构。

| 特征 | 功能像 EPI | 结构像 T1 |
|---|---|---|
| 主要用途 | 测量 BOLD 活动 | 显示脑解剖结构 |
| 空间分辨率 | 相对较低，例如 3 mm | 相对较高，例如 1 mm |
| 时间维度 | 通常有数百个 volumes | 通常是一幅三维图像 |
| 图像对比度 | 常规 BOLD 主要为 T2* 加权 | T1 加权 |
| 磁敏感畸变 | 通常较明显 | 通常较小 |
| 常见处理 | Realignment、GLM | Segmentation、Normalization |

Coregistration 的目标是估计两张图像之间的空间变换，使相同解剖结构位于相同的物理位置。EPI 与 T1 的对比度不同，所以一般使用互信息类方法，而不是要求同一位置的强度数值相等。

理解 SPM Coregistration 时，要分清三个层面：

1. **操作方式：**Estimate、Reslice、Estimate & Reslice，决定是否估计变换、是否真正重采样图像。
2. **目标函数：**MI、NMI、ECC、NCC，决定程序如何评价两张图像的对应程度。
3. **参数：**Reference、Source、Other、采样间隔、容差、直方图平滑，以及重采样时的插值、环绕和 Masking。

标准 SPM Coregistration 使用六自由度刚体模型，即三个平移、三个旋转，不在这里估计局部非线性形变。

### 1. Coregistration 与 Realignment 的区别

两者都使用刚体配准，但处理对象不同。

Realignment 通常在同一模态内部沿时间轴进行。例如把 240 个 EPI volumes 对齐，使每个位置尽可能对应同一组织。Coregistration 则通常建立不同模态之间的对应，如 EPI 与 T1。

由于两种序列的组织对比度不同，跨模态配准不能简单照搬逐体素强度差平方，这也是互信息类目标函数的用途。

### 2. Coregistration 与 Normalization 的区别

```text
Coregistration：同一个人，EPI 与 T1 对齐
Normalization：个体大脑映射到 MNI 等标准空间
```

Coregistration 通常只有六个刚体自由度；标准化可能包含缩放、剪切和非线性形变。把 EPI 配准到 T1，不等于已把它放进 MNI 空间。

**接口设置：**当前程序分别调用 `.coreg.estimate` 与 `.normalise.write`，不是把配准和标准化合成一个操作。这两类作业由 `matlab/+psy/spatial_steps.m` 按所选标准化路线组织。

## 二、SPM 中常见的三种 Coregistration 操作

原生菜单通常在 `SPM → Spatial → Coregister`。

| 原生 SPM 操作 | 估计配准参数 | 更新图像空间信息 | 实际重采样 | 当前工具包 |
|---|---|---|---|---|
| Coregister: Estimate | 是 | 是，更新 Source/Other | 否 | **固定使用这一项** |
| Coregister: Reslice | 否，使用已有空间关系 | 主要按已有关系写出新图 | 是 | **未开放，配置里无法选择** |
| Coregister: Estimate & Reslice | 是 | 是 | 是 | **未开放，配置里无法选择** |

它们与 Realignment 的 Estimate/Reslice 类似，但输入图像和目标函数不同。

### 1. Coregister: Estimate

Estimate 只估计 Source 相对于 Reference 的空间变换，并更新 Source 和 Other 的空间定位信息，不重新计算整幅图像的体素强度。

例如：

```text
Reference：meanEPI.nii
Source：T1.nii
操作：Coregister: Estimate
```

SPM 寻找使 T1 与 Mean EPI 对齐的刚体变换。完成后，T1 的 voxel-to-world 空间矩阵改变，体素强度数组不因这一步重新插值，原有高分辨率网格也保留。

这对后续分割有意义：不必先把高分辨率 T1 插值到低分辨率 EPI 网格。SPM 基础教程使用这一方向，然后对配准后的 T1 分割。[SPM 基础教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri_preprocessing/coregistration/)

**接口设置：当前也是 Estimate，但方向采用 EPI→T1。**

`spatial_steps.m` 的实际关系是：

```text
Reference：原生 T1 工作副本
Source：当前 run 的平均 EPI
Other：该 run 全部工作 EPI 帧
操作：Coregister: Estimate
```

所以更新的是均值及整段 EPI 的空间信息，T1 固定。四项 `cfg.coreg.*` 只调节估计参数，不选择操作。当前没有 `cfg.coreg.method` 这样的切换字段；不能自行添加一个字符串就认为程序会读它。

### 2. Coregister: Reslice

Reslice 在已有正确空间关系的基础上，重新计算体素数值，将图像采样到 Reference 定义的网格。例如：

```text
Image Defining Space：T1.nii
Images to Reslice：meanEPI.nii
```

要区分：

- **物理空间对齐：**两张图像的空间矩阵将对应组织放在相同位置。
- **体素网格一致：**它们的维度、体素间隔和采样位置也相同。

Estimate 可以建立前一种关系，Reslice 用来获得后一种结果。

例如 EPI 是 `64×64×36、3 mm`，T1 是 `256×256×176、1 mm`。它们物理空间对齐时不必具有相同体素数；将 EPI Reslice 到 T1 网格后，输出可具有 T1 的采样网格。但这不意味着原本 3 mm 的 EPI 获得了真实 1 mm 分辨率，插值没有创造新的脑影像观测。

**接口设置：本节介绍 SPM 原生能力，当前接口没有 Reslice-only。**没有对应配置行，也不在当前 Coreg 阶段生成这种输出。后续 Normalise 写出属于另一个步骤，不能当作已开放 Coreg Reslice。

### 3. Coregister: Estimate & Reslice

这是先估计刚体变换、再重采样的组合。例如：

```text
Reference：T1.nii
Source：meanEPI.nii
Other：EPI 时间序列
```

程序根据均值与 T1 估计变换，将同一变换用于 Other，并按 Reference 的网格写出。适合需要立即得到同网格图像的情况，但会增加一次实际插值；若后面还需标准化和其它重采样，应考虑重复插值的代价。

一般而言，常规 task-fMRI，尤其还要分割、标准化时，先理解 Estimate-only，不默认在配准时立即 Reslice。

**接口设置：当前没有 Estimate & Reslice 的选择。**`spatial_steps.m` 使用的是 `.coreg.estimate`，没有 `.coreg.estwrite` 或 Coreg 的 `roptions`。下文介绍其原生参数，当前接口没有相应选择。

## 三、Reference、Source 和 Other：先弄清谁固定、谁移动

这些名称不是固定等同于“功能像、结构像、其它图像”，而是由所选方向决定。

### 1. Reference Image：固定图像

Reference 也称 Fixed Image 或 Target Image，配准时保持固定，Source 向它对齐。

若以 Mean EPI 作为 Reference，仅选择它，不意味着所有输出都会变成 EPI 体素大小；是否改变采样网格还取决于是否 Reslice。

**接口设置：**当前 Reference 固定为 TSV `t1` 对应的原生 T1 工作副本，由 `spatial_steps.m` 自动填入。可以为不同 run 关联正确 T1 路径，但没有“Reference 类型”的配置选择。

### 2. Source Image：需要移动的图像

Source 也称 Moving Image。在 T1→EPI 方向中，T1 是 Source。通俗的刚体关系可写为：

$$
\mathbf x_{\mathrm{reference}}=R\mathbf x_{\mathrm{source}}+\mathbf t
$$

`R` 为三维旋转矩阵，`t` 为平移向量。这是对物理空间关系的说明，实际 SPM 的矩阵保存与应用遵循其坐标约定；不用手动按公式改头信息。

标准 Coreg 不在这里估计局部非线性组织形变。

**接口设置：**当前 Source 是头动/所选 SDC 流程得到的平均 EPI，在 `spatial_steps.m` 传入。不是通过 `cfg.coreg.*` 手动写均值路径，也不能在当前接口改选 SBRef 或外部代表图。

### 3. Other Images：与 Source 一起移动的图像

Other 是已经与 Source 有正确空间关系、必须一起接受同一变换的图像。

例如 Reference=T1、Source=Mean EPI、Other=240 帧 EPI，意味着均值移动时，整个时间序列也同步移动。否则可能只对齐均值，真正用于 GLM 的 EPI 仍处在旧空间。

如果采用 Reference=Mean EPI、Source=T1，而不需要额外图像随 T1 移动，可以 Other=None。此时移动 T1，均值和 EPI 保持不动。

**判断移动对象时，始终按“Reference 固定，Source 与 Other 同步移动”理解。**

**接口设置：**当前自动把全部工作 EPI 帧加入 Other，同一 run 的均值和序列会同步更新。没有自定义额外 Other 清单或任意关闭传播的普通用户开关。它更新的是私有工作文件，原始输入不因此被改动。

### 4. T1→EPI 与 EPI→T1，两种策略

#### 方案 A：T1→Mean EPI

这是 SPM 基础教程采用的一种方向：Reference=Mean EPI、Source=T1，使用 Estimate。先更新 T1 的空间信息，再对该 T1 分割，得到组织图和个体到 MNI 的形变场；因为 T1 与 EPI 已有共同物理空间关系，可将形变用于功能像。

优点是流程简洁，不必在 Coreg 阶段重采样全部 EPI。

#### 方案 B：Mean EPI→T1

它以高分辨率结构像为固定解剖参考。必须同步处理整段 EPI，不能只更新 Mean EPI。

两种方向没有绝对优劣，重要的是相关图像和后续变换一致，以及真实解剖对齐质量。SPM 也有以 T1 为 Reference 的多模态示例。[SPM 多模态 fMRI 示例](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/multi/fmri/)

**接口设置：当前固定方案 B，且先 Segment 再 Coreg。**

```text
原生 T1 分割，获得原生组织图和 MNI 前向形变
    ↓
平均 EPI 及整段工作 EPI → T1：Coregister Estimate
    ↓
用 T1 的前向形变标准化 EPI，再按选择进行最终平滑
```

T1 未因 Coreg 移动，所以先计算的 T1 形变仍与其空间一致。当前接口使用方案B；切换到方案A需要相应调整分割时机和变换关系，不能只交换两个输入。

## 四、配准目标函数：MI、NMI、ECC 和 NCC

配准不是让使用者手动指定移动几毫米，而是优化器寻找使两图统计对应较好的空间参数。目标函数就是它评价“对齐得怎么样”的依据。

| 方法 | SPM 字符串 | 主要特点 | 常见适用情况 |
|---|---|---|---|
| Mutual Information | `'mi'` | 衡量强度的统计依赖 | 跨模态 |
| Normalized Mutual Information | `'nmi'` | 对熵归一化，减弱部分重叠范围变化影响 | SPM 默认、常规 EPI–T1 起点 |
| Entropy Correlation Coefficient | `'ecc'` | 基于归一化共享信息 | 跨模态备选 |
| Normalized Cross-Correlation | `'ncc'` | 衡量线性强度相关 | 同模态或对比度相近图像 |

**接口设置：：

```matlab
cfg.coreg.costFunction = 'nmi'; % 配置第266行
```

四种字符串都可选，传给 SPM `eoptions.cost_fun`。一般 EPI–T1 先保留 `'nmi'`；下面的公式由 SPM 实现，工具包只是传递选择。

### 1. MI：互信息

为什么不能直接要求两图强度相等？例如：T1 白质为 150、灰质为 100；EPI 白质为 70、灰质为 95。即使空间完全对齐，对应组织强度也不同，灰白质相对亮暗甚至相反。

互信息不要求对应体素一样亮，而是利用两图强度之间较稳定的统计关系。

把 T1 与 EPI 强度看成随机变量 `A=I_T1`、`B=I_EPI`：

$$
MI(A,B)=H(A)+H(B)-H(A,B)
$$

其中：

$$
H(A)=-\sum_a p(a)\log_2p(a)
$$

$$
H(B)=-\sum_b p(b)\log_2p(b)
$$

$$
H(A,B)=-\sum_{a,b}p(a,b)\log_2p(a,b)
$$

`H(A)`、`H(B)` 为各图强度分布的熵，`H(A,B)` 是联合熵。熵可通俗理解为分布的不确定程度。互信息也可以写成：

$$
MI(A,B)=\sum_{a,b}p(a,b)\log_2\frac{p(a,b)}{p(a)p(b)}
$$

完全独立时 `MI(A,B)=0`；共享信息越多，MI 通常越大。配准寻找使这种对应关系更强的空间变换。

#### Joint Histogram：联合直方图

两条轴分别是两图的强度值，每个格子的计数表示多少空间对应的体素出现了这个强度组合。

对齐较好时，对应组织的强度关系通常更稳定，联合分布更有结构；错误配对不同组织时，这种关系可能减弱。但高 MI 不等于所有脑区都准确对齐。

**接口设置：**选择 `'mi'` 即调用 SPM 的互信息实现。SPM 优化器最小化其相反数，与“最大化 MI”的理论描述一致，不需要改公式或手动取负数。

### 2. NMI：归一化互信息

普通 MI 会受到重叠范围和参与统计的分布影响。例如某个变换改变两图重叠区域，MI 也可能变化，而不完全反映解剖对应改善。NMI 通过归一化减弱部分这类影响。

SPM 使用的形式为：

$$
NMI(A,B)=\frac{H(A)+H(B)}{H(A,B)}
$$

它比较两图边缘熵之和与联合熵。SPM 寻找使它更大的空间变换。

不同文献也可能采用另一种归一化互信息，例如：

$$
\frac{MI(A,B)}{\sqrt{H(A)H(B)}}
$$

它们都涉及归一化，但不是同一个公式。本工具包调用 SPM 时，应以上面的熵比形式为准。

NMI 不依赖强度相等或简单正线性相关，适合对比度不同的 EPI–T1。但严重 EPI 畸变、信号丢失、覆盖不足或初始方向错误仍可能导致失败，NMI 并非保证成功的条件。

**接口设置：**当前的 `'nmi'` 已对应这一实现。若解剖对齐良好，无须仅为尝试而换一遍所有目标函数。

### 3. ECC：熵相关系数

ECC 也是信息论指标，SPM 的形式为：

$$
ECC(A,B)=\frac{2MI(A,B)}{H(A)+H(B)}
$$

它衡量共享信息相对于总信息的比例。统计依赖强时通常较高，与 NMI 思路相近但归一化方式不同。

对一般 EPI–T1，可作为备选。不能因为名字中有 Correlation 就判断它一定更适合；若 NMI 结果已经好，通常没有必要继续改。

**接口设置：改为 `'ecc'`，不是填写完整英文名称。

### 4. NCC：归一化互相关

NCC 的常见形式是：

$$
NCC(A,B)=\frac{\sum_i(A_i-\bar A)(B_i-\bar B)}{\sqrt{\sum_i(A_i-\bar A)^2\sum_i(B_i-\bar B)^2}}
$$

它反映对应体素强度的线性关系。若 `B_i=aA_i+b` 且 `a>0`，理想情况下可有较高正相关。

相同或相近对比度之间可能适用；T1 与 EPI 的组织对比度差异较大，不一定有稳定正线性关系。因此一般更适合 T1↔T1、相近 EPI↔EPI，而不是作为常规 T1↔EPI 的第一选择。

**接口设置：可选 `'ncc'`，当前未选择它。当前输入角色仍固定为 EPI–T1，改变目标函数不会自动改变为同模态工作流。

## 五、Estimation Options：配准估计参数

这部分对应 SPM Batch 的 `Coregister → Estimation Options`。它与 Realignment 的估计参数不同，不在这里设置 Realign 的 Quality、Num Passes。

| SPM 参数 | 经典默认 | 当前配置字段 | 作用 |
|---|---|---|---|
| Objective Function | `'nmi'` | `cfg.coreg.costFunction`（配置第266行） | 选择目标函数 |
| Separation | `[4 2] mm` | `cfg.coreg.separationMm`（配置第268行） | 粗到细的空间采样间隔 |
| Tolerances | 完整 12 个值 | `cfg.coreg.tolerance`（配置第272行） | 优化参数容差 |
| Histogram Smoothing | `[7 7]`，bin 尺度 | 历史字段 `cfg.coreg.smoothingFwhmMm`（配置第270行） | 平滑联合强度直方图 |

**这四项都已接入当前固定 Estimate 流程。**

### 1. Separation：空间采样间隔

经典默认 `sep=[4 2]`，单位 mm，表示先用 4 mm、再用 2 mm 的优化采样间隔。

它不是 x/y 两方向的间隔，也不是先生成 4 mm 输出再生成 2 mm 输出。第一阶段采样较稀疏，找到整体合理的位置；第二阶段采样较密，在已有结果上进一步优化六个刚体参数。这叫作从粗到细（coarse-to-fine）的优化。

若一开始很密，计算更多，也未必避免局部最优。若改成 `[2 1]`，理论上利用更多空间采样，但成本增加，仍可能受噪声影响。EPI 原分辨率只有 3 mm 时，1 mm 采样没有创造真实 1 mm 功能信息。

明显配准失败时，先检查初始朝向、覆盖和畸变，不要先把间隔减成 `[1 0.5]`。

**接口设置：：

```matlab
cfg.coreg.separationMm = [4 2]; % 配置第268行
```

传给 `eoptions.sep`，可填正数标量或正数向量，例如 `4`、`[4 2]`、`[2 1]`。每个元素是一个优化尺度；一般保留 `[4 2]`，不是只能选两个预设组合，也不是填三项 x/y/z 分辨率。

### 2. Tolerances：收敛容差

完整默认向量是：

```matlab
tol = [0.02 0.02 0.02 ...
       0.001 0.001 0.001 ...
       0.01 0.01 0.01 ...
       0.001 0.001 0.001];
```

既然是六自由度，为什么有 12 项？因为 SPM 配置保留较通用的参数形式，标准 Coreg 实际优化六个刚体参数；本机 `spm_coreg.m` 按参数数目截取前六个容差。

| 前六项 | 默认容差 | 数值尺度 |
|---|---|---|
| x 平移 | 0.02 | mm |
| y 平移 | 0.02 | mm |
| z 平移 | 0.02 | mm |
| x 旋转 | 0.001 | rad |
| y 旋转 | 0.001 | rad |
| z 旋转 | 0.001 | rad |

SPM 使用 Powell 优化方法，容差控制参数优化的精度要求。可以用以下概念式理解：

$$
|\Delta p_i|<\varepsilon_i
$$

来表达“变化小到一定程度后认为收敛”。`ε_i` 是相应容差，实际停止判据由优化器实现。较大可能较早停止，较小可能需要更多搜索。

`0.02 mm` 不代表最终解剖误差小于 0.02 mm。即使改为 `0.0001`，也不能保证边界达到相应真实精度，因为分辨率、信噪比、畸变和目标函数仍有限制。一般不随意改默认。

**接口设置：：

```matlab
cfg.coreg.tolerance = [0.02 0.02 0.02 0.001 0.001 0.001 ... % 配置第272行
                      0.01 0.01 0.01 0.001 0.001 0.001];
```

当前接口要求完整 12 个有限正数，传给 `eoptions.tol`。保留后六项不意味着正在做缩放、剪切或 12 自由度仿射配准。配置中“刚体/仿射优化容差”的注释应按这个实际使用范围理解。

### 3. Histogram Smoothing：联合直方图平滑

经典默认 `fwhm=[7 7]`。它**不是对 T1 或 EPI 做 7 mm 空间平滑**，而是平滑配准目标函数所用的联合强度直方图。

经典实现的直方图为 `256×256`，一维是 Reference 强度，一维是 Source 强度。噪声、采样位置和插值使直方图计数可能变化不平稳，空间参数微变时，MI/NMI 目标函数可能突然变化。

Gaussian kernel 平滑直方图，让目标函数更连续，帮助优化器稳定搜索。两个数分别对应两个强度轴，按 histogram bin 尺度理解。

| FWHM 项目 | 作用对象 | 单位 |
|---|---|---|
| Realignment Smoothing | 运动估计用图像 | mm |
| Coregistration Histogram Smoothing | 联合强度直方图 | histogram bins |
| 最终 Spatial Smoothing | 后续分析功能像 | mm |

如果用 `[3 3]`，平滑较弱，保留较多局部分布结构，但目标函数可能不稳定；用 `[12 12]`，平滑更强，但也可能损失区别不同配准位置的信息。一般先保留 `[7 7]`。

**接口设置：的名字容易误导，但该功能已实现。**

```matlab
cfg.coreg.smoothingFwhmMm = [7 7]; % 配置第270行
```

它直接传给 `eoptions.fwhm`，实际就是本节的 Histogram Smoothing。历史字段中的 `Mm` 和“参考/源图配准前平滑、毫米”注释不准确；本文按实际算法解释，没有为了修名改代码。

应填写两个非负宽度值，例如 `[7 7]`、`[3 3]`、`[12 12]`。当前只检查非负，没有独立强制两值的校验，使用时不要填单个 7。SPM 内部还会为优化准备图像，但不能把那项处理与这组直方图 FWHM 混淆。

### 填写直方图平滑参数时的检查

`cfg.coreg.smoothingFwhmMm`（配置第270行） 必须按联合强度直方图的两条强度轴填写两个非负数，例如 `[7 7]`。现有通用预检未单独把长度限制为2；不要据此填写一个标量或三轴BOLD核。它不改变最终BOLD平滑，也没有让当前六自由度配准变成十二自由度仿射。

## 六、Reslice Options：实际重采样参数

**以下四项属于 SPM 原生重采样选项。当前接口固定 Estimate，Coreg 阶段不执行这些选项，也没有对应配置行。**它们只适用于 Reslice 或 Estimate & Reslice。

| 原生 SPM 参数 | 经典默认 | 作用 | 当前接口 |
|---|---|---|---|
| Interpolation | 4th Degree B-spline | 空间插值 | 未开放，Estimate 不重采样 |
| Wrapping | `[0 0 0]` | 周期性边界环绕 | 未开放 |
| Masking | No / `0` | 处理不一致的无效采样位置 | 未开放 |
| Filename Prefix | `'r'` | 重采样输出前缀 | 未开放 |

Coreg Reslice 的经典 Masking 默认为 No，Realignment Reslice 常为 Yes，不能机械地照搬。

### 1. Interpolation：空间插值算法

空间变换后，一个输出体素可能对应原图 `(30.4,41.7,22.3)` 这样的非整数位置。原图只有离散体素，需要插值估计该处强度。

| SPM 数值 | 方法 | 特点 |
|---|---|---|
| `0` | Nearest Neighbour | 最近邻，保留离散标签值 |
| `1` | Trilinear | 三线性，较快 |
| `2` | 2nd Degree B-spline | 二阶 B 样条 |
| `3` | 3rd Degree B-spline | 三阶 B 样条 |
| `4` | 4th Degree B-spline | 常规连续 MRI 的选择 |
| `5` | 5th Degree B-spline | 五阶，使用更多邻域 |
| `6` | 6th Degree B-spline | 六阶 |
| `7` | 7th Degree B-spline | 七阶，计算成本更高 |

#### Nearest Neighbour

选最近的原体素值。标签 17、18 重采样后仍为 17 或 18，不会变成 17.4，因此适合 Brainnetome Atlas 246 等整数脑区图谱。连续 BOLD/T1 则可能出现较明显阶梯边界，通常不是首选。

#### Trilinear

按位置对邻近八个体素加权平均，速度较快，但可能带来一定模糊。

#### B-spline

用局部基函数描述连续信号。高阶通常能更平滑地插值，但并非越高越好。连续T1/EPI常用4阶，离散标签用0阶保留编号。

**接口设置：上述 0–7 是原生 Coreg Reslice 的选择，当前没有对应 `cfg.coreg.*` 写出插值字段。**`cfg.realign.writeInterpolation`（配置第153行） 只控制头动相关写出，`cfg.normalise.interpolation`（配置第340行） 控制标准化写出，不会使当前 Coreg 自动 Reslice。

### 2. Wrapping：图像边界环绕

经典 `wrap=[0 0 0]` 为 x/y/z 都不环绕。`[0 1 0]` 为图像 y 方向环绕，可用于某些未重采样、具有特定采集边界特征的数据。

原生 SPM 可选以下八种单/多轴组合：`[0 0 0]`、`[1 0 0]`、`[0 1 0]`、`[0 0 1]`、`[1 1 0]`、`[1 0 1]`、`[0 1 1]`、`[1 1 1]`。这里是图像轴，不必固定对应解剖方向。

一般无明确依据时保持全关。Wrapping 不是磁敏感畸变校正，不能靠它恢复 EPI 几何形状。

**接口设置：当前 Coreg 没有 Wrapping 入口。**即使配置里有 `cfg.realign.wrap`（配置第155行），也不会把它用到不存在的 Coreg 重采样步骤。

### 3. Masking：无效采样位置

原生 Coreg Reslice 默认 `mask=0`，不统一 mask。若 `mask=1`，SPM 根据一组图像是否存在超出视野的采样，在相应输出位置统一处理零值/缺失值，可能使用 NaN。

例如某个位置在部分帧可采样、另一些帧落在视野外，统一处理可以减少覆盖不一致。若只处理一张 T1 和一张均值，不一定需要照搬全时序 Realign 的选择；若重采样很多 EPI 帧，应结合有效覆盖和后续统计判断。

这不是解剖脑提取，也不会自动识别颈部或脑外组织。

**接口设置：当前 Coreg 没有 Masking 参数，也没有执行这项重采样。**`cfg.realign.mask`（配置第157行） 不代替它；原生 Coreg 默认 0 与 Realign 默认 1 的差别在此保留说明。

### 4. Filename Prefix：输出前缀

原生默认 `prefix='r'`。只有真正 Reslice 才产生相应新图像；Estimate 通常不会生成 `rT1.nii`。

Coreg 和 Realignment 都可能用 r，因此文件名 r 开头不能说明是哪一步，需结合 batch 和记录。

**接口设置：当前没有 Coreg Prefix 设置，因为固定 Estimate。**程序保存 `04_coregister.mat`，更新工作均值/序列的空间信息，没有因为这一步另写带 r 前缀的配准重采样图。已有 r 图可能来自前面的 Realignment，后面 w/sw 图来自标准化/平滑。

## 七、SPM Coregistration 的推荐参数汇总

方案A的常见设置如下：

| 参数 | 选择建议 |
|---|---|
| Module | Coregister: Estimate |
| Reference Image | Realignment 后的 Mean EPI |
| Source Image | T1-weighted anatomical image |
| Other Images | 通常 None；或需要随 T1 移动的图像 |
| Objective Function | Normalized Mutual Information，`'nmi'` |
| Separation | `[4 2] mm` |
| Tolerances | 保留 SPM 完整 12 个默认值 |
| Histogram Smoothing | `[7 7]` |
| Reslice | 配准阶段通常不执行 |
| 后续 | T1 Segmentation → Normalization |
| QC | 检查脑轮廓、侧脑室、皮层和关键 ROI 对应 |

最容易混淆的三点仍是：Reference/Source 决定谁移动；Estimate 不等于 Reslice；直方图 `[7 7]` 不等于影像 7 mm 平滑。

### 当前工具包怎样对应这份汇总？

| 项目 | 当前实际行为 |
|---|---|
| 操作 | **固定 Estimate，不能选择另两种操作** |
| 方向 | 固定 Reference=T1、Source=Mean EPI |
| Other | 自动加入同 run 全部工作 EPI 帧 |
| 目标函数/采样/容差/直方图平滑 | 四项均有集中配置，默认与上表相应数值一致 |
| 阶段顺序 | T1 Segment → Coreg Estimate → Normalise → Smooth |
| Coreg 重采样参数 | 无，当前阶段不执行 Reslice |
| 完整解剖/ROI QC | 仍需检查，不能以程序成功代替 |

不能只交换 Reference 和 Source 就采用方案 A，还涉及分割时机及组织/形变空间一致性。当前接口没有这一流程切换。

## 八、实际批量运行与检查记录

### 1. 这一阶段需要填写什么？

每个 run 在 TSV 中关联正确 BOLD/T1，均值和全部工作 EPI 由前面步骤产生，Coreg 自动接收。没有必要在配置里逐帧填 240 个文件名。

只需要按研究需要查看四行：

| 行号 | 配置 | 可选与约束 |
|---|---|---|
| 218 | `cfg.coreg.costFunction`（配置第266行） | `'mi'/'nmi'/'ecc'/'ncc'` |
| 220 | `cfg.coreg.separationMm`（配置第268行） | 正毫米标量/向量，通常 `[4 2]` |
| 222 | `cfg.coreg.smoothingFwhmMm`（配置第270行） | 两个非负直方图宽度，通常 `[7 7]`，单位不是 mm |
| 224 | `cfg.coreg.tolerance`（配置第272行） | 完整 12 个有限正数，通常保持默认 |

D 盘实际配置：[toolkit_config.m](D:/CogNeuro_fMRI_Toolkit/config/toolkit_config.m)。参数位置在本章对应参数旁说明。

### 2. 哪个运行选择会执行 Coreg？

`cfg.execute=false` 只预检；正式执行时，当前普通完整空间流程需要 `cfg.execute=true`、`cfg.stopAfter='smooth'` 才会继续到 Coreg。

`stopAfter='realign'` 在头动阶段结束，`'segment'` 在 T1 分割后、Coreg 前结束。没有单独的 `'coreg'` 停止值。SDC 的 VDM-only 路线也不进入这些后续步骤，已经预处理输入的入口只核查。

修改已执行的参数后用新输出目录，成功结果不覆盖。纯代码发布目录用于存代码/文档，数据处理输出放在其外。

### 3. 记录与原始数据保护

程序在处理 run 的私有目录复制 T1、处理功能像，Estimate 修改工作图像的空间信息；原始文件保持不变。

`04_coregister.mat` 保存传给 SPM 的 `matlabbatch`，可以查 Reference、Source、Other 和四项 eoptions。它是作业记录，不是已经单独导出的数值结果矩阵；当前没有额外保存返回的 `out.M` 或最终目标函数值。

“没有 rT1”不等于失败；“有 04_coregister.mat”也不单独证明成功，因为作业在执行前保存。完成状态、输出及解剖检查要一起看。

### 4. 怎样检查配准质量？

将均值 EPI 与 T1 在正确物理空间下叠加，检查脑轮廓、脑室、皮层和研究关键 ROI。重点看整体偏移/旋转与局部畸变；刚体 Coreg 无法凭自身修复严重 EPI 局部畸变或信号脱落。

当前时序 QC 不是 EPI–T1 解剖 QC。旧 `psy.verify_spatial` 有部分组织轮廓叠加，但没有在通用入口自动接入完整的 Coreg 审查，也不能当作任意新目录布局下的通用检查。

既往真实空间链已使用当前固定模式；这不意味着 Reslice、Estimate & Reslice 或反向模式已经验证。本次未扩展功能，也未重跑影像，既往验证范围见 [VALIDATION.md](VALIDATION.md)。参数逐项差异见 [COREGISTRATION_PARAMETER_COMPARISON.md](Coregistration.md)。
