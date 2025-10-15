% simply check that they all play and load correctly
% Plays stimuli/s1.wav ... stimuli/s51.wav sequentially.

InitializePsychSound(1);
PsychPortAudio('Close');

here  = fileparts(mfilename('fullpath'));
stimdir = fullfile(here, 'version_julia_2');

cleanupObj = onCleanup(@() PsychPortAudio('Close'));

pah = [];
curr_fs = [];
curr_ch = [];

for k = 1:52
    fn = fullfile(stimdir, sprintf('s%d.wav', k));
    if exist(fn, 'file') ~= 2
        warning('Missing file: %s', fn);
        continue
    end

    [y, kkk] = audioread(fn);
    y = y.';       % channels x samples

    pah = PsychPortAudio('Open', [], 1, 1, 44100, size(y,1));
    PsychPortAudio('Volume', pah, 1.0);
    curr_ch = size(y,1);

    fprintf('Playing %s\n', fn);
    PsychPortAudio('FillBuffer', pah, y);
    PsychPortAudio('Start', pah, 1, 0, 1);  % start immediately, wait for end
    PsychPortAudio('Stop', pah, 1);         % block until finished
end

PsychPortAudio('Close');
