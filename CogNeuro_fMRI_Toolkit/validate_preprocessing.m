% VALIDATE_PREPROCESSING Run this in an already-open MATLAB if batch login fails.
projectRoot=fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot,'matlab'),fullfile(projectRoot,'config'));
cfg=preprocess_config;
if ~isfolder(cfg.outputRoot), mkdir(cfg.outputRoot); end
diary(fullfile(cfg.outputRoot,'validation_log.txt'));
try
    results=runtests(fullfile(projectRoot,'tests'));
    save(fullfile(cfg.outputRoot,'test_results.mat'),'results');
    assert(all([results.Passed]),'One or more unit tests failed');
    report=psy.preprocess_hcp(cfg);
    assert(~any(strcmp({report.status},'failed')),'One or more input checks failed');
catch exception
    diary off;
    rethrow(exception);
end
diary off;
