function results=validate_hcp_stage2_searchlight(workspace)
%VALIDATE_HCP_STAGE2_SEARCHLIGHT 复用TYPEB beta，仅少量固定中心和低置换次数。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function('D:/matlab/atoolbox/spm12');out=fullfile(workspace,'derivatives','function_stage2_searchlight_20261017_02');if isfolder(out),error('cog:Exists','Preserve successful output');end;mkdir(out);
catalog=fullfile(workspace,'derivatives','function_stage1_real_20261016','patterns_results','selected_catalog.tsv');t=cog.read_tsv(catalog);subjects=unique(t.subject);d=[];
for k=1:numel(subjects)
    masks=unique(t.mask_path(t.subject==subjects(k)));common=[];for j=1:numel(masks),v=spm_vol(char(masks(j)));m=spm_read_vols(v)>0;if isempty(common),common=m;else,common=common&m;end;end
    ids=find(common);[i,j,h]=ind2sub(v.dim,ids);xyz=v.mat*[i';j';h';ones(1,numel(ids))];neighbors=rangesearch(xyz(1:3,:)',xyz(1:3,:)',4);eligible=find(cellfun(@numel,neighbors)>=3);if isempty(eligible),error('cog:ExampleCoverage','No adequate engineering neighborhoods');end
    if isempty(d),d=zeros(v.dim);end;pick=eligible(round(linspace(1,numel(eligible),min(12,numel(eligible)))));d(ids(pick))=1;
end
v.fname=fullfile(out,'fixed_centers.nii');v.dt=[16 0];v.pinfo=[1;0;0];spm_write_vol(v,d);
c=searchlight_config;c.catalogFile=catalog;c.centerMaskFile=v.fname;c.outputRoot=fullfile(out,'decode');c.execute=true;c.options.radiusMm=4;c.options.nPermutations=9;c.options.exchangeabilityJustification='Engineering only: beta labels shuffled within run to test the numerical path; upstream GLMsingle HRF was selected across both runs, trial-level exchangeability and end-to-end CV are not established.';
results.decode=run_searchlight(c);c.options.mode='rsa';c.options.rsa.metric='euclidean';c.options.nPermutations=0;c.outputRoot=fullfile(out,'rsa');results.rsa=run_searchlight(c);
results.scope='2 HCP subjects, 50 total TYPEB units, 2 runs each. Each subject retains its own common mask (4096 sparse engineering voxels); union of 12 fixed eligible centers per subject, radius4mm/min3 voxels. LDA/9 engineering permutations and Euclidean mean-distance RSA. Two conditions cannot support model-RDM rank correlation; that real-data case skipped. No scientific p-value or leakage-free upstream CV claim. Earlier cross-subject mask-intersection attempt failed before scores and is preserved separately.';cog.write_json(fullfile(out,'VALIDATION.json'),results);
end
