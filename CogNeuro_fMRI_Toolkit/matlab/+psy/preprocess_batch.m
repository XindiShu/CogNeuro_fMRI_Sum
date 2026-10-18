function report = preprocess_batch(cfg)
%PREPROCESS_BATCH 通用多被试/session/run 调度，命名约定由输入适配器处理。
% 统一入口按 cfg.sdc.method 选择无校正、FSL TOPUP 或 SPM FieldMap 分支。
% 梯度非线性校正及时间去噪仍不属于此空间预处理入口。
if isfield(cfg,'inputStage') && strcmp(cfg.inputStage,'preprocessed') && cfg.execute
    error('psy:DerivativeExecution','Preprocessed inputs support validation only; do not repeat spatial preprocessing');
end
if ~ismember(cfg.stopAfter,{'realign','segment','smooth'}), error('psy:Stage','stopAfter 应为 realign/segment/smooth'); end
% FILE_MANIFEST.json 表示这是精简发布副本。发布目录只放代码/文档，
% 默认的 root/derivatives 不可用于实际分析或预检输出；请改到副本外。
projectRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
if isfile(fullfile(projectRoot,'FILE_MANIFEST.json'))
    releasePath=char(java.io.File(projectRoot).getCanonicalPath());
    outputPath=char(java.io.File(cfg.outputRoot).getCanonicalPath());
    if strcmpi(outputPath,releasePath) || ...
            startsWith(lower(outputPath),[lower(releasePath) filesep])
        error('psy:ReleaseOutputRoot', ...
            'D 盘精简副本只存代码和文档：请把 cfg.outputRoot 设到该文件夹外。');
    end
end
if strcmp(cfg.inputStage,'sdc_corrected')
    if ~strcmp(cfg.distortionCorrection,'already_applied')
        error('psy:SDC','sdc_corrected 输入必须声明 distortionCorrection=already_applied');
    end
elseif ~ismember(cfg.distortionCorrection,{'not_applied','not_implemented'})
    error('psy:SDC','raw 输入请用 cfg.sdc.method 选择畸变校正；旧 distortionCorrection 字段保持 not_applied');
end
psy.validate_preprocess_config(cfg);
if isempty(cfg.spmPath) || ~isfile(fullfile(cfg.spmPath,'spm.m'))
    error('psy:SPMPath','Set cfg.spmPath to the SPM installation directory containing spm.m');
end
addpath(cfg.spmPath);
segmentOptions=psy.segment_options(cfg);
if isfile(fullfile(segmentOptions.cat12.path,'cat12.m'))
    % SPM 的工具箱 batch 初始化也会读 CAT defaults；先初始化，避免菜单缺省警告。
    addpath(segmentOptions.cat12.path);cat_defaults;cat_get_defaults('extopts.send_info',0);
end
assert(exist('spm','file')==2,'SPM not found');
spm('defaults','fmri'); spm_jobman('initcfg');
switch cfg.inputMode
    case 'manifest', runs=psy.read_manifest(cfg);
    case 'hcp', runs=psy.discover_hcp(cfg);
    otherwise, error('psy:InputMode','Use manifest or hcp inputMode');
end
report=struct('subject',{},'session',{},'run',{},'status',{},'message',{},'output',{});
if ~isfolder(cfg.outputRoot), mkdir(cfg.outputRoot); end
save(fullfile(cfg.outputRoot,'config_and_inventory.mat'),'cfg','runs');
n=psy.normalise_options(cfg);
if ~strcmp(n.method,'segmentation')&&strcmp(cfg.stopAfter,'smooth')&&~strcmp(cfg.inputStage,'preprocessed')
    report=psy.preprocess_group_batch(runs,cfg);return;
end
for i=1:numel(runs)
    r=runs(i); out=psy.run_output_dir(cfg.outputRoot,r);
    if ~isfield(r,'session'), r.session=''; end
    row=struct('subject',r.subject,'session',r.session,'run',r.name,'status','pending','message','','output',out);
    try
        if psy.has_dicom_sources(r)
            if ~cfg.execute
                % 只核对明确指定的序列目录；尚未转换，不能冒充 NIfTI/场图完整预检。
                inventory=psy.inspect_dicom_inventory(r);
                row.status='dicom_inventory_only';
                row.message=sprintf('%d 个 DICOM 序列目录已关联；execute=true 后转换并完成 NIfTI 预检', ...
                    numel(inventory.seriesDirectories));
                continueRun=true;
            else
                r=psy.materialize_dicom_run(r,cfg);
                continueRun=false;
            end
        else
            continueRun=false;
        end
        if continueRun
            report(end+1)=row; %#ok<AGROW>
            writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
            fprintf('%s %s: %s %s\n',row.subject,row.run,row.status,row.message);
            continue
        end
        info=psy.inspect_run(r);
        plan=psy.preprocess_plan(r,info,cfg); % 先核查每个 run 的 STC/场图采集参数。
        plan.dummy=psy.dummy_plan(r,info,cfg);
        if ismember(cfg.stopAfter,{'segment','smooth'}) && ...
                ~strcmp(plan.sdc.method,'spm_vdm_only') && ~strcmp(cfg.inputStage,'preprocessed')
            plan.segment=psy.segment_plan(r,cfg);
        end
        info.preprocessPlan=plan;
        headerDir=psy.run_output_dir(fullfile(cfg.outputRoot,'input_checks'),r);
        if ~isfolder(headerDir), mkdir(headerDir); end
        save(fullfile(headerDir,'header.mat'),'info');
        if ~cfg.execute
            row.status='validated_inputs';
            row.message=sprintf('%d input volumes, %d retained, TR %.6g s; SDC %s; STC %s', ...
                info.nVolumes,plan.dummy.retainedVolumes,info.trSeconds,plan.sdc.method,plan.slice.mode);
            if isfield(info,'eventEndOverrunSeconds') && any(info.eventEndOverrunSeconds>0)
                row.message=sprintf('%s; event-end overrun %.3f s preserved',row.message,max(info.eventEndOverrunSeconds));
            end
        else
            row.status=psy.process_run(r,info,cfg,out,plan);
            if strcmp(cfg.inputStage,'sdc_corrected')
                row.message='Susceptibility correction supplied as input; gradient distortion correction not performed';
            elseif strcmp(plan.sdc.method,'spm_vdm_only')
                row.message='VDM 已准备；没有对整套 BOLD 做头动、校正、QC 或空间后续步骤';
            elseif strcmp(plan.sdc.method,'spm_unwarp')
                row.message='动态 Unwarp，没有提供测量的静态 VDM；不代表静态解剖畸变已校正';
            elseif ~strcmp(plan.sdc.method,'none')
                row.message=['Susceptibility correction: ' plan.sdc.method '; gradient distortion correction not performed'];
            else
                row.message='Susceptibility and gradient distortion correction not performed';
            end
        end
    catch exception
        row.status='failed'; row.message=exception.message;
    end
    report(end+1)=row; %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'),'FileType','text','Delimiter','\t');
    fprintf('%s %s: %s %s\n',row.subject,row.run,row.status,row.message);
    if strcmp(row.status,'failed') && ~cfg.continueOnError
        error('psy:RunFailed','%s/%s/%s failed: %s',row.subject,row.session,row.run,row.message);
    end
end
end
