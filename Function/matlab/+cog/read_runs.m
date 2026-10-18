function runs=read_runs(file)
%READ_RUNS 数据集无关清单；subject/session/run共同组成唯一键。
required={'subject','session','run','bold','mask','roi_file','tr_seconds','temporal_state','smoothing_fwhm_mm','confounds','purpose'};
runs=cog.read_tsv(file,required);base=fileparts(file);
if isempty(runs),error('cog:Manifest','Empty run list');end
for name={'subject','run','session'}
    v=runs.(name{1});allowEmpty=strcmp(name{1},'session');
    for k=1:numel(v)
        if allowEmpty&&strlength(v(k))==0,continue;end
        if isempty(regexp(char(v(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:Manifest','Unsafe identifier');end
    end
end
keys=runs.subject+"/"+runs.session+"/"+runs.run;
if numel(unique(lower(keys)))~=height(runs),error('cog:Manifest','Duplicate subject/session/run');end
for field={'bold','mask','roi_file','confounds'}
    for k=1:height(runs),runs.(field{1})(k)=string(cog.resolve_path(runs.(field{1})(k),base));end
end
if any(strlength(runs.bold)==0|strlength(runs.mask)==0|strlength(runs.roi_file)==0),error('cog:Manifest','BOLD, mask and ROI paths cannot be empty');end
runs.tr_seconds=str2double(runs.tr_seconds);runs.smoothing_fwhm_mm=str2double(runs.smoothing_fwhm_mm);
if any(~isfinite(runs.tr_seconds)|runs.tr_seconds<=0)||any(~isfinite(runs.smoothing_fwhm_mm)|runs.smoothing_fwhm_mm<0)
    error('cog:Manifest','Invalid TR or smoothing declaration');
end
if any(~ismember(runs.temporal_state,["unfiltered_unregressed","nuisance_regressed_unfiltered","nuisance_regressed_highpassed","denoised_bandpassed"]))||any(~ismember(runs.purpose,["rest","task","engineering"]))
    error('cog:Manifest','Explicit processing state and purpose required');
end
end
