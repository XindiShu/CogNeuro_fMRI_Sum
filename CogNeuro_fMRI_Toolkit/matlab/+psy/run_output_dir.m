function out = run_output_dir(root,run)
%RUN_OUTPUT_DIR 按被试/session/run 分目录，同名 run 不会跨访视覆盖。
out=fullfile(root,['sub-' run.subject]);
if isfield(run,'session') && ~isempty(run.session)
    out=fullfile(out,['ses-' run.session]);
end
out=fullfile(out,run.name);
end
