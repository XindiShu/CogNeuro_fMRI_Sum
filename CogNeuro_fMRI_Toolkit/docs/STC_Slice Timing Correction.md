# 3. Slice Timing Correction（STC）

本章说明逐层采集时间为什么需要校正、如何选择采集顺序与参考时间，以及 STC 与后续模型 Microtime 的关系。参数直接通过 toolkit_config.m 控制，逐 run 的真实采集时间由元数据提供。

参数位置对应最终版 `config/toolkit_config.m`。以下“配置第N行”均指该文件；SPM原生能力与当前接口已开放功能在各节分别说明。

## 为什么需要 Slice Timing Correction？

一个 TR 并不是“一瞬间拍完整个脑”。假设 `TR=2 s`、一帧有 36 张切片，扫描可能是：

- Slice 1 在 `t=0.00 s` 采集。
- Slice 2 在大约 `t=0.06 s` 采集。
- 后面的切片再依次采集。

也就是说，虽然这些切片被存成同一个 volume，它们实际上并不是同时采集的。

## Slice Timing 做什么？

它通过**时间插值**，把不同切片的信号估计为在同一个参考时刻采集的信号。它没有产生新的真实观测，而是利用已有的时间序列估计参考时刻的信号值。

## Reference Slice：参考切片

做 STC 时需要选择一个共同的参考时刻。在传统的切片编号输入方式中，这个时刻由 reference slice（参考切片）决定。常见选择是中间切片，或者采集时间处在一个 TR 中间附近的切片。

SPM 中会涉及 `Slice Order`、`Reference Slice`、`TR` 和 `TA`。传统单带、均匀采集情况下常用：

$$
TA = TR - \frac{TR}{N_{\text{slice}}}
$$

其中，`N_slice` 是每个 volume 的切片数。这个公式的适用条件和例子在后面的 TA 部分说明。

## STC 是否必须做？

不一定。

- 如果 `TR=2-3 s`，并且采用事件相关设计（event-related design），Slice Timing 往往有一定价值。
- 如果 `TR=0.5-0.8 s`，并且采用 Multiband（多带、同时多层采集），切片间的时间差通常较小，STC 的影响也可能减小。

是否使用，还需要结合实际采集时间、实验设计和分析目的，后文会继续说明。

**接口设置：是否执行 STC 的设置**

`toolkit_config.m` ：

```matlab
cfg.sliceTiming.mode = 'off'; % 配置第49行
```

`'off'` 表示不执行 STC；改为后文介绍的采集顺序或时间输入模式，就会启用相应处理。当前默认关闭；HCP 示例中尚未核实多带逐层采集时间，因此也保持关闭。这是采集信息和当前验证范围的限制，与示例被试只有几个无关。

`toolkit_config.m` 的 `cfg.sliceTiming.enabled=false` 是旧配置兼容字段，建议保留 `false`，通过 `mode` 选择方法。其实际行为是：当 `mode='off'` 且 `enabled=true` 时，程序转用 `explicit_seconds`；`enabled=false` 不会覆盖一个已经设为非 `off` 的 `mode`。

## SPM12 可以处理哪些采集方式？

### 1. Sequential Ascending：顺序升序采集

切片的采集顺序与空间编号一致。例如 8 张切片按下面顺序采集：

```text
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
```

如果选择空间上中间位置的切片作为参考，通常也能选到时间上接近扫描中点的切片。

**接口设置：**`toolkit_config.m` 可以选择：

```matlab
cfg.sliceTiming.mode = 'ascending'; % 配置第49行
```

程序按 `1:N` 生成顺序，再结合该 run 的 TR、切片数与 TA 生成逐层时间。这个预设只适用于已经核实为该顺序的单带扫描。

### 2. Sequential Descending：顺序降序采集

采集顺序与空间编号相反，例如：

```text
8 → 7 → 6 → 5 → 4 → 3 → 2 → 1
```

升序和降序使用相同的校正算法，只是各切片需要移动的时间不同。

**接口设置：设置：

```matlab
cfg.sliceTiming.mode = 'descending'; % 配置第49行
```

程序按 `N:-1:1` 生成单带顺序。

### 3. Interleaved Ascending：交错升序采集

例如先采奇数切片，再采偶数切片：

```text
1 → 3 → 5 → 7 → 2 → 4 → 6 → 8
```

这种方式最重要的特点是：**空间上相邻的切片，在时间上不一定相邻。**在这个例子中，Slice 1 第一个采集，Slice 2 却是第五个采集。

交错采集过去常用于减少相邻切片激发带来的 slice cross-talk，也就是相邻切片之间的激发干扰。

**接口设置：设置：

```matlab
cfg.sliceTiming.mode = 'interleaved_bottomup'; % 配置第49行
```

它固定生成 `[1:2:N 2:2:N]`，即**奇数编号先行**。如果扫描仪实际采用偶数先行或其他交错规则，不能仅看到“交错升序”就使用这个预设；应使用核实后的逐层时间。

### 4. Interleaved Descending：交错降序采集

例如先采高编号偶数切片，再采高编号到低编号的奇数切片：

```text
8 → 6 → 4 → 2 → 7 → 5 → 3 → 1
```

交错采集不只有一种奇偶顺序，实际仍要看扫描协议。

**接口设置：设置：

```matlab
cfg.sliceTiming.mode = 'interleaved_topdown'; % 配置第49行
```

它生成 `[N:-2:1 N-1:-2:1]`。此外，代码还提供 `'interleaved_midtop'`，使用 SPM 帮助中的另一种交错公式；例如 `N=8` 时生成 `[8 4 7 3 6 2 5 1]`。它也是一个**单带顺序预设**，须与实际协议匹配，不代表下面的 Multiband。

### 5. Multiband：同时多层采集

又称 Simultaneous Multi-Slice（SMS）acquisition。例如 `MB=2`，意味着一次 RF 激发可以同时激发并采集两张切片。此时可能出现 Slice 1 与 Slice 5 的采集时间相同。

它们具有相同的时间偏移，因此 STC 不需要在这两张切片之间做相对时间校正。

对于 Multiband 数据，通常应直接提供**每张切片的实际采集时间**，而不是普通的 Slice Order 编号排列。普通顺序向量不能准确表达“多个切片同时采集”的情况。

**接口设置：可以选择：

```matlab
cfg.sliceTiming.mode = 'metadata'; % 配置第49行
```

这时每个 run 从 TSV 的 `metadata` 列所指向的 JSON 文件读取 `SliceTiming` 秒数组。也可以选择 `'explicit_seconds'`，并在填写：

```matlab
cfg.sliceTiming.seconds = []; % 替换为实际逐层采集时间，单位秒 % 配置第45行
```

这一向量按 NIfTI 第三维的切片编号排列，长度必须等于切片数；每项应在 `[0,TR)` 秒内，同时采集的层允许出现相同时间。`explicit_seconds` 的同一个向量会用于整个批次；不同 run 的采集时间不同时，选择逐 run 的 `metadata` 更合适。

这里没有根据 MB 倍数自动猜时间的功能。多带时间数组的参数生成已有单元测试，现有 HCP 真实全流程运行中 STC 仍关闭，不能据此称为真实多带 STC 已验证。

## SPM12 的 Slice Timing 参数详解

SPM 的 Temporal → Slice Timing 提供以下参数；自动接口按相同含义组织输入。

| SPM12 参数         | 含义                      | 单位或形式        |
| ---------------- | ----------------------- | ------------ |
| Data / Session   | 需要校正的 EPI 时间序列          | NIfTI 图像     |
| Number of Slices | 每个 volume 的切片数量         | 整数           |
| TR               | 相邻两个 volume 的重复采集时间     | 秒            |
| TA               | 第一个与最后一个切片采集起始时刻之间的时间间隔 | 秒            |
| Slice Order      | 切片采集顺序，或逐切片采集时间         | 编号向量，或毫秒时间向量 |
| Reference Slice  | 所有切片对齐的参考切片或参考时刻        | 切片编号或毫秒      |
| Filename Prefix  | 校正后文件名的前缀               | 字符串，通常为 `a`  |

### 1. Number of Slices：切片数量

每个 volume 沿第三维（z 方向）包含多少张切片。这个数**不是 volume 数量，也不是 TR 的数量**。

如果图像已经发生空间重采样，z 方向的维度可能改变。STC 应根据原始 EPI 的切片结构及其对应采集信息设置，通常不应在标准化（Normalization）之后才做。

**接口设置：**这一项不需要在 `toolkit_config.m` 手填。`matlab/+psy/inspect_run.m` 读取 BOLD 的 NIfTI 尺寸，`matlab/+psy/process_run.m` 将 `info.size(3)` 写入 SPM 的 `nslices`。当前实现按第三维处理，未提供更换切片轴的配置。

### 2. TR：Repetition Time

TR 表示相邻两个 volume 的对应采样时刻之间的时间间隔，单位为秒。

**接口设置：**TR 也不是 STC 配置段中手填的全局常数。`inspect_run.m` 读取 NIfTI 的第四维时间间隔，并按头信息中的单位换算为秒；`process_run.m` 把它写入 SPM 的 `tr`。如果 JSON 也给出了 `RepetitionTime`，程序会检查它是否与影像头一致，不一致时报错。

### 3. TA：Acquisition Time

TA 是一个 volume 中**第一个和最后一个切片的采集起始时刻**之间的间隔，`TR≠TA`。

在传统单层、均匀间隔采集的情况下，常用：

$$
TA = TR - \frac{TR}{N_{\text{slice}}}
$$

例如：

$$
TR=2\ \mathrm{s},\qquad N_{\text{slice}}=36
$$

得到：

$$
TA=2-\frac{2}{36}\approx1.9444\ \mathrm{s}
$$

这表示第一张和最后一张切片的采集起始时刻相差约 1.9444 秒，并不表示采到最后一张切片就用完了整个 TR 的时间。

这个公式的前提是切片等间隔采集，并且序列的时间分配符合这种简化模型。它不适用于所有 EPI 序列。例如：

- Sparse sampling（稀疏采样）可能有较长的静默间隔，实际 TA 远小于 TR。
- Multiband 同时采集多个切片，不能直接用总切片数套普通单层采集公式。
- 已经有每张切片的精确采集时间时，应优先使用这些时间，而不是重新假设均匀间隔。

SPM12 支持以毫秒直接输入逐层采集时间。此时 TA 不参与切片间相对时间偏移的计算，可以设为 0。

**接口设置：**`toolkit_config.m` ：

```matlab
cfg.sliceTiming.acquisitionTimeSeconds = []; % 配置第51行
```

这行**仅对五种标准单带顺序预设生效**。`[]` 表示使用上面的默认公式；如果扫描协议给出了真实 TA，可以填一个秒数，当前要求 `0<TA<TR`。`metadata` 和 `explicit_seconds` 使用实际逐层时间，不靠这一行推算。

工具包会把单带顺序和 TA 先转换为逐层时间向量，所以它最终交给 SPM 的仍是毫秒时间输入方式；`process_run.m` 固定传入 `ta=0`。这不表示真实采集没有时间间隔。

### 4. Slice Order：切片采集顺序

SPM12 提供两种输入方式：按照采集顺序填写切片编号，或直接填写每张切片各自的采集时间。

**方法 A：输入切片编号（Slice Index）**

例如填写 `[1 3 5 7 2 4 6 8]`。这种方法假设相邻采集位置之间的时间间隔相等，SPM12 根据 TR、TA 和切片数量计算时间偏移。

**方法 B：直接输入 Slice Timing**

这里输入的是每张**空间切片**各自的采集时刻，SPM 中单位为毫秒。向量中的数字依 Slice 1 到 Slice N 排列，**不是按时间先后排序后的列表**。

如何获取真实 Slice Timing？如果使用 dcm2niix 将 DICOM 转换为 NIfTI，通常还会得到配套 JSON，其中可能包含 `RepetitionTime` 和 `SliceTiming`。这两个字段都以秒为单位，而 SPM12 逐切片时间输入需要毫秒，因此要换算单位。

还要检查 `SliceEncodingDirection`。根据 BIDS 的定义，如果采用 `k-`，`SliceTiming` 列表的顺序与 NIfTI 第三维的递增编号相反；直接复制而不调整可能出错。[BIDS MRI 规范](https://bids-specification.readthedocs.io/en/stable/modality-specific-files/magnetic-resonance-imaging-data.html)说明了这一方向约定。

SPM12 的 `spm_slice_timing.m` 对切片编号和逐切片时间两种输入方式都有实现。

**接口设置：的完整 `mode` 选项为：

| 输入值                      | 在本工具包中对应什么                               |
| ------------------------ | ---------------------------------------- |
| `'off'`                  | 不执行 STC。                                 |
| `'ascending'`            | 标准单带顺序升序。                                |
| `'descending'`           | 标准单带顺序降序。                                |
| `'interleaved_bottomup'` | 奇数编号先行的单带交错顺序。                           |
| `'interleaved_topdown'`  | 从高编号开始的单带交错顺序。                           |
| `'interleaved_midtop'`   | SPM 帮助中另一种公式生成的单带交错顺序。                   |
| `'metadata'`             | 每个 run 从自己的 JSON 读取 `SliceTiming` 秒数组。   |
| `'explicit_seconds'`     | 全批次使用 `cfg.sliceTiming.seconds`（配置第45行） 中的逐层秒数组。 |

工具包最终统一采用“方法 B”：预设的切片编号顺序也先转成时间向量，再由 `process_run.m` 乘以 1000 后交给 SPM。当前没有单独手填“任意切片编号排列”的配置项；特殊顺序应使用核实的逐层时间。

**当前代码不会根据 `SliceEncodingDirection='k-'` 自动反转列表**，也未提供非第三维切片轴的适配。遇到这种情况，应先核对时间与 NIfTI 层编号的关系，再准备正确的时间输入；保留原始采集记录，不要把未经核实的 JSON 原样用于此模式。

### 5. Reference Slice：参考切片

它决定所有切片最终要对齐到哪个时刻。常见选择有三种。

**第一种：以第一个采集的切片为参考。**容易与实验事件的时间零点对应，GLM 的 Microtime onset 也比较直观；代价是最后采集的切片需要更大的时间插值位移。

**第二种：以时间上居中的切片为参考。**通常可以减小最大的插值位移。但要特别注意：**空间上中间的切片，不一定是时间上中间采集的切片**，交错采集时尤其如此。

**第三种：直接指定参考时间。**如果使用前面的毫秒时间输入方式，参考时间也相应以毫秒输入 SPM。

**接口设置：**`toolkit_config.m` ：

```matlab
cfg.sliceTiming.reference = 'middle_time'; % 配置第53行
```

| 可选值             | 程序实际选择                             |
| --------------- | ---------------------------------- |
| `'middle_time'` | 从真实/生成的层时间中，选择最接近 `TR/2` 的时刻；当前默认。 |
| `'first'`       | 最早采集时刻，即层时间中的最小值。                  |
| `'last'`        | 最晚采集时刻，即层时间中的最大值。                  |
| `'seconds'`     | 使用下面一行指定的参考秒数。                     |

`middle_time` 当前寻找的是 `TR/2` 附近的层，不是自动计算采集窗口的中点 `TA/2`。稀疏采样等情形若需要指定实际采集时段中点，可以选择 `seconds`。

`toolkit_config.m` ：

```matlab
cfg.sliceTiming.referenceSeconds = 0; % 配置第47行
```

仅当 `reference='seconds'` 时这行生效，填一个 `[0,TR)` 内的**秒数**，例如 `0` 表示 volume 起始时刻。其他三种选择会忽略这行。工具包在 `process_run.m` 将参考秒数乘以 1000 后传入 SPM。

**Data / Session 与 Filename Prefix 的**当前 run 的 BOLD 文件由数据清单或 HCP 适配器指定，`process_run.m` 自动展开各帧并写入 STC 的 `scans`，不需要在 STC 配置段再次填文件路径。将输出前缀固定为 `a`；这一命名参数目前没有开放为配置选项。

## SPM12 使用什么算法做 Slice Timing Correction？

SPM12 的经典 STC 实现采用 **Fourier interpolation（傅里叶时间插值）**，不是让使用者从线性、三次或 sinc 插值中任选一种。

### 1. 为什么可以利用插值校正采集时间？

假设一个体素的 BOLD 信号为 `y(t)`，但我们只在某些时刻观测到它，例如 `y(0)`、`y(2)`、`y(4)`。如果想知道 1 秒时的值，就需要根据已知采样点估计。

最简单的线性插值可以写为：

$$
y(1)\approx\frac{y(0)+y(2)}{2}
$$

真实 BOLD 信号不一定在两点之间线性变化，傅里叶插值则利用更完整的时间序列结构来估计。

**STC 主要利用同一空间切片在不同 volume 中的时间序列，不是用同一个 volume 里其他切片的 BOLD 值，来估计当前切片。**

### 2. Fourier interpolation 的原理

对于某个体素的离散 BOLD 时间序列：

$$
y[n],\qquad n=0,1,\ldots,N-1
$$

这里的 `N` 是时间序列的采样点数，区别于前面的切片数量 `N_slice`。

先进行离散傅里叶变换：

$$
Y[k]=\sum_{n=0}^{N-1}y[n]e^{-i2\pi kn/N}
$$

这相当于把信号表示成不同频率成分的组合。然后根据需要校正的时间偏移：

$$
\Delta t=t_{\text{slice}}-t_{\text{ref}}
$$

对每个频率成分调整相位：

$$
Y_{\text{corrected}}(f)=Y(f)e^{-i2\pi f\Delta t}
$$

最后使用逆傅里叶变换：

$$
y_{\text{corrected}}(t)=\mathcal{F}^{-1}\left[Y_{\text{corrected}}(f)\right]
$$

这样就得到时间平移后的信号估计。SPM12 源代码使用 `fft`、复数相位因子和 `ifft` 完成这一步；上面的公式用于理解原理，不需要使用者自行计算。

**接口设置：**本工具包没有重新实现傅里叶插值，也没有“STC 插值算法”的可选配置。`process_run.m` 生成 SPM 的 `spm.temporal.st` 作业，再调用 SPM 执行。

### 3. 为什么使用 Fourier interpolation？

相比简单线性插值，它可以利用整段时间序列的多个频率成分，表示具有一定平滑性和周期结构的信号。

它的一个关键假设是信号近似带限（band-limited）：主要变化位于现有采样频率能表示的范围内，没有大量超出奈奎斯特频率的重要成分。

对于 `TR=2 s`：

$$
f_s=\frac{1}{TR}=0.5\ \mathrm{Hz}
$$

$$
f_{\text{Nyquist}}=\frac{f_s}{2}=0.25\ \mathrm{Hz}
$$

BOLD 反应变化较慢，因此这种方法在常规任务态 fMRI 中通常有合理性。但它也有局限：突然头动、信号尖峰、时间序列两端的不连续，都可能影响插值。SPM12 会对序列做一定延拓，以减少边界效应。

因此，STC 无法替代 Realignment、运动混杂回归或其他伪影控制，也不意味着插值后的信号一定更接近真实神经活动。

## Slice Timing 与 GLM 中的 Microtime 参数

这一部分很重要，也容易在实际操作中被忽略。

在 SPM12 做完 STC 后，一级模型位于 SPM → Stats → fMRI Model Specification，其中有两个参数：**Microtime resolution（`fmri_t`）**和 **Microtime onset（`fmri_t0`）**。它们不是 STC 参数，但应与 STC 的参考时间保持一致。

### 1. Microtime resolution

SPM 将一个 TR 划分成多少个内部时间格，用于构建设计矩阵中的高时间分辨率预测信号。例如 `TR=2 s`、`fmri_t=16`：

$$
\Delta t_{\text{micro}}=\frac{TR}{fmri\_t}=\frac{2}{16}=0.125\ \mathrm{s}
$$

SPM 在 0.125 秒的内部时间网格上生成事件与 HRF 卷积后的预测信号，再按指定的 Microtime onset 取样到每个 TR 一个值。

这只改变模型内部的计算网格，**不会让真实 BOLD 数据获得 0.125 秒的采样分辨率**。

**接口设置：**`toolkit_config.m` ：

```matlab
cfg.sliceTiming.microtimeResolution = 16; % 配置第55行
```

可填正整数；当前默认 16。它只用于生成并保存后续一级模型的建议，不进入 STC batch。真正的独立 GLM 配置位于 `config/glm_config.m` 的 `cfg.microtimeResolution`。

### 2. Microtime onset

它决定在一个 TR 内的哪一个内部时间格，对 GLM 的高时间分辨率预测信号取样。

SPM12 常见默认设置是：

```matlab
fmri_t = 16;
fmri_t0 = 8;
```

可理解为在一个 TR 内靠近中间的位置取样。如果 STC 把切片对齐到 TR 起始的第一个采集时刻，GLM 通常应相应采用 `fmri_t0=1`；换成其他参考时刻时，也要调整 onset。

### 3. 为什么要与 STC 的参考时间匹配？

[SPM 官方教程](https://www.fil.ion.ucl.ac.uk/spm/docs/tutorials/fmri/preprocessing/slice_timing/)强调两者应当匹配。假设影像已校正到较早时刻，但模型仍在较晚的内部时间格取样，相当于用一个时刻的模型预测去拟合另一个时刻的数据。

这种不一致可能影响 β 估计，尤其是在快速事件相关设计、较长 TR，或者需要准确区分反应时段的研究中。

**接口设置：**STC 配置里没有让使用者另填 `fmri_t0` 的一行。程序在 `slice_timing_plan.m` 根据实际参考秒数计算建议值，但**不会自动写入独立 GLM 配置**。正式 GLM 使用的是 `config/glm_config.m` 的 `cfg.microtimeOnset`，目前默认 8；需要根据 STC 结果核查和填写。实际 SPM 模型字段由 `matlab/+psy/glm_run.m` 生成。

### 4. 在交错采集时如何对应？

假设切片采集顺序为：

```matlab
slice_order = [1 3 5 7 2 4 6 8];
refslice = 7;
```

Slice 7 是**第四个采集**的切片，可以相应设置：

```matlab
fmri_t = 8;
fmri_t0 = 4;
```

这里的 `fmri_t0=4` 表达第四个时间位置，**不是空间上的 Slice 4**。

更一般地，选择实际参考时间 `t_ref` 后，可近似映射到 GLM 时间格：

$$
t_0\approx1+\frac{t_{\text{ref}}}{TR}\times T
$$

其中 `T` 是 Microtime resolution，再把结果取为有效的整数时间格。这个关系是对 SPM 时间网格的近似对应；采集时刻和模型网格未必完全重合，Multiband 等复杂采集中尤其不能直接把空间 Slice 编号当作 `fmri_t0`。

**接口设置：**当前实现具体保存：

```matlab
fmri_t0_suggested = min(T, max(1, round(t_ref / TR * T) + 1));
```

例如上面的均匀单带交错采集，若 `TR=2 s`、第 7 层采集时间为 `0.75 s`、`T=8`，程序建议值为 4。若 `T=16`，相同参考时刻建议值会变成 7。因此，不能只保留 GLM 默认 `16/8` 就认为已经匹配。

建议值保存在逐 run 预检的 `header.mat` 内 `info.preprocessPlan.slice`，正式运行还会写入 `preprocessing_plan.json`；STC 关闭时没有实际 STC 参考时间，记录的默认 onset 不能作为“已经匹配”的证据。

## Slice Timing 应该在 Realignment 之前还是之后？

这是 fMRI 预处理中长期存在的方法学问题，没有一种顺序适用于所有数据；研究中两种流程都能见到。

**先做 Slice Timing 的理由：**如果先做 Realignment，空间重采样可能把来自不同采集时刻的切片信号混合起来，后续时间校正就不再严格对应原始层时间。

**先做 Realignment 的理由：**如果扫描中有明显头动，先做 STC 可能通过时间插值，把运动造成的突发信号变化传播到邻近时间点。

SPM 官方文档讨论了两种策略的权衡，没有规定所有研究必须采用同一顺序。一个教学流程采用 Realignment → Slice Timing，而关于复杂交错顺序的说明也提出了优先 STC 的理由。

**接口设置：**当前 `process_run.m` 的 STC 作业在，头动处理在，因此工具包采用 **STC → Realignment**。目前没有一行配置可交换它们的顺序。FSL TOPUP 路线在这两步之前先做 BOLD 畸变校正；SPM FieldMap 路线的头动/畸变处理在 `spm_motion_step.m` 内执行。

## 什么时候需要做 STC？什么时候可以不做？

是否进行 STC，应同时考虑 TR、实验设计、采集方式和后续分析目标，而不只看某一个数值。

一个常见策略是在 GLM 中加入 canonical HRF 的 **temporal derivative（时间导数）**。它能在一定程度上容纳神经反应与模型预测之间的小幅时间偏移，但做法是增加模型的灵活性，并没有把影像各层真正校正到相同时刻。因此，Temporal derivative 与 STC 不能看作完全等价的处理。SPM 官方文档也讨论了这一策略，特别是较短 TR 的任务态研究。

**接口设置：**在当前预处理入口中，用 `cfg.sliceTiming.mode='off'` 跳过 STC，或用上述模式启用它。这个选择**不会自动给后续 GLM 增加 HRF 时间导数**；后续模型必须另外按其实际功能和研究设计设置。现有空间处理完成记录也不能替代对时序采集信息的核查。
