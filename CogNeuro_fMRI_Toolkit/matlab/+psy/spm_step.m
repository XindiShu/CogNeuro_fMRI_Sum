function spm_step(batch, filename)
%SPM_STEP Persist each exact SPM job before execution.
matlabbatch=batch; %#ok<NASGU>
save(filename,'matlabbatch');
spm_jobman('run',batch);
end
