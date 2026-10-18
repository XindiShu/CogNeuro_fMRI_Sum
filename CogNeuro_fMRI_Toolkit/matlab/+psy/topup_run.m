function result=topup_run(spec,cfg)
%TOPUP_RUN 在独立目录估计反向 PE 场；可选直接应用于已核实对齐的 BOLD。
% spec.subject/session/run 可任意命名，批量调用本函数即可处理多被试/会话/run。
% 估计阶段不读写原始数据；已有完成输出不会被覆盖。
plan=psy.topup_validate(spec,cfg);
if ~isnumeric(cfg.threads)||~isscalar(cfg.threads)||cfg.threads<1||cfg.threads~=floor(cfg.threads)
    error('psy:TopupThreads','threads 必须是正整数');
end
if ~all(isfield(spec,{'subject','session','run'})), error('psy:TopupIdentity','需要 subject/session/run'); end
run=struct('subject',spec.subject,'session',spec.session,'name',spec.run);
out=psy.run_output_dir(cfg.outputRoot,run);
done=fullfile(out,'TOPUP_COMPLETE.json');
if isfile(done), error('psy:TopupExisting','已有完成输出，拒绝覆盖: %s',done); end
if isfolder(out), error('psy:TopupExisting','已有输出目录，拒绝覆盖: %s',out); end
if cfg.applyToBold
    if ~isfield(spec,'alignmentConfirmed') || ~isequal(spec.alignmentConfirmed,true)
        error('psy:TopupAlignment','应用到 BOLD 需要独立核实头位配准，并显式设置 alignmentConfirmed=true');
    end
    if isempty(plan.boldVector), error('psy:TopupInput','应用到 BOLD 需要 bold、方向及总读出时间'); end
    if abs(plan.boldReadoutSeconds-plan.negativeReadoutSeconds)>1e-6 || ...
            abs(plan.boldReadoutSeconds-plan.positiveReadoutSeconds)>1e-6
        error('psy:TopupReadout','当前 applytopup 分支仅支持 BOLD 与 SE-EPI 相同总读出时间');
    end
end
mkdir(out);
acq=fullfile(out,'acqparams.txt'); fid=fopen(acq,'w');
if fid<0, error('psy:TopupWrite','无法写 acqparams'); end
clean=onCleanup(@()fclose(fid));
for k=1:plan.negativeVolumes
    fprintf(fid,'%d %d %d %.9f\n',plan.negativeVector,plan.negativeReadoutSeconds);
end
for k=1:plan.positiveVolumes
    fprintf(fid,'%d %d %d %.9f\n',plan.positiveVector,plan.positiveReadoutSeconds);
end
clear clean
script=fullfile(out,'run_topup.sh');
merge=fullfile(out,'se_pair.nii.gz'); resultBase=fullfile(out,'topup');
lines={'#!/usr/bin/env bash','set -euo pipefail', ...
    ['exec > ' q(wslpath(fullfile(out,'fsl.log'))) ' 2>&1'], ...
    ['export FSLDIR=' q(cfg.fslRoot)], ...
    'export FSLOUTPUTTYPE=NIFTI_GZ', ...
    ['export PATH=' q([cfg.fslRoot '/bin']) ':"$PATH"'], ...
    ['cd ' q(wslpath(out))], ...
    ['"$FSLDIR/bin/fslmerge" -t ' q(wslpath(merge)) ' ' q(wslpath(spec.negative)) ' ' q(wslpath(spec.positive))], ...
    ['"$FSLDIR/bin/topup" --imain=' q(wslpath(merge)) ' --datain=' q(wslpath(acq)) ...
    ' --config=' q(cfg.fslConfig) ' --out=' q(wslpath(resultBase)) ...
    ' --nthr=' num2str(cfg.threads) ...
    ' --fout=' q(wslpath(fullfile(out,'field_hz'))) ...
    ' --iout=' q(wslpath(fullfile(out,'se_unwarped'))) ], ...
    ... % BOLD 模块需要校正后全部 SE 帧的三维均值；调用 FSL，不改动原始输入。
    ['"$FSLDIR/bin/fslmaths" ' q(wslpath(fullfile(out,'se_unwarped.nii.gz'))) ...
    ' -Tmean ' q(wslpath(fullfile(out,'se_unwarped_mean.nii.gz'))) ' -odt float']};
if cfg.applyToBold
    idx=1; if isequal(plan.boldVector,plan.positiveVector), idx=plan.negativeVolumes+1; end
    lines{end+1}=['"$FSLDIR/bin/applytopup" --imain=' q(wslpath(spec.bold)) ...
        ' --datain=' q(wslpath(acq)) ' --inindex=' num2str(idx) ...
        ' --topup=' q(wslpath(resultBase)) ' --method=jac --out=' ...
        q(wslpath(fullfile(out,'bold_unwarped')))];
end
fid=fopen(script,'w'); if fid<0, error('psy:TopupWrite','无法写脚本'); end
fprintf(fid,'%s\n',lines{:}); fclose(fid);
result=struct('outputDir',out,'plan',plan,'script',script,'status','planned_not_executed');
save(fullfile(out,'plan.mat'),'spec','cfg','plan');
if ~cfg.execute, return; end
cmd=['wsl -d ' cfg.wslDistro ' -- /bin/bash ' qwin(wslpath(script))];
[code,~]=system(cmd); result.exitCode=code;
if code~=0
    result.status='failed_see_fsl_log';
    save(fullfile(out,'failed.mat'),'result');
    error('psy:TopupFailed','TOPUP 失败，退出码 %d；查看 %s',code,fullfile(out,'fsl.log'));
end
needed={fullfile(out,'topup_fieldcoef.nii.gz'),fullfile(out,'topup_movpar.txt'), ...
    fullfile(out,'field_hz.nii.gz'),fullfile(out,'se_unwarped.nii.gz'), ...
    fullfile(out,'se_unwarped_mean.nii.gz')};
if cfg.applyToBold, needed{end+1}=fullfile(out,'bold_unwarped.nii.gz'); end
if ~all(cellfun(@isfile,needed)), error('psy:TopupOutput','TOPUP 命令成功但输出缺失'); end
qc=psy.topup_qc(out,plan.negativeVolumes,plan.positiveVolumes);
result.status='topup_estimated';
if cfg.applyToBold, result.status='topup_estimated_bold_direct_apply_engineering'; end
summary=struct('status',result.status,'estimatedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
    'inputs',spec,'acqparams',acq,'outputs',{needed},'qc',qc,'fslLog',fullfile(out,'fsl.log'));
fid=fopen(done,'w'); fprintf(fid,'%s',jsonencode(summary,PrettyPrint=true)); fclose(fid);
end

function p=wslpath(w)
% 标准 WSL automount 路径；拒绝 UNC/非盘符路径，避免拼错静默运行。
w=char(string(w));
if numel(w)<3 || ~isletter(w(1)) || w(2)~=':' || ~ismember(w(3),['\' '/'])
    error('psy:TopupPath','当前 WSL 转换仅支持本机盘符绝对路径: %s',w);
end
p=['/mnt/' lower(w(1)) strrep(w(3:end),'\','/')];
end
function s=q(value)
s=['''' strrep(char(value),'''','''"''"''') ''''];
end
function s=qwin(value)
if contains(value,'"'), error('psy:TopupPath','脚本路径含双引号'); end
s=['"' value '"'];
end
