function summary=validate_hcp_stage2_gradients(workspace)
%VALIDATE_HCP_STAGE2_GRADIENTS 复用三人的6节点FC，仅检验原生梯度/对齐链。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function;out=fullfile(workspace,'derivatives','function_stage2_gradients_20261017');if isfolder(out),error('cog:Exists','Preserve successful output');end;mkdir(out);
subjects=["100206";"100307";"100408"];tab=table;
for k=1:3
    source=fullfile(workspace,'derivatives','function_stage1_real_20261016','timeseries_results',subjects(k),'REST1_LR_prefix256','static_fc.mat');s=load(source);matrix=s.fc.correlation;matrix(1:size(matrix,1)+1:end)=0;data=struct('matrix',matrix,'nodeIds',string(s.roiInfo.label),'featureIds',string(s.roiInfo.label),'source',source,'diagonalPolicy','explicit zero for this engineering example');file=fullfile(out,subjects(k)+"_data.mat");save(file,'data');tab=[tab;table(subjects(k),"","REST1_LR_prefix256",string(file),'VariableNames',{'subject','session','run','data_file'})]; %#ok<AGROW>
end
manifest=fullfile(out,'inputs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');c=gradient_config;c.manifestFile=manifest;c.outputRoot=fullfile(out,'results');c.brainSpacePath='D:/matlab/atoolbox/BrainSpace_function_20261017/matlab';c.execute=true;c.options.nComponents=2;c.options.sparsityPercent=0;summary=run_gradients(c);summary.scope='Three 6-node engineering FC profiles, explicit zero diagonal, normalized-angle/diffusion/PA, sparsity0. File-chain test only, not macroscale gradient interpretation. Real Moran/spin association omitted: no scientific spatial marker in this prepared input and ROI values do not form a cortical vertex map.';cog.write_json(fullfile(out,'VALIDATION.json'),summary);
end
