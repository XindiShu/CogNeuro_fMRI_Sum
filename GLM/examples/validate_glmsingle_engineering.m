function report=validate_glmsingle_engineering(outputRoot,noiseProfile)
%VALIDATE_GLMSINGLE_ENGINEERING 可重复的合成数据示例；不是HCP或真实科研结论。
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
if nargin<1,outputRoot=fullfile(tempdir,['cogneuro_glmsingle_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);end
if nargin<2,noiseProfile='mixed';end
if ~isscalar(string(noiseProfile))||~ismember(string(noiseProfile),["mixed","slow"]),error('psy:GLMsingleExample','noiseProfile is mixed or slow');end
outputRoot=char(java.io.File(outputRoot).getCanonicalPath());
if isfolder(outputRoot)||isfile(outputRoot),error('psy:GLMExists','Use a new validation root');end
cfg=glm_config;addpath(cfg.spmPath);oldPath=path;oldRng=rng;restore=onCleanup(@()restoreState(oldPath,oldRng));
dependency=psy.glmsingle_dependency(cfg.glmsingle.path);mkdir(outputRoot);
cfg.engine='glmsingle';cfg.level='subject';cfg.model.unit='event';cfg.hrf.type='library';
cfg.conditions={'A','B'};cfg.contrastNames={'A_minus_B'};cfg.contrastWeights=[1 -1];cfg.execute=true;cfg.continueOnError=false;
cfg.design.motionModel='none';cfg.design.includeTissueMeans=false;cfg.design.linearTrend=false;
cfg.glmsingle.maxPCs=2;cfg.glmsingle.noiseR2Threshold=5;cfg.glmsingle.pcR2Threshold=10;cfg.glmsingle.fracs=[1 .75 .5];
cfg.glmsingle.maxPolyDegree=1;cfg.glmsingle.wantDenoise=true;cfg.glmsingle.wantRidge=true;
n=240;dim=[6 6 4];nVox=prod(dim);onset=(10:12:190)';duration=ones(size(onset))*2;
trial_type=repmat(["A";"B"],numel(onset)/2,1);stimulus_id="stim_"+compose('%02d',mod((0:numel(onset)-1)',8)+1);
events=table(onset,duration,trial_type,stimulus_id);hrf=getcanonicalhrf(2,1);hrf=hrf(:)/max(hrf);
stimulus=zeros(n,numel(onset));stimulus(sub2ind(size(stimulus),onset+1,(1:numel(onset))'))=1;
design=conv2(stimulus,hrf);design=design(1:n,:);rng(189,'twister');runs=struct([]);truth=cell(1,2);
mask=ones(dim);mask(end)=0;maskFile=fullfile(outputRoot,'mask.nii');writeImage(maskFile,mask);
for r=1:2
    source=fullfile(outputRoot,sprintf('run_%02d',r));mkdir(source);
    amplitude=repmat((mod(0:numel(onset)-1,8)+1)*.7,nVox,1);amplitude(73:end,:)=0;truth{r}=amplitude;
    shared=sin((1:n)'/.97+r)+.5*sin((1:n)'/7+r);
    if strcmp(noiseProfile,'slow'),shared=sin((1:n)'/7+r)+.5*sin((1:n)'/17+r);end
    data=1000+design*amplitude'+.01*randn(n,nVox)+shared*(1+3*rand(1,nVox));
    bold=fullfile(source,'bold.nii');writeImage(bold,reshape(data',[dim n]));
    eventFile=fullfile(source,'events.tsv');writetable(events,eventFile,'FileType','text','Delimiter','\t');
    confounds=fullfile(source,'confounds.tsv');writetable(table((1:n)','VariableNames',{'unused'}),confounds,'FileType','text','Delimiter','\t');
    run=struct('subject','synthetic','session','','name',sprintf('run%02d',r),'temporal_state','unfiltered_unregressed', ...
        'bold',bold,'events',eventFile,'confounds',confounds,'mask',maskFile);
    if isempty(runs),runs=run;else,runs(r)=run;end
end
save(fullfile(outputRoot,'synthetic_truth.mat'),'truth','design','hrf','dependency','noiseProfile');
subject=string({runs.subject})';session=string({runs.session})';run=string({runs.name})';bold=string({runs.bold})';
events=string({runs.events})';confounds=string({runs.confounds})';temporal_state=string({runs.temporal_state})';mask=string({runs.mask})';
cfg.manifestFile=fullfile(outputRoot,'runs.tsv');cfg.outputRoot=fullfile(outputRoot,'models');
writetable(table(subject,session,run,bold,events,confounds,temporal_state,mask),cfg.manifestFile,'FileType','text','Delimiter','\t');
report=psy.glm_batch(cfg);assert(all(strcmp({report.status},'glmsingle_models_estimated')));
save(fullfile(outputRoot,'SYNTHETIC_VALIDATION_COMPLETE.mat'),'report','cfg');clear restore;
end
function writeImage(file,data)
ni=nifti;ni.dat=file_array(file,size(data),'FLOAT32-LE',352,1,0);ni.mat=diag([2 2 2 1]);ni.mat0=ni.mat;
ni.timing=struct('toffset',0,'tspace',1);create(ni);ni.dat(:)=single(data(:));
end
function restoreState(oldPath,oldRng)
path(oldPath);rng(oldRng);
end
