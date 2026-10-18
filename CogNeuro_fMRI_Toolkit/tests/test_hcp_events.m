function tests = test_hcp_events
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
addpath(fullfile(root, 'matlab'));
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
end

function setup(testCase)
testCase.TestData.folder = tempname;
mkdir(testCase.TestData.folder);
writematrix([0 10 1; 20 10 1], fullfile(testCase.TestData.folder,'story.txt'), 'Delimiter','tab');
writematrix([10 10 1; 30 10 1], fullfile(testCase.TestData.folder,'math.txt'), 'Delimiter','tab');
end

function teardown(testCase)
rmdir(testCase.TestData.folder, 's');
end

function testValidTiming(testCase)
events = psy.read_hcp_events(testCase.TestData.folder, {'story','math'}, 40);
verifyEqual(testCase, events.onsets{1}, [0;20]);
verifyEqual(testCase, events.durations{2}, [10;10]);
end

function testTruncatedScan(testCase)
verifyError(testCase, @() psy.read_hcp_events(testCase.TestData.folder, {'story','math'}, 39), 'psy:Timing');
end

function testExplicitPreserveOverrun(testCase)
events=psy.read_hcp_events(testCase.TestData.folder, {'story','math'}, 39, "preserve");
verifyEqual(testCase,events.durations{2},[10;10]);
verifyError(testCase,@()psy.read_hcp_events(testCase.TestData.folder, {'story','math'}, 30, "preserve"),'psy:Timing');
end

function testAmplitudeNotSilentlyDropped(testCase)
writematrix([0 10 2], fullfile(testCase.TestData.folder,'story.txt'), 'Delimiter','tab');
verifyError(testCase, @() psy.read_hcp_events(testCase.TestData.folder, {'story'}, 40), 'psy:Amplitude');
end

function testMissingCondition(testCase)
verifyError(testCase, @() psy.read_hcp_events(testCase.TestData.folder, {'missing'}, 40), 'psy:MissingEV');
end
