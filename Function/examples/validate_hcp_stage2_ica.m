function summary=validate_hcp_stage2_ica(workspace)
%VALIDATE_HCP_STAGE2_ICA 三被试共同工程掩膜，空间ICA/双回归/FNC工程链。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function('D:/matlab/atoolbox/spm12');
out=fullfile(workspace,'derivatives','function_stage2_ica_20261017');if isfolder(out),error('cog:Exists','Preserve successful output');end;mkdir(out);
first=fullfile(workspace,'derivatives','function_stage1_real_20261016','prepared');subjects=["100206";"100307";"100408"];tab=table;base=function_config;base.clean.bandHz=[];
for k=1:3
    prepared=fullfile(first,subjects(k));file=fullfile(out,subjects(k)+"_data.mat");cog.prepare_ica_nifti(fullfile(prepared,'rest_prefix.nii'),fullfile(prepared,'engineering_mask.nii'),.72,[],base.clean,2,file);
    tab=[tab;table(subjects(k),"","REST1_LR_prefix256",string(file),'VariableNames',{'subject','session','run','data_file'})]; %#ok<AGROW>
end
manifest=fullfile(out,'runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');cfg=ica_config;cfg.manifestFile=manifest;cfg.outputRoot=fullfile(out,'results');cfg.giftPath='D:/matlab/atoolbox/gift_minimal_df369a2';cfg.nComponents=5;cfg.perRunPca=20;cfg.execute=true;
summary=run_ica(cfg);summary.scope='3 HCP REST1_LR prefix256 runs, same 6 engineering-sphere union, five components and per-run PCA20. Engineering only, no network-label, ICA stability or denoising efficacy claim.';cog.write_json(fullfile(out,'VALIDATION.json'),summary);
end
