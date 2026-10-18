function data=prepare_dcm_spm(spmMat,roiManifest,sessionIndex,TESeconds,out)
%PREPARE_DCM_SPM 私有SPM F/VOI原生提取；区域和高分辨率输入显式对应。
if isfolder(out),error('cog:Exists','Use a new preparation directory');end
s=load(spmMat,'SPM');SPM=s.SPM;base=fileparts(spmMat);t=cog.read_tsv(roiManifest,{'name','mask_file'});
if isempty(t)||numel(unique(t.name))~=height(t),error('cog:DCMROI','Unique ordered named ROI list required');end
if ~isscalar(sessionIndex)||sessionIndex<1||sessionIndex~=fix(sessionIndex)||sessionIndex>numel(SPM.Sess),error('cog:Session','Invalid SPM session');end
for k=1:height(t)
    if isempty(regexp(char(t.name(k)),'^[A-Za-z0-9][A-Za-z0-9_-]*$','once')),error('cog:DCMROI','Safe ROI names required');end
    t.mask_file(k)=string(cog.resolve_path(t.mask_file(k),fileparts(roiManifest)));v=spm_vol(char(t.mask_file(k)));cog.check_grid(v,SPM.xY.VY(1));
end
for f={'Vbeta','VResMS','VM'},for k=1:numel(SPM.(f{1})),SPM.(f{1})(k).fname=cog.resolve_path(SPM.(f{1})(k).fname,base);end,end
for k=1:numel(SPM.xY.VY),SPM.xY.VY(k).fname=cog.resolve_path(SPM.xY.VY(k).fname,base);end
mkdir(out);old=pwd;cleanup=onCleanup(@()cd(old));cd(out);SPM.swd=out;SPM.pwd=out;session=SPM.Sess(sessionIndex); %#ok<NASGU>
task=[];for k=1:numel(session.Fc),task=[task session.col(session.Fc(k).i)];end;task=unique(task);c=zeros(size(SPM.xX.X,2),numel(task)); %#ok<AGROW>
if isempty(task),error('cog:TaskDesign','No task effects available');end
for k=1:numel(task),c(task(k),k)=1;end
SPM.xCon=spm_FcUtil('Set','effects_of_interest','F','c',c,SPM.xX.xKXs);SPM=spm_contrasts(SPM,1);save(fullfile(out,'SPM.mat'),'SPM');
job=cell(height(t),1);for k=1:height(t)
    job{k}.spm.util.voi.spmmat={fullfile(out,'SPM.mat')};job{k}.spm.util.voi.adjust=1;job{k}.spm.util.voi.session=sessionIndex;job{k}.spm.util.voi.name=char(t.name(k));job{k}.spm.util.voi.roi{1}.mask.image={char(t.mask_file(k))};job{k}.spm.util.voi.roi{1}.mask.threshold=.5;job{k}.spm.util.voi.expression='i1';
end
spm_jobman('initcfg');spm_jobman('run',job);y=[];X0=[];for k=1:height(t)
    a=load(fullfile(out,sprintf('VOI_%s_%d.mat',t.name(k),sessionIndex)),'xY');y=[y a.xY.u]; %#ok<AGROW>
    if k==1,X0=a.xY.X0;elseif ~isequal(X0,a.xY.X0),error('cog:DCMROI','ROI nuisance bases disagree');end
end
[q,r,~]=svd(X0,'econ');v=diag(r);X0=q(:,v>max(size(X0))*eps(max(v)));
u=[];inputNames={};for k=1:numel(session.U),u=[u session.U(k).u(33:end,:)];inputNames=[inputNames session.U(k).name(:)'];end %#ok<AGROW>
ratio=round(SPM.xY.RT/SPM.xBF.dt);n=size(y,1);if size(u,1)<n*ratio,error('cog:DCMInput','SPM inputs do not cover selected session');end;u=u(1:n*ratio,:);
data=struct('y',y,'trSeconds',SPM.xY.RT,'roiNames',{cellstr(t.name)},'TESeconds',TESeconds,'delaysSeconds',repmat(SPM.xY.RT*SPM.xBF.T0/SPM.xBF.T,height(t),1), ...
    'u',u,'inputDtSeconds',SPM.xBF.dt,'inputNames',{inputNames},'X0',X0,'sourceSPM',spmMat,'roiManifest',roiManifest,'note','Native SPM whitened/filtered/effects-adjusted VOI eigenvariates; private output only.');
save(fullfile(out,'dcm_data.mat'),'data');
end
