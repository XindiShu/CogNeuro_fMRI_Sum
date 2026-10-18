function tests = test_preprocessing
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'matlab'));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function setup(t)
t.TestData.root=tempname; mkdir(t.TestData.root);
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function touch(file)
mkdir(fileparts(file)); f=fopen(file,'w'); fclose(f);
end
function testMultipleSubjectsExcludeDerivatives(t)
root=t.TestData.root;
for id={'100206','100307'}
    subject=id{1};
    touch(fullfile(root,subject,'unprocessed','3T','T1w_MPR1',[subject '_3T_T1w_MPR1.nii.gz']));
    for name={'tfMRI_LANGUAGE_LR','tfMRI_LANGUAGE_RL'}
        touch(fullfile(root,subject,'unprocessed','3T',name{1},[subject '_3T_' name{1} '.nii.gz']));
    end
    touch(fullfile(root,subject,'MNINonLinear','Results','tfMRI_LANGUAGE_LR','tfMRI_LANGUAGE_LR.nii.gz'));
end
cfg=struct('dataRoot',root,'subjects',{{}},'runNames',{{'tfMRI_LANGUAGE_LR','tfMRI_LANGUAGE_RL'}});
r=psy.discover_hcp(cfg);
verifyEqual(t,numel(r),4);
cfg.subjects={'100307'}; r=psy.discover_hcp(cfg);
verifyEqual(t,numel(r),2); verifyTrue(t,all(strcmp({r.subject},'100307')));
end
function testAmbiguousAnatomyRejected(t)
root=t.TestData.root; subject='100206';
for n=1:2
    seq=sprintf('T1w_MPR%d',n);
    touch(fullfile(root,subject,'unprocessed','3T',seq,[subject '_3T_' seq '.nii.gz']));
end
touch(fullfile(root,subject,'unprocessed','3T','tfMRI_LANGUAGE_LR',[subject '_3T_tfMRI_LANGUAGE_LR.nii.gz']));
cfg=struct('dataRoot',root,'subjects',{{}},'runNames',{{'tfMRI_LANGUAGE_LR'}});
verifyError(t,@()psy.discover_hcp(cfg),'psy:T1Selection');
end
function testMotionUnits(t)
root=t.TestData.root; rp=zeros(3,6); rp(2,1)=1; rp(3,1)=1; rp(3,4)=0.01;
file=fullfile(root,'rp.txt'); writematrix(rp,file,'Delimiter','tab');
q=psy.motion_qc(file,50,0.5,root);
verifyEqual(t,q.meanFDmm,0.5,'AbsTol',1e-10);
verifyEqual(t,q.maxFDmm,1); verifyEqual(t,q.fractionFlagged,1/3);
end
