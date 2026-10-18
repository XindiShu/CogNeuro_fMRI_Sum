function result=bold_unwarp_finalize(spec,cfg,plan,out)
%BOLD_UNWARP_FINALIZE 不重跑 FSL；核验已写结果、计算 QC 和完成记录。
required={fullfile(out,'se_to_sbref.mat'),fullfile(out,'se_registered.nii.gz'), ...
    fullfile(out,'field_sbref_rad.nii.gz'),fullfile(out,'bold_warp.nii.gz'), ...
    fullfile(out,'sbref_unwarped.nii.gz'),fullfile(out,'bold_unwarped.nii.gz')};
if cfg.jacobianModulation
    required=[required,{fullfile(out,'jacobian_raw.nii.gz'),fullfile(out,'jacobian.nii.gz'), ...
        fullfile(out,'bold_unwarped_jac.nii.gz')}];
end
if ~all(cellfun(@isfile,required)), error('psy:BoldUnwarpOutput','必要输出缺失，不能标记完成'); end
qc=psy.bold_unwarp_qc(spec,plan,out,cfg);
result=struct('status','bold_susceptibility_unwarped_pre_motion','outputDir',out,'qc',qc);
summary=struct('status',result.status,'inputs',spec,'parameters',cfg,'plan',plan, ...
    'qc',qc,'outputs',{required},'completedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
file=fullfile(out,'BOLD_UNWARP_COMPLETE.json');
if isfile(file), error('psy:BoldUnwarpExisting','完成记录已存在，拒绝覆盖'); end
fid=fopen(file,'w');
if fid<0, error('psy:BoldUnwarpWrite','无法写完成记录'); end
fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true));fclose(fid);
chosen=fullfile(out,'bold_unwarped.nii.gz');
if cfg.jacobianModulation, chosen=fullfile(out,'bold_unwarped_jac.nii.gz'); end
provenance=struct('Pipeline','psy.bold_unwarp_run','Version','1', ...
    'Space','native_BOLD_SBRef','Description','TOPUP-derived field registered to SBRef; susceptibility unwarp only, before motion correction', ...
    'CorrectionStatus','completed','ProcessingStage','sdc_only', ...
    'OutputFile',chosen,'CompletionFile',file);
fid=fopen(fullfile(out,'provenance.json'),'w');
fprintf(fid,'%s',jsonencode(provenance,PrettyPrint=true));fclose(fid);
end
