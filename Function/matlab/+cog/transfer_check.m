function transfer_check(train,test,o)
%TRANSFER_CHECK 身份和域边界；目标标签从不参与训练。
for d={train,test}
    a=d{1};n=size(a.X,1);ids=string(a.sampleIds(:));units=string(a.independentUnitIds(:));features=string(a.featureIds(:));domain=string(a.domainId);
    if ~isnumeric(a.X)||~ismatrix(a.X)||~isreal(a.X)||any(~isfinite(a.X),'all')||n<1||numel(ids)~=n||numel(unique(ids))~=n||numel(units)~=n||any(ismissing(ids)|ids=="")||any(ismissing(units)|units=="")||~isscalar(domain)||ismissing(domain)||domain==""||numel(features)~=size(a.X,2)||numel(unique(features))~=numel(features)||any(ismissing(features)|features==""),error('cog:TransferInput','Complete finite matrix and explicit unique identities/domains required');end
end
if ~isfield(train,'Y')||numel(train.Y)~=size(train.X,1)||isfield(test,'Y')&&numel(test.Y)~=size(test.X,1)||~isequal(string(train.featureIds(:)),string(test.featureIds(:)))||string(train.domainId)==string(test.domainId)||~isempty(intersect(string(train.sampleIds),string(test.sampleIds)))||strlength(string(o.dependencyNote))==0,error('cog:TransferInput','Distinct domains/disjoint sample IDs/exact features/source targets and dependency justification required');end
if ~ismember(o.unitPolicy,{'disjoint_units','matched_units_distinct_domains'}),error('cog:TransferPolicy','Unknown dependency policy');end
if strcmp(o.unitPolicy,'disjoint_units')&&~isempty(intersect(string(train.independentUnitIds),string(test.independentUnitIds))),error('cog:TransferLeakage','Cross-subject train/test independent units overlap');end
end
