function tests=test_bold_unwarp
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.root=tempname;mkdir(t.TestData.root);
raw=fullfile(t.TestData.root,'raw');mkdir(raw);
td=fullfile(t.TestData.root,'topup');mkdir(td);
a=single(reshape(1:8*8*8,[8 8 8]));
niftiwrite(a,fullfile(raw,'sbref.nii'));
niftiwrite(cat(4,a,a+1),fullfile(raw,'bold.nii'));
niftiwrite(a,fullfile(td,'field_hz.nii'),'Compressed',true);
niftiwrite(a,fullfile(td,'se_unwarped_mean.nii'),'Compressed',true);
fid=fopen(fullfile(td,'TOPUP_COMPLETE.json'),'w');fprintf(fid,'%s','{"status":"topup_estimated"}');fclose(fid);
s=struct('subject','S01','session','A','run','run1','topupDir',td, ...
    'sbref',fullfile(raw,'sbref.nii'),'bold',fullfile(raw,'bold.nii'), ...
    'boldDirection','j-','boldReadoutSeconds',0.07);
t.TestData.spec=s;
c=bold_unwarp_config;c.outputRoot=fullfile(t.TestData.root,'out');t.TestData.cfg=c;
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function testDwellAndPlan(t)
p=psy.bold_unwarp_validate(t.TestData.spec,t.TestData.cfg);
verifyEqual(t,p.phaseVector,[0 -1 0]);verifyEqual(t,p.boldFrames,2);
verifyEqual(t,p.effectiveEchoSpacingSeconds,0.01,'AbsTol',1e-12);
r=psy.bold_unwarp_run(t.TestData.spec,t.TestData.cfg);
verifyEqual(t,r.status,'planned_not_executed');
script=fileread(r.script);
verifyTrue(t,contains(script,'-mul 6.283185307179586'));
verifyTrue(t,contains(script,'--shiftdir=y-'));
verifyTrue(t,contains(script,'--datatype=float'));
verifyTrue(t,contains(script,'jacobian_raw'));
verifyTrue(t,contains(script,' -thr 0 '));
verifyError(t,@()psy.bold_unwarp_run(t.TestData.spec,t.TestData.cfg),'psy:BoldUnwarpExisting');
end
function testRejectBadMetadata(t)
s=t.TestData.spec;c=t.TestData.cfg;
s.boldDirection='LR';verifyError(t,@()psy.bold_unwarp_validate(s,c),'psy:BoldUnwarpDirection');
s=t.TestData.spec;s.boldReadoutSeconds=-0.05;verifyError(t,@()psy.bold_unwarp_validate(s,c),'psy:BoldUnwarpReadout');
s=t.TestData.spec;s.sbref=fullfile(t.TestData.root,'missing.nii');
verifyError(t,@()psy.bold_unwarp_validate(s,c),'psy:BoldUnwarpInput');
end
function testBatchIsolation(t)
s=t.TestData.spec;s2=s;s2.subject='S02';s2.session='B';s2.run='rest';
rows=psy.bold_unwarp_batch([s s2],t.TestData.cfg);
verifyEqual(t,{rows.status},{'planned_not_executed','planned_not_executed'});
verifyTrue(t,isfile(fullfile(t.TestData.cfg.outputRoot,'sub-S01','ses-A','run1','run_bold_unwarp.sh')));
verifyTrue(t,isfile(fullfile(t.TestData.cfg.outputRoot,'sub-S02','ses-B','rest','run_bold_unwarp.sh')));
end
