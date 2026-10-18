function result=cogneuro_toolkit_dispatch(job)
%COGNEURO_TOOLKIT_DISPATCH 现成工具包配置/调用桥，不实现任何分析算法。
% prepare只加载受选包配置；execute才按登记的原始签名调用原函数。
previous=path;directory=pwd;restore=onCleanup(@()restoreEnvironment(previous,directory));
root=char(java.io.File(job.toolkit_root).getCanonicalPath());
registry=jsondecode(fileread(job.catalog_file));entries=registry.entries;
index=find(strcmp({entries.id},job.method_id));assert(isscalar(index),'cogneuro:NativeMethod','Unknown/duplicate method');
entry=entries(index);assert(~strcmp(entry.role,'validation'),'cogneuro:NativeMethod','Development tests are not analysis methods');
assert(~isfolder(job.output_root)&&~isfile(job.output_root),'cogneuro:NativeExists','Choose a new output root');
addpath(root,fullfile(root,'matlab'),fullfile(root,'config'),'-begin');
if ~isempty(job.spm_root),addpath(job.spm_root,'-begin');end
verifySource(entry.target,root);
demo=struct;
if isempty(entry.config_file)
    cfg=struct('spmMat',[],'roiManifest',[],'sessionIndex',[],'TESeconds',[]);
else
    [~,factory]=fileparts(entry.config_file);verifySource(factory,root);
    if strcmp(entry.style,'cfg_demo'),[cfg,demo]=feval(factory);else,cfg=feval(factory);end
end
for k=1:numel(job.overrides)
    key=char(job.overrides(k).path);
    assert(~ismember(key,{'execute','outputRoot'}),'cogneuro:NativeOverride','Controlled execution/output field');
    if startsWith(key,'demo.')
        assert(strcmp(entry.style,'cfg_demo'),'cogneuro:NativeOverride','No demo arguments for this method');
        demo=setExisting(demo,key(6:end),job.overrides(k).value);
    else
        cfg=setExisting(cfg,key,job.overrides(k).value);
    end
end
manifest='';specs=[];
for k=1:numel(job.bindings)
    key=char(job.bindings(k).path);value=job.bindings(k).value;
    assert(ismember(string(key),string(entry.input_names)),'cogneuro:NativeBinding','Input is not part of selected interface');
    if strcmp(key,'argument_manifest')
        manifest=char(value);
    elseif strcmp(key,'specsFile')
        specs=jsondecode(fileread(char(value)));
    else
        cfg=setExisting(cfg,key,value);
    end
end
cfg.outputRoot=job.output_root;
if isfield(cfg,'spmPath')&&~isempty(job.spm_root),cfg.spmPath=job.spm_root;end
assert(islogical(job.native_execute)&&isscalar(job.native_execute),'cogneuro:NativeMode','Explicit native_execute required');
if isfield(cfg,'execute')
    cfg.execute=job.native_execute;
else
    assert(job.native_execute,'cogneuro:NativeMode','This native entry has no execute flag');
end
result=struct('schema_version',1,'route','toolkit_method','method_id',job.method_id,'mode',job.mode, ...
    'status','preflight_passed','native_analysis_called',false,'scientific_qc_passed',false, ...
    'target',entry.target,'native_execute',job.native_execute,'resolved_config',jsonSafe(cfg),'resolved_demo',jsonSafe(demo), ...
    'preflight_level','configuration_only','output_files',{{}}, ...
    'limitations',{{'No native analysis or native execute=false preflight is run by configuration inspection.', ...
    'Native entry owns mathematical, model and dependency checks; source mapping does not establish scientific validity.'}});
if strcmp(job.mode,'preflight'),return;end
% 只在此处调用已确认的现成函数；不运行会重新覆盖cfg的顶层脚本。
switch entry.style
    case 'cfg',nativeReturn=feval(entry.target,cfg);
    case 'cfg_manifest',nativeReturn=feval(entry.target,cfg,manifest);
    case 'qc_roots',nativeReturn=feval(entry.target,cfg.inputRoot,cfg.outputRoot);
    case 'cfg_demo',nativeReturn=feval(entry.target,cfg,demo);
    case 'specs_cfg',nativeReturn=feval(entry.target,specs,cfg);
    case 'dcm_spm',nativeReturn=feval(entry.target,cfg.spmMat,cfg.roiManifest,cfg.sessionIndex,cfg.TESeconds,cfg.outputRoot);
    otherwise,error('cogneuro:NativeStyle','Unsupported registered argument signature');
end
assert(isfolder(job.output_root),'cogneuro:NativeNoOutput','Native entry did not create its declared output root');
save(fullfile(job.output_root,'cogneuro_native_return.mat'),'nativeReturn','cfg','demo','-v7.3');
statuses=collectStatuses(nativeReturn);
bad=contains(lower(string(statuses)),["failed","error","incomplete"]);
assert(~any(bad,'all'),'cogneuro:NativeIncomplete','Native return contains failure/incomplete status; outputs preserved');
listing=dir(fullfile(job.output_root,'**','*'));listing=listing(~[listing.isdir]);
result.output_files=arrayfun(@(item)fullfile(item.folder,item.name),listing,'UniformOutput',false);
result.status='complete';result.native_analysis_called=true;result.native_statuses=statuses;
result.native_return_file=fullfile(job.output_root,'cogneuro_native_return.mat');
result.preflight_level='configuration_only; native entry subsequently executed';
end
function value=setExisting(value,key,new)
parts=strsplit(char(key),'.');assert(all(cellfun(@(p)~isempty(regexp(p,'^[A-Za-z][A-Za-z0-9_]*$','once')),parts)), ...
    'cogneuro:NativeOverride','Invalid field path');
name=parts{1};assert(isstruct(value)&&isscalar(value)&&isfield(value,name),'cogneuro:NativeOverride','Unknown native field: %s',key);
if numel(parts)>1,value.(name)=setExisting(value.(name),strjoin(parts(2:end),'.'),new);return;end
old=value.(name);
% 原生模型/三维网络/成分矩阵可从已确认MAT变量传递，保留维度和MATLAB类型。
if isstruct(new)&&isscalar(new)&&isequal(sort(fieldnames(new)),sort({'matlab_value_file';'variable'}))
    file=char(new.matlab_value_file);variable=char(new.variable);
    assert(java.io.File(file).isAbsolute()&&isfile(file)&&isvarname(variable),'cogneuro:NativeValue','Existing absolute MAT file and variable required');
    loaded=load(file,variable);assert(isfield(loaded,variable),'cogneuro:NativeValue','Confirmed MAT variable missing');
    value.(name)=loaded.(variable);return;
end
if iscell(old)&&~iscell(new)&&isstruct(new),new=num2cell(new);end
if iscell(old)&&(iscell(new)||isstring(new))
    new=reshape(cellstrIfString(new),1,[]);
elseif isnumeric(old)&&isnumeric(new)&&isvector(new)&&isrow(old)
    new=new(:)';
elseif islogical(old)&&isnumeric(new)&&isscalar(new)&&ismember(new,[0 1])
    new=logical(new);
end
value.(name)=new;
end
function value=cellstrIfString(value)
if isstring(value),value=cellstr(value);end
end
function statuses=collectStatuses(value)
statuses={};
if isstruct(value)
    for k=1:numel(value)
        fields=fieldnames(value);
        for j=1:numel(fields)
            item=value(k).(fields{j});
            if strcmpi(fields{j},'status')&&(ischar(item)||isstring(item)),statuses{end+1}=char(item); %#ok<AGROW>
            elseif isstruct(item)||iscell(item),statuses=[statuses collectStatuses(item)];end %#ok<AGROW>
        end
    end
elseif iscell(value)
    for k=1:numel(value),if isstruct(value{k})||iscell(value{k}),statuses=[statuses collectStatuses(value{k})];end,end %#ok<AGROW>
end
end
function verifySource(name,root)
file=which(name);assert(~isempty(file),'cogneuro:NativeSource','Missing native function %s',name);
file=char(java.io.File(file).getCanonicalPath());
assert(startsWith(lower(file),[lower(root) filesep]),'cogneuro:NativeSource','Function resolves outside selected toolkit: %s',name);
end
function value=jsonSafe(value)
if isstruct(value)
    for k=1:numel(value),fields=fieldnames(value);for j=1:numel(fields),value(k).(fields{j})=jsonSafe(value(k).(fields{j}));end,end
elseif iscell(value)
    for k=1:numel(value),value{k}=jsonSafe(value{k});end
elseif isnumeric(value)&&any(~isfinite(value),'all')
    cells=num2cell(value);
    for k=1:numel(cells)
        if isnan(cells{k}),cells{k}='NaN';elseif cells{k}>0,cells{k}='Inf';else,cells{k}='-Inf';end
    end
    if isscalar(value),value=cells{1};else,value=cells;end
end
end
function restoreEnvironment(previous,directory)
path(previous);cd(directory);
end
