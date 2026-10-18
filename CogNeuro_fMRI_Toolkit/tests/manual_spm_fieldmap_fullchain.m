function report = manual_spm_fieldmap_fullchain(root)
%MANUAL_SPM_FIELDMAP_FULLCHAIN 两条 SPM FieldMap 路线的一次运行接口集成试验。
% 只用于工程验证：8 帧真实 HCP BOLD + 真实 T1 + 人工生成的 GRE 场图。
% 第二行的 AP 相位编码元数据也是合成的；不能把输出当作 HCP 科研结果。
% 原始数据只读，全部派生输入与结果写到新的 root；已有目录绝不覆盖。
project=fileparts(fileparts(mfilename('fullpath')));
if nargin<1
    root=fullfile(project,'derivatives', ...
        ['spm_fieldmap_fullchain_' char(datetime('now','Format','yyyyMMdd_HHmmssSSS'))]);
end
if isfolder(root), error('psy:FullchainExisting','输出目录已存在: %s',root); end
addpath(fullfile(project,'matlab'),fullfile(project,'config'));
cfg=preprocess_config;
cfg.subjects={'100206'}; % [示例] 只选一个已有 HCP 被试；通用批处理仍由 manifest 驱动。
cfg.runNames={'tfMRI_LANGUAGE_LR'};
source=psy.discover_hcp(cfg);
assert(isscalar(source),'HCP 示例应找到一个 LANGUAGE LR run');
addpath(cfg.spmPath); spm('defaults','fmri'); spm_jobman('initcfg');
mkdir(root); fixture=fullfile(root,'fixture'); mkdir(fixture);

% SPM 不能直接从 .nii.gz 逐帧读取，先只读解压到私有 fixture，再取前 8 帧。
% 保留原始仿射和 TR，避免为了接口试验重复处理 316 帧。
uncompressedBold=psy.stage_image(source.bold,fixture);
v=spm_vol(uncompressedBold); assert(numel(v)>=8);
shortBold=fullfile(fixture,'bold_first8.nii');
spm_file_merge(v(1:8),shortBold,spm_type('int16'),0.72);
assert(numel(spm_vol(shortBold))==8);

% 生成有界、非零且与 EPI 同空间的合成相位差和幅度图，单位分别为弧度和原信号强度。
% 这里不借用该 HCP 被试的结构像 GRE：其扫描日/匀场组与 LANGUAGE EPI 不同。
first=spm_read_vols(v(1)); dims=size(first);
[i,j,k]=ndgrid(linspace(-1,1,dims(1)),linspace(-1,1,dims(2)), ...
    linspace(-1,1,dims(3)));
phase=single(0.10*i+0.05*j+0.03*k);
magnitude=single(max(first,0));
phaseFile=fullfile(fixture,'synthetic_phasediff_rad.nii');
magFile=fullfile(fixture,'synthetic_magnitude.nii');
write_like(v(1),phaseFile,phase);
write_like(v(1),magFile,magnitude);

fieldmaps=struct('Type','phasediff','Units','rad', ...
    'EchoTime1',0.00492,'EchoTime2',0.00738,'SPMBlipDirection',-1, ...
    'Images',[struct('Role','phasediff','Path','synthetic_phasediff_rad.nii'), ...
              struct('Role','magnitude','Path','synthetic_magnitude.nii')]);
fieldmapJson=fullfile(fixture,'fieldmaps.json'); write_json(fieldmapJson,fieldmaps);
metadata=struct('RepetitionTime',0.72,'TotalReadoutTime',0.05162, ...
    'SPMTotalReadoutTimeMs',51.62);
metaI=metadata; metaI.PhaseEncodingDirection='i-';
metaJ=metadata; metaJ.PhaseEncodingDirection='j-';
metaIFile=fullfile(fixture,'metadata_applyvdm.json');
metaJFile=fullfile(fixture,'metadata_unwarp_SYNTHETIC_AP.json');
write_json(metaIFile,metaI); write_json(metaJFile,metaJ);

cfg.inputMode='manifest'; cfg.subjects={}; cfg.runNames={};
cfg.execute=true; cfg.stopAfter='smooth'; cfg.continueOnError=false;
cfg.resume=false; cfg.sdc.method='none'; cfg.sliceTiming.mode='off';
cfg.sliceTiming.enabled=false;
% 第 2 次批处理在第 1 次成功后复用同一 T1 的 Segment；read_manifest
% 会先检查复用目录，因此两次调用须顺序执行，不能提前合成一个清单。
cfg.outputRoot=fullfile(root,'processed_applyvdm'); % [测试输出] 每次试验必须为新目录。
cfg.manifestFile=fullfile(fixture,'runs_applyvdm.tsv');
write_manifest(cfg.manifestFile,'engineering_applyvdm',shortBold,source.t1, ...
    metaIFile,fieldmapJson,'spm_fieldmap_applyvdm','');
firstReport=psy.preprocess_batch(cfg);
assert(isscalar(firstReport) && strcmp(firstReport.status, ...
    'spatial_pipeline_after_spm_fieldmap_applyvdm'), ...
    'Apply VDM 未完成平滑，停止后续解剖复用');
reuseDir=fullfile(firstReport.output,'anat');
cfg.outputRoot=fullfile(root,'processed_unwarp');
cfg.manifestFile=fullfile(fixture,'runs_unwarp.tsv');
write_manifest(cfg.manifestFile,'engineering_unwarp',shortBold,source.t1, ...
    metaJFile,fieldmapJson,'spm_fieldmap_unwarp',reuseDir);
secondReport=psy.preprocess_batch(cfg);
report=[firstReport secondReport];
assert(numel(report)==2 && all(startsWith({report.status},'spatial_pipeline_after_')), ...
    '两条路线都应到达 SPM 平滑后才算端到端通过');
for n=1:numel(report)
    assert(isfile(fullfile(report(n).output,'COMPLETE.mat')));
    assert(isfile(fullfile(report(n).output,'06_smooth.mat')));
end
save(fullfile(root,'fullchain_report.mat'),'report');
end

function write_manifest(path,runName,bold,t1,metadata,fieldmaps,method,reuseDir)
fid=fopen(path,'w'); assert(fid>0);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,['subject\tsession\trun\tbold\tt1\tinput_stage\tmetadata\tfieldmaps\t' ...
    'sdc_method\tanatomy_reuse_dir\n']);
fprintf(fid,'100206\t\t%s\t%s\t%s\traw\t%s\t%s\t%s\t%s\n', ...
    runName,bold,t1,metadata,fieldmaps,method,reuseDir);
end

function write_like(reference,path,data)
out=reference; out.fname=path; out.n=[1 1];
out.dt=[spm_type('float32') 0]; out.pinfo=[1;0;0];
spm_write_vol(out,data);
end

function write_json(path,value)
fid=fopen(path,'w'); assert(fid>0);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(value,PrettyPrint=true));
end
