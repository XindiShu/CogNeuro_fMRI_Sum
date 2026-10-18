function results=validate_hcp_stage2_dcm(workspace)
%VALIDATE_HCP_STAGE2_DCM 三人REST spectral DCM/PEB及一人任务DCM工程验证。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function('D:/matlab/atoolbox/spm12');
out=fullfile(workspace,'derivatives','function_stage2_dcm_20261017');if isfolder(out),error('cog:Exists','Do not repeat a successful example');end;mkdir(out);
subjects=["100206";"100307";"100408"];tab=table;first=fullfile(workspace,'derivatives','function_stage1_real_20261016');base=function_config;base.clean.bandHz=[];
for k=1:3
    prepared=fullfile(first,'prepared',subjects(k));[y,space]=cog.load_bold(fullfile(prepared,'rest_prefix.nii'),fullfile(prepared,'engineering_mask.nii'),.72,2);
    [clean,cleanInfo]=cog.clean_timeseries(y,.72,[],base.clean);[roi,coverage]=cog.roi_extract(clean,space,fullfile(prepared,'engineering_rois.nii'),3);
    data=struct('y',roi(:,1:2),'trSeconds',.72,'roiNames',{{'left_engineering','right_engineering'}},'TESeconds',.0331,'delaysSeconds',[.36;.36],'X0',ones(size(roi,1),1), ...
        'note','HCP released highpassed/cleaned volume prefix256; two fixed engineering spheres, no added bandpass. TE=.0331s is an explicit engineering assumption, not local protocol verification.');
    file=fullfile(out,subjects(k)+"_rest_data.mat");save(file,'data','cleanInfo','coverage');row=table(subjects(k),"","REST1_LR_prefix256",string(file),'VariableNames',{'subject','session','run','data_file'});tab=[tab;row]; %#ok<AGROW>
end
manifest=fullfile(out,'rest_runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');cfg=dcm_config;cfg.manifestFile=manifest;cfg.mode='spectral';cfg.execute=true;cfg.options.maxIterations=32;cfg.models=struct('id','full','a',ones(2),'b',[],'c',[]);cfg.outputRoot=fullfile(out,'spectral_results');
results.spectral=run_dcm(cfg);catalog=cog.read_tsv(fullfile(cfg.outputRoot,'dcm_catalog.tsv'));group=table(catalog.subject,catalog.dcm_file,'VariableNames',{'subject','dcm_file'});gf=fullfile(out,'group.tsv');writetable(group,gf,'FileType','text','Delimiter','\t');
g=dcm_group_config;g.manifestFile=gf;g.execute=true;g.outputRoot=fullfile(out,'peb_results');g.maxIterations=32;results.peb=run_dcm_group(g);
% 任务侧复用已完成一级模型，两个独立工程种子，原模型不写入。
source=fullfile(workspace,'derivatives','hcp_sdc_glm_validation','sub-100206','tfMRI_LANGUAGE_LR','SPM.mat');s=load(source,'SPM');v=s.SPM.VM;v.fname=cog.resolve_path(v.fname,fileparts(source));mask=spm_read_vols(v)>0;idx=find(mask);pick=idx(round(linspace(1,numel(idx),48)));
roiFiles=strings(2,1);for k=1:2,d=zeros(v.dim);d(pick((k-1)*16+(1:16)))=1;v.fname=fullfile(out,sprintf('task_roi_%d.nii',k));v.dt=[16 0];v.pinfo=[1;0;0];spm_write_vol(v,d);roiFiles(k)=string(v.fname);end
rt=table(["region1";"region2"],roiFiles,'VariableNames',{'name','mask_file'});rf=fullfile(out,'task_rois.tsv');writetable(rt,rf,'FileType','text','Delimiter','\t');
cog.prepare_dcm_spm(source,rf,1,.0331,fullfile(out,'task_voi'));tf=fullfile(out,'task_runs.tsv');tt=table("100206","","LANGUAGE_LR",string(fullfile(out,'task_voi','dcm_data.mat')),'VariableNames',{'subject','session','run','data_file'});writetable(tt,tf,'FileType','text','Delimiter','\t');
c=dcm_config;c.execute=true;c.manifestFile=tf;c.outputRoot=fullfile(out,'task_results');c.options.maxIterations=32;b=zeros(2,2,2);b(2,1,1)=1;c.models=struct('id','full','a',ones(2),'b',b,'c',ones(2,2));results.task=run_dcm(c);
results.scope='Engineering only: 3 two-node spectral models/PEB/BMR/BMA from 256 frames and one two-node task DCM from native 316-frame VOIs, max32 iterations. No convergence/identifiability or scientific network interpretation claim.';cog.write_json(fullfile(out,'VALIDATION.json'),results);
end
