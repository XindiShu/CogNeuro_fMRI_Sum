function [forward,inverse,outputs]=group_deformations(field,template,t1,n,cfg,out,mni)
%GROUP_DEFORMATIONS 用 SPM Deformations 保存最终 MNI 拉回场及原生逆向场。
% DARTEL flow 不可冒充 y_；Shooting 原生 y_ 的模板网格也不自动等于 MNI。
folder=fullfile(out,'normalisation_fields');mkdir(folder);outputs={};
if strcmp(n.method,'dartel')
    component=struct('dartel',struct('flowfield',{{field}},'times',[1 0], ...
        'K',n.dartel.timeSteps(end),'template',{{template}}));
else
    % 原生 Shoot y_ 储存 native 毫米坐标；把模板网格映射到 MNI，数据值不变。
    mniField=fullfile(folder,'y_shoot_mni_mapping.nii');copyfile(field,mniField);
    spm_get_space(mniField,mni.affine);outputs={mniField};
    component=struct('def',{{mniField}});
end
job=struct('comp',{{component,struct('idbbvox',struct('bb',cfg.boundingBoxMm,'vox',cfg.voxelSizeMm))}}, ...
    'out',{{struct('savedef',struct('ofname','group_forward','savedir',struct('saveusr',{{folder}})))}});
b={};b{1}.spm.util.defs=job;record=fullfile(folder,'forward_job.mat');psy.spm_step(b,record);
forward=fullfile(folder,'y_group_forward.nii');
% 反演原始密集场，而非截到目标 bbox 后的场，保留原生图谱转换覆盖。
job=struct('comp',{{struct('inv',struct('comp',{{component}},'space',{{t1}}))}}, ...
    'out',{{struct('savedef',struct('ofname','group_inverse','savedir',struct('saveusr',{{folder}})))}});
b={};b{1}.spm.util.defs=job;inverseRecord=fullfile(folder,'inverse_job.mat');psy.spm_step(b,inverseRecord);
inverse=fullfile(folder,'y_group_inverse.nii'); % 名称不是 stock iy_，记录中明确用途。
outputs=[outputs,{record,inverseRecord,forward,inverse}];
end
