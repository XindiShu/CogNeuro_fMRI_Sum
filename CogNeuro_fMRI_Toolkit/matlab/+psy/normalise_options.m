function n=normalise_options(cfg)
%NORMALISE_OPTIONS 标准化路线和原生 SPM 菜单；旧配置缺字段时保持原路线。
% segmentation 使用当前 Segment/CAT 的 y_；dartel/shooting 使用 SPM Imported GM/WM。
n=cfg.normalise;
n=fill(n,struct('method','segmentation'));
n=branch(n,'group',struct('mode','create','templates',{{}}, ...
    'anatomyUnit','subject','writeMethod','native','preserve',0));
n=branch(n,'dartel',struct('regularisationForm',0,'innerIterations',[3 3 3 3 3 3], ...
    'regularisation',[4 2 1e-6;2 1 1e-6;1 .5 1e-6;.5 .25 1e-6;.25 .125 1e-6;.25 .125 1e-6], ...
    'timeSteps',[0 0 1 2 4 6],'templateSmoothing',[16 8 4 2 1 .5], ...
    'lmRegularisation',.01,'solverCycles',3,'solverIterations',3));
n=branch(n,'shooting',struct('iterations',24,'regularisation',[1e-4 .001 .2 .05 .2], ...
    'templateRegularisation',[.0001 .08 .8],'smoothingIterations',16, ...
    'solverCyclesIterations',[2 2],'stepScale',.8,'maxTimeSteps',8, ...
    'coarseScale',32,'scheduleDecay',.5,'symmetricTemplate',false));
if ~ismember(n.method,{'segmentation','dartel','shooting'}) || ...
        ~ismember(n.group.mode,{'create','existing'}) || ...
        ~ismember(n.group.anatomyUnit,{'subject','subject_session'}) || ...
        ~ismember(n.group.writeMethod,{'native','deformations'})
    error('psy:NormaliseConfig','无效的标准化路线/模板模式/结构单位/写出方式');
end
if ~isscalar(n.group.preserve)||~ismember(n.group.preserve,[0 1])
    error('psy:NormaliseConfig','group.preserve=0浓度或1组织量调制；fMRI通常保持0');
end
if strcmp(n.group.writeMethod,'deformations') && n.group.preserve~=0
    error('psy:NormaliseConfig','Deformations 拉回写出只支持 preserve=0；调制请选择 native');
end
if ~iscell(n.group.templates)||~all(cellfun(@(x)ischar(x)&&isrow(x)&&~isempty(x),n.group.templates))
    error('psy:NormaliseConfig','group.templates 须为按粗到细排序的文件路径 cell');
end
if ~strcmp(n.method,'segmentation')
    s=psy.segment_options(cfg);
    if ~strcmp(s.backend,'spm')
        error('psy:NormaliseBackend','独立 DARTEL/Shooting 需要 SPM Segment Imported 图；CAT 请选 segmentation');
    end
    if strcmp(n.group.mode,'existing')
        if (strcmp(n.method,'dartel')&&numel(n.group.templates)~=6) || ...
                (strcmp(n.method,'shooting')&&isempty(n.group.templates))
            error('psy:NormaliseTemplates','已有模板模式：DARTEL需要6个模板；Shooting至少1个，按粗到细排序');
        end
    elseif ~isempty(n.group.templates)
        error('psy:NormaliseTemplates','create 模式请将 templates 留空；输入已有模板时选 existing');
    end
end
d=n.dartel;
menu(d.regularisationForm,0:2,'dartel.regularisationForm');
integerVector(d.innerIterations,6,1,10,'dartel.innerIterations');
array(d.regularisation,[6 3],0,'dartel.regularisation');
integerVector(d.timeSteps,6,0,9,'dartel.timeSteps');
if numel(d.templateSmoothing)~=6 || any(~ismember(d.templateSmoothing,[0 .5 1 2 4 8 16 32]))
    error('psy:NormaliseConfig','dartel.templateSmoothing 须有6个 SPM 菜单值');
end
array(d.lmRegularisation,[1 1],0,'dartel.lmRegularisation');
menu(d.solverCycles,1:8,'dartel.solverCycles');menu(d.solverIterations,1:8,'dartel.solverIterations');
s=n.shooting;
integerVector(s.iterations,1,2,1000,'shooting.iterations');
array(s.regularisation,[1 5],0,'shooting.regularisation');
array(s.templateRegularisation,[1 3],0,'shooting.templateRegularisation');
integerVector(s.smoothingIterations,1,0,1000,'shooting.smoothingIterations');
integerVector(s.solverCyclesIterations,2,1,100,'shooting.solverCyclesIterations');
array(s.stepScale,[1 1],eps,'shooting.stepScale');
if s.stepScale>1,error('psy:NormaliseConfig','shooting.stepScale 不超过1');end
integerVector(s.maxTimeSteps,1,1,64,'shooting.maxTimeSteps');
array(s.coarseScale,[1 1],1,'shooting.coarseScale');
array(s.scheduleDecay,[1 1],eps,'shooting.scheduleDecay');
menu(s.symmetricTemplate,[0 1],'shooting.symmetricTemplate');
end
function s=branch(s,name,d)
if ~isfield(s,name),s.(name)=struct;end
s.(name)=fill(s.(name),d);
end
function s=fill(s,d)
if ~isstruct(s)||~isscalar(s),error('psy:NormaliseConfig','配置分支须为标量struct');end
for name=fieldnames(d)',if ~isfield(s,name{1}),s.(name{1})=d.(name{1});end,end
end
function array(x,shape,minimum,name)
if ~isnumeric(x)||~isequal(size(x),shape)||any(~isfinite(x(:)))||any(x(:)<minimum)
    error('psy:NormaliseConfig','%s 的形状/有限数值/下界无效',name);
end
end
function integerVector(x,count,lo,hi,name)
if ~isnumeric(x)||~isequal(size(x),[1 count])||any(~isfinite(x))|| ...
        any(x~=floor(x))||any(x<lo)||any(x>hi)
    error('psy:NormaliseConfig','%s 须为 %d 个 %g..%g 的整数',name,count,lo,hi);
end
end
function menu(x,choices,name)
if ~isscalar(x)||~ismember(x,choices),error('psy:NormaliseConfig','%s 不在菜单中',name);end
end
