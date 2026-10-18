function summary=validate_hcp_stage3_states(workspace)
%VALIDATE_HCP_STAGE3_STATES 复用第二批准备的三人ROI矩阵，分别拟合三种不同观测。
if nargin<1,workspace=fileparts(fileparts(fileparts(mfilename('fullpath'))));end
addpath(fullfile(workspace,'function_toolkit'));setup_function;out=fullfile(workspace,'derivatives','function_stage3_states_20261017');if isfolder(out),error('cog:Exists','Preserve successful output');end;mkdir(out);
manifest=fullfile(workspace,'derivatives','function_stage2_dynamic_20261017','runs.tsv');c=state_config;c.manifestFile=manifest;c.pythonExecutable='D:/matlab/atoolbox/function_glhmm_env/Scripts/python.exe';c.execute=true;c.options.nStates=3;c.options.hmmMaxCycles=20;c.options.hmmInitializations=2;
for method={'hmm','cap','leida'},c.options.method=method{1};c.outputRoot=fullfile(out,method{1});summary.(method{1})=run_states(c);end
summary.scope='3 HCP prefix256 REST runs, 6 engineering ROIs, existing .01-.08Hz data; each run standardized, fixedK3. Gaussian HMM GLHMM native posterior/Viterbi, CAP all frames, LEiDA segment-wise Hilbert/3-frame endpoint trim. Descriptive engineering only: no K optimality, label reproducibility, clustering stability, neural-state or population-inference claim.';cog.write_json(fullfile(out,'VALIDATION.json'),summary);
end
