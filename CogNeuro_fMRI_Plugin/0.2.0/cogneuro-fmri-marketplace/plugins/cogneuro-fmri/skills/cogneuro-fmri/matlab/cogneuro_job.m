function cogneuro_job(jobFile)
%COGNEURO_JOB 固定进程入口；JSON仅作为数据，不执行其中的代码字符串。
job=jsondecode(fileread(jobFile));
if ~isstruct(job)||~isfield(job,'schema_version')||job.schema_version~=1
    error('cogneuro:Schema','Unsupported job schema');
end
if ~ismember(job.mode,{'preflight','execute'})||~ismember(job.route,{'fc','glm','preprocess','handoff','toolkit_method'})
    error('cogneuro:Route','Unsupported execution route or mode');
end
if isfile(job.result_file),error('cogneuro:Exists','Result file already exists');end
try
    switch job.route
        case 'fc',result=cogneuro_fc_adapter(job);
        case 'glm',result=cogneuro_glm_adapter(job);
        case 'preprocess',result=cogneuro_preprocess_adapter(job);
        case 'handoff',result=cogneuro_preprocess_handoff(job);
        case 'toolkit_method',result=cogneuro_toolkit_dispatch(job);
    end
    writeResult(job.result_file,result);
catch exception
    result=struct('status','failed','identifier',exception.identifier,'message',exception.message, ...
        'scientific_qc_passed',false);
    writeResult(job.result_file,result);
    rethrow(exception);
end
end

function writeResult(file,result)
% 输出采用UTF-8；只写本次新尝试的固定结果文件，不覆盖旧产物。
if isfile(file),error('cogneuro:Exists','Result file already exists');end
[fid,message]=fopen(file,'w','n','UTF-8');
if fid<0,error('cogneuro:Output','%s',message);end
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));
end
