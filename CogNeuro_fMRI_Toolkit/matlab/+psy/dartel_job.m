function job=dartel_job(images,n,templates)
%DARTEL_JOB 映射官方 Run Dartel 的 settings；每列组织的被试顺序一致。
if nargin<3,templates={};end
d=n.dartel;
job=struct('images',{images},'settings',struct('rform',d.regularisationForm));
for k=1:6
    parameter=struct('its',d.innerIterations(k), ...
        'rparam',d.regularisation(k,:),'K',d.timeSteps(k));
    if isempty(templates),parameter.slam=d.templateSmoothing(k);
    else,parameter.template=templates(k);end
    job.settings.param(k)=parameter;
end
job.settings.optim=struct('lmreg',d.lmRegularisation,'cyc',d.solverCycles,'its',d.solverIterations);
if isempty(templates),job.settings.template='Template';end
end
