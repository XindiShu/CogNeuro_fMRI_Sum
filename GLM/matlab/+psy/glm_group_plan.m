function plans=glm_group_plan(cfg)
%GLM_GROUP_PLAN 二级清单→按ID配对/分组/协变量/独立设计；不创建文件或估计。
cfg=psy.glm_framework_options(cfg);g=cfg.group;
if ~java.io.File(cfg.manifestFile).isAbsolute(),cfg.manifestFile=fullfile(pwd,cfg.manifestFile);end
o=detectImportOptions(cfg.manifestFile,'FileType','text','Delimiter','\t','VariableNamingRule','preserve');
required={'subject','session','contrast','contrast_image','mask'};extra=g.covariateColumns(:)';
if strcmp(g.design,'paired'),extra=[extra {'pair_level'}];end
if strcmp(g.design,'two_sample'),extra=[extra {'group'}];end
allowed=[required extra];
if ~all(ismember(allowed,o.VariableNames))||any(~ismember(o.VariableNames,allowed))
    error('psy:GLMGroupColumns','Group manifest columns must match the selected design and covariates');
end
o.DataLines=[2 Inf];o.ConsecutiveDelimitersRule='split';o.ExtraColumnsRule='error';
o=setvartype(o,o.VariableNames,'string');t=fillmissing(readtable(cfg.manifestFile,o),'constant',"");
if isempty(t),error('psy:NoRuns','Empty group manifest');end
for label={'subject','session'}
    for k=1:height(t)
        id=char(t.(label{1})(k));if isempty(id)&&strcmp(label{1},'session'),continue;end
        if isempty(regexp(id,'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('psy:UnsafeID','Invalid ID');end
    end
end
if any(strlength(strtrim(t.contrast))==0),error('psy:GLMContrast','Empty contrast labels');end
keys=lower(t.subject)+"/"+t.contrast;
if strcmp(g.design,'paired'),keys=keys+"/"+t.pair_level;end
if numel(unique(keys))~=height(t),error('psy:GLMGroupDuplicate','Repeated subject/effect or pair level');end
base=fileparts(char(java.io.File(cfg.manifestFile).getCanonicalPath()));
for k=1:height(t)
    for label={'contrast_image','mask'}
        p=char(t.(label{1})(k));if isempty(p),error('psy:GLMGroupInput','Empty contrast/mask path');end
        if ~java.io.File(p).isAbsolute(),p=fullfile(base,p);end
        p=char(java.io.File(p).getCanonicalPath());if ~isfile(p),error('psy:GLMGroupInput','Missing input: %s',p);end
        t.(label{1})(k)=string(p);
    end
    [~,name]=fileparts(t.contrast_image(k));
    if any(startsWith(name,{'spmT','spmF','ess_'},'IgnoreCase',true))
        error('psy:GLMGroupInput','Use unthresholded effect images, not statistic images');
    end
end
labels=unique(t.contrast,'stable');cohort=sort(unique(lower(t.subject(t.contrast==labels(1)))));
plans=struct([]);
for k=1:numel(labels)
    rows=t(t.contrast==labels(k),:);subjects=unique(lower(rows.subject),'stable');n=numel(subjects);
    if n<g.minSubjects||~isequal(sort(subjects),cohort),error('psy:GLMGroupSample','Insufficient/inconsistent explicit subject cohort');end
    if numel(unique(lower(rows.contrast_image)))~=height(rows),error('psy:GLMGroupDuplicate','Repeated input effect image');end
    switch g.design
        case 'paired'
            levels=string(g.pairedLevels);
            if ~all(ismember(rows.pair_level,levels))||height(rows)~=2*n
                error('psy:GLMGroupPair','Exactly one image at each configured level is required per subject');
            end
            order=zeros(2*n,1);
            for j=1:n
                for level=1:2
                    index=find(lower(rows.subject)==subjects(j)&rows.pair_level==levels(level));
                    if numel(index)~=1,error('psy:GLMGroupPair','Incomplete pair; no automatic subject deletion');end
                    order(2*j-2+level)=index;
                end
            end
            rows=rows(order,:);x=ones(n,1);names={'intercept'};
            comparison=char(levels(1)+"_minus_"+levels(2));counts=[n n];
        case 'two_sample'
            groups=string(g.groupLabels);
            if ~all(ismember(rows.group,groups)),error('psy:GLMGroupSample','Unknown group label');end
            ix1=find(rows.group==groups(1));ix2=find(rows.group==groups(2));counts=[numel(ix1) numel(ix2)];
            if any(counts<g.minPerGroup),error('psy:GLMGroupSample','Each group must meet minPerGroup');end
            rows=rows([ix1;ix2],:);x=[ones(counts(1),1) zeros(counts(1),1);zeros(counts(2),1) ones(counts(2),1)];
            names={'group1','group2'};comparison=char(groups(1)+"_minus_"+groups(2));
        otherwise
            x=ones(n,1);names={'intercept'};comparison='mean';counts=n;
    end
    covAudit=table;
    for j=1:numel(g.covariateColumns)
        label=g.covariateColumns{j};raw=str2double(rows.(label));
        if any(~isfinite(raw))||max(raw)==min(raw),error('psy:GLMGroupCovariate','Covariates must be finite and varying; no imputation');end
        center=0;if strcmp(g.covariateCenter,'overall'),center=mean(raw);end
        modeled=raw-center;x=[x modeled];names{end+1}=label; %#ok<AGROW>
        a=table(rows.subject,repmat(string(label),n,1),raw,repmat(center,n,1),modeled, ...
            'VariableNames',{'subject','covariate','raw_value','center','modeled_value'});
        if isempty(covAudit),covAudit=a;else,covAudit=[covAudit;a];end %#ok<AGROW>
    end
    r=rank(x);df=size(x,1)-r;
    if r~=size(x,2)||df<g.minResidualDF,error('psy:GLMGroupDesign','Rank-deficient design or insufficient residual dimensions');end
    c=zeros(1,size(x,2));c(1)=1;if strcmp(g.design,'two_sample'),c(2)=-1;end
    weights=[c;-c];conNames={comparison,[comparison '_negative']};
    if strcmp(g.design,'one_sample'),conNames={[char(labels(k)) '_positive'],[char(labels(k)) '_negative']};end
    offset=size(x,2)-numel(g.covariateColumns);
    for j=1:numel(g.covariateColumns)
        c=zeros(1,size(x,2));c(offset+j)=1;weights=[weights;c;-c]; %#ok<AGROW>
        label=g.covariateColumns{j};conNames=[conNames {[label '_positive'],[label '_negative']}]; %#ok<AGROW>
    end
    p=struct('design',g.design,'effectLabel',char(labels(k)),'rows',rows,'designMatrix',x, ...
        'columnNames',{names},'contrastWeights',weights,'contrastNames',{conNames},'comparison',comparison, ...
        'covariateAudit',covAudit,'nSubjects',n,'nInputs',height(rows),'sampleCounts',counts,'rank',r,'residualDF',df);
    if isempty(plans),plans=p;else,plans(k)=p;end
end
% 同一批多项效应必须保持同一个人的分组和协变量，不接受标签随contrast改变。
for k=2:numel(plans)
    for id=cohort'
        a=plans(1).rows(lower(plans(1).rows.subject)==id,:);b=plans(k).rows(lower(plans(k).rows.subject)==id,:);
        for label=[g.covariateColumns(:)' intersect({'group'},extra)]
            av=a.(label{1});bv=b.(label{1});
            if ~strcmp(label{1},'group'),av=str2double(av);bv=str2double(bv);end
            if ~isequal(av,bv),error('psy:GLMGroupSample','Group/covariate changed across effects for one subject');end
        end
    end
end
end
