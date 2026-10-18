function fixture=cogneuro_make_spatial_fixture(spmRoot,folder,nFrames)
%COGNEURO_MAKE_SPATIAL_FIXTURE 由SPM组织先验构造合成影像，不读参与者数据。
% [路径] spmRoot为实际SPM目录；folder必须全新；不修改SPM或已有输出。
% [测试约束] 4mm网格、TR=2秒、两帧dummy、粗分辨率仅用于工程测试。
if nargin<3,nFrames=50;end % [测试规模] 50原始帧，删除2帧，非科研建议。
assert(~isfolder(folder)&&~isfile(folder),'Fixture directory already exists');
assert(nFrames>=8&&fix(nFrames)==nFrames,'Use at least 8 synthetic frames');
addpath(spmRoot,'-begin');mkdir(folder);rng(20261018);
prior=fullfile(spmRoot,'tpm','TPM.nii');priors=spm_vol(prior);
tr=2;dummy=2;voxel=[4 4 4];bounds=[-78 -112 -70;78 76 86];
[targetMat,targetDim]=spm_get_matdim('',voxel,bounds);
[baseMat,baseDim]=spm_get_matdim('',voxel,[-92 -128 -84;92 96 100]);
[probability,world]=samplePriors(priors,baseMat,baseDim);
% [已知扰动] T1原点偏移[6 -4 2]mm；EPI另偏移8mm，以实际调用配准而非恒等图像。
t1Mat=baseMat;t1Mat(1:3,4)=t1Mat(1:3,4)+[6;-4;2];
boldMat=t1Mat;boldMat(1,4)=boldMat(1,4)+8;
bias=1+.06*sin(world(1,:)/55);
t1Values=(single([650 1000 250 100 450 0])*probability).*single(bias);
t1Values=max(0,t1Values+single(randn(size(t1Values))*2));
t1Values(probability(6,:)>.98)=0;
base=single([1200 800 1600 120 400 0])*probability;
onsets=4:10:(nFrames*tr-12);labels=repmat(["A";"B"],ceil(numel(onsets)/2),1);labels=labels(1:numel(onsets));
dt=.125;resolution=16;ticks=0:dt:32;
h=exp(-ticks).*(ticks.^5/gamma(6)-ticks.^15/(6*gamma(16)));h=h/sum(h);
stim=zeros(1,nFrames*resolution);
for k=1:numel(onsets)
    a=40;if labels(k)=="B",a=-20;end
    first=round(onsets(k)/dt)+1;last=min(numel(stim),first+round(2/dt)-1);stim(first:last)=a;
end
signal=conv(stim,h);data=zeros([baseDim nFrames],'single');
for k=1:nFrames
    task=signal((k-1)*resolution+8);
    frame=base+single(task)*probability(1,:)+single(randn(size(base))*.6);
    frame(probability(6,:)>.98)=0;data(:,:,:,k)=reshape(frame,baseDim);
end
t1=fullfile(folder,'sub-phantom_T1w.nii');bold=fullfile(folder,'sub-phantom_ses-baseline_task-test_run-01_bold.nii');
writeImage(t1,reshape(t1Values,baseDim),t1Mat,tr);writeImage(bold,data,boldMat,tr);
[targetProbability,targetWorld]=samplePriors(priors,targetMat,targetDim);
inside=(targetWorld(1,:)/45).^2+((targetWorld(2,:)+15)/45).^2+((targetWorld(3,:)-20)/35).^2<1;
maskValues=targetProbability(1,:)>.65&inside;assert(nnz(maskValues)>50,'Synthetic mask is unexpectedly empty');
mask=fullfile(folder,'analysis_mask_mni.nii');writeImage(mask,reshape(single(maskValues),targetDim),targetMat,tr);
events=fullfile(folder,'events.tsv');
writetable(table(onsets(:),ones(numel(onsets),1)*2,labels,'VariableNames',{'onset','duration','trial_type'}), ...
    events,'FileType','text','Delimiter','\t');
metadata=fullfile(folder,'sub-phantom_ses-baseline_task-test_run-01_bold.json');
writeJson(metadata,struct('RepetitionTime',tr,'EchoTime',.03,'SyntheticTestOnly',true));
overrides=[struct('path','qc.enabled','value',false),struct('path','sliceTiming.mode','value','off'), ...
    struct('path','realign.mask','value',false),struct('path','segment.warpSamplingMm','value',4), ...
    struct('path','voxelSizeMm','value',voxel),struct('path','boundingBoxMm','value',bounds), ...
    struct('path','normalise.interpolation','value',1),struct('path','smoothingFwhmMm','value',[4 4 4]), ...
    struct('path','smooth.prefix','value','g'),struct('path','smooth.dataType','value','float32')];
fixture=struct('bold',bold,'t1',t1,'metadata',metadata,'events',events,'mask',mask, ...
    'tr_seconds',tr,'input_frames',nFrames,'discard_volumes',dummy,'retained_frames',nFrames-dummy, ...
    'event_reference','original_first_volume','onsets',onsets,'overrides',overrides, ...
    'expected_affine',targetMat,'expected_dimensions',targetDim,'smoothing_fwhm_mm',[4 4 4], ...
    'masked_voxels',nnz(maskValues),'native_t1_affine',t1Mat,'raw_bold_affine',boldMat, ...
    'prior_source',prior,'synthetic_only',true, ...
    'limitations',{{'Template-derived synthetic phantom, not independent anatomical ground truth or participant validation.', ...
    'Coarse 4mm grid, 4mm segment sampling, linear interpolation, STC/QC off, no SDC: engineering choices only.', ...
    'Task signal and mask derive from prior anatomy, never from fitted statistics.'}});
writeJson(fullfile(folder,'fixture.json'),fixture);
end
function [p,world]=samplePriors(v,mat,dim)
[x,y,z]=ndgrid(1:dim(1),1:dim(2),1:dim(3));
world=mat*[x(:)';y(:)';z(:)';ones(1,numel(x))];p=zeros(6,numel(x),'single');
for k=1:6
    xyz=v(k).mat\world;values=spm_sample_vol(v(k),xyz(1,:),xyz(2,:),xyz(3,:),1);
    p(k,:)=single(max(0,values));
end
total=sum(p,1);empty=total==0;p(6,empty)=1;total(empty)=1;p=p./total;
end
function writeImage(file,values,mat,tr)
n=nifti;n.dat=file_array(file,size(values),'FLOAT32-LE',352,1,0);n.mat=mat;n.mat0=mat;
n.timing=struct('toffset',0,'tspace',tr);create(n);n.dat(:,:,:,:)=values;
end
function writeJson(file,value)
f=fopen(file,'w','n','UTF-8');assert(f>0);cleanup=onCleanup(@()fclose(f)); %#ok<NASGU>
fprintf(f,'%s',jsonencode(value,PrettyPrint=true));
end
