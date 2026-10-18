function output=import_dicom_series(sourceDir,outputDir,role,trSeconds)
%IMPORT_DICOM_SERIES 用 SPM DICOM Import 转换一条明确指定的扫描序列。
% sourceDir 只放一个 SeriesInstanceUID；原始 DICOM 只读。SPM 先写 3D NIfTI，
% 本函数再把 BOLD 按 SPM 返回的顺序合并为 4D。不得靠目录名猜任务或场图。
if nargin<4, trSeconds=[]; end
if ~isfolder(sourceDir), error('psy:DICOMDirectory','DICOM 目录不存在: %s',sourceDir); end
files=dir(fullfile(sourceDir,'**','*'));
files=files(~[files.isdir]);
files=files(~startsWith({files.name},'.'));
if isempty(files), error('psy:DICOMEmpty','DICOM 目录为空: %s',sourceDir); end
[~,order]=sort(fullfile({files.folder},{files.name})); files=files(order);
paths=fullfile({files.folder},{files.name}); paths=paths(:);
inventory=struct('source',char(java.io.File(sourceDir).getCanonicalPath()), ...
    'files',{paths},'bytes',[files.bytes],'dates',[files.datenum], ...
    'role',role,'trSeconds',trSeconds);
signature=jsonencode(inventory);
target=fullfile(outputDir,[role '.nii']);
marker=fullfile(outputDir,'DICOM_IMPORT_COMPLETE.mat');
if isfile(marker)
    old=load(marker,'signature','output');
    if strcmp(old.signature,signature) && isfile(old.output)
        output=old.output; return
    end
    error('psy:DICOMChanged','DICOM 来源或参数已变化；请使用新的 outputRoot');
end
if isfolder(outputDir), error('psy:DICOMPartial','DICOM 转换目录已存在且未完成: %s',outputDir); end
if strcmp(role,'bold') && (~isscalar(trSeconds) || ~isnumeric(trSeconds) || ...
        ~isfinite(trSeconds) || trSeconds<=0)
    error('psy:DICOMTR','DICOM BOLD 需要逐 run metadata JSON 中核实的 RepetitionTime（秒）');
end
mkdir(outputDir);
headers=spm_dicom_headers(char(paths),true);
if numel(headers)~=numel(paths)
    error('psy:DICOMHeader','有 DICOM 文件无法读取；目录必须仅包含当前序列');
end
uids=cellfun(@(h)get_uid(h),headers,'UniformOutput',false);
uids=uids(~cellfun(@isempty,uids));
if numel(unique(uids))>1
    error('psy:DICOMMixedSeries','同一目录含多个 DICOM SeriesInstanceUID；请逐序列分目录');
end
convertedDir=fullfile(outputDir,'spm_3d'); mkdir(convertedDir);
job={};
job{1}.spm.util.import.dicom.data=paths;
job{1}.spm.util.import.dicom.root='flat';
job{1}.spm.util.import.dicom.outdir={convertedDir};
job{1}.spm.util.import.dicom.protfilter='.*';
job{1}.spm.util.import.dicom.convopts.format='nii';
job{1}.spm.util.import.dicom.convopts.meta=0;
job{1}.spm.util.import.dicom.convopts.icedims=0;
save(fullfile(outputDir,'spm_dicom_import_job.mat'),'job');
result=spm_jobman('run',job);
images=result{1}.files;
images=images(~cellfun(@isempty,images));
if isempty(images) || ~all(cellfun(@isfile,images))
    error('psy:DICOMConversion','SPM 未生成完整 NIfTI 序列: %s',sourceDir);
end
images=sort(images(:)); % SPM 文件名含补零 InstanceNumber；保留可审计顺序。
volumes=spm_vol(char(images));
if strcmp(role,'t1') || strcmp(role,'sbref') || strcmp(role,'phasediff') || strcmp(role,'fieldmap_hz')
    if numel(volumes)~=1
        error('psy:DICOMShape','%s 应恰有一个 3D 体积，实际 %d',role,numel(volumes));
    end
    copyfile(images{1},target);
elseif strcmp(role,'magnitude')
    if ~ismember(numel(volumes),[1 2])
        error('psy:DICOMShape','magnitude 应为 1 或 2 个回波体积');
    end
    if isscalar(volumes), copyfile(images{1},target);
    else, spm_file_merge(volumes,target,0,1); end
elseif startsWith(role,'pepolar_')
    if isscalar(volumes), copyfile(images{1},target);
    else, spm_file_merge(volumes,target,0,1); end
else
    if numel(volumes)<2, error('psy:DICOMShape','%s 应至少有 2 帧',role); end
    if isempty(trSeconds), trSeconds=1; end % BOLD 已在上方强制真实 TR。
    spm_file_merge(volumes,target,0,trSeconds);
end
output=target;
save(marker,'signature','output','inventory','images');
end

function uid=get_uid(header)
uid='';
if isfield(header,'SeriesInstanceUID'), uid=char(string(header.SeriesInstanceUID)); end
end
