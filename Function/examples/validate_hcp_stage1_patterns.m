function outputs=validate_hcp_stage1_patterns(workspace)
%VALIDATE_HCP_STAGE1_PATTERNS 复用已完成GLMsingle TYPEB与LSA，不重估。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function('D:/matlab/atoolbox/spm12');
out=fullfile(workspace,'derivatives','function_stage1_real_20261016','patterns_inputs');if isfolder(out),error('cog:Exists','Example input staging already exists');end;mkdir(out);
demo=fullfile(workspace,'derivatives','glmsingle_hcp_demo_20261016_131115','hcp_example');runs=cog.read_tsv(fullfile(demo,'prepared','runs.tsv'));
catalog=table;
for subject=["100307","100408"]
    folder=fullfile(demo,'models',"sub-"+subject,'combined');map=cog.read_tsv(fullfile(folder,'TYPEB','beta_mapping.tsv'));groupRuns=runs(runs.subject==subject,:);
    for k=1:height(map)
        ri=str2double(map.run_index(k));row=table("B_"+subject+"_"+string(k),"glmsingle_B",subject,"",groupRuns.run(ri),map.condition(k),"event",map.beta_file(k),map.beta_index(k),string(fullfile(folder,'analysis_mask.nii')), ...
            'VariableNames',{'estimate_id','source_id','subject','session','run','condition','estimate_unit','image_path','volume_index','mask_path'});catalog=[catalog;row]; %#ok<AGROW>
    end
end
file=fullfile(out,'glmsingle_B_catalog.tsv');writetable(catalog,file,'FileType','text','Delimiter','\t');
% 使用原有与任务统计无关的工程掩膜，按空间x分半为两个工程ROI。
ref=spm_vol(char(catalog.mask_path(1)));mask=spm_read_vols(ref)>0;labels=zeros(ref.dim);[i,~,~]=ndgrid(1:ref.dim(1),1:ref.dim(2),1:ref.dim(3));labels(mask&i<=ref.dim(1)/2)=1;labels(mask&i>ref.dim(1)/2)=2;
roi=fullfile(out,'engineering_roi_halves.nii');ref.fname=roi;ref.dt=[16 0];ref.pinfo=[1;0;0];spm_write_vol(ref,labels);
cfg=roi_patterns_config;cfg.catalogFile=file;cfg.roiFile=roi;cfg.execute=true;cfg.outputRoot=fullfile(fileparts(out),'patterns_results');cfg.sourceId='glmsingle_B';cfg.roiMinVoxels=3;
outputs=run_roi_patterns(cfg);outputs.validationScope='Two subjects (100307/100408), two LANGUAGE runs each, previously completed GLMsingle TYPEB event beta. Fixed spatial engineering ROIs. Upstream HRF/library fitting used multiple runs, so downstream leave-run classifier is engineering validation, not end-to-end independent predictive evidence. Story and math input rows have heterogeneous durations.';
cog.write_json(fullfile(fileparts(out),'HCP_PATTERNS_VALIDATION.json'),outputs);
end
