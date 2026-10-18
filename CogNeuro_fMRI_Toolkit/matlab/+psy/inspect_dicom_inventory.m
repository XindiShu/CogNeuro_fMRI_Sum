function summary=inspect_dicom_inventory(run)
%INSPECT_DICOM_INVENTORY 只读检查明确关联的序列目录，不声称完成影像头预检。
paths={};
for field={'bold','t1','sbref'}
    p=run.(field{1}); if isfolder(p), paths{end+1}=p; end %#ok<AGROW>
end
if isfield(run,'fieldmaps') && ~isempty(run.fieldmaps)
    map=jsondecode(fileread(run.fieldmaps)); base=fileparts(run.fieldmaps);
    for k=1:numel(map.Images)
        p=map.Images(k).Path;
        if ~java.io.File(p).isAbsolute(), p=fullfile(base,p); end
        if isfolder(p), paths{end+1}=p; end %#ok<AGROW>
    end
end
summary=struct('seriesDirectories',{paths},'fileCounts',zeros(1,numel(paths)));
for k=1:numel(paths)
    listing=dir(fullfile(paths{k},'**','*'));
    listing=listing(~[listing.isdir]);
    if isempty(listing), error('psy:DICOMEmpty','DICOM 序列目录为空: %s',paths{k}); end
    summary.fileCounts(k)=numel(listing);
end
end
