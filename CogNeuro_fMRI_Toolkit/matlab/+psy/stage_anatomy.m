function files=stage_anatomy(p,cfg,out)
%STAGE_ANATOMY 每 run 复制输入并提取选定 3D volume；不向原始结构像写 header。
for k=1:numel(p.inputFiles)
    if ~strcmp(psy.file_sha256(p.inputFiles{k}),p.hashes{k})
        error('psy:AnatomyChanged','预检后分割/图谱输入已改变: %s',p.inputFiles{k});
    end
end
files=cell(1,numel(p.channels));
for k=1:numel(files)
    folder=fullfile(out,'anat');
    if k>1, folder=fullfile(folder,p.channels(k).Name); end
    source=psy.stage_image(p.channels(k).Path,folder); v=spm_vol(source);
    if numel(v)>1
        selected=v(p.channels(k).Volume);[~,stem]=fileparts(source);
        selected.fname=fullfile(folder,sprintf('%s_vol%04d.nii',stem,p.channels(k).Volume));
        selected.n=[1 1]; selected.dt=[spm_type('float32') 0];selected.pinfo=[1;0;0];
        selected=spm_write_vol(selected,spm_read_vols(v(p.channels(k).Volume)));
        files{k}=selected.fname;
    else
        files{k}=source;
    end
    if k>1 && strcmp(p.options.channelAlignment,'coregister_reslice')
        % 额外结构通道刚体配准/重采样；与 BOLD Coregister 的固定 Estimate 无关。
        b={};b{1}.spm.spatial.coreg.estwrite=struct('ref',{{[files{1} ',1']}}, ...
            'source',{{[files{k} ',1']}},'other',{{''}}, ...
            'eoptions',struct('cost_fun',cfg.coreg.costFunction,'sep',cfg.coreg.separationMm, ...
                'tol',cfg.coreg.tolerance,'fwhm',cfg.coreg.smoothingFwhmMm), ...
            'roptions',struct('interp',4,'wrap',[0 0 0],'mask',0,'prefix','ac_'));
        psy.spm_step(b,fullfile(out,sprintf('03_channel_%s_coreg.mat',p.channels(k).Name)));
        [folder,stem,ext]=fileparts(files{k});files{k}=fullfile(folder,['ac_' stem ext]);
    end
end
% 批处理只判定几何一致，不能证明两种对比度的解剖配准质量合格。
v=cellfun(@spm_vol,files,'UniformOutput',false);
for k=2:numel(v)
    if ~isequal(v{1}.dim,v{k}.dim)||max(abs(v{1}.mat(:)-v{k}.mat(:)))>1e-4
        error('psy:AnatomyAlignment','结构通道工作副本未获得一致网格');
    end
end
end
