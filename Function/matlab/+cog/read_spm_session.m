function [y,space,design]=read_spm_session(spmMat,sessionIndex,maskFile,maxGiB)
%READ_SPM_SESSION 根据显式SPM引用读选中session；通用3D/4D扫描布局。
s=load(spmMat,'SPM');spm=s.SPM;base=fileparts(spmMat);
if ~isscalar(sessionIndex)||sessionIndex<1||fix(sessionIndex)~=sessionIndex||sessionIndex>numel(spm.Sess),error('cog:Session','Invalid session index');end
session=spm.Sess(sessionIndex);headers=spm.xY.VY(session.row);m=spm_vol(maskFile);if ~isscalar(m),error('cog:Mask','3D mask required');end
mask=spm_read_vols(m);if any(~isfinite(mask(:))|mask(:)<0)||~any(mask(:)>0),error('cog:Mask','Invalid fixed mask');end;mask=mask>0;
n=numel(headers);if ~isscalar(maxGiB)||~isfinite(maxGiB)||maxGiB<=0||n*nnz(mask)*8/2^30>maxGiB,error('cog:Memory','Invalid/exceeded matrix budget');end
y=zeros(n,nnz(mask));for k=1:n
    headers(k).fname=cog.resolve_path(headers(k).fname,base);cog.check_grid(headers(k),m);d=spm_read_vols(headers(k));a=d(mask);if any(~isfinite(a)),error('cog:Nonfinite','Nonfinite inside fixed mask');end;y(k,:)=a';
end
idx=find(mask);[i,j,k]=ind2sub(m.dim,idx);space=struct('reference',m,'mask',mask,'indices',idx,'ijk',[i j k],'trSeconds',spm.xY.RT);
task=[];for k=1:numel(session.Fc),task=[task session.col(session.Fc(k).i)];end %#ok<AGROW>
task=unique(task);if isempty(task),error('cog:TaskDesign','No task design columns');end
motion=[];if isfield(session,'C'),motion=session.C.C;end
if numel(spm.xX.K)==1,k=1;else,k=sessionIndex;end
drift=spm.xX.K(k).X0;if size(drift,1)~=n,error('cog:TaskDesign','Concatenated-session filtering layout needs explicit adaptation');end
design=struct('task',spm.xX.X(session.row,task),'confounds',[motion drift],'taskColumnIndices',task,'sourceModel',spmMat,'sessionIndex',sessionIndex);
end
