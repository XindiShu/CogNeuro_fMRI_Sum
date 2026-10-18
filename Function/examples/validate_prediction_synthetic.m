function summary=validate_prediction_synthetic(workspace)
%VALIDATE_PREDICTION_SYNTHETIC 多独立模拟被试；HCP三人嵌套预测明确跳过。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function;out=fullfile(workspace,'derivatives','function_stage2_prediction_20261017');if isfolder(out),error('cog:Exists','Preserve successful output');end;mkdir(out);
rng(71);n=48;data=struct('x',randn(n,15),'subjectIds',string((1:n)'),'groupIds',string((1:n)'),'featureIds',"edge"+string((1:15)'));data.target=data.x(:,1)*3-data.x(:,2)*2+randn(n,1)*.3;file=fullfile(out,'synthetic_data.mat');save(file,'data');c=prediction_config;c.dataFile=file;c.execute=true;
for method={'ridge','cpm'},c.options.method=method{1};c.outputRoot=fullfile(out,method{1});r=run_prediction(c);summary.(method{1})=struct('status',r.status,'correlation',r.correlation,'rSquared',r.rSquared);end
summary.realHcp=struct('status','skipped','reason','Only three unique HCP subjects. This nested implementation requires >=6 independent outer groups and estimable inner training designs; do not replicate runs as subjects. Existing task statistics may provide behavior but cannot increase independent N.');summary.scope='Synthetic engineering validation only; no real-data-tested prediction claim.';cog.write_json(fullfile(out,'VALIDATION.json'),summary);
end
