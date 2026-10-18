function tests=test_input_contract
tests=functiontests(localfunctions);
end
function setup(t)
t.TestData.root=tempname; mkdir(t.TestData.root);
t.TestData.info=struct('trSeconds',2,'size',[3 3 3 10],'durationSeconds',20);
end
function teardown(t)
rmdir(t.TestData.root,'s');
end
function p=put(t,name,content)
p=fullfile(t.TestData.root,name); f=fopen(p,'w'); c=onCleanup(@()fclose(f)); fprintf(f,'%s',content);
end
function testMetadataMismatch(t)
r.metadata=put(t,'m.json','{"RepetitionTime":3}');
verifyError(t,@()psy.inspect_contract(r,t.TestData.info),'psy:MetadataTR');
end
function testMetadataAndNegativeOnset(t)
r.metadata=put(t,'m.json','{"RepetitionTime":2,"SliceTiming":[0,0.5,1],"PhaseEncodingDirection":"j-"}');
r.events=put(t,'e.tsv',sprintf('onset\tduration\ttrial_type\n-1\t2\tstory\n19\t3\tmath\n'));
c=psy.inspect_contract(r,t.TestData.info);
verifyEqual(t,c.events.negativeOnsetCount,1); verifyEqual(t,c.events.endOverrunSeconds,2);
end
function testInvalidEvents(t)
p=put(t,'e.tsv',sprintf('onset\tduration\ttrial_type\n0\t-1\tstory\n'));
verifyError(t,@()psy.read_events_tsv(p,20),'psy:EventValues');
p=put(t,'e.tsv',sprintf('onset\tduration\ttrial_type\n20\t1\tstory\n'));
verifyError(t,@()psy.read_events_tsv(p,20),'psy:EventOutside');
end
function testDirectionRejectsAnatomicalLabel(t)
r.metadata=put(t,'m.json','{"PhaseEncodingDirection":"LR"}');
verifyError(t,@()psy.inspect_contract(r,t.TestData.info),'psy:PEDirection');
end
function testFieldmapPair(t)
niftiwrite(ones(3,3,3,'single'),fullfile(t.TestData.root,'f.nii'));
r.fieldmaps=put(t,'f.json','{"Type":"pepolar","Images":[{"Path":"f.nii","PhaseEncodingDirection":"j","TotalReadoutTime":0.05},{"Path":"f.nii","PhaseEncodingDirection":"j-","TotalReadoutTime":0.05}]}');
c=psy.inspect_contract(r,t.TestData.info); verifyEqual(t,c.fieldmapsStatus,'inventory_checked_correction_pending');
r.fieldmaps=put(t,'f.json','{"Type":"pepolar","Images":[{"Path":"f.nii","PhaseEncodingDirection":"j","TotalReadoutTime":0.05}]}');
verifyError(t,@()psy.inspect_contract(r,t.TestData.info),'psy:FieldmapPair');
end
function testDualEchoMagnitudeAndPhaseShape(t)
% HCP 等 GRE 扫描可把两个 magnitude echo 放在一个 4D NIfTI。
phase=fullfile(t.TestData.root,'phase.nii');
mag=fullfile(t.TestData.root,'magnitude.nii');
niftiwrite(zeros(3,3,3,'single'),phase);
niftiwrite(ones(3,3,3,2,'single'),mag);
r.fieldmaps=put(t,'gre.json',[ ...
    '{"Type":"phasediff","Units":"rad","EchoTime1":0.00492,"EchoTime2":0.00738,' ...
    '"Images":[{"Role":"phasediff","Path":"phase.nii"},' ...
    '{"Role":"magnitude","Path":"magnitude.nii"}]}']);
c=psy.inspect_contract(r,t.TestData.info);
verifyEqual(t,c.fieldmapsStatus,'inventory_checked_correction_pending');
% 即便 JSON 错写 rad，扫描仪整数相位也必须在预检时拒绝。
niftiwrite(ones(3,3,3,'single')*4096,phase);
verifyError(t,@()psy.inspect_contract(r,t.TestData.info),'psy:PhaseUnits');
% 4D 只对 magnitude 合法；相位差仍必须是一幅 3D 图。
movefile(phase,fullfile(t.TestData.root,'phase3d.nii'));
copyfile(mag,phase);
verifyError(t,@()psy.inspect_contract(r,t.TestData.info),'psy:FieldmapShape');
end
function testDerivativeExecutionGuard(t)
cfg=toolkit_config; cfg.inputStage='preprocessed'; cfg.execute=true;
verifyError(t,@()psy.preprocess_batch(cfg),'psy:DerivativeExecution');
end
function testDerivativeManifest(t)
put(t,'bold.nii','');
prov=put(t,'p.json','{"Pipeline":"test","Version":"1","Space":"native","Description":"test only"}'); %#ok<NASGU>
p=put(t,'runs.tsv',sprintf('subject\tsession\trun\tbold\tt1\tinput_stage\tprovenance\n001\t\trest\tbold.nii\t\tpreprocessed\tp.json\n'));
cfg=toolkit_config; cfg.inputStage='preprocessed'; cfg.manifestFile=p;
r=psy.read_manifest(cfg); verifyEmpty(t,r.t1); verifyEqual(t,r.subject,'001');
c=psy.inspect_contract(r,t.TestData.info); verifyEqual(t,c.provenanceStatus,'declared_not_independently_verified');
end
function testSdcCompletionHandoff(t)
bold=fullfile(t.TestData.root,'sdc.nii');niftiwrite(ones(3,3,3,2,'single'),bold);
t1=fullfile(t.TestData.root,'t1.nii');niftiwrite(ones(3,3,3,'single'),t1);
complete=put(t,'complete.json','{"status":"bold_susceptibility_unwarped_pre_motion"}');
p=struct('Pipeline','test-topup','Version','1','Space','native','Description','SDC only', ...
    'CorrectionStatus','completed','ProcessingStage','sdc_only', ...
    'OutputFile',bold,'CompletionFile',complete);
prov=put(t,'provenance_sdc.json',jsonencode(p));
manifest=put(t,'sdc.tsv',sprintf('subject\tsession\trun\tbold\tt1\tinput_stage\tprovenance\nS01\tA\ttask\t%s\t%s\tsdc_corrected\t%s\n',bold,t1,prov));
cfg=toolkit_config;cfg.manifestFile=manifest;cfg.inputStage='sdc_corrected';cfg.distortionCorrection='already_applied';
r=psy.read_manifest(cfg);c=psy.inspect_contract(r,t.TestData.info);
verifyEqual(t,c.provenanceStatus,'sdc_completion_record_checked');
p.OutputFile=t1;put(t,'provenance_sdc.json',jsonencode(p));
verifyError(t,@()psy.inspect_contract(r,t.TestData.info),'psy:SDCProvenance');
cfg.distortionCorrection='not_implemented';
verifyError(t,@()psy.preprocess_batch(cfg),'psy:SDC');
end
