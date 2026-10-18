function report=preprocess_group_batch(runs,cfg)
%PREPROCESS_GROUP_BATCH 群体路线的一次运行入口：全批预检→唯一结构→模板→各run。
% 若全批输入预检失败，不悄悄移除被试再建立另一个模板。
addpath(fullfile(cfg.spmPath,'toolbox','DARTEL'),fullfile(cfg.spmPath,'toolbox','Shoot'));
report=repmat(struct('subject','','session','','run','','status','pending','message','','output',''),1,numel(runs));
infos=cell(size(runs));plans=cell(size(runs));eligible=[];pendingDicom=false;
for k=1:numel(runs)
    r=runs(k);out=psy.run_output_dir(cfg.outputRoot,r);
    report(k)=struct('subject',r.subject,'session',r.session,'run',r.name, ...
        'status','pending','message','','output',out);
    try
        if psy.has_dicom_sources(r)
            if ~cfg.execute
                inventory=psy.inspect_dicom_inventory(r);
                report(k).status='dicom_inventory_only';
                report(k).message=sprintf('%d 个 DICOM 目录；转换后才能确认完整群体输入',numel(inventory.seriesDirectories));
                pendingDicom=true;continue;
            end
            r=psy.materialize_dicom_run(r,cfg);runs(k)=r;
        end
        info=psy.inspect_run(r);plan=psy.preprocess_plan(r,info,cfg);
        plan.dummy=psy.dummy_plan(r,info,cfg);
        if ~strcmp(plan.sdc.method,'spm_vdm_only')
            if isfield(r,'anatomyReuseDir')&&~isempty(r.anatomyReuseDir)
                error('psy:NormaliseReuse','群体路线不接受旧 anatomy_reuse_dir；完成的群体结果用 resume 复用');
            end
            plan.segment=psy.segment_plan(r,cfg);eligible(end+1)=k; %#ok<AGROW>
        end
        info.preprocessPlan=plan;infos{k}=info;plans{k}=plan;
        folder=psy.run_output_dir(fullfile(cfg.outputRoot,'input_checks'),r);
        if ~isfolder(folder),mkdir(folder);end
        save(fullfile(folder,'header.mat'),'info');
        report(k).status='validated_inputs';
        report(k).message=sprintf('%d保留帧，TR %.6g秒；等待群体标准化准备',plan.dummy.retainedVolumes,info.trSeconds);
    catch exception
        report(k).status='failed';report(k).message=exception.message;
    end
end
save_report(report,cfg);
if any(strcmp({report.status},'failed'))
    if cfg.execute,error('psy:NormaliseGroupPreflight','全批输入预检失败；未建立/改变群体模板，见 batch_status.tsv');end
    return;
end
if pendingDicom
    return; % 没有转换的结构输入时，不宣称群体模板预检已完成。
end
if isempty(eligible),error('psy:NormaliseGroup','本批没有 BOLD 空间标准化行，只有 VDM-only');end
p=psy.normalise_group_plan(runs(eligible),plans(eligible),cfg);
save(fullfile(cfg.outputRoot,'normalisation_group_plan.mat'),'p');
if ~cfg.execute
    for k=eligible
        report(k).message=[report(k).message sprintf('；全批%d个唯一结构单位，%s/%s', ...
            numel(p.entries),p.options.method,p.options.group.mode)];
    end
    save_report(report,cfg);return;
end
context=psy.normalise_group_run(p,cfg);
done=fullfile(context.folder,'GROUP_COMPLETE.mat');stamp=psy.file_sha256(done);
for j=1:numel(eligible)
    k=eligible(j);index=context.runToAnatomy(j);
    plans{k}.normalise=struct('method',context.method,'options',context.options, ...
        'anatomy',context.entries(index),'finalTemplate',context.finalTemplate, ...
        'groupComplete',done,'groupSha256',stamp);
end
for k=1:numel(runs)
    try
        report(k).status=psy.process_run(runs(k),infos{k},cfg,report(k).output,plans{k});
        report(k).message=sprintf('SDC=%s；标准化=%s；未执行梯度非线性校正',plans{k}.sdc.method,context.method);
    catch exception
        report(k).status='failed';report(k).message=exception.message;
    end
    save_report(report,cfg);
    fprintf('%s %s: %s %s\n',report(k).subject,report(k).run,report(k).status,report(k).message);
    if strcmp(report(k).status,'failed')&&~cfg.continueOnError
        error('psy:RunFailed','群体路线 run 失败：%s',report(k).message);
    end
end
end
function save_report(report,cfg)
writetable(struct2table(report,'AsArray',true),fullfile(cfg.outputRoot,'batch_status.tsv'), ...
    'FileType','text','Delimiter','\t');
end
