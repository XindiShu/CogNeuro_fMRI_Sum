function report = preprocess_hcp(cfg)
%PREPROCESS_HCP 兼容 HCP 示例入口，实际计算共用通用批处理。
cfg.inputMode='hcp';
report=psy.preprocess_batch(cfg);
end
