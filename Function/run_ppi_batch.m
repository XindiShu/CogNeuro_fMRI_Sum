function records=run_ppi_batch(cfg,manifest)
%RUN_PPI_BATCH 多被试/session/run清单；与HCP无关，已存在输出不覆盖。
required={'subject','session','run','spm_mat','seed_mask','spm_session_index'};t=cog.read_tsv(manifest,required);base=fileparts(manifest);
keys=t.subject+"/"+t.session+"/"+t.run;if isempty(t)||numel(unique(lower(keys)))~=height(t),error('cog:Manifest','Nonempty unique PPI keys required');end
records=cell(height(t),1);
for k=1:height(t)
    for f={'subject','session','run'}
        value=char(t.(f{1})(k));if strcmp(f{1},'session')&&isempty(value),continue;end
        if isempty(regexp(value,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:Manifest','Unsafe PPI identifier');end
    end
    one=cfg;one.spmMat=cog.resolve_path(t.spm_mat(k),base);one.seedMask=cog.resolve_path(t.seed_mask(k),base);one.sessionIndex=str2double(t.spm_session_index(k));
    parts={char(t.subject(k))};if strlength(t.session(k))>0,parts{end+1}=char(t.session(k));end;parts{end+1}=char(t.run(k));one.outputRoot=fullfile(cfg.outputRoot,parts{:});
    records{k}=run_ppi(one);
end
end
