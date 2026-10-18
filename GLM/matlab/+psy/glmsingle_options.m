function glmsingle_options(g)
%GLMSINGLE_OPTIONS 验证本接口开放的固定版本GLMsingle参数；不接受任意透传字段。
fields={'path','identityColumn','wantDenoise','wantRidge','fracs','maxPCs','noiseR2Threshold', ...
    'pcR2Threshold','maxPolyDegree','onsetMode','maxOnsetErrorSeconds','minEndBufferSeconds', ...
    'chunkVoxels','maxInputGiB','wantPercentBold','randomSeed'};
if ~isstruct(g)||~isscalar(g)||~all(isfield(g,fields))||any(~ismember(fieldnames(g),fields))
    error('psy:GLMsingleConfig','Unknown/missing GLMsingle fields; use current glm_config');
end
if ~isscalar(string(g.path))||ismissing(string(g.path))||strlength(string(g.path))==0
    error('psy:GLMsingleConfig','Set the dependency root');
end
label=string(g.identityColumn);
if ~isscalar(label)||ismissing(label)||isempty(regexp(char(label),'^[A-Za-z][A-Za-z0-9_]*$','once'))
    error('psy:GLMsingleConfig','identityColumn must be an explicit simple column label');
end
for key={'wantDenoise','wantRidge','wantPercentBold'}
    if ~islogical(g.(key{1}))||~isscalar(g.(key{1})),error('psy:GLMsingleConfig','Flags must be logical scalars');end
end
if ~isnumeric(g.fracs)||~isreal(g.fracs)||~isvector(g.fracs)||numel(unique(g.fracs))<2|| ...
        any(~isfinite(g.fracs)|g.fracs<=0|g.fracs>1)
    error('psy:GLMsingleConfig','fracs must contain at least two distinct fractions in (0,1]');
end
for key={'maxPCs','chunkVoxels'}
    v=g.(key{1});if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||v<1||fix(v)~=v,error('psy:GLMsingleConfig','PC/chunk counts must be positive integers');end
end
for key={'noiseR2Threshold','pcR2Threshold','maxPolyDegree'}
    v=g.(key{1});if ~isnumeric(v)||~isreal(v)||(~isempty(v)&&(~isscalar(v)||~isfinite(v))),error('psy:GLMsingleConfig','Threshold/degree must be empty or finite numeric scalar');end
end
v=g.maxPolyDegree;if ~isempty(v)&&(v<0||fix(v)~=v),error('psy:GLMsingleConfig','maxPolyDegree must be a nonnegative integer');end
if ~isscalar(string(g.onsetMode))||~ismember(string(g.onsetMode),["strict","nearest"]),error('psy:GLMsingleConfig','onsetMode is strict or nearest');end
for key={'maxOnsetErrorSeconds','minEndBufferSeconds','maxInputGiB','randomSeed'}
    v=g.(key{1});if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||v<0,error('psy:GLMsingleConfig','Invalid nonnegative limit');end
end
if g.maxInputGiB==0||g.randomSeed>2^32-1||fix(g.randomSeed)~=g.randomSeed,error('psy:GLMsingleConfig','Invalid memory budget/random seed');end
end
