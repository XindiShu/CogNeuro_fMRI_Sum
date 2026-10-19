# 现成工具包调用的问答与项目状态

先确定研究问题、范式和终点，再按当前数据阶段挑选原包入口。不要预先把流程固定为预处理→GLM→PPI/DCM，也不要把所有任务变成逐run BOLD分析。

| 现有材料 | 优先检查的现成入口 | 要追问的关键事实 |
| --- | --- | --- |
| 原始影像/采集JSON/结构像 | preprocessing.preprocess | 需要哪些步骤、采集事实、畸变校正依据、dummy和事件零点 |
| 已有预处理BOLD | glm.model 或 function.function/prepare_inputs | 真实空间/平滑/滤波/回归历史、事件/混杂及目标 |
| 已估计SPM模型 | function.ppi/ppi_batch 或 prepare_dcm_spm | 实际模型session、独立ROI、条件含义；DCM还需TE和有序区域 |
| 既有GLM beta/对比结果 | glm.outputs → function.roi_patterns/searchlight | 估计单位/模型来源、重复样本去重、目标/CV/条件/交换块 |
| ROI时序或连接矩阵MAT | 对应动态/状态/梯度/网络/谱DCM入口 | MAT原生字段、节点顺序、连续帧、TR、独立单位；不自动重清理 |
| 被试/特征/行为矩阵 | prediction/encoding/multivariate/transfer等 | 独立单位和特征ID、对齐、训练/测试/CV边界 |
| 行为试次、RDM或重复测量 | behavior/rsa_ceiling/reliability | 原生表/结构、真实时间单位、条件/单位身份和统计目标 |

每轮聚合同主题的少量问题，答案保存真实来源和confirmed。用户未说明时必须先问参数是否已改，记录顶层parameter_setup；已有明确回答沿用。按[参数审阅与报告流程](parameter-review-and-report.md)复核已改项或自动配置未改项，展示全部适用参数及保留值，解释关键选择并等待真实确认。文件发现只是候选，目标/条件对比/网络/独立单位是用户的科学决定。

## 答案结构

`route` 使用toolkit_method，`method_id` 对应入口目录。`parameter_choices.native_config` 是一条带来源的确认事实，其value含：

- `config_hashes`：当前目录返回的所有配置工厂/继承配置文件哈希映射。
- `native_execute`：true/false，表示是否调用原包实际计算分支；不是skill是否获授权的开关。
- `overrides`：{path,value}数组，项目内存配置；空数组是明确沿用已审阅默认。

`inputs` 键来自所选入口的inputs。现成文件使用 `{value,source,confirmed}`；填表使用 `{template,rows}`，每行每列同样保存确认事实。模板无实体文件而来自原生读表声明时，用`schema: native`。需要额外目标/CV/协变量列时，在`extra_columns`中明确列名，再对每个单元格保留来源。

每轮plan追加revision，保留答案、问题、参数和DRAFT表；不会替用户覆盖旧修订。项目版本兼容旧数据盘点；重新plan创建当前修订。更换目标/方法后只要求新入口的缺项，保留仍有效的采集和身份事实。

## 缺项与检查范围

检查安装包入口/工厂/模板是否存在；读取实际表头、输入引用路径和参数源码。配置文件与已确认版本冲突时重新审阅当前文件，不恢复旧副本。目录有新入口时列为需要补接调用契约，不称该方法未开发。

MAT是否含原生需要的data/SPM等结构、内部字段/形状及研究约束，应根据原包契约和必要的元信息读取判断。仅文件名或扩展名不能证明已满足。需要进一步原生检查时说明其行为；一些execute=false分支仍会计算或写准备产物，不能暗中批量运行。

通用prepare只做配置加载与交接检查，保存覆盖前/后配置及参数评估模板。Codex补齐逐项评估后运行assess-parameters，展示新review并等待真实确认，再用approve记录回复来源；仅给execute确认短语不能运行。review保存函数目标、表格绑定及检查范围。参数或代码变化后旧摘要不能沿用；修改需要plan新修订和prepare新尝试。

## 多阶段授权与完成

在首次执行前把完整依赖顺序、研究参数、待生成输入的产物选取规则、输出位置和失败停止策略展示清楚。用户已批准这些具体选择时，后续根据真实产物填入机械路径并继续；不重复追问同一授权。尚未决定的模型/掩膜/CV/网络不能藏在“自动继续”中。

每阶段保留原生配置和返回结果，读取真实输出元数据后交接。任务DCM用原生prepare_dcm_spm准备VOI，不重新写提取算法；已有beta用原生输出接口读取，不重估GLM。其他MAT格式转换只补真实元信息和显式映射，保留来源副本，不重算原包已提供的分析。

失败保留产物，先报告原包返回原因；不降低阈值、删被试或换算法来“跑通”。用workflow登记三包实际execute/reuse/skip及原因；各阶段执行成功或失败自动生成版本化步骤与参数报告，子阶段更新已登记父报告。最后report汇总并读取真实结果补充解释/图表。区分调用完成、估计完成、原包警告/跳过、模型诊断与科学推断；旧测试数字不是当前数据已经验证。
