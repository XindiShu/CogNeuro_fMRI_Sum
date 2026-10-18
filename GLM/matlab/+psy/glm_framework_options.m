function cfg=glm_framework_options(cfg)
%GLM_FRAMEWORK_OPTIONS 在创建输出前验证配置与组合；不静默降级未实现功能。
required={'model','events','hrf','fit','level','engine','explicitMask','qc','subject','group','pmod','glmsingle'};
if ~all(isfield(cfg,required)), error('psy:GLMFrameworkConfig','Use the current glm_config as the complete configuration'); end
base={'manifestFile','outputRoot','spmPath','execute','conditions','contrastNames','contrastWeights', ...
    'highpassSeconds','serialCorrelation','microtimeResolution','microtimeOnset','design', ...
    'maskThreshold','minResidualDF','continueOnError'};
if ~all(isfield(cfg,base))||any(~ismember(fieldnames(cfg),[base required]))
    error('psy:GLMFrameworkConfig','Unknown/missing top-level configuration fields; use the documented configuration');
end
checkFields(cfg.model,{'unit','targetConditions'},'model');
checkFields(cfg.events,{'expression','fixedDurationSeconds'},'events');
checkFields(cfg.hrf,{'type','fir'},'hrf');
checkFields(cfg.hrf.fir,{'windowSeconds','nBins','summaryBins','includeOmnibus'},'hrf.fir');
checkFields(cfg.pmod,{'enabled','modulators','center','scale','orthogonalize'},'pmod');
f=cfg.hrf.fir;
if ~isnumeric(f.windowSeconds)||~isreal(f.windowSeconds)||~isscalar(f.windowSeconds)||~isfinite(f.windowSeconds)||f.windowSeconds<=0|| ...
        ~isnumeric(f.nBins)||~isreal(f.nBins)||~isscalar(f.nBins)||~isfinite(f.nBins)||f.nBins<1||fix(f.nBins)~=f.nBins
    error('psy:GLMFIRConfig','FIR window must be positive seconds and nBins a positive integer');
end
if ~isnumeric(f.summaryBins)||~isreal(f.summaryBins)||(~isempty(f.summaryBins)&&~isvector(f.summaryBins))|| ...
        any(~isfinite(f.summaryBins)|f.summaryBins<1|f.summaryBins>f.nBins|fix(f.summaryBins)~=f.summaryBins)|| ...
        numel(unique(f.summaryBins))~=numel(f.summaryBins)
    error('psy:GLMFIRConfig','summaryBins must contain distinct indices in 1..nBins, or be empty');
end
for value={cfg.pmod.enabled,cfg.pmod.orthogonalize,f.includeOmnibus}
    if ~islogical(value{1})||~isscalar(value{1}),error('psy:GLMFrameworkConfig','pmod/FIR switches must be logical scalars');end
end
cfg.pmod.center=choice(cfg.pmod.center,{'within_condition','none'},'pmod centering');
cfg.pmod.scale=choice(cfg.pmod.scale,{'none','zscore'},'pmod scaling');
if strcmp(cfg.pmod.scale,'zscore')&&~strcmp(cfg.pmod.center,'within_condition')
    error('psy:GLMPmodConfig','zscore requires within_condition centering');
end
m=cfg.pmod.modulators;fields={'condition','column','name','poly'};
if ~isstruct(m)||~all(isfield(m,fields))||any(~ismember(fieldnames(m),fields))
    error('psy:GLMPmodConfig','modulators must be a struct array with condition/column/name/poly');
end
keys=strings(numel(m),1);
for k=1:numel(m)
    for label={'condition','column','name'}
        v=string(m(k).(label{1}));
        if ~isscalar(v)||ismissing(v)||isempty(regexp(char(v),'^[A-Za-z][A-Za-z0-9_]*$','once'))
            error('psy:GLMPmodConfig','pmod labels/columns must be simple letter-led labels');
        end
    end
    if ~ismember(string(m(k).condition),string(cfg.conditions)),error('psy:GLMPmodConfig','Unknown pmod condition');end
    v=m(k).poly;
    if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||v<1||v>6||fix(v)~=v,error('psy:GLMPmodConfig','poly must be an integer in 1..6');end
    keys(k)=string(m(k).condition)+"/"+string(m(k).name);
end
if numel(unique(keys))~=numel(keys),error('psy:GLMPmodConfig','Duplicate pmod name within a condition');end
if cfg.pmod.enabled==isempty(m),error('psy:GLMPmodConfig','Enabled pmod needs modulators; disabled pmod requires an empty array');end
checkFields(cfg.fit,{'strategy','lssGrouping'},'fit');
checkFields(cfg.qc,{'plot','maxResidualVoxels'},'qc');
checkFields(cfg.subject,{'combineSessions'},'subject');
% 兼容早期仅含两个group字段的完整配置；新增字段按当前默认补齐。
groupDefaults=struct('pairedLevels',{{'pre','post'}},'groupLabels',{{'groupA','groupB'}}, ...
    'minPerGroup',2,'covariateColumns',{{}},'covariateCenter','overall','minResidualDF',1);
for label=fieldnames(groupDefaults)'
    if ~isfield(cfg.group,label{1}),cfg.group.(label{1})=groupDefaults.(label{1});end
end
checkFields(cfg.group,[{'design','minSubjects'} fieldnames(groupDefaults)'],'group');
if ~islogical(cfg.subject.combineSessions)||~isscalar(cfg.subject.combineSessions)
    error('psy:GLMFrameworkConfig','combineSessions must be logical scalar');
end
cfg.group.design=choice(cfg.group.design,{'one_sample','paired','two_sample','regression'},'group design');
if ~isnumeric(cfg.group.minSubjects)||~isreal(cfg.group.minSubjects)||~isscalar(cfg.group.minSubjects)|| ...
        ~isfinite(cfg.group.minSubjects)||cfg.group.minSubjects<2||fix(cfg.group.minSubjects)~=cfg.group.minSubjects
    error('psy:GLMFrameworkConfig','group.minSubjects must be an integer >=2');
end
for label={'minPerGroup','minResidualDF'}
    v=cfg.group.(label{1});minimum=1;if strcmp(label{1},'minPerGroup'),minimum=2;end
    if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||v<minimum||fix(v)~=v
        error('psy:GLMGroupConfig','Invalid group minimum count/dimensions');
    end
end
for label={'pairedLevels','groupLabels'}
    v=string(cfg.group.(label{1}));
    if ~isvector(v)||numel(v)~=2||any(ismissing(v)|strlength(strtrim(v))==0)||numel(unique(lower(v)))~=2
        error('psy:GLMGroupConfig','Set two distinct nonempty group/paired labels');
    end
    cfg.group.(label{1})=cellstr(v(:));
end
v=string(cfg.group.covariateColumns(:));
if any(ismissing(v))||numel(unique(lower(v)))~=numel(v)
    error('psy:GLMGroupConfig','Distinct explicit covariate column names required');
end
reserved={'subject','session','contrast','contrast_image','mask','group','pair_level','intercept','group1','group2'};
for k=1:numel(v)
    if isempty(regexp(char(v(k)),'^[A-Za-z][A-Za-z0-9_]*$','once'))||ismember(lower(v(k)),reserved)
        error('psy:GLMGroupConfig','Covariate columns must be safe nonreserved names');
    end
end
cfg.group.covariateColumns=cellstr(v);
cfg.group.covariateCenter=choice(cfg.group.covariateCenter,{'overall','none'},'group covariate centering');
if strcmp(cfg.group.design,'regression')&&isempty(v)||strcmp(cfg.group.design,'paired')&&~isempty(v)
    error('psy:GLMGroupConfig','Regression needs covariates; paired currently forbids covariates');
end
designFields={'motionModel','includeTissueMeans','linearTrend','addSpikes','fdThresholdMm','minResidualDF','inputRoot','outputRoot'};
if ~isstruct(cfg.design)||~isscalar(cfg.design)||any(~ismember(fieldnames(cfg.design),designFields))
    error('psy:GLMFrameworkConfig','Unknown fields in design configuration');
end
for name={'microtimeResolution','microtimeOnset','minResidualDF'}
    value=cfg.(name{1});
    if ~isnumeric(value)||~isreal(value)||~isscalar(value)||~isfinite(value)||value<1||fix(value)~=value
        error('psy:GLMFrameworkConfig','%s must be a finite positive integer',name{1});
    end
end
if cfg.microtimeOnset>cfg.microtimeResolution,error('psy:GLMFrameworkConfig','microtimeOnset exceeds resolution');end
cfg.model.unit=choice(cfg.model.unit,{'condition','event','trial','item','block','phase','trial_phase'},'unit');
cfg.events.expression=choice(cfg.events.expression,{'duration','impulse','fixed'},'event expression');
cfg.fit.strategy=choice(cfg.fit.strategy,{'joint','lss'},'fit strategy');
cfg.fit.lssGrouping=choice(cfg.fit.lssGrouping,{'pooled','condition'},'LSS grouping');
cfg.level=choice(cfg.level,{'run','subject','group'},'level');
cfg.engine=choice(cfg.engine,{'spm_classical','glmsingle'},'engine');
if strcmp(cfg.engine,'spm_classical')&&strcmp(cfg.level,'subject')&&(~strcmp(cfg.model.unit,'condition')||~strcmp(cfg.fit.strategy,'joint'))
    error('psy:GLMUnsupportedCombination','Subject level currently requires condition units with joint fitting');
end
if strcmp(cfg.engine,'glmsingle')
    cfg.hrf.type=choice(cfg.hrf.type,{'canonical','library'},'GLMsingle HRF');
    if ~strcmp(cfg.level,'subject')||~ismember(cfg.model.unit,{'event','trial'})||~strcmp(cfg.fit.strategy,'joint')|| ...
            cfg.pmod.enabled||~isempty(cfg.model.targetConditions)||strcmp(cfg.events.expression,'impulse')
        error('psy:GLMUnsupportedCombination','GLMsingle requires subject level, event/trial units, joint fitting, no target filter/pmod, and duration/fixed expression');
    end
else
    psy.glm_basis(cfg.hrf.type,cfg.hrf.fir);cfg.hrf.type=char(cfg.hrf.type);
end
psy.glmsingle_options(cfg.glmsingle);
if (cfg.pmod.enabled||strcmp(cfg.hrf.type,'fir'))&&(~strcmp(cfg.model.unit,'condition')||~strcmp(cfg.fit.strategy,'joint'))
    error('psy:GLMUnsupportedCombination','pmod/FIR currently require condition units with joint fitting');
end
if cfg.pmod.enabled&&strcmp(cfg.hrf.type,'fir'),error('psy:GLMUnsupportedCombination','Combined pmod+FIR is not implemented');end
if strcmp(cfg.fit.strategy,'lss') && ismember(cfg.model.unit,{'condition','phase'})
    error('psy:GLMUnsupportedCombination','Condition/condition-phase means use joint fitting; condition-target LSS is not implemented');
end
if ~isnumeric(cfg.events.fixedDurationSeconds)||~isreal(cfg.events.fixedDurationSeconds)||~isscalar(cfg.events.fixedDurationSeconds)|| ...
        ~isfinite(cfg.events.fixedDurationSeconds)||cfg.events.fixedDurationSeconds<0
    error('psy:GLMFrameworkConfig','fixedDurationSeconds must be a finite nonnegative scalar');
end
for name={'execute','continueOnError'}
    value=cfg.(name{1});
    if ~islogical(value)||~isscalar(value), error('psy:GLMFrameworkConfig','%s must be logical scalar',name{1}); end
end
if ~islogical(cfg.qc.plot)||~isscalar(cfg.qc.plot)||~isnumeric(cfg.qc.maxResidualVoxels)|| ...
        ~isscalar(cfg.qc.maxResidualVoxels)||~isfinite(cfg.qc.maxResidualVoxels)|| ...
        cfg.qc.maxResidualVoxels<1||fix(cfg.qc.maxResidualVoxels)~=cfg.qc.maxResidualVoxels
    error('psy:GLMFrameworkConfig','Invalid diagnostic settings');
end
cfg.model.targetConditions=cellstr(string(cfg.model.targetConditions(:)));
if numel(unique(cfg.model.targetConditions))~=numel(cfg.model.targetConditions)|| ...
        any(strlength(strtrim(string(cfg.model.targetConditions)))==0)
    error('psy:GLMFrameworkConfig','Target conditions must be distinct nonempty labels');
end
if strcmp(cfg.model.unit,'condition') && ~isempty(cfg.model.targetConditions)
    error('psy:GLMFrameworkConfig','Condition mode uses explicit condition contrasts; leave targetConditions empty');
end
if ~(ischar(cfg.explicitMask)||isstring(cfg.explicitMask))||~isscalar(string(cfg.explicitMask))||ismissing(string(cfg.explicitMask))
    error('psy:GLMFrameworkConfig','explicitMask must be a scalar path or empty text');
end
cfg.explicitMask=char(cfg.explicitMask);
if ~isempty(cfg.explicitMask) && (~java.io.File(cfg.explicitMask).isAbsolute()||~isfile(cfg.explicitMask))
    error('psy:GLMMask','Global explicitMask must be an existing absolute path');
end
end

function checkFields(s,names,label)
if ~isstruct(s)||~isscalar(s)||~all(isfield(s,names))||any(~ismember(fieldnames(s),names))
    error('psy:GLMFrameworkConfig','Unknown/missing configuration fields in %s',label);
end
end

function value=choice(value,allowed,label)
if ~(ischar(value)||isstring(value))||~isscalar(string(value))||~ismember(string(value),string(allowed))
    error('psy:GLMUnsupportedOption','Unsupported %s',label);
end
value=char(value);
end
