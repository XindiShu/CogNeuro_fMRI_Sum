function c=inspect_contract(run,info)
%INSPECT_CONTRACT 只核查与记录输入约定；不执行畸变校正/去噪/事件建模。
c=struct('metadataStatus','not_supplied','eventsStatus','not_supplied', ...
    'fieldmapsStatus','not_supplied','provenanceStatus','not_supplied');
if present(run,'metadata')
    m=jsondecode(fileread(run.metadata));
    if isfield(m,'RepetitionTime')
        positive(m.RepetitionTime,'RepetitionTime');
        if abs(m.RepetitionTime-info.trSeconds)>1e-4, error('psy:MetadataTR','JSON/header TR mismatch'); end
    end
    if isfield(m,'SliceTiming')
        s=m.SliceTiming;
        if ~isnumeric(s) || numel(s)~=info.size(3) || any(~isfinite(s(:))|s(:)<0|s(:)>=info.trSeconds)
            error('psy:MetadataTiming','Invalid SliceTiming seconds');
        end
    end
    if isfield(m,'PhaseEncodingDirection'), direction(m.PhaseEncodingDirection); end
    if isfield(m,'TotalReadoutTime'), positive(m.TotalReadoutTime,'TotalReadoutTime'); end
    if isfield(m,'SPMTotalReadoutTimeMs'), positive(m.SPMTotalReadoutTimeMs,'SPMTotalReadoutTimeMs'); end
    c.metadata=m; c.metadataStatus='checked_supplied_fields';
end
if present(run,'events')
    c.events=psy.read_events_tsv(run.events,info.durationSeconds); c.eventsStatus='checked';
end
if present(run,'fieldmaps')
    f=psy.inspect_fieldmaps(run.fieldmaps);
    c.fieldmaps=f; c.fieldmapsStatus='inventory_checked_correction_pending';
end
if present(run,'provenance')
    p=jsondecode(fileread(run.provenance));
    for key={'Pipeline','Version','Space','Description'}
        if ~isfield(p,key{1}) || ~(ischar(p.(key{1})) && ~isempty(strtrim(p.(key{1})))) || startsWith(p.(key{1}),'REPLACE')
            error('psy:Provenance','Provenance needs nonempty Pipeline/Version/Space/Description');
        end
    end
    c.provenance=p; c.provenanceStatus='declared_not_independently_verified';
    if isfield(run,'inputStage') && strcmp(run.inputStage,'sdc_corrected')
        fields={'CorrectionStatus','ProcessingStage','OutputFile','CompletionFile'};
        if ~all(isfield(p,fields)) || ~strcmp(p.CorrectionStatus,'completed') || ...
                ~strcmp(p.ProcessingStage,'sdc_only') || ~isfile(p.CompletionFile) || ...
                ~strcmp(char(java.io.File(p.OutputFile).getCanonicalPath()),run.bold)
            error('psy:SDCProvenance','sdc_corrected 必须有匹配影像的完成记录，且尚未做头动/空间处理');
        end
        marker=jsondecode(fileread(p.CompletionFile));
        if ~isfield(marker,'status') || ~strcmp(marker.status,'bold_susceptibility_unwarped_pre_motion')
            error('psy:SDCProvenance','畸变校正完成记录的状态不匹配');
        end
        c.provenanceStatus='sdc_completion_record_checked';
    end
end
end
function yes=present(r,k)
yes=isfield(r,k) && ~isempty(r.(k));
end
function positive(v,name)
if ~(isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0), error('psy:MetadataValue','%s must be positive seconds',name); end
end
function direction(v)
if ~ischar(v) || ~ismember(v,{'i','i-','j','j-','k','k-'}), error('psy:PEDirection','Use NIfTI i/j/k direction, not LR/AP labels'); end
end
