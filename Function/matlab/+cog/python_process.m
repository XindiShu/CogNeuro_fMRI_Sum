function python_process(executable,script,args,logFile,timeoutSeconds)
%PYTHON_PROCESS Java参数数组，不经过shell拼接；日志保留，超时只终止本子进程。
if ~isfile(executable)||~isfile(script)||isfile(logFile)||~isscalar(timeoutSeconds)||~isfinite(timeoutSeconds)||timeoutSeconds<=0,error('cog:PythonProcess','Existing Python/script, new log and positive timeout required');end
command=java.util.ArrayList;command.add(java.lang.String(executable));command.add(java.lang.String(script));for k=1:numel(args),command.add(java.lang.String(args{k}));end
builder=java.lang.ProcessBuilder(command);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(logFile));env=builder.environment;env.put('OMP_NUM_THREADS','1');env.put('OPENBLAS_NUM_THREADS','1');env.put('MKL_NUM_THREADS','1');env.put('NUMBA_NUM_THREADS','1');env.put('PYTHONDONTWRITEBYTECODE','1');process=builder.start;cleanup=onCleanup(@()stopIfAlive(process)); %#ok<NASGU>
completed=process.waitFor(int64(ceil(timeoutSeconds)),java.util.concurrent.TimeUnit.SECONDS);if ~completed,process.destroyForcibly;error('cog:PythonTimeout','Python timed out; inspect %s',logFile);end
if process.exitValue~=0,error('cog:PythonFailure','Python returned %d; inspect %s',process.exitValue,logFile);end
end
function stopIfAlive(process)
if process.isAlive,process.destroyForcibly;end
end
