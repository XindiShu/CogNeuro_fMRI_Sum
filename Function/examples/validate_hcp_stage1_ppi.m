function summary=validate_hcp_stage1_ppi(workspace)
%VALIDATE_HCP_STAGE1_PPI 原已估计LANGUAGE模型，少量mask体素验证SPM完整接口。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function('D:/matlab/atoolbox/spm12');
cfg=ppi_config;cfg.spmMat=fullfile(workspace,'derivatives','hcp_sdc_glm_validation','sub-100206','tfMRI_LANGUAGE_LR','SPM.mat');
folder=fullfile(workspace,'derivatives','function_stage1_real_20261016','ppi_inputs');if isfolder(folder),error('cog:Exists','PPI example staging exists');end;mkdir(folder);
source=fileparts(cfg.spmMat);before=readBytes(cfg.spmMat);listing=dir(source);namesBefore=sort(string({listing.name}));s=load(cfg.spmMat,'SPM');v=s.SPM.VM;
v.fname=cog.resolve_path(v.fname,source);m=spm_read_vols(v);idx=find(m>0);pick=idx(round(linspace(1,numel(idx),512)));mask=zeros(v.dim);mask(pick)=1;seed=zeros(v.dim);seed(pick(1:16))=1;
cfg.seedMask=fullfile(folder,'engineering_seed.nii');v.fname=cfg.seedMask;v.dt=[16 0];v.pinfo=[1;0;0];spm_write_vol(v,seed);
cfg.analysisMask=fullfile(folder,'engineering_targets.nii');v.fname=cfg.analysisMask;spm_write_vol(v,mask);
cfg.execute=true;cfg.outputRoot=fullfile(fileparts(folder),'gppi_results');summary=run_ppi(cfg);
assert(isequal(before,readBytes(cfg.spmMat)),'Original SPM changed');listing=dir(source);assert(isequal(namesBefore,sort(string({listing.name}))),'Original model directory gained files');
summary.validationScope='One real 316-frame LANGUAGE run, 16 fixed engineering seed voxels and 512 fixed target voxels; native SPM VOI adjustment/deconvolution/gPPI+FAST estimation, no scientific ROI interpretation.';
cog.write_json(fullfile(fileparts(folder),'HCP_GPPI_VALIDATION.json'),summary);
end
function b=readBytes(file)
f=fopen(file,'rb');c=onCleanup(@()fclose(f));b=fread(f,Inf,'*uint8'); %#ok<NASGU>
end
