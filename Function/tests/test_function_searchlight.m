function tests=test_function_searchlight
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function('D:/matlab/atoolbox/spm12');
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testPhysicalRadiusAndRestrictedMaximumNull(t)
rng(9);target=repmat(["a";"a";"b";"b"],4,1);groups=repelem(string((1:4)'),4);x=randn(16,8)*.1;x(:,1:4)=x(:,1:4)+2*double(target=="b");xyz=[(0:7)'*2 zeros(8,2)];cfg=searchlight_config;o=cfg.options;o.radiusMm=2.01;o.minFeatures=2;o.nPermutations=9;o.exchangeabilityJustification='Engineering simulation: condition labels are randomized independently within each run.';
r=cog.searchlight(x,xyz,[2;7],target,groups,groups,o);verifyEqual(t,r.nFeatures,[3 3]);verifyEqual(t,r.score(1),1);verifyGreaterThanOrEqual(t,r.pFweMax,r.pUncorrected);verifyGreaterThanOrEqual(t,r.pUncorrected,.1);verifyFalse(t,r.inferenceEligible);verifySize(t,r.nullMaximum,[9 1]);
o.exchangeabilityJustification='';verifyError(t,@()cog.searchlight(x,xyz,2,target,groups,groups,o),'cog:Exchangeability');
end
function testRsaDistanceAndModelPermutations(t)
target=repmat(["a";"b";"c"],2,1);parts=repelem(["run1";"run2"],3);x=repmat([0 0 1;3 0 2;3 4 3],2,1);xyz=[(1:3)' zeros(3,2)];cfg=searchlight_config;o=cfg.options;o.mode='rsa';o.radiusMm=5;o.rsa.metric='euclidean';o.minFeatures=2;
r=cog.searchlight(x,xyz,2,target,parts,parts,o);verifyEqual(t,r.score,mean([sqrt(10) sqrt(17) sqrt(29)]),'AbsTol',1e-12);o.rsaScore='model_spearman';o.rsa.modelLabels=["a";"b";"c"];o.rsa.modelRDMs=[0 sqrt(10) sqrt(29);sqrt(10) 0 sqrt(17);sqrt(29) sqrt(17) 0];o.nPermutations=5;o.exchangeabilityJustification='Engineering item-label shuffle';r=cog.searchlight(x,xyz,2,target,parts,parts,o);verifyEqual(t,r.score,1,'AbsTol',1e-12);verifyTrue(t,isfinite(r.pFweMax));
end
function testSubjectsKeepTheirOwnDisjointMasks(t)
folder=tempname;mkdir(folder);cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
rng(33);tab=table;v=struct('fname','','dim',[4 4 4],'dt',[16 0],'mat',eye(4),'pinfo',[1;0;0],'n',[1 1],'descrip','synthetic');
for subject=1:2
    mask=false(4,4,4);mask((subject-1)*2+(1:2),:,:)=true;v.fname=fullfile(folder,sprintf('mask%d.nii',subject));spm_write_vol(v,double(mask));maskPath=string(v.fname);
    for sample=1:8
        label=mod(floor((sample-1)/2),2);image=randn(4,4,4)*.1+label*3;v.fname=fullfile(folder,sprintf('beta%d_%d.nii',subject,sample));spm_write_vol(v,image);
        row=table(string(sprintf('s%d_e%d',subject,sample)),string(subject),"",string(ceil(sample/4)),string(label),string(v.fname),"1",maskPath,'VariableNames',{'estimate_id','subject','session','run','condition','image_path','volume_index','mask_path'});tab=[tab;row]; %#ok<AGROW>
    end
end
file=fullfile(folder,'catalog.tsv');writetable(tab,file,'FileType','text','Delimiter','\t');c=searchlight_config;c.catalogFile=file;c.outputRoot=fullfile(folder,'out');c.execute=true;c.options.radiusMm=1.5;c.options.minFeatures=2;r=run_searchlight(c);verifyEqual(t,numel(r.records),2);verifyEqual(t,[r.records{1}.nValid r.records{2}.nValid],[32 32]);
end
