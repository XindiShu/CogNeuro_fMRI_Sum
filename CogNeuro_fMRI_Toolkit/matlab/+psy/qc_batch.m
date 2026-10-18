function report = qc_batch(inputRoot,outputRoot)
%QC_BATCH QC all run folders carrying input_info.mat and native realign outputs.
% Run independently of preprocessing; one failed run does not stop the others.
if isfolder(outputRoot), error('psy:QCExists','Choose a new QC output root'); end
inputAbsolute=char(java.io.File(inputRoot).getCanonicalPath());
outputAbsolute=char(java.io.File(outputRoot).getCanonicalPath());
if strcmpi(inputAbsolute,outputAbsolute) || startsWith(lower(outputAbsolute),[lower(inputAbsolute) filesep])
    error('psy:QCRoot','QC output must be outside the input batch directory');
end
jobs=dir(fullfile(inputRoot,'**','input_info.mat'));
assert(~isempty(jobs),'No run inputs found'); mkdir(outputRoot);
report=struct('subject',{},'session',{},'run',{},'status',{},'message',{},'output',{});
for i=1:numel(jobs)
    row=struct('subject','','session','','run','','status','failed','message','','output','');
    try
        data=load(fullfile(jobs(i).folder,jobs(i).name));
        row.subject=data.run.subject; row.run=data.run.name;
        if isfield(data.run,'session'), row.session=data.run.session; end
        out=fullfile(psy.run_output_dir(outputRoot,data.run),'timeseries_qc'); row.output=out;
        means=dir(fullfile(jobs(i).folder,'mean*.nii')); motion=dir(fullfile(jobs(i).folder,'rp_*.txt'));
        assert(numel(means)==1 && numel(motion)==1,'Expected one native mean and one motion file');
        stem=char(extractAfter(means(1).name,'mean'));
        series=fullfile(jobs(i).folder,['r' stem]);
        fraction=0.2;
        if isfield(data.cfg,'qc'), fraction=data.cfg.qc.maskFraction; end
        summary=psy.timeseries_qc(series,fullfile(means.folder,means.name), ...
            fullfile(motion.folder,motion.name),out,maskFraction=fraction, ...
            fdRadiusMm=data.cfg.fdRadiusMm,fdFlagMm=data.cfg.fdFlagMm);
        row.status='qc_completed'; row.message=sprintf('%d frames checked; median tSNR %.3f',summary.nVolumes,summary.medianTSNR);
    catch exception
        row.message=exception.message;
    end
    report(end+1)=row; %#ok<AGROW>
    writetable(struct2table(report,'AsArray',true),fullfile(outputRoot,'qc_batch_status.tsv'),'FileType','text','Delimiter','\t');
end
end
