function bases=glm_basis(type,fir)
%GLM_BASIS 映射SPM原生canonical/导数/FIR基函数；未接通的基函数明确拒绝。
if ~(ischar(type)||isstring(type))||~isscalar(string(type))||ismissing(string(type))
    error('psy:GLMUnsupportedHRF','HRF type must be one documented text value');
end
switch string(type)
    case "fir"
        if nargin<2,error('psy:GLMFIRConfig','FIR requires explicit windowSeconds and nBins');end
        bases=struct('fir',struct('length',fir.windowSeconds,'order',fir.nBins));return;
    case "canonical", derivatives=[0 0];
    case "canonical_time", derivatives=[1 0];
    case "canonical_time_dispersion", derivatives=[1 1];
    otherwise
        error('psy:GLMUnsupportedHRF','Supported HRF: canonical, canonical_time, canonical_time_dispersion, fir');
end
bases=struct('hrf',struct('derivs',derivatives));
end
