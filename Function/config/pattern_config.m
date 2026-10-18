function o=pattern_config
%PATTERN_CONFIG ROI模式分析选项；输入矩阵行保留估计单元身份。
o.decode.task='classification'; % [可调] classification=diagLinear LDA；regression=固定lambda ridge。
o.decode.lambda=1; % [可调] ridge正则化>0；分类忽略，不根据测试集调参。
o.rsa.metric='correlation'; % [可调] correlation/euclidean/crossnobis。
o.rsa.noiseCovariance=[]; % [必改若crossnobis] 特征×特征的独立残差噪声协方差，正定；不自动从测试标签估计。
o.rsa.modelRDMs=[]; % [可调] 条件×条件×模型数组，空仅生成脑RDM。
o.rsa.modelLabels=strings(0,1); % [必改若比较模型] 与返回的条件标签顺序完全一致。
o.betaSeries.minTrials=4; % [可调] 每subject/session/run/condition最少估计单元，整数>=3。
o.betaSeries.estimator='pearson'; % [可调] pearson/spearman/partial。
end
