function [RES, S] = MBEDS_sleepstim
    % Reactivation stimulation during sleep for the Many Beds project
    % When promted, provide participant ID
    % 
    % Subfolders:
    %   Stimuli - contains stimulus sounds ("s*.wav") and images("p*.wav"), baselinesound ("baselinesound.wav"), and background noise ("noise.wav")
    %   StimFilesSubjects - contains "LABID_PARTICIPANTID_anticlust.csv" with header ("x") and soundfile names ("s*.wav"), this file comes from the learning task
    %   Results - contains logfiles and results files for each subject. Logfiles are appended for each start with same SUBID. Results files are backupped for older versions. 

    %% initialize log file und result variables
    cleanupObj = onCleanup(@() cleanUp());  % remove screen and audio playback in case of crash
    InitializePsychSound

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(projectRoot);

    %% General Study Information
    C = MBEDS_LabConfig;
    S = struct;                  % contains general study information
    S.location = C.location;     % adapt according to location
    S.lab_id = C.lab_id;         % adapt according to location (LAB ID)
    S.trigger_interface = C.trigger_interface;
    S.trigger_port = C.trigger_port;
    S.trigger_duration = C.trigger_duration;
    S.baudrate = C.baudrate;
    S.noise_type = C.noise_type;
    S.force_value = C.force_value;

    fprintf("ManyBeds - Lab %s (%s)\n",S.location, S.lab_id);
    S.subnr = input("Participant ID: ", "s");   % enter participant ID
    S.max_repetitions = 3;  % repeat all stimuli maximally 3 rounds
    S.stimdelay = 5;        % seconds between stimulus presentations
    [S.audio_device_id, S.audio_fs] = chooseAudioOutputDevice();

    % debug mode will disable sending EEG triggers and send debug messages instead
    S.debug = C.debug_mode;     % MUST BE false during experiment

    if S.debug
        warning('Debug mode is still enabled, disable config file')
        S.minsleepdur = 1;     % minutes before experiment can be stopped
    else
        S.minsleepdur = 45;     % minutes before experiment can be stopped
    end

    currpath = fileparts(mfilename('fullpath'));                            % currpath: folder should contain Results and SleepSounds  
    if isempty(currpath)
        currpath = cd;                                                      % use path of current function or current directory
    end
    
    soundFilePath = fullfile(currpath,"Stimuli");
    if ~exist(soundFilePath,"dir")
        error("Cannot find Stimuli folder");
    end
    
    resultsFilePath = fullfile(currpath, "Results");
    if ~exist(resultsFilePath,"dir")
        mkdir(resultsFilePath);
    end
    
    S.subid = sprintf("%s_%s", S.lab_id, S.subnr);
    
    %% read in audiofiles
    
    sound_csv = readtable(fullfile(soundFilePath, "MBEDS_soundfiles.csv")); % read sound names
    anticlust_file = fullfile(fileparts(currpath), "stimulation_files", sprintf("%s_anticlust.csv", S.subid));

    try
        sound_csv_subject = readtable(anticlust_file);
    catch
        error("Cannot load stimsounds for subject %s from folder stimulation_files, " + ...
              "make sure the file %s has been calculated and is present", ...
              S.subid, anticlust_file);
    end
    
    if istable(sound_csv_subject)
        sound_csv_subject = table2cell(sound_csv_subject); 
    end
    sounds_subject = sound_csv_subject(:);
    sound_ids_subject = double(extract(string(sounds_subject),digitsPattern))';
    
    stim_id = table2array(sound_csv(:, 'ID'));
    stim_name = table2array(sound_csv(:, 'Name'));
    stim_name_dict = containers.Map(stim_id, stim_name);
    
    stim_dict = containers.Map('KeyType', 'double', 'ValueType', 'any');
    for i = stim_id'
        soundFilename = fullfile(soundFilePath, sprintf('s%d.wav', i)); 
        imageFilename = fullfile(soundFilePath, sprintf('p%d.bmp', i));  
        audio = audioread(soundFilename)';
        if size(audio,1)==1
            audio = repmat(audio,2,1);
        end
        image = imread(imageFilename);
        stim_dict(i) = {stim_name_dict(i), audio, image};
    end
    
    %% read in baseline sound
    baselinesound_name = 'baselinesound';
    audio = audioread(fullfile(soundFilePath, [baselinesound_name '.wav']))';
    if size(audio,1)==1
        audio = repmat(audio,2,1);
    end
    stim_dict(99) = {baselinesound_name, audio, ones(100, 100)};
    %add the baseline sound to stimulation list
    S.sound_ids_subject = [sound_ids_subject, repmat(99, 1, length(sound_ids_subject))];
    S.sound_ids_subject = S.sound_ids_subject(randperm(numel(S.sound_ids_subject))); % intial shuffle
    
    %% read in background noise 
    backgroundnoise_name = "noise_" + S.noise_type + ".mp3";
    backgroundnoise = audioread(fullfile(soundFilePath, backgroundnoise_name))';
    if size(backgroundnoise,1)==1
        backgroundnoise = repmat(backgroundnoise,2,1);
    end
    
    %% start experiment
    RES = MBEDS_sleepstimGUI(S, resultsFilePath, stim_dict, backgroundnoise);
end

function [deviceIndex, fs] = chooseAudioOutputDevice()
    devices = PsychPortAudio('GetDevices');
    fprintf('\nAvailable Audio Output Devices:\n\n');
    
    outputDevices = devices([devices.NrOutputChannels] > 0);
    
    for i = 1:numel(outputDevices)
        d = outputDevices(i);
        name = d.DeviceName;
        if numel(name) > 40, name = [name(1:min([length(name),40])) '...']; end
        fprintf('  [%d] %s (%s), %d ch, %.0f Hz\n', ...
            d.DeviceIndex, name, d.HostAudioAPIName, ...
            d.NrOutputChannels, d.DefaultSampleRate);
    end

    fprintf('\nSelect a playback device (ENTER = default): ');
    str = input('', 's');

    if isempty(str)
        deviceIndex = [];      % let PsychPortAudio pick the default
        fs          = 44100;
        return
    end

    sel = str2double(str);
    idx = find([devices.DeviceIndex] == sel & [devices.NrOutputChannels] > 0, 1);  % valid output device only

    if isempty(idx)
        warning('Invalid selection; using system default device.');
        deviceIndex = [];
        fs          = 44100;
    else
        deviceIndex = sel;
        fs          = devices(idx).DefaultSampleRate;
    end
end



function cleanUp()
    % Runs no matter how you exit (error, CTRL-C, normal return)
    warning('Performing cleanup of GUI, timer, and audio.');
    PsychPortAudio('Close');
end
