# fMRI GLM 工具包

本目录保存独立的条件平均 GLM、逐事件行 LSA/LSS、配置、模板、示例和测试。预处理位于CogNeuro_fMRI_Toolkit

## 使用

1. 条件平均 GLM：复制 config/glm_runs_template.tsv 为 config/glm_runs.tsv，填写已核查的 BOLD、事件及混杂表路径，修改 config/glm_config.m，运行 run_glm.m。
2. LSA/LSS：复制 config/single_trial_runs_template.tsv 为 config/single_trial_runs.tsv，修改 config/single_trial_config.m，运行 run_single_trial.m。
3. 两个入口默认 execute=false，只准备相应模型；确认模型与输入后，在新的输出目录设置 true 才估计。输入 BOLD 必须符合 unfiltered_unregressed 的时间处理声明。


