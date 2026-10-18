function d=shooting_defaults(n)
%SHOOTING_DEFAULTS 从本机官方 defaults 派生本次参数，不修改 SPM 安装。
% schedule/eul_its 采用 spm_shoot_defaults 原公式；这是接口映射，不重写配准。
d=spm_shoot_defaults;s=n.shooting;
d.tname='Template';d.issym=logical(s.symmetricTemplate);
d.cyc_its=s.solverCyclesIterations;d.rparam=s.regularisation;
d.sparam=s.templateRegularisation;d.smits=s.smoothingIterations;d.scale=s.stepScale;
d.sched=(s.coarseScale-1)*exp(-s.scheduleDecay*(0:s.iterations))+1;
d.sched=d.sched/d.sched(end);
d.eul_its=round((0:s.iterations-1)*(s.maxTimeSteps-.5001)/(s.iterations-1)+1);
end
