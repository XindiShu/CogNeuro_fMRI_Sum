# 12. Segmentation：结构像分割与偏置场校正

本章说明组织概率、偏置场与空间形变的联合估计，以及 SPM Segment、CAT12、多通道结构像和逆向图谱的设置。先确定后端和输入，再选择估计参数与需要保存的结果。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

## 一、Segmentation 在做什么？为什么重要？

Segmentation 最直接的任务是把高分辨率 T1 结构像中的组织分开。常用的三类是：

- Gray Matter（GM）：灰质。
- White Matter（WM）：白质。
- Cerebrospinal Fluid（CSF）：脑脊液。

但在 SPM12 中，它不只是给每个体素贴一个组织标签。默认的 **Unified Segmentation（统一分割）**把三项工作放进同一套概率模型中：

```text
组织分类 + 强度不均匀校正 + 个体结构像与模板的空间关系估计
Tissue Classification + Bias Field Correction + Spatial Registration
```

为什么要一起做？组织分类要知道模板中哪些位置常见灰质、白质或脑脊液；使用模板先验，又需要把模板与这个人的脑对齐。与此同时，线圈和射频场引起的亮度不均匀，也可能干扰组织分类。这几件事彼此影响，放在一起反复估计，可以互相提供约束。

因此，Segmentation 不仅提供 GM/WM/CSF 概率图，也估计后续标准化要用的 **deformation field（形变场）**。结构像和功能像已经正确配准时，就可以用结构像的形变信息把 EPI 写到标准空间。[SPM 官方分割教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/block/preprocessing/segmentation/)

对于常规 task-fMRI，这一步通常处理高分辨率 T1，**不是把 240 个 BOLD volumes 逐帧进行组织分割**。组织图可以供分割检查、组织掩膜及后续混杂提取使用；BOLD 标准化主要依赖形变场，而不是把组织概率图当成功能信号。

### 1. MRI 强度为什么不能直接当组织标签？

常规 T1-weighted MRI 中，常见的对比关系是：

| 组织               | T1 图像中的典型表现 | 主要解剖结构       |
| ---------------- | ----------- | ------------ |
| Gray Matter（GM）  | 中等亮度        | 大脑皮层、基底节、丘脑等 |
| White Matter（WM） | 相对较亮        | 皮层下白质纤维束等    |
| CSF              | 相对较暗        | 脑室、脑沟中的脑脊液   |

这是常见对比，不是所有序列都必须符合的固定数值规则。MRI 强度通常没有跨扫描统一的绝对物理单位，也会受到序列、线圈和扫描参数影响。

所以算法不能只用“亮＝白质、暗＝脑脊液”这条规则。它还要考虑强度分布、空间位置及组织先验，判断这个体素更可能属于哪一类组织。

### 2. Segmentation 输出概率，不只是标签

这与整数编号的 ROI 图谱不同。假设一个体素位于灰质和白质的交界处，模型可能得到：

```text
P(GM)    = 0.65
P(WM)    = 0.30
P(CSF)   = 0.04
P(Other) = 0.01
```

这些数值是在当前模型、图像和先验条件下的**后验概率**。`c1T1.nii` 等 Native 组织图是连续概率图，不是只含 0 和 1 的二值图。

例如，一个位置的 GM 值是 0.98，另一个位置是 0.72，表示两者被判为灰质的概率不同。它们不是“98 号脑区、72 号脑区”；后验概率也不应直接当作不带模型误差的真实组织比例。

如果后续需要二值 GM mask，可以另设阈值。例如：

```text
GM_mask(r) = 1，当 P(GM | 当前数据) > 0.5
GM_mask(r) = 0，其余情况
```

这里的 0.5 只是说明阈值化的例子，不能当作所有应用的统一推荐。某些分析需要较纯的组织，某些分析保留连续概率更合适；VBM 通常使用连续组织图或调制组织图，不应机械地先全部变成 0/1。

**代码对应：**当前 Segment 不自动阈值化，也没有 `cfg.segment.threshold`。`cfg.segment.nativeOutputs`（配置第224行）（）决定保存哪些 Native 图，不决定二值化阈值。后续独立混杂模块的 WM/CSF 阈值和腐蚀在 `confounds_config.m`，不会因为运行本次分割入口就自动执行。

## 二、SPM12 中常见的分割方法与当前后端选择

先分清名称：SPM8 的 **New Segment** 经改进成为 SPM12 默认的 **Segment**；SPM12 的 **Old Segment** 是保留下来的旧实现。

| 方法            | 所属体系                      | 主要特点                        |
| ------------- | ------------------------- | --------------------------- |
| Old Segment   | SPM 的旧实现，在 SPM12 的旧版工具中保留 | 早期 Unified Segmentation 实现  |
| SPM12 Segment | SPM12 常规默认方法              | 扩展的统一分割、多组织类别、多对比度及形变模型     |
| CAT12         | 在 SPM 环境中运行的独立工具箱         | 面向结构形态学、皮层厚度、VBM 和结构质量检查等任务 |

### 1. Old Segment

早期方法已经把图像强度、组织先验、偏置校正和空间配准结合起来。核心思路可以写成：

```text
图像强度 + 组织先验 → 当前被试的组织后验概率
同时估计与标准模板的空间关系
```

它比更早的“先配准、再单独分割”流程更完整，但在组织类别、跨模态支持和形变模型方面有局限。普通 SPM12 task-fMRI 通常不需要退回 Old Segment；复现旧研究的特定 pipeline 时，才需要专门考虑。

**代码对应：**当前工具包没有 Old Segment 入口。不能填写 `cfg.segment.backend='old'` 并认为它已经接入。

### 2. SPM12 Segment：Unified Segmentation

它的理论基础是 Ashburner 和 Friston（2005）的 Unified Segmentation。传统流程可能分别做：

```text
Registration → Segmentation → Bias Correction
```

问题是：分割需要模板先验的位置，模板先验的位置又需要配准；强度不均匀还会使两者都受到影响。

SPM 因此反复联合估计：每个体素的组织类别、各组织的强度分布、图像的偏置场，以及个体脑与标准先验之间的空间变换。下文第三区别说明这些组成部分。

### 3. CAT12 与普通 fMRI 分割的关系

CAT12（Computational Anatomy Toolbox）基于 SPM 环境，但不是把 Segment 的一个参数改一下就得到的同一算法。它更关注灰质体积、皮层厚度、表面形态学及更细的结构质量检查。

如果只是为常规 fMRI 获得 GM/WM/CSF 及标准化形变场，SPM12 Segment 通常已经是可用的起点。研究问题是脑形态差异时，才有理由进一步考虑 CAT 的专门流程。**CAT 不是所有 fMRI 数据都必须使用的“升级版分割”。**

**代码对应：控制方法选择，不需要删减计算函数。**

```matlab
cfg.segment.backend = 'spm';   % SPM12 默认 Segment，当前默认 % 配置第191行
% 或改成：
cfg.segment.backend = 'cat12'; % 固定的 CAT12.9 原生分割流程 % 配置第191行
```

同一批次使用同一个后端。切换后端应选新的输出目录，不把两种方法的组织图和形变场混在一套研究结果里。

### 4. CAT 的流程和独立参数

当前 CAT 分支以单幅 T1 为输入，先做 SPM 初始化，再进行 CAT 自身的组织处理、局部强度处理和 Shooting 配准。其后给 BOLD 使用的是 **CAT 的前向场**，不是再默默运行一次 SPM Segment。

当前接口只接入 CAT 的结构体积流程，**不运行表面重建、皮层厚度流程、纵向模型或自动 ROI 统计**。CAT 工具箱原生有这些能力，不等于本接口已经开放。

CAT 标准化采用安装版本的 MNI152NLin2009cAsym 模板，而 SPM Segment 使用其 TPM 空间。两者都带 MNI 名称，仍不代表模板完全相同。之后做图谱转换时必须匹配空间，见第七章。

本机 CAT 安装在 `D:\matlab\atoolbox\spm12\toolbox\cat12`，实际版本 CAT12.9、revision 2577。指定这个路径；切换到未经验证的新版本会触发兼容检查。

| 配置位置                                          | 可选值                                          | 当前作用与建议                                                         |
| --------------------------------------------- | -------------------------------------------- | --------------------------------------------------------------- |
| `cfg.segment.cat12.path`（配置第233行）              | CAT12.9 目录路径                                 | 目录须包含 `cat12.m`；默认取 SPM 的 toolbox/cat12。换电脑后核对路径。               |
| `cfg.segment.cat12.accuracy`（配置第235行）          | `'default'`、`'high'`                         | 对应 CAT 的 accstr 0.5、1；默认是起点，high 计算可能很慢，不保证每份数据都得到更好的科研结果。      |
| `cfg.segment.cat12.nativeTissues`（配置第237行）     | GM/WM/CSF 各填 0 或 1                           | 0 不写、1 写原生 p1/p2/p3；默认 `[1 1 1]`。                               |
| `cfg.segment.cat12.dartelTissues`（配置第239行）     | GM/WM/CSF 各填 0 或 1                           | 1 写 CAT 的刚体 DARTEL export；默认 `[0 0 0]`。只是准备图，不建立群体模板。           |
| `cfg.segment.cat12.warpedTissues`（配置第241行）     | 三项 `'none'/'unmodulated'/'modulated'/'both'` | 决定各组织标准化图；modulated 使用 CAT 的 affine＋nonlinear 调制。默认三项 none。     |
| `cfg.segment.cat12.saveBiasCorrected`（配置第243行） | `true`、`false`                               | 是否写 CAT 校正后的 mT1；默认 true。包含 CAT 的偏置、噪声和全局强度处理，不等同于只做 SPM 的偏置校正。 |

例如，需要 CAT 原生三类组织、GM/WM 的刚体导出及 GM 两类标准化图：

```matlab
cfg.segment.backend = 'cat12'; % 配置第191行
cfg.segment.cat12.nativeTissues = [1 1 1]; % 配置第237行
cfg.segment.cat12.dartelTissues = [1 1 0]; % 配置第239行
cfg.segment.cat12.warpedTissues = {'both','none','none'}; % 配置第241行
cfg.segment.cat12.saveBiasCorrected = true; % 配置第243行
```

**两套参数不能混用。**CAT 分支共同使用 `cfg.segment.affineRegistration`（配置第207行） 和 `cfg.segment.deformationFields`（配置第217行）；不把下文 SPM 的 Gaussian、MRF、cleanup、Smoothness、warpRegularisation、warpSamplingMm 或 bias 参数作为 CAT 的控制项。CAT 偏置强度保留原生 biasstr=0.5，其余未开放的内部选项从固定版本的 defaults 读取，实际 job 会保存。

Native 图名也不同：SPM 为 c1/c2/c3，CAT 为 `anat/mri/p1/p2/p3`；CAT 的刚体 export 为 `rp*_rigid.nii`，标准化图为 `wp*/mwp*`。后续组织信号或 QC 输入要填写对应的真实路径，不能仍套用 c* 名称。

CAT 只接收单通道 T1。T1＋T2／PD 必须选 SPM；本接口会提前拒绝把多通道清单用于 CAT。当前 CAT 每 run 串行等待完成，不在后台拆成多个不易追踪的 MATLAB 作业。安装/恢复信息见 [SEGMENTATION_OPTIONS.md](Segmentation.md)；这里的 CAT 说明按本机固定 12.9 源码核对。

## 三、Unified Segmentation 的统计学原理

这一章主要解释 **SPM12 Segment**。CAT 虽然使用 SPM 初始化，但不能把本章模型和每个参数逐项当成 CAT 全流程的完整说明。

### 1. Tissue Probability Maps：空间先验

TPM 即 Tissue Probability Map，组织概率先验图。标准空间某个位置可能有：

```text
P(GM)  = 0.80
P(WM)  = 0.15
P(CSF) = 0.05
```

意思是：根据建立模板的人群，这个位置更常见灰质。它不是根据当前被试的 T1 强度直接算出来的，而是先由参考数据建立的空间先验。

SPM12 默认的 `SPM12/tpm/TPM.nii` 包含六类组织，且这些先验处在同一个模板空间。因此，它们不仅帮助分类，也帮助建立个体结构像与标准空间的对应关系。

### 2. Gaussian Mixture Model：组织的强度分布

除了空间先验，算法还利用各组织的 MRI 强度分布。较纯的白质通常较亮，CSF 通常较暗，可以先用一个高斯分布近似某一类组织的强度：

```text
p(I | k) = 1 / sqrt(2πσ_k²) × exp[ −(I − μ_k)² / (2σ_k²) ]
```

其中，I 是体素强度，k 是组织类别，μ_k 是这一类的平均强度，σ_k² 是其强度方差。严格地说，连续强度这里使用的是概率密度；直觉上，它告诉模型“这个强度在这一类组织中有多常见”。

真实的组织强度不一定只有一个简单峰。例如灰白质交界存在 **Partial Volume Effect（部分容积效应）**，一个体素可能同时包含两种组织；同类组织也可能有复杂的强度分布。因此可以用多个高斯成分表示同一类：

```text
p(I | k) = Σ[j=1…K_k] π_kj × N(I; μ_kj, σ_kj²)
```

K_k 是组织 k 使用的高斯数量，π_kj 是混合权重，N 表示高斯密度。**一类组织使用多个成分，不等于新增了多个解剖类别。**

这正对应后面的 **Num. Gaussians**。工具包的控制行是`cfg.segment.gaussians`（配置第205行），完整候选和六项对应见第六章。

### 3. Bias Field：缓慢变化的强度不均匀

同属正常白质的两个位置，真实属性相近，但接收线圈敏感度、B1 等射频场不均匀性可能让它们一亮一暗。可用下面的概念模型理解：

```text
I_observed(r) = B(r) × I_true(r) + ε(r)
```

r 是空间位置，B(r) 是缓慢变化的乘性偏差，ε(r) 是噪声。估计这种不均匀性，可以减少“把线圈造成的亮度变化误分成不同组织”的情况。

**概念公式里的 B 与输出文件的数值方向要分清。**本机 SPM 的 `spm_preproc_write8.m` 把 `BiasField_*.nii` 保存为校正乘数 F，并用 `I_corrected = F × I_input` 写 mT1。它不是让使用者再把 T1 除以这个文件。上式的 B 用来解释造成观测偏差的过程；不能只看到“Bias Field”同名，就把它与校正乘数混为同一个方向。接口已经调用 SPM 写出，普通使用不需要自己再应用一次偏置场。

### 4. Spatial Deformation：把个体脑与 TPM 对应起来

TPM 在模板空间，而每个人的大脑形状不同。模型需要空间变换 T(r; θ)，将个体的位置与模板位置对应。

它包含整体的 affine transformation（仿射变换），也包含局部非线性 deformation。这里只靠刚体平移和旋转，通常不能充分匹配不同人的脑沟、脑回和脑室。

### 5. 四种信息怎样结合？

在某个位置 r，组织 k 的后验概率可以概念化写成：

```text
P(k | I, r) ∝ p(I_corrected | k) × P_TPM(k | T(r))
```

第一项说明“校正后的强度像不像这一类组织”，第二项说明“变换到模板位置后，这一类组织的先验概率有多大”。符号 ∝ 表示成正比，还需要归一化。

这是帮助理解的简化表达。实际 SPM 模型还包括组织混合比例、偏置场先验、形变正则化等因素，不是工具包自己用这条公式替代原生分割计算。

联合估计流程可以表示为：

```text
T1 的体素强度                  TPM 的空间先验
       └──────────┬──────────┘
           Unified Segmentation
      GMM + Bias Correction + Registration
                  ↓
         组织概率图 + 空间形变场
```

组织概率帮助配准；更好的配准，又让组织先验更准确地对应当前被试。这种相互约束是统一分割的重要意义。

## 四、SPM12 的六种 Tissue Classes

默认模型不只分 GM、WM 和 CSF，还解释骨、脑外软组织和背景。六类分别对应 TPM.nii 的六个 volume：

| 序号  | 组织类别                    | 先验输入        | 选择 Native 后的典型输出 |
| --- | ----------------------- | ----------- | ---------------- |
| 1   | Gray Matter，灰质          | `TPM.nii,1` | `c1T1.nii`       |
| 2   | White Matter，白质         | `TPM.nii,2` | `c2T1.nii`       |
| 3   | Cerebrospinal Fluid，脑脊液 | `TPM.nii,3` | `c3T1.nii`       |
| 4   | Bone，骨                  | `TPM.nii,4` | `c4T1.nii`       |
| 5   | Soft Tissue，其他软组织       | `TPM.nii,5` | `c5T1.nii`       |
| 6   | Background / Air，背景     | `TPM.nii,6` | `c6T1.nii`       |

为什么连脑外组织也要解释？假如模型只允许 GM/WM/CSF，头骨和头皮也必须被硬归进这三类中的某一类，容易造成误分类。提供额外类别，就给非脑组织一个更合理的解释，有助于减少其被误认为脑组织的风险。

这六张先验不是互不相关的六个解剖模板，而是同一坐标系中不同组织类别的概率集合。

**代码对应：**当前 SPM 固定使用六类 TPM，控制算法的是六个 Gaussian 数和其他共同参数。是否保存 c1 至 c6，由`cfg.segment.nativeOutputs` 决定；不写 c4/c5/c6，不代表这三类没有参与估计。默认只保存前三类 Native。

## 五、Data / Channel 参数详解

SPM GUI 的位置是 `SPM → Spatial → Segment → Data → Channel`，一个或多个 Channel 可提供不同对比度。本工具包把相同输入安排放到 TSV 与可选 JSON 中，运行时生成 SPM job，无需逐个点 GUI。

| Channel 参数          | SPM12 常见设置 | 含义            |
| ------------------- | ---------- | ------------- |
| Volumes             | `T1.nii,1` | 需要分割的结构像      |
| Bias Regularisation | `0.001`    | 对强度不均匀估计施加的约束 |
| Bias FWHM           | `60 mm`    | 偏置场变化的空间尺度    |
| Save Bias Corrected | 按需要选择      | 是否写偏置校正图或偏置场  |

### 1. Volumes：输入哪一幅结构像？

普通 fMRI 常用该被试的高分辨率 T1，例如 `T1.nii,1`。它通常不是 Mean EPI，也不是经过平滑的功能像。

如果某个 pipeline 采用 `Reference=Mean EPI、Source=T1` 的 Coregister: Estimate，应让后续分割使用配准估计后、空间矩阵正确关联的 T1。若采用 EPI→T1，则不用为了套用另一方向的教程再移动 T1。

**代码对应：当前使用 EPI→T1。**先分割 T1，再将平均 EPI 及全部工作 EPI 对齐 T1，然后应用 T1 形变。完整流程见第九章及 [COREGISTRATION.md](Coregistration.md)。

结构像的**路径**填写在清单 `t1` 列；路径不在 `cfg.segment.inputVolume`（配置第193行） 里填写。只选择容器中的一幅图：

```matlab
cfg.segment.inputVolume = 1; % 配置第193行
```

- 普通 3D T1：填 1。
- 4D 结构容器：可填 1 至其实际帧数，例如 2 表示使用第二幅。
- 它不是“输入两个被试”，也不是“分割 BOLD 第二帧”。
- 每 run 先复制/解压，再将选中 volume 写为单幅 3D 工作图。原容器不被截断或覆盖；4D 提取后的工作名类似 `T1_vol0002.nii`。

### 2. Multi-channel Segmentation：多通道联合分割

SPM 原生支持不同结构对比度一起参与估计，例如 T1＋T2，原生也可以使用 PD＋T2。多种对比度提供互补的组织信息。

从单一强度扩展到两通道时，可以用多变量分布理解：

```text
I(r) = [I_T1(r), I_T2(r)]ᵀ
p(I | k) = N(I; μ_k, Σ_k)
```

I 是同一物理位置的强度向量，μ_k 是均值向量，Σ_k 是描述各通道变化及相互关系的协方差矩阵。多个成分时也可扩展为多变量高斯混合。

关键要求是：**这些通道必须来自同一被试，正确配准，并在相匹配的采样位置上提供强度。**网格不同应先配准和重采样；同网格也不保证扫描间没有头动。SPM 允许各通道分别设置偏置校正参数。

只有高质量 T1 时，单通道就可作为起点。不需要为了凑多通道，把低分辨率、不同成像特性的 BOLD EPI 加进来。

**代码对应：当前接口必须以 T1 为第一通道，可再加 T2 和/或 PD。**PD＋T2 属于 SPM 原生能力，当前接口没有“PD 为主、完全不提供 T1”的选择；CAT 路线也不支持这一多通道输入。

指定多通道 JSON，选择通道对齐安排：

```matlab
cfg.segment.channelsFile = '';                   % 默认只用清单 t1 % 配置第195行
cfg.segment.channelAlignment = 'require_aligned'; % 默认要求已对齐 % 配置第197行
```

| 字段与填写方式                                                   | 当前行为                                                  |
| --------------------------------------------------------- | ----------------------------------------------------- |
| `cfg.segment.channelsFile = ''`                           | 单通道，使用 TSV 的 t1 与全局分割参数                               |
| `cfg.segment.channelsFile = 'D:/Study/S01/channels.json'` | 用这个 JSON 指定结构通道；固定文件适合明确选中的数据                         |
| TSV 可选列 `anatomy_channels`                                | 每行填写相应被试/run 的 JSON；非空时覆盖全局 channelsFile              |
| `cfg.segment.channelAlignment = 'require_aligned'`        | 不自动配准；检查尺寸/仿射的一致性，并要求使用者已完成解剖对齐                       |
| `cfg.segment.channelAlignment = 'coregister_reslice'`     | 调用 SPM，将 T2/PD 刚体 Estimate & Reslice 到 T1，再送进 Segment |

自动结构通道配准使用共享 `cfg.coreg.*` 估计参数；对应 cfg.coreg.costFunction、cfg.coreg.separationMm、cfg.coreg.smoothingFwhmMm、cfg.coreg.tolerance。重采样固定 4 阶插值、不 wrap、不 mask，前缀 ac_。其中 `smoothingFwhmMm` 是历史字段名，实际用于联合强度直方图平滑，不能当成毫米影像平滑。

**这里的 Estimate & Reslice 是 T2/PD→T1 的结构通道准备，不改变 BOLD Coregister 当前固定 Estimate 的选择。**自动操作完成后仍需人工检查两种对比度的叠加质量。

#### 多通道 JSON 的逐项填写

复制 [anatomy_channels_template.json](../config/anatomy_channels_template.json)，例如：

```json
{
  "Channels": [
    {"Name":"T1", "Path":"T1.nii.gz", "Volume":1, "SaveBias":"both"},
    {"Name":"T2", "Path":"T2.nii.gz", "Volume":1,
     "BiasRegularisation":0.001, "BiasFwhmMm":60, "SaveBias":"corrected"}
  ]
}
```

| JSON 字段              | 可选填写                      | 含义与约束                                    |
| -------------------- | ------------------------- | ---------------------------------------- |
| `Channels`           | 非空对象数组                    | 每个对象是一种结构对比度，不是一个 BOLD run               |
| `Name`               | `T1`、`T2`、`PD`            | 首项须 T1，每种角色最多一次；这里的名称用于声明真实对比度，不能任意给图像改名 |
| `Path`               | `.nii/.nii.gz` 路径         | 相对 JSON 或绝对路径；第一项必须与这一行 TSV 的 t1 对应      |
| `Volume`             | 正整数                       | 当前通道的一幅图；省略时继承 inputVolume，可逐通道覆盖        |
| `BiasRegularisation` | 下节的八个 SPM 档位              | 省略时继承全局 biasRegularisation               |
| `BiasFwhmMm`         | 数字 30、40、…、150，或省略        | 省略时继承全局 biasFwhmMm；标准 JSON 不能直接写 Inf     |
| `SaveBias`           | none、field、corrected、both | 省略时继承全局 saveBias                         |

不同被试的 T1/T2 路径不能写成同一个固定 JSON 再不加检查地给所有人使用。每名被试可以有自己的 JSON，同一被试多个 run 可以关联相同文件；当前仍各 run 独立处理。

若某通道需要 Bias FWHM 的 Inf，应在 MATLAB 全局设 `cfg.segment.biasFwhmMm=Inf`，让该通道省略 BiasFwhmMm 继承它，再在其他需要校正的通道里填写具体数值。不要在标准 JSON 里写 Inf 字面量或字符串 "Inf"；当前接口没有将字符串转换为该数值的功能。

多通道 JSON **只接收 NIfTI，不直接接收 DICOM 目录**。原有清单 T1 的 DICOM 导入保留；需要 JSON 中的多通道结构像时，先把各通道转换为 NIfTI。默认单 T1 不需要填写这份 JSON。

### 3. Bias Regularisation：约束强度不均匀场

经典默认是 `biasreg=0.001`，GUI 对应 Light regularisation。

假设两个白质位置的观察强度不同，模型要分清：这是线圈造成的偏差，还是组织本来有不同强度？Bias Field Correction 估计缓慢变化的乘性偏差，正则化则防止模型过于灵活，把真正的组织差异也吸收进去。

可以概念化为：

```text
E_bias = E_data + λ_bias × R(B)
```

E_data 评价与图像数据的匹配，R(B) 惩罚不合理的偏置场，λ_bias 控制约束强度。这是直观表达，不是自行实现 SPM 的全部目标函数。

较强的正则化更限制偏置估计；较弱的正则化允许拟合更明显的不均匀，也增加过度校正的可能。**数值越低，不代表校正必然越好。**

**代码对应：`cfg.segment.biasRegularisation`（配置第201行），传给 SPM `channel.biasreg`。**

| SPM 档位            | 配置输入             | 含义                |
| ----------------- | ---------------- | ----------------- |
| No regularisation | `0`              | 不施加这一正则化，不是关闭偏置校正 |
| Extremely light   | `1e-5`，即 0.00001 | 极弱约束              |
| Very light        | `1e-4`，即 0.0001  | 很弱约束              |
| Light             | `0.001`          | 轻度，当前默认           |
| Medium            | `0.01`           | 中等约束              |
| Heavy             | `0.1`            | 较强约束              |
| Very heavy        | `1`              | 很强约束              |
| Extremely heavy   | `10`             | 极强约束              |

对普通结构像，默认 0.001 是起点。图像已经经过可靠的不均匀校正时，可以评估是否需要更强约束以减少重复校正；但应比较原图、校正图和组织结果，不能仅根据“看上去很均匀”随意设为 0。多通道 JSON 可用 BiasRegularisation 逐通道覆盖；这些设置不控制 CAT 的内部偏置算法。

### 4. Bias FWHM：偏置场的空间尺度

经典默认 `biasfwhm=60`，单位 mm。

这个参数描述模型认为偏置场会在多大的空间尺度上变化。射频场及线圈敏感度造成的不均匀，通常比真正的灰白质边界变化更缓慢，因此不能让偏置场跟着每个组织边界突然变化。

- 较大值，例如 120 mm：估计的偏置场更缓慢、平滑，减少把局部解剖差异当成偏差的风险；但也可能无法拟合某些较复杂的不均匀。
- 较小值，例如 30 mm：允许更局部的变化，可能拟合复杂偏差，也更容易吸收真正的组织强度变化。

**代码对应：`cfg.segment.biasFwhmMm`（配置第203行），传给 `channel.biasfwhm`。**允许的离散档位是 30、40、50、60、70、80、90、100、110、120、130、140、150 mm，另有 `Inf` 表示关闭相应偏置校正；当前接口不接受 65 等中间值。

它与最后的 Spatial Smoothing 完全不同：

| 设置                       | 处理对象            |
| ------------------------ | --------------- |
| Bias FWHM = 60 mm        | 估计的强度不均匀场及其空间尺度 |
| Spatial Smoothing = 6 mm | 最终功能图像的高斯空间平滑   |

所以，`biasFwhmMm=60` 不等于直接把 T1/EPI 平滑 60 mm，也不把它的输出分辨率变成 60 mm。`Inf` 与 `biasRegularisation=0` 也是不同含义，不能互相替代。多通道 JSON 可用 BiasFwhmMm 覆盖该通道。

### 5. Save Bias Corrected：保存校正图、场，还是两者？

以 T1.nii 为例，常见输出是 `mT1.nii`（校正后的结构像）与 `BiasField_T1.nii`（SPM 的校正场）。比较原 T1 和 mT1 可以检查亮度是否更均匀、组织对比是否被不合理地改变。

**代码对应：`cfg.segment.saveBias`（配置第220行），映射到 `channel.write`。**

| SPM 选项                   | 配置字符串         | SPM 数组  | 输出           |
| ------------------------ | ------------- | ------- | ------------ |
| Save Nothing             | `'none'`      | `[0 0]` | 不写这两类图       |
| Save Bias Corrected      | `'corrected'` | `[0 1]` | mT1，当前默认     |
| Save Bias Field          | `'field'`     | `[1 0]` | BiasField_T1 |
| Save Field and Corrected | `'both'`      | `[1 1]` | 两者           |

通常保存校正后的结构像，便于 QC；需要查看场是否异常时可以选 both。`none` 只关闭写出，不等于关闭模型中的偏置估计。要关闭相应校正应理解 Bias FWHM 的 Inf 选项，而不是靠不保存文件。

多通道 JSON 的 SaveBias 可分别选择。例如 T1 写 both，T2 只写 corrected。SPM 的四种 Bias 输出菜单不控制 CAT；CAT 的保存开关见第二章。当前 BOLD Coregister 的 Reference 仍是工作 T1，不会因为保存了 mT1 就自动换成它。

## 六、Tissues 参数详解

SPM12 的每一类 Tissue 有四项常见设置：TPM、Num. Gaussians、Native Tissue、Warped Tissue。前两项参与模型估计，后两项决定保存什么图。

### 1. Tissue Probability Map：先验来自哪里？

SPM 默认路径为：

```matlab
fullfile(spm('Dir'),'tpm','TPM.nii')
```

六个 volume 与第四章表格对应。原则上，SPM 原生可以使用其他 TPM，但必须检查组织定义、空间方向、概率范围及相互关系；自定义 TPM 还可能使原来的 cleanup 假设不再合适。

对普通成年人的 T1，没有特殊理由时先用自带 TPM。不能只替换模板文件而不检查后续模型假设。

**代码对应：当前固定 `cfg.spmPath/tpm/TPM.nii,1..6`。**路径基于`cfg.spmPath`（配置第15行），在 `spm_segment_batch.m` 生成；当前没有独立的自定义 TPM 路径/类别数配置。`cfg.segment.affineRegistration='eastern'` 也不会改成另一份 TPM 文件。

### 2. Num. Gaussians：每类组织用几个高斯？

经典组合为 `[1 1 2 3 4 2]`：

| 组织          | 默认高斯数 |
| ----------- | ----- |
| GM          | 1     |
| WM          | 1     |
| CSF         | 2     |
| Bone        | 3     |
| Soft Tissue | 4     |
| Background  | 2     |

高质量 T1 的较纯 GM、WM 强度常相对集中，一个高斯可以近似；CSF、骨和脑外组织可能有更复杂的强度分布，需要更多成分。

SPM 也允许 GM/WM 使用更多成分，但成分越多只是模型更灵活，不保证分类更准确；可能更容易拟合噪声，或降低不同组织之间的可区分性。

**代码对应：。**

```matlab
cfg.segment.gaussians = [1 1 2 3 4 2]; % 配置第205行
```

必须是六元素行向量，每项为 1–8 的整数，依次传给 tissue(1..6).ngaus。本机 SPM 原生还有 `Inf=Nonparametric`，当前接口没有开放；不能因为 Bias FWHM 接受 Inf，就认为这里也接受。Gaussian 数改变，不改变六类组织的数量。

### 3. Native Tissue 与 DARTEL Imported

**Native Space** 指与输入 T1 对应的个体空间。`c1T1.nii` 是原生 GM 概率图，可与工作 T1 做体素对应，用于分割检查、组织掩膜和体积指标等；它不是已经标准化到 MNI 的 GM 图。

**DARTEL Imported** 图，例如 `rc1T1.nii`，是为后续 DARTEL 群体配准准备的输入。这里 r 是这一特定输出的前缀，不应简单当成普通 Coregistration Reslice 的 r。没有准备使用 DARTEL 时，不必仅为“多保存文件”而输出 rc*。

**代码对应：，六类组织分别选择。**

| SPM 选项                   | 配置字符串             | tissue.native | 保存内容     |
| ------------------------ | ----------------- | ------------- | -------- |
| None                     | `'none'`          | `[0 0]`       | 不写这一类    |
| Native Space             | `'native'`        | `[1 0]`       | c* 原生概率图 |
| Dartel Imported          | `'dartel'`        | `[0 1]`       | rc* 导入图  |
| Native + Dartel Imported | `'native_dartel'` | `[1 1]`       | 两种都写     |

当前默认：

```matlab
cfg.segment.nativeOutputs = {'native','native','native','none','none','none'}; % 配置第224行
```

按 GM、WM、CSF、骨、软组织、背景排列。若只想让 GM/WM 同时写 Native 和 DARTEL，CSF 保留 Native：

```matlab
cfg.segment.nativeOutputs = {'native_dartel','native_dartel','native','none','none','none'}; % 配置第224行
```

**写出 Imported 图不等于已经建立群体 DARTEL 模板。**默认 segmentation 路线不执行群体建模；可选择 `normalise.method='dartel'/'shooting'`，统一入口会追加Imported、准备群体模板并应用到BOLD，见 [NORMALIZATION_OPTIONS.md](Normalization.md)。关闭某组织的 Native 输出后，需要它的独立 QC/混杂模块也不能继续使用默认 c* 路径。

### 组织输出与后续模块的依赖

关闭 GM、WM 或 CSF 的 Native 输出，仅改变这些文件是否写出；并不自动替后续混杂或质控模块寻找替代输入。若后续需要组织图，应保留对应输出，或为独立模块明确提供已检查的实际路径。CAT与SPM的组织命名、概率模型和标准空间声明分别处理，不应只改前缀混用。

### 4. Warped Tissue：标准空间组织图及体积调制

这项决定是否直接保存标准空间组织图。

**Unmodulated（未调制）**，例如 wc1T1.nii，主要表达标准空间的组织概率或浓度；没有专门保留空间变形前的组织量。

**Modulated（调制）**，例如 mwc1T1.nii，考虑标准化造成的局部扩张或压缩，尽量保留原组织量。

例如一小块组织被拉到两倍体积，如果单纯重采样，它会占据更多输出体素。用体积保存的概念理解，相应强度要减少，才能让积分表达的组织量不因拉伸而加倍。

Jacobian determinant 可以帮助理解体积变化，但需要注意：本机 SPM12 的 mwc* 使用组织量投影的实现，不应把它简单说成“每个 warped 体素都直接乘一个 Jacobian”。CAT 的调制实现也不能据此当作与 SPM 完全相同。

这些图对 VBM 尤其相关。普通任务激活、ROI 或 RSA，并不因为做了 Segment 就必须输出 wc1/mwc1。把 BOLD 标准化，主要靠前向形变场，不是用灰质图代替 BOLD。

**代码对应：，六元素 cell 与组织顺序一致。**

| SPM 选项                  | 配置字符串           | tissue.warped | 输出        |
| ----------------------- | --------------- | ------------- | --------- |
| None                    | `'none'`        | `[0 0]`       | 不写标准空间组织图 |
| Unmodulated             | `'unmodulated'` | `[1 0]`       | wc*       |
| Modulated               | `'modulated'`   | `[0 1]`       | mwc*      |
| Modulated + Unmodulated | `'both'`        | `[1 1]`       | 两者        |

**SPM 的 tissue.warped 数组第一位控制未调制输出，第二位控制调制输出。**其他表的 `[1 0]` 有其他含义，不能跨菜单套用。[SPM12 官方菜单源码](https://raw.githubusercontent.com/spm/spm12/main/config/spm_cfg_preproc8.m)

默认全部 none；若只想保存 GM 两种标准空间图：

```matlab
cfg.segment.warpedOutputs = {'both','none','none','none','none','none'}; % 配置第226行
```

这里调制的是组织图，不控制 FSL/FieldMap 路线的 BOLD Jacobian 调制。SPM 分割的标准组织图使用 TPM 默认网格；之后 BOLD 的 `cfg.voxelSizeMm`（配置第342行）、`cfg.boundingBoxMm`（配置第344行） 不是它的同一组输出控制。

## 七、Warping & MRF 参数详解

这组参数与组织输出的清理、空间估计及后续 Normalization 有关。下面按七类参数说明含义和默认设置：

| SPM 参数                 | 常见默认                     | 在当前接口中的位置                        |
| ---------------------- | ------------------------ | -------------------------------- |
| MRF Parameter          | 1                        | mrf                      |
| Clean Up               | Light Clean              | cleanup=1                |
| Warping Regularisation | `[0 0.001 0.5 0.05 0.2]` | warpRegularisation       |
| Affine Regularisation  | ICBM / European brains   | affineRegistration='mni' |
| Smoothness             | 0 mm                     | smoothnessMm             |
| Sampling Distance      | 3 mm                     | warpSamplingMm           |
| Deformation Fields     | SPM 原生常不保存               | ；工具包默认 forward            |

### 1. MRF Parameter：局部组织分类的一致性

MRF 是 Markov Random Field，马尔可夫随机场。组织通常有空间连续性，例如一块白质内突然出现孤立 GM 体素，可能来自噪声或分类误差。MRF 让局部分类还受到邻近分类的影响。

本机 SPM 配置把这个参数用于**写出组织图时的局部 MRF cleanup**；不是说单独改它就重新定义整个 Unified Segmentation 模型。

**代码对应：`cfg.segment.mrf`（配置第209行），传给 warp.mrf。**允许有限非负数；0 关闭这项 MRF，1 是默认强度。过强可能损伤狭窄脑沟、细小组织或复杂边界，普通 T1 先从 1 开始检查。

### 2. Clean Up：另一类分割清理

它与 MRF 有联系，但不是同一操作。MRF 主要关注局部分类连续性；Clean Up 还利用组织结构假设，做形态学处理，例如白质区域的腐蚀/条件膨胀，减少明显脑外 GM/WM 及某些眼球液体的误分类。

**代码对应：`cfg.segment.cleanup`（配置第211行），传给 warp.cleanup。**

| SPM 选项           | 配置输入 | 含义      |
| ---------------- | ---- | ------- |
| Don't do cleanup | `0`  | 不执行这一清理 |
| Light Clean      | `1`  | 轻度清理，默认 |
| Thorough Clean   | `2`  | 更强清理    |

普通结构像默认 1 是起点。特殊解剖、病变或复杂边界需要检查是否误删真实组织，不能认为更强一定更好。`mrf=0` 不会自动把 cleanup 改成 0，反之亦然；两者都不是“脑掩膜必定正确”的保证。

### 3. Warping Regularisation：约束非线性形变

不同人的脑沟、脑回、脑室和皮层下结构不同，整体仿射不能完全匹配，因此需要非线性形变。但如果每个位置都能任意变形，模型可能为了贴合模板而产生不合理的拉伸和压缩。

正则化可以概念化为：

```text
E_total = E_matching + E_regularisation
```

第一项评价组织匹配，第二项约束不合理变形。SPM 使用五个权重，**不是五种互斥方法**：

| 位置  | 默认值   | 惩罚/约束的直观含义                         |
| --- | ----- | ---------------------------------- |
| 1   | 0     | Absolute displacement penalty，场的幅度 |
| 2   | 0.001 | Membrane energy，一阶空间变化             |
| 3   | 0.5   | Bending energy，二阶变化及不规则弯曲          |
| 4   | 0.05  | Linear elasticity：μ，与对称梯度/剪切等变化有关  |
| 5   | 0.2   | Linear elasticity：λ，与散度及体积膨胀/收缩有关  |

逐项理解：

- 第一项可直观理解为限制场本身的幅度。例如局部位移为 15 mm，是否允许还取决于其他项和数据匹配，不只取决于这一项。默认 0 不等于全部正则化关闭。
- Membrane energy 约束相邻位置的形变不能突然不同，使空间变化更连续。
- Bending energy 约束变化的“弯曲”，减少不规则形变。
- μ、λ 借鉴线性弹性，涉及局部拉伸、剪切、膨胀和压缩。

**实际 SPM 正则化基于速度场。**上面的“位移/弯曲”是便于理解的说法，不是把原生模型改成五个简单的体素位移计算。

**代码对应：。**

```matlab
cfg.segment.warpRegularisation = [0 0.001 0.5 0.05 0.2]; % 配置第213行
```

必须五项有限非负值，整体传入 warp.reg。普通 T1 通常先保留默认。局部变形异常时，先检查方向、初始对齐、TPM 和组织分类，再判断是否需要改正则化；不要先随机调某一项。ROI 和 RSA 的小区域边界/体素模式也可能受空间变形影响，因此应检查实际输出。

### 4. Affine Regularisation：初始整体配准的约束

非线性估计前，需要把个体结构像与 TPM 大致对应。仿射可以包含平移、旋转、缩放和剪切，一般为 12 个自由度，与 Coregister 的六自由度刚体不同。

```text
x' = A × x + t
```

A 是一般 3×3 矩阵，不仅是旋转矩阵，t 为平移向量。

**代码对应：`cfg.segment.affineRegistration`，传给 warp.affreg；CAT 初始仿射也读取这一项。**

| SPM 选项                                  | 配置字符串       | 当前解释            |
| --------------------------------------- | ----------- | --------------- |
| No Affine Registration                  | `''`        | 不执行这一步初始仿射      |
| ICBM space template – European brains   | `'mni'`     | 相应的仿射正则化先验；默认   |
| ICBM space template – East Asian brains | `'eastern'` | 另一组仿射正则化先验      |
| Average sized template                  | `'subj'`    | 面向接近平均尺寸的模板先验方案 |
| No regularisation                       | `'none'`    | 做仿射，但不使用这组正则化   |

这些是大小/形状和仿射缩放的先验，不是要求只按国籍机械选择。可以从 mni 开始，有方法学理由改变时在研究中保持一致，并检查实际质量。eastern 可作为需要评估的方案，但不因被试来自中国就自动更准确。

**`'none'` 与 `''` 不同；修改 mni/eastern/subj 也不会替换 TPM。**方向或初始位置很差时，仿射正则化不能保证自动纠正一切，仍需输入检查。

### 5. Smoothness：估计中的空间噪声相关性

经典默认 `fwhm=0`，单位 mm。这个参数帮助模型考虑邻近体素的噪声相关性，不是在这个步骤直接对 T1/BOLD 执行最终空间平滑。

例如 PET/SPECT 的噪声可能有更明显的空间相关性，原生模型会考虑更大值；这里的工具包专注 fMRI，普通高分辨率 T1 默认 0 是起点，不因此扩展成 PET/SPECT 接口。

**代码对应：`cfg.segment.smoothnessMm`（配置第222行），传给 warp.fwhm。**允许单个有限非负毫米数。

| 参数                 | 典型值     | 控制对象             |
| ------------------ | ------- | ---------------- |
| Bias FWHM          | 60 mm   | 估计的强度不均匀场尺度      |
| Warping Smoothness | 0 mm    | 分割估计中对空间噪声相关性的处理 |
| Spatial Smoothing  | 例如 6 mm | 最后对功能图像执行的实际高斯平滑 |

最后一项在`cfg.smoothingFwhmMm`（配置第352行），不是本段参数。三者不能互相代替。

### 6. Sampling Distance：估计时用多密的空间采样？

经典默认 `samp=3`，单位 mm，表示估计模型时采样点之间的近似间隔。它与 Realignment/Coregistration 的 Separation 在概念上相似，但应用于不同的估计步骤。

约 3 mm 采样可以减少每次优化的计算量；改成 1 mm 往往使用更多点，也更耗时间和内存。对于 1 mm T1，默认 3 mm 通常是效率与估计精度之间的起点。

**代码对应：`cfg.segment.warpSamplingMm`（配置第215行），传给 warp.samp。**需有限正毫米值。

**Sampling Distance=3 mm 不等于 Native 组织图变成 3 mm 分辨率。**Native 图仍对应工作 T1 的网格，标准化组织图及 BOLD 的写出网格又由相应写出阶段决定。

### 7. Deformation Fields：前向与逆向形变场

这是后续 Normalization 需要注意的输出。SPM 的菜单为：

| SPM 选项            | 配置字符串               | SPM warp.write | 保存        |
| ----------------- | ------------------- | -------------- | --------- |
| None              | `'none'`            | `[0 0]`        | 不保存这两种场   |
| Inverse           | `'inverse'`         | `[1 0]`        | iy_T1.nii |
| Forward           | `'forward'`         | `[0 1]`        | y_T1.nii  |
| Inverse + Forward | `'inverse_forward'` | `[1 1]`        | 两者        |

**代码对应：`cfg.segment.deformationFields`，工具包默认 forward。**这里控制保存，并不靠 none 关闭模型里的空间估计。

Forward 的使用目标是把个体数据写到标准空间。T1 和 EPI 正确配准后，可以在 Normalise: Write 使用 y_T1.nii，将 EPI 写到 MNI。

Inverse 可用于把标准空间图谱写回个体，例如：

```text
标准空间 BNA-246 标签图谱 → 逆向形变信息 → 个体原生空间
```

这个示例说明方向，不证明某一版 BNA 图谱已经与当前模板空间匹配。真实应用还要核实源模板、目标网格和插值；标签图谱优先最近邻，并检查小脑区边界和连续性。

**SPM 场不是三列平移/旋转参数，也不是普通标量 T1。**它含三个空间坐标分量，保存用于输入/输出之间的非线性采样关系。Forward/Inverse 描述使用目的，不能只看文件存在哪个网格就凭直觉随意交换 y_ 与 iy_。

****`stopAfter='smooth'` 必须含 forward；只选 none/inverse 应使用 `stopAfter='segment'`。CAT 的原生开关位序是 `[forward inverse]`，与 SPM 相反；接口已转换，所以配置仍填相同字符串，不要自己给 CAT 交换填写方式。

### 8. 自动把图谱写回原生空间

自动接口调用 **SPM Deformations**，将逆向场与目标参考网格的 identity 复合，再写出图谱。

| 配置行与字段                            | 可选值             | 作用                                                      |
| --------------------------------- | --------------- | ------------------------------------------------------- |
| `cfg.atlas.enabled`（配置第247行）       | `false`、`true`  | 默认关闭；true 才执行图谱步骤                                       |
| `cfg.atlas.manifestFile`（配置第249行）  | JSON 绝对路径或空     | 全局图谱清单；TSV atlases 可逐 run 覆盖；关闭时不必填写                    |
| `cfg.atlas.target`（配置第251行）        | `'t1'`、`'bold'` | T1 原生网格，或配准后的未标准化均值 EPI 网格                              |
| `cfg.atlas.ensureInverse`（配置第253行） | `true`、`false`  | true 在启用图谱时自动追加逆向场；false 则须手动选择 inverse/inverse_forward |
| `cfg.atlas.prefix`（配置第255行）        | 安全前缀            | 默认 native_；字母开头，其后字母/数字/下划线                             |

target=t1 在分割后执行，segment/smooth 均可使用。target=bold 需要 `stopAfter='smooth'`，在 EPI→T1 Coregister 后、BOLD 标准化前执行；它不会直接写到已经 w 标准化的 EPI 网格。

例如需要 T1 原生图谱，并保留后续 BOLD 标准化所用前向场：

```matlab
cfg.segment.deformationFields = 'forward'; % 配置第217行
cfg.atlas.enabled = true; % 配置第247行
cfg.atlas.manifestFile = 'D:/Study/atlases.json'; % 配置第249行
cfg.atlas.target = 't1'; % 配置第251行
cfg.atlas.ensureInverse = true; % 本 run 有效场写出变为 inverse+forward % 配置第253行
```

ensureInverse 只追加逆向场，不自动追加 forward；不能用它绕过完整标准化的前向场要求。配置中请求的字段和计划里实际使用的开关都会记录。

图谱 JSON 模板为 [atlases_template.json](../config/atlases_template.json)：

```json
{
  "Atlases": [
    {"Name":"LanguageLabels", "Path":"language_labels.nii",
     "Kind":"labels", "Space":"spm_tpm_mni"},
    {"Name":"LanguageProbability", "Path":"language_probability.nii",
     "Kind":"probability", "Space":"spm_tpm_mni"}
  ]
}
```

| JSON 字段 | 填写方式                                 | 意义                            |
| ------- | ------------------------------------ | ----------------------------- |
| `Name`  | 唯一的安全名称                              | 各图谱输出子目录；允许字母、数字、下划线、连字符      |
| `Path`  | 相对 JSON 或绝对路径                        | 单幅 3D 毫米单位 `.nii/.nii.gz`     |
| `Kind`  | `'labels'`                           | 非负整数标签；固定最近邻插值，SPM interp=0   |
| `Kind`  | `'probability'`                      | 有限 0–1 概率；固定线性插值，SPM interp=1 |
| `Space` | `'spm_tpm_mni'` 或 `'cat12_mni2009c'` | 必须与分割后端对应的模板一致                |

不做图谱平滑，也不做组织量/Jacobian 调制。标签采用线性或高阶插值会产生介于编号之间的数值，不能继续当作合法脑区标签；概率采用线性可以避免本接口引入高阶插值的过冲。

Space 是使用者对源空间的声明，代码不能凭这个字符串证明空间已经匹配。不同模板的图谱必须先有经过验证的模板转换；**不能只改 Space 字符串让不匹配的图谱通过检查。**

输出在 `当前 run/atlases/<Name>/`。形变场或图谱覆盖外，SPM 可能写 NaN；接口把这些位置标记在 coverage_mask，并显式填背景 0。0 不意味着真实属于某个 ROI，coverage_mask 也不是解剖脑掩膜。结果会检查参考网格、有限值和标签编号；这些工程检查不替代人工解剖审核。

该步骤只完成空间转换，不自动提取 ROI 信号，也不自动做 FC/PPI/DCM。

## 八、Segmentation 输出文件完整解释

假设工作输入为 T1.nii。下面是可选输出合集，并不是每次都会自动产生全部文件；真实名字随工作输入变化，4D volume 提取或结构通道配准也会改变工作文件名。

### 1. SPM 输出与当前开关

| 文件               | 含义与用途                        | 当前控制                                  |
| ---------------- | ---------------------------- | ------------------------------------- |
| c1T1.nii         | Native GM，GM mask/分割检查       | nativeOutputs 第 1 项                   |
| c2T1.nii         | Native WM，WM mask/后续组织混杂     | nativeOutputs 第 2 项                   |
| c3T1.nii         | Native CSF，CSF mask/后续组织混杂   | nativeOutputs 第 3 项                   |
| c4T1.nii         | Bone probability，分割检查        | nativeOutputs 第 4 项                   |
| c5T1.nii         | Soft tissue probability，分割检查 | nativeOutputs 第 5 项                   |
| c6T1.nii         | Background probability，分割检查  | nativeOutputs 第 6 项                   |
| rc1T1.nii        | DARTEL-imported GM           | 第 1 项选 dartel/native_dartel           |
| rc2T1.nii        | DARTEL-imported WM           | 第 2 项选 dartel/native_dartel           |
| wc1T1.nii        | 标准空间未调制 GM                   | warpedOutputs 第 1 项选 unmodulated/both |
| mwc1T1.nii       | 标准空间调制 GM，用于相关 VBM 流程        | 第 1 项选 modulated/both                 |
| mT1.nii          | 偏置校正 T1，检查校正效果               | saveBias=corrected/both               |
| BiasField_T1.nii | SPM 校正场，检查低频强度变化             | saveBias=field/both                   |
| y_T1.nii         | 用于个体数据标准化的前向场                | deformationFields 含 forward           |
| iy_T1.nii        | 用于标准空间→原生的逆向场                | 显式选择或 atlas.ensureInverse 追加          |
| T1_seg8.mat      | SPM 分割模型与估计参数                | 分割时保存；当前必需输出核查包含它                     |

rc3 至 rc6、wc2 至 wc6、mwc2 至 mwc6 也按各组织选择写出，不是只允许表中 GM/WM 的例子。多通道时，每个通道的 m* 和 BiasField_* 按各自 SaveBias 决定；组织图以第一通道为主名。

**默认 SPM 输出组合**仍是 mT1、c1/c2/c3、y_ 和 seg8 模型，不写 BiasField、rc*、wc*/mwc* 或 iy_。启用原生图谱并追加 inverse 时，iy_ 也成为必需结果。

### 2. CAT 输出与共同记录

| 文件/目录                                      | 当前用途                                    |
| ------------------------------------------ | --------------------------------------- |
| `anat/mri/p1T1.nii`、p2、p3                  | CAT Native GM/WM/CSF，按 nativeTissues 保存 |
| `anat/mri/rp1T1_rigid.nii` 等               | CAT 刚体 export，按 dartelTissues 保存        |
| `anat/mri/wp1T1.nii` 等                     | CAT 未调制标准化组织图                           |
| `anat/mri/mwp1T1.nii` 等                    | CAT affine＋nonlinear 调制图                |
| `anat/mri/mT1.nii`                         | CAT 的偏置/噪声/全局强度校正结构像                    |
| `anat/mri/y_T1.nii`、iy_T1                  | CAT 的所选前向/逆向场                           |
| `anat/report/cat_T1.xml`                   | CAT 真实版本、参数、组织体积及质量信息                   |
| run 的 `03_segment.mat`                     | SPM 路线的实际 matlabbatch；不是 seg8 模型参数      |
| run 的 `03_cat12_segment.mat`               | CAT 原生 job 与 execution='cat_run'        |
| run 的 `SEGMENT_COMPLETE.mat`               | 后端、计划、工作 T1、实际场路径及必需分割输出                |
| `atlases/<Name>/atlas_deformation_job.mat` | 图谱 SPM Deformations 作业                  |
| `atlases/<Name>/ATLAS_COMPLETE.mat`        | 图谱源哈希、参考图、逆向场、输出网格及覆盖记录                 |
| run 的 `COMPLETE.mat`                       | 整个所选 run 流程的完成签名及必需输出，不只是分割             |

CAT 原生 job 要用 `cat_run(job)` 重放，不能当作 matlabbatch 直接传入 spm_jobman。普通用户仍使用 run_toolkit，无需手动重放这些开发记录。当前 CAT 关闭打印报告/表面输出，不能因为没有 CAT 打印报告或表面文件就判断必需分割结果失败。

SPM Native 概率图可能使用带缩放的存储类型；读取数值时应应用 NIfTI 缩放，例如本接口使用 spm_read_vols。不能仅按磁盘原始整数值判断“概率超过 1”。

## 九、当前自动流程、批量输入与结果保护

### 1. 本工具包怎样安排分割与后续空间步骤？

配置文件把选项按步骤分段，不代表算法执行顺序完全等于文件行的顺序。默认 segmentation 路线进入空间后续阶段时，安排如下；DARTEL/Shooting 的共享结构与群体准备按标准化章节说明执行：

```text
清单关联当前 run 的 BOLD、T1、可选结构通道和图谱
                         ↓
复制结构像，选择单幅 volume；必要时 T2/PD→T1 配准及重采样
                         ↓
                 SPM Segment 或 CAT12
                         ↓
       可选：图谱写到 T1（atlas.target='t1'）
                         ↓
     stopAfter='segment' 在此结束；smooth 时继续
                         ↓
   平均 EPI→T1：SPM Coregister Estimate，带上全部工作 EPI
                         ↓
       可选：图谱写到均值 EPI（atlas.target='bold'）
                         ↓
       所选后端前向场 → SPM Normalise: Write → SPM Smooth
```

上游的导入、dummy 帧、STC、SDC 和 Realign 仍按各自设置执行；`stopAfter='segment'` **不是整个入口直接跳过 BOLD 处理、只分割 T1 的命令**，而是在原有头动/QC之后完成分割并停下。

### 2. 多被试、多 session、多 run 如何填写？

通用清单每行是一名被试、一个 session 的一个 fMRI run。24 名被试每人两个 run，要 **48 行数据**；增加结构通道不再增加额外 BOLD run 行。

| 输入/设置                  | 当前填写位置                   |
| ---------------------- | ------------------------ |
| BOLD 与对应 T1            | runs.tsv 的 bold/t1 列     |
| 当前 run 的结构通道 JSON      | 可选 anatomy_channels 列    |
| 当前 run 的图谱 JSON        | 可选 atlases 列             |
| 全局分割/写出/图谱开关           | toolkit_config.m 中本章对应字段 |
| 相同研究中不同通道的 bias/volume | 各结构通道 JSON               |

新增列模板见 [runs_segmentation_template.tsv](../config/runs_segmentation_template.tsv)，可以把 anatomy_channels/atlases 两列加入原 extended 清单，同时保留原先 STC/SDC 等列。

JSON 的 Path 相对各 JSON；TSV 中的 JSON 路径相对 TSV，或使用绝对路径。全局 channelsFile/atlas.manifestFile 需要绝对路径。这几种相对位置不能混淆。

原始输入只读。默认 segmentation 路线通常为每个 run 建立私有 anat 工作目录并独立分割；独立 DARTEL/Shooting 路线先按 anatomyUnit 整理唯一结构，分割结果存放在共享群体结构目录，同一结构不会因多个 run 重复计入模板。后续模块应读取完成记录中的真实组织图路径。

### 3. 什么时候要修改 JSON？

**默认 SPM 单 T1、不启用图谱：**无需新建或修改这两个新增 JSON，清单 t1 和配置即可。

**使用 SPM 多通道：**需要对应结构通道 JSON，填写真实角色、文件及需要的逐通道覆盖，或在清单逐行关联。

**启用图谱反变换：**需要对应图谱 JSON，填写真实图谱与正确模板空间声明。

JSON 主要描述“数据是什么、在哪里”；cfg 主要描述“怎样计算、保存什么”。不是所有 JSON 都要为每次预处理重填一遍；真实输入信息不变时不应随意改动。
