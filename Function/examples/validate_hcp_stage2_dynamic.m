function summary=validate_hcp_stage2_dynamic(workspace)
%VALIDATE_HCP_STAGE2_DYNAMIC 复用已完成ROI时序，不重读/重滤原始影像。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function;out=fullfile(workspace,'derivatives','function_stage2_dynamic_20261017');if isfolder(out),error('cog:Exists','Preserve successful output');end;mkdir(out);
subjects=["100206";"100307";"100408"];tab=table;
for k=1:3
    source=fullfile(workspace,'derivatives','function_stage1_real_20261016','timeseries_results',subjects(k),'REST1_LR_prefix256','roi_timeseries.mat');s=load(source);data=struct('y',s.roi,'trSeconds',.72,'roiNames',"roi"+string(s.roiInfo.label),'frameIndices',(1:size(s.roi,1))','source',source,'processing',s.cleanInfo);file=fullfile(out,subjects(k)+"_data.mat");save(file,'data');tab=[tab;table(subjects(k),"","REST1_LR_prefix256",string(file),'VariableNames',{'subject','session','run','data_file'})]; %#ok<AGROW>
end
manifest=fullfile(out,'runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');c=dynamic_fc_config;c.manifestFile=manifest;c.outputRoot=fullfile(out,'results');c.options.stepSeconds=5;c.options.nSurrogates=19;c.execute=true;summary=run_dynamic_fc(c);summary.scope='Three 256-frame REST runs/6 engineering ROIs, reused .01-.08Hz DCT-cleaned ROI series; 30/60/90sec windows rounded to TR=.72s, Gaussian weights, 19 shared-phase surrogates. Engineering sensitivity only, p resolution .05, no scientific state-change claim or evidence of stationarity/adequate scan length.';cog.write_json(fullfile(out,'VALIDATION.json'),summary);
end
