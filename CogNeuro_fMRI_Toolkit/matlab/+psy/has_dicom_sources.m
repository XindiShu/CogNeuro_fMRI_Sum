function yes=has_dicom_sources(run)
%HAS_DICOM_SOURCES 清单的 BOLD/T1/SBRef 或场图 Path 是否为 DICOM 序列目录。
yes=any(cellfun(@isfolder,{run.bold,run.t1,run.sbref}));
if isfield(run,'fieldmaps') && ~isempty(run.fieldmaps)
    map=jsondecode(fileread(run.fieldmaps));
    if isfield(map,'Images')
        base=fileparts(run.fieldmaps);
        for k=1:numel(map.Images)
            p=map.Images(k).Path;
            if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
            yes=yes || isfolder(p);
        end
    end
end
end
