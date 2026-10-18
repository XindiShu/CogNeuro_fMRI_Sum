function summary=validate_hcp_stage1_timeseries(workspace)
%VALIDATE_HCP_STAGE1_TIMESERIES 三人REST前256帧+6固定工程球ROI，不重跑预处理。
% HCP路径只在此适配器；前缀由stage_nifti_prefix.py预先生成。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
root=fullfile(workspace,'function_toolkit');addpath(root);setup_function('D:/matlab/atoolbox/spm12');
work=fullfile(workspace,'derivatives','function_stage1_real_20261016');subjects=["100206";"100307";"100408"];n=numel(subjects);tab=table;
centers=[-42 -24 18;42 -24 18;-24 -56 22;24 -56 22;-8 50 20;8 50 20];radius=8; % [示例可调] 毫米；独立于功能统计的固定位置，仅工程ROI。
for k=1:n
    prepared=fullfile(work,'prepared',char(subjects(k)));bold=fullfile(prepared,'rest_prefix.nii');v=spm_vol(bold);
    src=fullfile('D:/IBM',subjects(k)+"_extracted",subjects(k)+"_Rest3TRecommended",subjects(k),'MNINonLinear','Results','rfMRI_REST1_LR','brainmask_fs.2.nii.gz');
    maskCopy=fullfile(prepared,'brainmask_fs.2.nii');if ~isfile(maskCopy),gunzip(char(src),prepared);end
    mv=spm_vol(maskCopy);cog.check_grid(v(1),mv);brain=spm_read_vols(mv)>0;
    [i,j,z]=ndgrid(1:mv.dim(1),1:mv.dim(2),1:mv.dim(3));xyz=mv.mat*[i(:)';j(:)';z(:)';ones(1,numel(i))];labels=zeros(mv.dim);
    for c=1:size(centers,1),d=sum((xyz(1:3,:)'-centers(c,:)).^2,2);labels(d<=radius^2&brain(:))=c;end
    mask=labels>0;roiFile=fullfile(prepared,'engineering_rois.nii');maskFile=fullfile(prepared,'engineering_mask.nii');
    if ~isfile(roiFile),writeImage(roiFile,labels,mv);writeImage(maskFile,double(mask),mv);end
    row=table(subjects(k),"", "REST1_LR_prefix256",string(bold),string(maskFile),string(roiFile),.72,"nuisance_regressed_highpassed",0,"","engineering", ...
        'VariableNames',{'subject','session','run','bold','mask','roi_file','tr_seconds','temporal_state','smoothing_fwhm_mm','confounds','purpose'});
    tab=[tab;row]; %#ok<AGROW>
end
manifest=fullfile(work,'rest_runs.tsv');writetable(tab,manifest,'FileType','text','Delimiter','\t');
cfg=function_config;cfg.manifestFile=manifest;cfg.outputRoot=fullfile(work,'timeseries_results');cfg.methods={'static_fc','alff','reho'};cfg.execute=true;cfg.fc.seedColumns=[1 2];cfg.clean.bandHz=[.01 .08];
summary=run_function(cfg);summary.validationScope='3 subjects, REST1 LR prefix 256/1200 frames, six fixed engineering spheres. HCP released hp2000 clean/rclean/tclean volume; additional DCT bandpass only for FC/ReHo. ALFF/fALFF denominator is the retained spectrum after upstream HCP highpass/cleaning; no claim of raw-spectrum equivalence. Not a full-brain analysis or scientific validation.';
cog.write_json(fullfile(work,'HCP_TIMESERIES_VALIDATION.json'),summary);assert(summary.failed==0,'HCP example failed');
end
function writeImage(file,d,ref)
ref.fname=file;ref.dt=[16 0];ref.pinfo=[1;0;0];ref.n=[1 1];spm_write_vol(ref,d);
end
