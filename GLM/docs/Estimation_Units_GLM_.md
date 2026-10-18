# GLM估计单元：event、trial、item、block与阶段

本章讲“哪些事件共用一个系数”，不是新增回归算法。联合拟合和LSS决定怎样估计；unit决定估计对象。方法操作见[详细配置指南](Methods_Summary.md)。



## 一、为什么不能把一行事件直接叫一个trial

事件表中的一行可能表示瞬时刺激、整段故事、反应阶段或一个区块。给它独立beta不改变它的实验含义。HCP语言的story行和math行粒度不同，不能因为有12行就说有12个同质刺激。

另外还有三个不同ID：trial_id标记一次实验试次，stimulus_id标记什么刺激，phase标记这次试次中的哪个阶段。同一刺激可重复出现在不同trial，一个trial也可有多个phase。它们不能用同一串行号含糊代替。

## 二、分组就是一个共享参数约束

将事件 $i$ 按组 $g(i)$ 分给单元 $u$。事件表达与HRF生成单事件列 $x_i$ 后，该单元列是

$$
x_u=\sum_{i:g(i)=u}x_i,\qquad y=\sum_u x_u\beta_u+Z\gamma+\epsilon.
$$

也可写成 $X_{\mathrm{unit}}=X_{\mathrm{event}}G$，$G$ 的每行说明该事件属于哪个单元。共享列意味着这些事件使用同一个幅度参数，不是先估每行beta再求算术平均；两个估计一般不必相同。

例如A图呈现两次，item模型为两次响应共享一个系数；event模型分别估计两次。前者减少参数并施加一致性假设，后者保留逐次变化但需要更多信息。它们回答的问题不同，不能以beta数量更多判断更好。

**代码对应：**第27行选unit，glm_framework_plan用事件列建立分组，unit_mapping记录成员数和目标。模型列使用程序生成的安全标签；原始ID仍存映射，不能只按unit_000001推断原刺激。



## 三、七种unit的准确规则

| unit        | 单元键              | 当前规则                           | joint / lss |
| ----------- | ---------------- | ------------------------------ | ----------- |
| condition   | trial_type       | 同条件所有事件聚合；条件顺序来自cfg.conditions | joint       |
| event       | 输入事件行            | 每行独立，不要求额外ID                   | 两者          |
| trial       | trial_id         | 每run每ID恰好一行；不是多阶段合并器           | 两者          |
| item        | stimulus_id      | 同ID多行聚合；一个ID不能跨矛盾trial_type    | 两者          |
| block       | block_id         | 每run唯一ID且恰好一行，duration描述区块     | 两者          |
| phase       | trial_type×phase | 同条件同阶段跨试次聚合                    | joint       |
| trial_phase | trial_id×phase   | 每组合恰好一行；同trial可有不同phase        | 两者          |

ID须明确非空，不能用n/a补缺；分组不能混合不同条件。这里的唯一性在一个run内核对，不代表代码已经实现跨run刺激配对。SPM这些逐单元路线当前level=run；subject联合仅condition，GLMsingle另只接受event/trial。



## 四、每种单位怎样准备事件

### 1. event与trial：一行是否确实是一整次试次

```text
onset  duration  trial_type  trial_id
4      1         face        tr01
12     1         face        tr02
```

可event，每行一个单元；若确认tr01/tr02是真正独立试次ID也可trial。若同tr01另有编码、反应两行，trial模式会因重复ID拒绝，不能靠删ID掩盖阶段结构。

### 2. item：同刺激重复，共享响应幅度

```text
onset  duration  trial_type  stimulus_id
4      1         face        img01
12     1         face        img02
20     1         face        img01
```

item产生img01一个系数（关联第1/3行），img02一个系数。它要求两次img01共享幅度；若要研究重复抑制或学习变化，单一item系数会压掉相应逐次差别，需要先决定正确估计对象，而不是从结果好不好再选。

统一beta接口保留一行item估计与多行event_links，不把同一个beta复制两份。更不能把两份复制值当独立样本。GLMsingle重复身份也不是这里的item聚合：GLMsingle仍为每次出现估beta。

### 3. block：当前一行表示一个整区块

```text
onset  duration  trial_type  block_id
10     20        story       story01
50     20        story       story02
```

block不是将同block_id的多个短事件自动合成长区块。本接口要求每个block一行、ID唯一；如果原表每句一行而共用区块ID，需要在项目数据准备环节明确“建整块输入”还是“保留每句”，不能仅换unit字符串。

### 4. phase与trial_phase：跨试次共享，还是每次分别估计

```text
onset  duration  trial_type  trial_id  phase
4      1         A           tr01      encode
6      2         A           tr01      delay
10     1         A           tr02      encode
12     2         A           tr02      delay
```

phase得到A×encode与A×delay两个共同幅度；trial_phase得到四个独立组合。条件与phase不是一回事：不要把trial_type全部改成encode/delay而丢掉原条件。

阶段时长和顺序会影响可估性。encode、delay高度锁定时，即使每个ID填写正确，卷积后的列仍可能相似；正确标签不能替代足够的时间信息。phase目前只joint，trial_phase可joint或LSS。

## 五、unit与拟合怎样组合

```matlab
addpath('D:\GLM','D:\GLM\config','D:\GLM\matlab','D:\matlab\atoolbox\spm12'); % [必查] 包与SPM
cfg=glm_config;
cfg.model.unit='item'; % 配置第27行；[方法选择] 改成block/phase/trial_phase须相应事件列
cfg.fit.strategy='joint'; % 配置第60行；[可调] item可lss，phase必须joint
cfg.level='run'; % 配置第68行；[约束] 当前SPM逐单元为独立run
cfg.events.expression='duration'; % 配置第31行；[建议起点] 保留真实持续时间
cfg.hrf.type='canonical'; % 配置第35行；[可调] 可用导数，不接逐单元FIR
cfg.model.targetConditions={}; % 配置第29行；[可调] 空保留全部目标
```

仍需填写自己的8/10/12行路径、17行完整条件与混杂，不执行此片段就自动完成模型。lss时第62行决定所有非目标事件按pooled或原条件合并；对item目标而言，目标可包含同刺激多行，其他事件并不自动按其他item各建一列。

非condition单元的目标权重由框架生成，不通过第21行填写一个任意长度的新任务向量。第50行保持false且52为空；当前pmod/FIR只能condition+joint。第35行library是GLMsingle专属，也不能用来给任意SPM item模型换HRF库。

## 六、先看映射，再看beta

| 文件                          | 一行是什么       | 要核对的内容                     |
| --------------------------- | ----------- | -------------------------- |
| events_used.tsv             | 原事件行及建模时长   | 是否保留原时间，fixed/impulse改变了什么 |
| event_mapping.tsv           | 原事件到单元      | 原始事件序号、实际单元索引、目标标记         |
| unit_mapping.tsv            | 单元          | 来源ID、条件、成员事件数、阶段、是否目标      |
| model_outputs.tsv           | 目标对比/模型输出   | 实际canonical beta与效应/统计文件路径 |
| 后处理beta_catalog/event_links | 一个估计/估计关联事件 | 单位、方法、source_id与一对多关系      |

不能把nUnits、nTargets、nModels混在一起：item可多事件一单元，target筛选可只输出部分单元，joint只有一个模型而LSS有多个模型。目录字段分别记录这些数量。

##
