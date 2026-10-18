function [vdm,outputs]=spm_fieldmap_vdm(sdc,epi,out,cfg)
%SPM_FIELDMAP_VDM 调用官方 FieldMap_create/MatchVDM，保留真实弧度幅度。
% 不使用 FieldMap_Run 的 min/max Scale；不复制/修改 SPM 安装源码。
% batch 结构保存供审查，execution 记录实际官方 API，而非声称执行原 stock runner。
fmDir=fullfile(out,'spm_fieldmap');
if isfolder(fmDir), error('psy:FieldMapExisting','场图工作目录已存在: %s',fmDir); end
mkdir(fmDir); addpath(fullfile(cfg.spmPath,'toolbox','FieldMap'));
options=psy.sdc_spm_options(cfg); source=sdc.fieldmap;
reference=psy.fieldmap_reference(sdc,epi,out,cfg);
outputs={reference};
if strcmp(source.type,'vdm')
    input=psy.stage_image(source.vdm,fmDir); volume=spm_vol(input);
    vdm=fullfile(fmDir,'vdm5_imported.nii');
    values=spm_read_vols(volume); volume.fname=vdm; volume.n=[1 1];
    volume.dt=[spm_type('float32') spm_platform('bigend')]; volume.pinfo=[1;0;0];
    spm_write_vol(volume,values);
    if options.writeReferenceEpi
        job.data=struct('scans',{{{reference}}},'vdmfile',{{vdm}});
        job.roptions=struct('pedir',sdc.phaseEncodingAxis,'which',[2 0], ...
            'rinterp',cfg.sdc.spm.applyVdmInterpolation,'wrap',cfg.realign.wrap, ...
            'mask',double(cfg.realign.mask),'prefix',options.outputPrefix);
        batch={}; batch{1}.spm.tools.fieldmap.applyvdm=job;
        psy.spm_step(batch,fullfile(fmDir,'reference_apply_vdm.mat'));
        [folder,name,ext]=fileparts(reference); outputs{end+1}=fullfile(folder,[options.outputPrefix name ext]);
    end
    save(fullfile(fmDir,'imported_vdm.mat'),'source','options','vdm');
    outputs=[outputs,{vdm,fullfile(fmDir,'imported_vdm.mat')}]; return;
end
staged=source; keys=fieldnames(source);
originals=cell(numel(keys),1); copies=cell(numel(keys),1); count=0;
for k=1:numel(keys)
    value=source.(keys{k});
    if ischar(value) && isfile(value)
        found=find(strcmp(originals(1:count),value),1);
        if isempty(found)
            copied=psy.stage_image(value,fullfile(fmDir,['input_' keys{k}]));
            count=count+1; originals{count}=value; copies{count}=copied;
        else
            copied=copies{found};
        end
        staged.(keys{k})=copied;
    end
end
% files 和相同角色别名只记录来源，避免将同一影像重复复制。
spmCfg=cfg.sdc.spm;
template=spmCfg.maskTemplate;
if isempty(template), template=fullfile(cfg.spmPath,'toolbox','FieldMap','T1.nii'); end
if spmCfg.maskBrain && ~isfile(template), error('psy:FieldMapTemplate','Mask Brain 模板不存在'); end
defaults=struct('et',{{source.echoTimesMs(1),source.echoTimesMs(2)}}, ...
    'maskbrain',double(spmCfg.maskBrain),'blipdir',sdc.blipDirection, ...
    'tert',sdc.readoutMs,'epifm',double(spmCfg.epiBased),'ajm',double(spmCfg.jacobianModulation));
defaults.uflags=struct('method',spmCfg.unwrapMethod,'fwhm',spmCfg.unwrapFwhmMm, ...
    'pad',spmCfg.unwrapPadding,'ws',double(spmCfg.weightedSmoothing), ...
    'etd',diff(source.echoTimesMs),'iformat','PM');
defaults.mflags=struct('template',template,'fwhm',spmCfg.maskFwhmMm, ...
    'nerode',spmCfg.maskErode,'ndilate',spmCfg.maskDilate, ...
    'thresh',spmCfg.maskThreshold,'reg',spmCfg.maskRegularisation);
magFrame=options.magnitudeVolume; magnitude='';
switch source.type
    case 'phasediff'
        phase=pick(staged,{'phase','phasediff'}); magnitude=staged.magnitude;
        images=[spm_vol([phase ',1']);spm_vol(sprintf('%s,%d',magnitude,magFrame))];
        data=struct('presubphasemag',struct('phase',{{[phase ',1']}}, ...
            'magnitude',{{sprintf('%s,%d',magnitude,magFrame)}}));
    case 'phase_magnitude'
        images=[spm_vol([staged.phase1 ',1']);spm_vol(sprintf('%s,%d',staged.magnitude1,magFrame)); ...
            spm_vol([staged.phase2 ',1']);spm_vol(sprintf('%s,%d',staged.magnitude2,magFrame))];
        data=struct('phasemag',struct('shortphase',{{[staged.phase1 ',1']}}, ...
            'shortmag',{{sprintf('%s,%d',staged.magnitude1,magFrame)}}, ...
            'longphase',{{[staged.phase2 ',1']}},'longmag',{{sprintf('%s,%d',staged.magnitude2,magFrame)}}));
    case 'real_imaginary'
        images=spm_vol(char(staged.real1,staged.imaginary1,staged.real2,staged.imaginary2));
        defaults.uflags.iformat='RI';
        data=struct('realimag',struct('shortreal',{{staged.real1}},'shortimag',{{staged.imaginary1}}, ...
            'longreal',{{staged.real2}},'longimag',{{staged.imaginary2}}));
    case 'fieldmap_hz'
        hz=pick(staged,{'hz','fieldmap_hz'}); images=spm_vol([hz ',1']);
        defaults.uflags.iformat='';
        if isfield(staged,'magnitude') && ~isempty(staged.magnitude)
            magnitude=staged.magnitude;
            defaults.magfieldmap=spm_vol(sprintf('%s,%d',magnitude,magFrame));
        end
        data=struct('precalcfieldmap',struct('precalcfieldmap',{{[hz ',1']}},'magfieldmap',{{magnitude}}));
    otherwise
        error('psy:SPMFieldMapType','未支持的 FieldMap 输入类型');
end
effectiveMatch=options.matchVdm;
if strcmp(source.type,'fieldmap_hz') && isempty(magnitude), effectiveMatch=false; end
if effectiveMatch && sdc.phaseEncodingAxis~=2
    error('psy:SPMMatchDirection','MatchVDM 在本机沿 y 建模；其他轴应先对齐并禁用自动匹配');
end
batchDefaults=defaults; batchDefaults.et=source.echoTimesMs;
batchDefaults.mflags.template={template}; batchDefaults.uflags=rmfield(defaults.uflags,{'iformat','etd'});
subject=struct('data',data,'defaults',struct('defaultsval',batchDefaults), ...
    'session',struct('epi',{{reference}}),'matchvdm',double(effectiveMatch), ...
    'sessname','run','writeunwarped',double(options.writeReferenceEpi),'anat',{{''}},'matchanat',0);
matlabbatch={}; matlabbatch{1}.spm.tools.fieldmap.calculatevdm.subj=subject;
execution=struct('backend','SPM FieldMap_create + optional MatchVDM/UnwarpEPI', ...
    'preserveRadianAmplitude',true,'effectiveMatchVdm',effectiveMatch, ...
    'writeReferenceEpi',options.writeReferenceEpi, ...
    'replay','通过工具包入口/API 重放；stock FieldMap_Run 会重新缩放相位，不是本次执行后端');
jobFile=fullfile(out,'01_fieldmap_calculate_vdm.mat'); save(jobFile,'matlabbatch','execution','defaults');
% 官方 API 的无 session 调用不会不受控制地写出参考 unwarped EPI。
try
    [maps,states]=FieldMap_create(images,{},defaults);
catch cause
    failure=struct('message',cause.message,'identifier',cause.identifier,'execution',execution);
    save(fullfile(fmDir,'FIELD_MAP_FAILED.mat'),'failure');
    exception=MException('psy:SPMFieldMapEstimation', ...
        'SPM 场图估计失败；请检查真实幅度图背景/SNR、相位、掩膜和解缠设置。未改动相位幅度。原错误: %s',cause.message);
    throw(addCause(exception,cause));
end
state=states{1};
state.epiP=spm_vol(reference);
if effectiveMatch, state.vdmP=FieldMap('MatchVDM',state); end
vdm=state.vdmP.fname;
if options.writeReferenceEpi
    if sdc.phaseEncodingAxis==2
        state.uepiP=FieldMap('UnwarpEPI',state);
        written=FieldMap('Write',state.epiP,state.uepiP.dat,options.outputPrefix, ...
            spm_type('float32'),'FieldMap reference QC image');
        outputs{end+1}=written.fname;
    else
        job.data=struct('scans',{{{reference}}},'vdmfile',{{vdm}});
        job.roptions=struct('pedir',sdc.phaseEncodingAxis,'which',[2 0], ...
            'rinterp',cfg.sdc.spm.applyVdmInterpolation,'wrap',cfg.realign.wrap, ...
            'mask',double(cfg.realign.mask),'prefix',options.outputPrefix);
        batch={}; batch{1}.spm.tools.fieldmap.applyvdm=job;
        psy.spm_step(batch,fullfile(fmDir,'reference_apply_vdm.mat'));
        [folder,name,ext]=fileparts(reference);
        outputs{end+1}=fullfile(folder,[options.outputPrefix name ext]);
    end
end
if ~isfile(vdm), error('psy:FieldMapOutput','SPM 未产生 VDM'); end
save(fullfile(fmDir,'fieldmap_execution.mat'),'execution','maps','vdm','source');
outputs=[outputs,{vdm,jobFile,fullfile(fmDir,'fieldmap_execution.mat')}];
end
function value=pick(source,names)
for k=1:numel(names)
    if isfield(source,names{k}) && ~isempty(source.(names{k})), value=source.(names{k}); return; end
end
error('psy:SPMFieldMapType','输入场图缺少 %s',strjoin(names,'/'));
end
