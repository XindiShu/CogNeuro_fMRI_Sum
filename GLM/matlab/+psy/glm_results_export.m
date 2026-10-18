function summary=glm_results_export(spmFile,index,opt,out)
%GLM_RESULTS_EXPORT 读取现成T/F模型，导出体素校正、簇峰表和图；不调用spm_getSPM改源模型。
spmFile=psy.glm_absolute_path(spmFile);folder=fileparts(spmFile);out=psy.glm_absolute_path(out);
if isfile(out)||isfolder(out),error('psy:GLMExists','Choose a new results export directory');end
if ~isnumeric(index)||~isscalar(index)||~isfinite(index)||index<1||fix(index)~=index,error('psy:GLMInference','Invalid contrast index');end
p=load(spmFile,'SPM');s=p.SPM;
if index>numel(s.xCon)||~ismember(s.xCon(index).STAT,{'T','F'}),error('psy:GLMInference','Choose an existing T/F contrast');end
c=s.xCon(index);stat=c.STAT;statFile=psy.glm_absolute_path(c.Vspm.fname,folder);maskFile=fullfile(folder,'mask.nii');
ref=spm_vol(maskFile);v=spm_vol(statFile);checkGrid(v,ref);mask=spm_read_vols(ref);
if any(~isfinite(mask(:))|mask(:)<0),error('psy:GLMInference','Invalid model mask');end
mask=mask>0;data=spm_read_vols(v);df=[c.eidf s.xX.erdf];resels=[];
if isfield(s,'xVol')&&isfield(s.xVol,'R'),resels=s.xVol.R;end
if isfield(s.xVol,'S')&&s.xVol.S~=nnz(mask),error('psy:GLMInference','SPM search volume differs from model mask');end
files=[string(spmFile);string(statFile);string(maskFile)];effectFile='';
if strcmp(stat,'T'),effectFile=psy.glm_absolute_path(c.Vcon.fname,folder);files(end+1)=effectFile;end
if ~isempty(opt.backgroundFile),opt.backgroundFile=psy.glm_absolute_path(opt.backgroundFile);files(end+1)=opt.backgroundFile;end
before=psy.glm_file_inventory(files);[pass,pValues,qValues,u,summary]=psy.glm_threshold(data(mask),stat,df,resels,opt);
selected=false(ref.dim);selected(mask)=pass;labels=zeros(ref.dim);clusterRows=struct([]);clusterId=0;
linear=find(selected);[x,y,z]=ind2sub(ref.dim,linear);xyz=[x y z]';
signs=1;if strcmp(stat,'T')&&strcmp(opt.tail,'negative'),signs=-1;end
if strcmp(stat,'T')&&strcmp(opt.tail,'two_sided'),signs=[1 -1];end
allP=NaN(ref.dim);allP(mask)=pValues;allQ=allP;allQ(mask)=qValues;
for sign=signs
    pick=true(size(linear));if strcmp(stat,'T'),pick=sign*data(linear)>0;end
    indices=linear(pick);if isempty(indices),continue;end
    components=spm_clusters(xyz(:,pick),opt.connectivity);
    for component=reshape(unique(components),1,[])
        vox=indices(components==component);
        if isempty(vox)||numel(vox)<opt.minClusterVoxels,continue;end
        clusterId=clusterId+1;labels(vox)=clusterId;[~,peak]=max(sign*data(vox));peak=vox(peak);[i,j,k]=ind2sub(ref.dim,peak);mm=ref.mat*[i;j;k;1];
        fwe=NaN;
        if numel(resels)==4&&all(isfinite(resels))&&any(resels>0)
            fwe=spm_P(1,0,sign*data(peak),df,stat,resels,1,nnz(mask));
            if strcmp(opt.tail,'two_sided'),fwe=min(1,2*fwe);end
        end
        row=struct('cluster_id',clusterId,'sign',sign,'n_voxels',numel(vox),'volume_mm3',numel(vox)*abs(det(ref.mat(1:3,1:3))), ...
            'peak_statistic',data(peak),'peak_p_uncorrected',allP(peak),'peak_q_voxel_fdr',allQ(peak),'peak_p_voxel_fwe',fwe, ...
            'voxel_i',i,'voxel_j',j,'voxel_k',k,'x_mm',mm(1),'y_mm',mm(2),'z_mm',mm(3));
        if isempty(clusterRows),clusterRows=row;else,clusterRows(end+1)=row;end %#ok<AGROW>
    end
end
selected=labels>0;mkdir(out);writetable(before,fullfile(out,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');
writeMap(ref,fullfile(out,'p_uncorrected.nii'),allP,64);writeMap(ref,fullfile(out,'q_voxel_fdr.nii'),allQ,64);
writeMap(ref,fullfile(out,'display_mask.nii'),double(selected),2);writeMap(ref,fullfile(out,'cluster_labels.nii'),labels,8);
displayed=NaN(ref.dim);displayed(mask)=0;displayed(selected)=data(selected);writeMap(ref,fullfile(out,'thresholded_statistic.nii'),displayed,16);
names={'cluster_id','sign','n_voxels','volume_mm3','peak_statistic','peak_p_uncorrected','peak_q_voxel_fdr','peak_p_voxel_fwe','voxel_i','voxel_j','voxel_k','x_mm','y_mm','z_mm'};
if isempty(clusterRows),clusters=array2table(zeros(0,numel(names)),'VariableNames',names);else,clusters=struct2table(clusterRows);end
writetable(clusters,fullfile(out,'clusters.tsv'),'FileType','text','Delimiter','\t');
if opt.writeVoxelTable
    ix=find(selected);[i,j,k]=ind2sub(ref.dim,ix);mm=ref.mat*[i';j';k';ones(1,numel(ix))];
    voxels=table(labels(ix),i,j,k,mm(1,:)',mm(2,:)',mm(3,:)',data(ix),allP(ix),allQ(ix), ...
        'VariableNames',{'cluster_id','voxel_i','voxel_j','voxel_k','x_mm','y_mm','z_mm','statistic','p_uncorrected','q_voxel_fdr'});
    writetable(voxels,fullfile(out,'voxels.tsv'),'FileType','text','Delimiter','\t');
end
summary.model=spmFile;summary.contrastIndex=index;summary.contrastName=c.name;summary.nDisplayedVoxels=nnz(selected);summary.nDisplayedClusters=height(clusters);
summary.extentFilterVoxels=opt.minClusterVoxels;summary.connectivity=opt.connectivity;summary.clusterInference='none; cluster sizes are descriptive/display filters';
summary.effectFile=effectFile;summary.inputHashesUnchanged=height(before);summary.sourceModelModified=false;
if opt.plot,psy.glm_results_plot(ref,data,selected,opt.backgroundFile,fullfile(out,'orthogonal_overlay.png'),[c.name ' / ' opt.correction ' / ' opt.tail],mask,stat);end
after=psy.glm_file_inventory(files);if ~isequal(before,after),error('psy:GLMInputChanged','Source model changed');end
writetable(after,fullfile(out,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');
psy.glm_write_json(fullfile(out,'summary.json'),summary);save(fullfile(out,'GLM_RESULTS_COMPLETE.mat'),'summary','clusters','u');
end
function checkGrid(a,b)
if ~isscalar(a)||~isscalar(b)||~isequal(a.dim,b.dim)||max(abs(a.mat-b.mat),[],'all')>1e-5,error('psy:GLMGrid','Model statistics and mask must share geometry');end
end
function writeMap(ref,file,data,type)
v=struct('fname',file,'dim',ref.dim,'mat',ref.mat,'dt',[type 0],'pinfo',[1;0;0],'descrip','Read-only GLM result export');spm_write_vol(v,data);
end
