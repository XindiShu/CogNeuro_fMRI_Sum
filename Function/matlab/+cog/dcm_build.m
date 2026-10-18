function DCM=dcm_build(data,model,mode,o)
%DCM_BUILD 显式区域时序、采集参数、输入及二值网络→SPM DCM，不写文件。
required={'y','trSeconds','roiNames','TESeconds','delaysSeconds'};
if ~isstruct(data)||~all(isfield(data,required))||~isnumeric(data.y)||~ismatrix(data.y)||~isreal(data.y)||any(~isfinite(data.y),'all'),error('cog:DCMData','Explicit finite region data and acquisition metadata required');end
[nt,n]=size(data.y);names=string(data.roiNames(:));
if n<1||nt<16||numel(names)~=n||numel(unique(names))~=n||any(ismissing(names)|names=="")||any(std(data.y,0,1)<=eps),error('cog:DCMData','Need >=16 frames, nonconstant ROIs and unique ordered names');end
tr=data.trSeconds;te=data.TESeconds;delays=data.delaysSeconds(:);
if ~isscalar(tr)||~isfinite(tr)||tr<=0||~isscalar(te)||~isfinite(te)||te<=0||te>.1||numel(delays)~=n||any(~isfinite(delays)|delays<0|delays>tr),error('cog:DCMTiming','TR/TE/delays must be seconds, TE in (0,.1], delays in [0,TR]');end
if ~ismember(mode,{'task','spectral'})||~isscalar(o.maxIterations)||o.maxIterations<1||fix(o.maxIterations)~=o.maxIterations||~isfinite(o.maxIterations),error('cog:DCMOptions','Invalid mode/maxIterations');end
if ~isscalar(o.arOrder)||~isfinite(o.arOrder)||o.arOrder<1||o.arOrder~=fix(o.arOrder),error('cog:DCMOptions','Invalid AR order');end
if ~isfield(model,'a')||~isequal(size(model.a),[n n])||any(diag(model.a)~=1),error('cog:DCMNetwork','A must match named nodes and include every diagonal');end
checkBinary(model.a);
X0=ones(nt,1);if isfield(data,'X0')&&~isempty(data.X0),X0=double(data.X0);end
if ~ismatrix(X0)||size(X0,1)~=nt||any(~isfinite(X0),'all')||rank(X0)~=size(X0,2)||nt-size(X0,2)<8,error('cog:DCMConfounds','Finite full-column-rank confounds must match time');end
DCM=struct('a',double(model.a),'n',n,'v',nt,'TE',te,'delays',delays,'d',zeros(n,n,0));
DCM.Y=struct('y',double(data.y),'dt',tr,'name',{cellstr(names)},'X0',X0,'Q',{spm_Ce(repmat(nt,1,n))});
DCM.options=struct('two_state',0,'stochastic',0,'nonlinear',0,'centre',logical(o.centerInputs),'nograph',1,'maxit',o.maxIterations,'order',o.arOrder,'maxnodes',8);
if strcmp(mode,'task')
    if ~all(isfield(data,{'u','inputDtSeconds','inputNames'}))||~isnumeric(data.u)||~ismatrix(data.u)||any(~isfinite(data.u),'all')||~isreal(data.u),error('cog:DCMInput','Explicit neural input matrix/time step/names required');end
    nu=size(data.u,2);dt=data.inputDtSeconds;inputNames=string(data.inputNames(:));
    if nu<1||~any(data.u,'all')||~isscalar(dt)||~isfinite(dt)||dt<=0||dt>tr||abs(tr/dt-round(tr/dt))>1e-7||size(data.u,1)*dt<nt*tr-1e-7||numel(inputNames)~=nu||numel(unique(inputNames))~=nu||any(ismissing(inputNames)|inputNames=="")
        error('cog:DCMInput','Input names/timing must cover full scan duration at an integer microtime ratio');
    end
    if ~all(isfield(model,{'b','c'}))||~isequal(size(model.c),[n nu])||size(model.b,1)~=n||size(model.b,2)~=n||size(model.b,3)~=nu||~any(model.c,'all'),error('cog:DCMNetwork','Explicit compatible B/C required, with driving inputs');end
    checkBinary(model.b);checkBinary(model.c);DCM.b=double(model.b);DCM.c=double(model.c);DCM.U=struct('u',double(data.u),'dt',dt,'name',{cellstr(inputNames)});DCM.options.induced=0;
else
    if nt<4*o.arOrder,error('cog:DCMData','Spectral AR requires at least 4*order frames');end
    if (isfield(model,'b')&&any(model.b,'all'))||(isfield(model,'c')&&any(model.c,'all')),error('cog:DCMNetwork','Rest spectral model has no task B/C');end
    DCM.b=zeros(n,n,0);DCM.c=zeros(n,0);DCM.U=struct('u',zeros(nt,0),'dt',tr,'name',{{}});DCM.options.induced=1;DCM.options.analysis='CSD';
end
end
function checkBinary(x)
if ~(isnumeric(x)||islogical(x))||~isreal(x)||any(~isfinite(x),'all')||any(x~=0&x~=1,'all'),error('cog:DCMNetwork','Binary connection masks required');end
end
