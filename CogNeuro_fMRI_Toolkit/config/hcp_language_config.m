function cfg = hcp_language_config(dataRoot, outputRoot)
%HCP_LANGUAGE_CONFIG Editable analysis choices; unset metadata must be verified.
arguments
    dataRoot (1,1) string
    outputRoot (1,1) string
end
cfg.dataset = "HCP-YA-2025";
cfg.dataRoot = dataRoot;
cfg.outputRoot = outputRoot;
cfg.subjects = strings(0,1); % Populate from the authorized download inventory.
cfg.runs = ["tfMRI_LANGUAGE_LR", "tfMRI_LANGUAGE_RL"];
cfg.conditions = {'story', 'math'};
cfg.inputStage = "unprocessed"; % Or an explicitly identified derivative stage.
cfg.trSeconds = []; % Read and verify against image header/protocol.
cfg.sliceTimingSeconds = []; % Do not infer multiband slice timing.
cfg.discardVolumes = 0;
cfg.smoothingFwhmMm = [6 6 6]; % Candidate, not an HCP-prescribed setting.
cfg.highPassSeconds = 128; % Candidate; inspect design before use.
cfg.globalSignalRegression = false;
cfg.fdThresholdMm = 0.5; % Candidate flagging threshold, not automatic exclusion.
cfg.roiDefinition = ""; % Require an independent atlas or justified selection.
cfg.distortionCorrectionBackend = "unconfigured";
cfg.phaseEncodingDirection = "";
cfg.totalReadoutTimeSeconds = [];
end

