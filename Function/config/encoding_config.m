function cfg=encoding_config
%ENCODING_CONFIG 特征空间→多输出脑活动；独立run CV，滞后不跨run/缺帧。
root=fileparts(fileparts(mfilename('fullpath')));
cfg.dataFile=fullfile(root,'config','encoding_data.mat'); % [必改] data.featureSpaces/featureIds/targetIds/y/runIds/frameIndices/cvGroups/featureSpaceNames，详见新编码指南。
cfg.outputRoot=fullfile(fileparts(root),'derivatives','function_encoding'); % [必改] 新绝对目录。
cfg.execute=false; % [可调] false读取/索引/候选预检，true实际CV。
cfg.options.method='ridge'; % [可调] ridge或banded_ridge。
cfg.options.lambdaCandidates=[.1;1;10;100]; % [可调] 每行候选；ridge单列，banded每列一个特征空间；单行表示预先固定、不调参。
cfg.options.lagsFrames=0; % [可调] 非负整数滞后，连续时序单位=采集帧；event_estimates只能0。
cfg.options.sampleKind='event_estimates'; % [可调] event_estimates或continuous，显式区分trial估计单元/采集帧。
cfg.options.purgeFrames=0; % [可调] 同一run跨CV块时额外排除相邻训练帧；还会加最大特征滞后以免重叠。
end
