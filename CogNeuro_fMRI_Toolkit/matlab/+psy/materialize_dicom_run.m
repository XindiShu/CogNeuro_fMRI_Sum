function run=materialize_dicom_run(run,cfg)
%MATERIALIZE_DICOM_RUN 将明示的单序列 DICOM 目录变成私有 NIfTI 后继续现有流水线。
% 不自动挑选扫描序列；场图 JSON 的 Images.Path 可指向单序列 DICOM 目录。
if ~psy.has_dicom_sources(run), return; end
if ~isfield(cfg,'dicom') || ~cfg.dicom.enabled || ~strcmp(run.inputStage,'raw')
    error('psy:DICOMMode','DICOM 输入只支持启用 cfg.dicom.enabled 的 raw 清单');
end
out=psy.run_output_dir(fullfile(cfg.outputRoot,'dicom_imports'),run);
tr=[];
if isfield(run,'metadata') && ~isempty(run.metadata)
    meta=jsondecode(fileread(run.metadata));
    if isfield(meta,'RepetitionTime'), tr=meta.RepetitionTime; end
end
for field={'bold','t1','sbref'}
    key=field{1};
    if isfolder(run.(key))
        run.(key)=psy.import_dicom_series(run.(key),fullfile(out,key),key,tr);
    end
end
if ~isempty(run.fieldmaps)
    map=jsondecode(fileread(run.fieldmaps));
    changed=false; base=fileparts(run.fieldmaps);
    for k=1:numel(map.Images)
        p=map.Images(k).Path;
        if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
        if ~isfolder(p), continue; end
        if strcmp(map.Type,'pepolar')
            role=sprintf('pepolar_%02d',k);
        else
            role=char(map.Images(k).Role);
        end
        map.Images(k).Path=psy.import_dicom_series(p,fullfile(out,'fieldmaps',role),role,[]);
        changed=true;
    end
    if changed
        localJson=fullfile(out,'fieldmaps_converted.json');
        payload=jsonencode(map,PrettyPrint=true);
        if isfile(localJson)
            if ~strcmp(fileread(localJson),payload)
                error('psy:DICOMChanged','已转换场图关联已变化；请使用新的 outputRoot');
            end
        else
            parent=fileparts(localJson); if ~isfolder(parent), mkdir(parent); end
            fid=fopen(localJson,'w'); c=onCleanup(@()fclose(fid));
            fwrite(fid,payload,'char'); clear c
        end
        run.fieldmaps=localJson;
    end
end
end
