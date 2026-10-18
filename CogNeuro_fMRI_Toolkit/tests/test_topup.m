function tests=test_topup
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.root=tempname; mkdir(t.TestData.root);
a=single(reshape(1:8*8*8,[8 8 8]));
niftiwrite(cat(4,a,a+1),fullfile(t.TestData.root,'neg.nii'));
niftiwrite(cat(4,a+2,a+3,a+4),fullfile(t.TestData.root,'pos.nii'));
niftiwrite(cat(4,a,a+1),fullfile(t.TestData.root,'bold.nii'));
s.subject='pilotA';s.session='visit1';s.run='task1';
s.negative=fullfile(t.TestData.root,'neg.nii');
s.positive=fullfile(t.TestData.root,'pos.nii');
s.negativeDirection='j-';s.positiveDirection='j';
s.negativeReadoutSeconds=0.05;s.positiveReadoutSeconds=0.05;
s.bold=fullfile(t.TestData.root,'bold.nii');
s.boldDirection='j-';s.boldReadoutSeconds=0.05;
t.TestData.spec=s;
c=topup_config;c.outputRoot=fullfile(t.TestData.root,'out');
t.TestData.cfg=c;
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testPlanAndOutputIsolation(t)
s=t.TestData.spec;c=t.TestData.cfg;
p=psy.topup_validate(s,c);
verifyEqual(t,p.negativeVolumes,2);verifyEqual(t,p.positiveVolumes,3);
verifyEqual(t,p.negativeVector,[0 -1 0]);
r=psy.topup_run(s,c);verifyEqual(t,r.status,'planned_not_executed');
verifyTrue(t,isfile(fullfile(r.outputDir,'acqparams.txt')));
rows=readlines(fullfile(r.outputDir,'acqparams.txt'));
verifyEqual(t,numel(rows(rows~="")),5);
verifyError(t,@()psy.topup_run(s,c),'psy:TopupExisting');
end
function testRejectMetadataAndGeometry(t)
s=t.TestData.spec;c=t.TestData.cfg;
s.positiveDirection='i';verifyError(t,@()psy.topup_validate(s,c),'psy:TopupDirection');
s=t.TestData.spec;s.negativeReadoutSeconds=0;verifyError(t,@()psy.topup_validate(s,c),'psy:TopupReadout');
s=t.TestData.spec;s.boldDirection='LR';verifyError(t,@()psy.topup_validate(s,c),'psy:TopupDirection');
s=t.TestData.spec;niftiwrite(ones(6,8,8,'single'),fullfile(t.TestData.root,'other.nii'));
s.positive=fullfile(t.TestData.root,'other.nii');
verifyError(t,@()psy.topup_validate(s,c),'psy:TopupGeometry');
end
function testBoldApplyRequiresAlignment(t)
s=t.TestData.spec;c=t.TestData.cfg;c.applyToBold=true;
verifyError(t,@()psy.topup_run(s,c),'psy:TopupAlignment');
verifyFalse(t,isfolder(c.outputRoot));
s.alignmentConfirmed=true;s.boldReadoutSeconds=0.06;
verifyError(t,@()psy.topup_run(s,c),'psy:TopupReadout');
end
function testBatchIsolatesSubjectsAndRuns(t)
s=t.TestData.spec;c=t.TestData.cfg;
s2=s;s2.subject='pilotB';s2.session='visit2';s2.run='rest';
rows=psy.topup_batch([s s2],c);
verifyEqual(t,{rows.status},{'planned_not_executed','planned_not_executed'});
verifyTrue(t,isfile(fullfile(c.outputRoot,'sub-pilotA','ses-visit1','task1','acqparams.txt')));
verifyTrue(t,isfile(fullfile(c.outputRoot,'sub-pilotB','ses-visit2','rest','acqparams.txt')));
end

function testMeanIsPlannedAfterTopupEvenWithoutDirectBold(t)
c=t.TestData.cfg;c.applyToBold=false;
r=psy.topup_run(t.TestData.spec,c);
script=fileread(r.script);
topupPosition=strfind(script,'/bin/topup"');
meanPosition=strfind(script,'/bin/fslmaths"');
verifyNumElements(t,meanPosition,1);
verifyGreaterThan(t,meanPosition,topupPosition);
verifyTrue(t,contains(script,' -Tmean '));
verifyTrue(t,contains(script,'se_unwarped_mean.nii.gz'' -odt float'));
verifyFalse(t,isfile(fullfile(r.outputDir,'TOPUP_COMPLETE.json')));
verifyFalse(t,isfile(fullfile(r.outputDir,'se_unwarped_mean.nii.gz')));
end

function testUnequalPeCountsUseAllFramesAndPassBoldValidation(t)
out=writeQcInputs(t);
a=single(niftiread(t.TestData.spec.negative));
% 两组分别有 2 和 3 帧；所有帧平均为首帧 +2，不是两组均值的均值 +1.75。
expected=a(:,:,:,1)+2;
niftiwrite(expected,fullfile(out,'se_unwarped_mean.nii'),'Compressed',true);
qc=psy.topup_qc(out,2,3);
verifyEqual(t,qc.seReferenceMaxAbsError,0);
verifyEqual(t,qc.seReferenceDatatype,'single');
verifyTrue(t,isfile(fullfile(out,'topup_qc.json')));
fid=fopen(fullfile(out,'TOPUP_COMPLETE.json'),'w');
fprintf(fid,'%s','{"status":"topup_estimated"}');fclose(fid);
s=t.TestData.spec;
b=struct('subject',s.subject,'session',s.session,'run',s.run,'topupDir',out, ...
    'sbref',fullfile(t.TestData.root,'sbref.nii'),'bold',s.bold, ...
    'boldDirection',s.boldDirection,'boldReadoutSeconds',s.boldReadoutSeconds);
niftiwrite(a(:,:,:,1),b.sbref);
p=psy.bold_unwarp_validate(b,bold_unwarp_config);
verifyEqual(t,p.seMagnitude,fullfile(out,'se_unwarped_mean.nii.gz'));
verifyEqual(t,p.boldFrames,2);
end

function testMissingWrongAndNonFiniteMeanAreRejected(t)
out=writeQcInputs(t);
verifyError(t,@()psy.topup_qc(out,2,3),'psy:TopupQCReference');
a=single(niftiread(t.TestData.spec.negative));
bad=a(:,:,:,1)+1.75; % 错误地将两组均值等权平均。
niftiwrite(bad,fullfile(out,'se_unwarped_mean.nii'),'Compressed',true);
verifyError(t,@()psy.topup_qc(out,2,3),'psy:TopupQCReference');
bad(1)=NaN;niftiwrite(bad,fullfile(out,'se_unwarped_mean.nii'),'Compressed',true);
verifyError(t,@()psy.topup_qc(out,2,3),'psy:TopupQCValues');
niftiwrite(ones(6,8,8,'single'),fullfile(out,'se_unwarped_mean.nii'),'Compressed',true);
verifyError(t,@()psy.topup_qc(out,2,3),'psy:TopupQCGeometry');
niftiwrite(uint16(a(:,:,:,1)+2),fullfile(out,'se_unwarped_mean.nii'),'Compressed',true);
verifyError(t,@()psy.topup_qc(out,2,3),'psy:TopupQCType');
verifyFalse(t,isfile(fullfile(out,'TOPUP_COMPLETE.json')));
end

function out=writeQcInputs(t)
out=fullfile(t.TestData.root,'qc');mkdir(out);
s=t.TestData.spec;
series=cat(4,single(niftiread(s.negative)),single(niftiread(s.positive)));
niftiwrite(series,fullfile(out,'se_pair.nii'),'Compressed',true);
niftiwrite(series,fullfile(out,'se_unwarped.nii'),'Compressed',true);
niftiwrite(zeros(8,8,8,'single'),fullfile(out,'field_hz.nii'),'Compressed',true);
end
