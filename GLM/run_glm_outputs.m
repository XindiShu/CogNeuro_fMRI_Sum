function report=run_glm_outputs(cfg)
%RUN_GLM_OUTPUTS 修改glm_outputs_config后运行；只读源模型，输出另建目录。
oldPath=path;oldDirectory=pwd;restore=onCleanup(@()restoreState(oldPath,oldDirectory));
root=fileparts(mfilename('fullpath'));addpath(fullfile(root,'matlab'),fullfile(root,'config'));
if nargin==0,cfg=glm_outputs_config;end
cfg=psy.glm_outputs_options(cfg);addpath(cfg.spmPath);
if isfile(cfg.outputRoot)||isfolder(cfg.outputRoot),error('psy:GLMExists','Choose a new postprocessing output root');end
mkdir(cfg.outputRoot);save(fullfile(cfg.outputRoot,'configuration.mat'),'cfg');report=struct('results',[],'betaEstimates',0,'eventLinks',0);
try
    if ismember(cfg.mode,{'results','both'})
        file=psy.glm_absolute_path(cfg.results.manifestFile);entries=psy.glm_read_table(file,{'id','spm_mat','contrast_index'});
        validateIds(entries.id);before=psy.glm_file_inventory(file);
        folder=fullfile(cfg.outputRoot,'results');mkdir(folder);summaries=cell(height(entries),1);
        for k=1:height(entries)
            source=psy.glm_absolute_path(entries.spm_mat(k),fileparts(file));out=fullfile(folder,char(entries.id(k)));
            summaries{k}=psy.glm_results_export(source,str2double(entries.contrast_index(k)),cfg.results,out);
            if ~isempty(cfg.results.roiManifestFile)&&~isempty(summaries{k}.effectFile)
                c=table(entries.id(k),string(summaries{k}.effectFile),1,string(fullfile(fileparts(source),'mask.nii')), ...
                    "unthresholded SPM contrast amplitude; source scaling retained", ...
                    'VariableNames',{'estimate_id','image_path','volume_index','mask_path','units'});
                roiFile=psy.glm_absolute_path(cfg.results.roiManifestFile);roiBefore=roiInventory(roiFile);
                [values,space]=psy.glm_beta_read(c,cfg.betas.maxMatrixGiB);
                roi=psy.glm_roi_extract(values,c,space,roiFile,cfg.roi);
                writetable(roi,fullfile(out,'roi_effects.tsv'),'FileType','text','Delimiter','\t');
                assert(isequal(roiBefore,roiInventory(roiFile)),'psy:GLMInputChanged','ROI input changed');
                writetable(roiBefore,fullfile(out,'roi_input_hashes.tsv'),'FileType','text','Delimiter','\t');
            end
        end
        assert(isequal(before,psy.glm_file_inventory(file)),'psy:GLMInputChanged','Results manifest changed');
        report.results=summaries;
    end
    if ismember(cfg.mode,{'betas','both'})
        file=psy.glm_absolute_path(cfg.betas.manifestFile);[catalog,events,files]=psy.glm_beta_catalog(file);
        before=psy.glm_file_inventory(files);folder=fullfile(cfg.outputRoot,'betas');mkdir(folder);
        writetable(catalog,fullfile(folder,'beta_catalog.tsv'),'FileType','text','Delimiter','\t');
        writetable(events,fullfile(folder,'event_links.tsv'),'FileType','text','Delimiter','\t');
        if cfg.betas.writeMatrix||~isempty(cfg.betas.roiManifestFile)
            [betaMatrix,space]=psy.glm_beta_read(catalog,cfg.betas.maxMatrixGiB);
            if cfg.betas.writeMatrix,save(fullfile(folder,'beta_matrix.mat'),'betaMatrix','catalog','space','-v7.3');end
            if ~isempty(cfg.betas.roiManifestFile)
                roiFile=psy.glm_absolute_path(cfg.betas.roiManifestFile);roiBefore=roiInventory(roiFile);
                roi=psy.glm_roi_extract(betaMatrix,catalog,space,roiFile,cfg.roi);
                writetable(roi,fullfile(folder,'roi_betas.tsv'),'FileType','text','Delimiter','\t');
                assert(isequal(roiBefore,roiInventory(roiFile)),'psy:GLMInputChanged','ROI input changed');
                writetable(roiBefore,fullfile(folder,'roi_input_hashes.tsv'),'FileType','text','Delimiter','\t');
            end
        end
        after=psy.glm_file_inventory(files);assert(isequal(before,after),'psy:GLMInputChanged','Beta source inputs changed');
        writetable(before,fullfile(folder,'input_hashes_before.tsv'),'FileType','text','Delimiter','\t');
        writetable(after,fullfile(folder,'input_hashes_after.tsv'),'FileType','text','Delimiter','\t');
        report.betaEstimates=height(catalog);report.eventLinks=height(events);
    end
    report.status='glm_outputs_complete';report.scope='read-only results and beta/ROI interfaces; no FC/PPI/DCM or RSA/MVPA fitting';
    psy.glm_write_json(fullfile(cfg.outputRoot,'summary.json'),report);save(fullfile(cfg.outputRoot,'GLM_OUTPUTS_COMPLETE.mat'),'report','cfg');
catch ex
    errorReport=getReport(ex,'extended','hyperlinks','off');save(fullfile(cfg.outputRoot,'GLM_OUTPUTS_FAILED.mat'),'errorReport');rethrow(ex);
end
clear restore;
end
function validateIds(ids)
if numel(unique(lower(ids)))~=numel(ids),error('psy:GLMOutputsConfig','Duplicate export ID');end
for k=1:numel(ids),if isempty(regexp(char(ids(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('psy:GLMOutputsConfig','Unsafe/empty export ID');end,end
end
function inventory=roiInventory(file)
t=psy.glm_read_table(file,{'roi','mask_file','label'});files=string(file);
for k=1:height(t),files(end+1)=psy.glm_absolute_path(t.mask_file(k),fileparts(file));end %#ok<AGROW>
inventory=psy.glm_file_inventory(files);
end
function restoreState(oldPath,oldDirectory)
path(oldPath);cd(oldDirectory);
end
