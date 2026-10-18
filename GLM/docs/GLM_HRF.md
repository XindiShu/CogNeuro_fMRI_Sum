# HRF与事件表达：持续时长、导数和时间采样

本章把“事件持续多久”与“BOLD怎样响应”分开解释。第31/33行控制事件表达，第35行控制HRF；二者都会改变设计列与系数含义。行号按D盘glm_config当前154行版。

## 一、事件输入和HRF各自负责什么

事件输入 $u$ 描述刺激或任务段从何时发生、持续多久；HRF $h$ 描述该输入怎样转成延迟的BOLD变化。概念上的任务列是

$$
x(t)=(u*h)(t)=\int u(s)h(t-s)\,ds.
$$

这不是对观测BOLD时间序列直接做平滑。设计先形成连续/微时间响应，再采样到影像时刻。事件onset必须对应当前BOLD时间零点，HRF不会自动修正错误的Sync、起始删帧或单位。

**代码对应：**glm_framework_plan确定建模时长，glm_basis选择SPM原生基函数，glm_run将事件、timing和basis交给SPM。用户不在配置里手写卷积核，也不重实现SPM采样。[SPM模型与基函数](https://www.fil.ion.ucl.ac.uk/spm/docs/manual/fmri_spec/fmri_spec/)

## 二、duration、impulse与fixed是三种输入假设

### 1. duration：保留原始秒数

对 onset 为 $o$、时长为 $d$ 的事件，输入是从 $o$ 到 $o+d$ 的方窗。概念响应为 $x(t)=\int_0^d h(t-o-s)\,ds$。较长输入的响应不是简单地把短输入的幅度增大，形状也可变化。

第31行duration使用每行原duration。适合把明确持续的任务段作为持续输入；不表示一行里的故事内容同质，也不决定估计单元是条件还是trial。

### 2. impulse：只表达触发

第31行impulse令建模duration为0，表达onset触发后的响应。原表不改，events_used和映射保留原/建模时长。适用于明确的触发模型问题，不因为程序更容易拟合就将20秒故事视为瞬时刺激。

### 3. fixed：统一建模时长

第31行fixed使用第33行的共同秒数。SPM支持有限非负数；GLMsingle还要求正值、0.1秒倍数。统一时长可能是实验真实结构，也可能是演示近似，两者必须在解释中区分。

改变这三种表达后，设计列及其尺度可能改变，beta不能天然直接比较。GLMsingle HRF还按其原生归一化规则生成，不能仅把SPM和GLMsingle都叫canonical就认定响应列一样。

## 三、canonical：一条固定形状

SPM canonical为预定义的标准BOLD响应形状。模型为每个条件/单元估一个乘在该列上的幅度。优点是任务参数少、解释直接；代价是体素/人/任务的真实响应形状若不同，幅度会受模板失配影响。

第35行canonical映射为SPM `hrf.derivs=[0 0]`。这不是对每个体素拟合任意HRF，且不自动估响应潜伏期。条件、LSA和LSS都可使用它；pmod也可基于该形状调制幅度。

## 四、时间导数和宽度导数增加了什么

### 1. 时间导数：容纳局部早晚偏差

小时间位移 $\delta$ 可用Taylor展开理解：

$$
h(t-\delta)\approx h(t)-\delta h'(t).
$$

加入时间导数后，模型能以两列的线性组合近似部分偏移。第35行canonical_time映射 `derivs=[1 0]`。这增加一列任务基函数，不是新增事件，也不是先平移onset再假装原表未变。

实际SPM基函数有归一化和正交化处理，导数系数的比值不能不经推导就解释为秒。当前工具包不输出一个自动校准的逐体素潜伏期图。

### 2. 宽度导数：容纳局部形状宽窄差异

canonical_time_dispersion映射 `derivs=[1 1]`，每个条件/单元通常三列：canonical、时间导数、弥散导数。它扩展局部可表达形状，但仍不是完全自由HRF。参数变多、列关系改变，可能影响可估性和幅度不确定性。

### 3. 本包究竟检验哪一列

当前glm_contrasts按 `bf(1)` 定位canonical权重，其他导数列权重为0；统一beta目录也读取canonical_beta。增加导数之后，输出仍是这套基函数参数化下的canonical系数，不能自动当三列合成峰值或面积。

**可做：**用导数模型控制部分形状偏差并读取明确的canonical对比。**未实现：**任意跨导数联合F、自动合成幅度/潜伏期指标、自定义HRF核透传。不要通过手改beta路径冒充这些功能。

## 五、微时间、TR和参考时刻

TR是BOLD实测采样间隔，从影像头读取。第139行microtimeResolution把一个TR细分成若干建模格点；第141行microtimeOnset选其中的参考格。TR=.72、resolution=16时微时间步长.045秒，并没有多出16倍的实测帧。

参考格要结合实际采集、STC参考及事件零点核对。设置8不是删前8帧，也不会自动证明数据已做切片时间校正。更不能用微时间给GLMsingle解除TR格点限制：其原生设计按TR处理，SPM微时间不参与那条后端。

高通第135行与HRF不同：它控制模型中的慢变化空间，可能削弱慢任务成分；FAST/AR(1)第137行处理误差相关，不负责改变事件持续时长。三个选择都需要设计和残差检查，不互相替代。

## 六、FIR与GLMsingle HRF库放在哪里理解

FIR用多个时间箱替代固定形状，详见[既有FIR篇](Pmod_and_FIR_GLM.md)第3节。onset-impulse加FIR可用于触发响应；duration加FIR描述持续输入的响应核，两者不能用同一个“原始时间曲线”解释。当前只有condition+joint可FIR，并且窗口/bin宽度须与SPM微时间格点兼容。

GLMsingle的canonical/library由其官方实现生成，library可选体素级20候选形状；HRF选择与PC/ridge的跨run超参数评估不是同一件事，不能称所有步骤都作留一run验证。它要求共同正刺激时长与适配层允许的TR设计，不接受本接口impulse。[完整说明](GLMsingle_ABCD.md)

## 七、选择参数与代码实践

| 参数 | 配置行号 | 可选与注意 |
| --- | --- | --- |
| `cfg.events.expression` | 31 | duration/impulse/fixed；先明确输入模型 |
| `cfg.events.fixedDurationSeconds` | 33 | fixed才使用，原表不改 |
| `cfg.hrf.type` | 35 | SPM canonical/两类导数/fir；GLMsingle canonical/library |
| `cfg.microtimeResolution` | 139 | SPM正整数，不是切片数量的同义词 |
| `cfg.microtimeOnset` | 141 | SPM参考格1..resolution，核对STC及采集 |

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必查] 安装位置
cfg=glm_config;
cfg.events.expression='duration'; % 配置第31行；[建议起点] 保留输入持续时间
cfg.hrf.type='canonical_time'; % 配置第35行；[选择] 标准HRF加时间导数
cfg.microtimeResolution=16; % 配置第139行；[必核对] 模型时间格
cfg.microtimeOnset=8; % 配置第141行；[必核对] 参考格不是删帧数
```

片段只选响应表达，仍须填写真实清单、条件、混杂、mask、新输出与执行状态。先看实际SPM.xX.name里的bf(1)/bf(2)列和model_outputs，再解释系数。选FIR请成套设置38/40/42/44；选GLMsingle请成套设置后端和输入要求，不能把35行单独改library后继续走SPM。

## 八、验证范围

本包有SPM canonical、时间/宽度导数实际合成系数与列映射验证；FIR在100307语言任务作过真实工程估计。GLMsingle候选库与导出走固定官方版本，真实HCP例是显式近似。不是每种unit×HRF×事件表达都已在真实数据完整验证。本轮仅补理论与参数说明，没有新增拟合或HRF质量结论。
