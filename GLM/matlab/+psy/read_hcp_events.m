function events = read_hcp_events(evDirectory, conditionNames, scanDurationSeconds, endOverrunPolicy)
%READ_HCP_EVENTS Read unit-amplitude HCP EVs as SPM multiple conditions.
% Each EV must contain onset (s), duration (s), amplitude. No time shifting,
% clipping, run concatenation or amplitude dropping is performed silently.
arguments
    evDirectory (1,1) string
    conditionNames (1,:) cell
    scanDurationSeconds (1,1) double {mustBePositive, mustBeFinite}
    endOverrunPolicy (1,1) string {mustBeMember(endOverrunPolicy,["error","preserve"])} = "error"
end
if isempty(conditionNames) || numel(unique(string(conditionNames))) ~= numel(conditionNames)
    error('psy:Conditions', 'Provide nonempty, distinct condition names.');
end
events.names = conditionNames;
events.onsets = cell(size(conditionNames));
events.durations = cell(size(conditionNames));
for k = 1:numel(conditionNames)
    name = string(conditionNames{k});
    if ~isscalar(name) || isempty(regexp(char(name), '^[A-Za-z0-9_]+$', 'once'))
        error('psy:Conditions', 'Condition names must be simple file stems.');
    end
    filename = fullfile(evDirectory, name + ".txt");
    if ~isfile(filename)
        error('psy:MissingEV', 'Missing EV: %s', filename);
    end
    values = readmatrix(filename, 'FileType', 'text');
    if isempty(values) || size(values,2) ~= 3 || any(~isfinite(values), 'all')
        error('psy:InvalidEV', 'EV must be a nonempty finite three-column matrix: %s', filename);
    end
    if any(values(:,1) < 0) || any(values(:,2) < 0) || any(diff(values(:,1)) < 0)
        error('psy:Timing', 'EV onsets must be sorted and times nonnegative: %s', filename);
    end
    if any(values(:,1) >= scanDurationSeconds) || (endOverrunPolicy=="error" && any(sum(values(:,1:2),2) > scanDurationSeconds + 1e-6))
        error('psy:Timing', 'EV exceeds scan duration; inspect timing alignment: %s', filename);
    end
    if any(abs(values(:,3) - 1) > 1e-8)
        error('psy:Amplitude', 'Non-unit amplitudes require explicit modeling: %s', filename);
    end
    events.onsets{k} = values(:,1);
    events.durations{k} = values(:,2);
end
end
