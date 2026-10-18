function report=confound_design_batch(cfg)
%CONFOUND_DESIGN_BATCH 递归保持原有 subject/session/run 目录，一项失败后继续。
input=char(java.io.File(cfg.inputRoot).getCanonicalPath());
output=char(java.io.File(cfg.outputRoot).getCanonicalPath());
if ~isfolder(input), error('psy:DesignInput','Missing input root'); end
if isfolder(output)||strcmpi(input,output)||startsWith(lower(output),[lower(input) filesep])
    error('psy:DesignOutput','Choose a new output outside input root');
end
files=dir(fullfile(input,'**','confounds.tsv'));
if isempty(files), error('psy:NoRuns','No confounds.tsv found'); end
mkdir(output); report=struct([]);
for k=1:numel(files)
    source=fullfile(files(k).folder,files(k).name);
    relative=files(k).folder(numel(input)+1:end);
    relative=regexprep(relative,'^[\\/]+',''); out=fullfile(output,relative);
    row=struct('source',source,'status','failed','rank',NaN,'remainingDF',NaN,'message','');
    try
        if ~isfile(fullfile(files(k).folder,'COMPLETE.mat')), error('psy:IncompleteConfounds','No completion record'); end
        result=psy.confound_design(source,cfg); if ~isfolder(out), mkdir(out); end
        writetable(array2table(result.matrix,'VariableNames',result.names),fullfile(out,'design.tsv'),'FileType','text','Delimiter','\t');
        save(fullfile(out,'design.mat'),'result','cfg','source');
        row.status='design_validated_not_regressed'; row.rank=result.rank; row.remainingDF=result.remainingDF;
    catch ex
        row.message=ex.message;
    end
    if isempty(report), report=row; else, report(end+1)=row; end %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(output,'batch_status.tsv'),'FileType','text','Delimiter','\t');
end
end
