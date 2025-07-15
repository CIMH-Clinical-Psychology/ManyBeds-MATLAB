function [RES, S] = MBEDS_SART
available_ports = serialportlist("all");
disp("Available serial ports:")
disp(available_ports)

    Screen('Preference', 'SkipSyncTests', 1);

    KbName('UnifyKeyNames');

    cleanupObj = onCleanup(@() cleanUp());  % remove screen and audio playback in case of crash
    InitializePsychSound(1)

    PsychPortAudio('Close') % stop previous playback

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(projectRoot);
    
    %% General Study Information
    C = MBEDS_LabConfig;
    S = struct;        
    S.location = C.location;                                    
    S.lab_id = C.lab_id; 
    S.language = C.language;
   % S.lpt_hex = C.lpt_hex;   % parallel port for EEG triggers 
    S.trigger_port = serialport("COM3", 9600);  % Adjust COM port if needed
    S.trigger_duration = 0.01;  % Trigger pulse duration
    S.debug = C.debug_mode;
    S.study = "SART";

    %%%%%%%%%%%%%%%%%%%%%%%%%%
    % change per participants
    S.backgroundVolume = 0.2;
    S.soundVolume = 0.5;
    %%%%%%%%%%%%%%%%%%%%%%%%%%

    if S.debug
         warning('The DEBUG flag has been set in the config file. Please remove before running the study')
    end
    
    fprintf("ManyBeds - Lab %s (%s) - %s\n", S.location, S.lab_id, S.study);
    S.subnr = input("Participant ID: ", "s");
    S.subid = sprintf("%s_%s", S.lab_id, S.subnr);
    S.start_cues_after = 1;  % minutes after which the playing of the cues should start
    S.stimdelay = 5;         % seconds between stimulus  presentations
    S.max_repetitions = 3;   % repeat all stimuli maximally 3 rounds
    S.stim_dur = 0.450; %Stimulus Duration
    S.mask_dur_mean = 4.550; % Mask duration mean seconds      % is 4.450 in OpenSesame, but Wamsley 2023 says 5 s SOA
    S.mask_dur_sd = 1;       % standard deviation to sample within, will be truncated above/bellow
    S.key_pause = 0.5;

    currpath = fileparts(mfilename('fullpath'));                            % currpath: folder should contain Results and SleepSounds  
    if isempty(currpath)
        currpath = cd;                                                      % use path of current function or current directory
    end

    resultsFilePath = fullfile(currpath, "Results");
    if ~exist(resultsFilePath,"dir")
        mkdir(resultsFilePath);
    end

    savefile = fullfile(resultsFilePath, sprintf('%s_SART_%s_Results.mat', S.subid, "TR"));
    if ~exist(savefile, "file")
        load(fullfile(currpath, "Stimuli", "MBEDS_SART_stim_TR"+".mat"),"stimulus_control");
        S.train = true;
    else
        savefile = fullfile(resultsFilePath, sprintf('%s_SART_%s_Results.mat', S.subid, "TE"));
        if exist(savefile, "file")
            error("Results file already exists. Please check the condition and subject number.");
        end
        load(fullfile(currpath, "Stimuli", "MBEDS_SART_stim_TE"+".mat"),"stimulus_control");
        S.train = false;
    end

    S.probes = stimulus_control(:,1);
    S.targets = stimulus_control(:,2);
    S.ntrials = length(stimulus_control);
    S.breaks = zeros(S.ntrials,1);
    S.breaks(168) = 1;

    %% read in audiofiles
    % read in the participant's anticlustered order and sound list
    sound_csv = readtable(fullfile(currpath, "Stimuli", "MBEDS_soundfiles.csv")); % read sound names
    anticlust_file = fullfile(fileparts(currpath), "stimulation_files", sprintf("%s_%s_anticlust.csv", S.lab_id, S.subnr));

    try
        sound_csv_subject = readtable(anticlust_file);
    catch
        error("Cannot load stimsounds for subject %s from subfolder StimFilesSubjects, " + ...
              "make sure the file %s has been calculated and is present", ...
              S.subid, anticlust_file);
    end
    
    if istable(sound_csv_subject)
        sound_csv_subject = table2cell(sound_csv_subject); 
    end
    sounds_subject = sound_csv_subject(:);
    sound_ids_subject = double(extract(string(sounds_subject), digitsPattern))';
    S.sound_ids_subject = sound_ids_subject;
    
    stim_id = table2array(sound_csv(:, 'ID'));
    stim_name = table2array(sound_csv(:, 'Name'));
    stim_name_dict = containers.Map(stim_id, stim_name);
    
    stim_dict = containers.Map('KeyType', 'double', 'ValueType', 'any');
    for i = stim_id'
        soundFilename = fullfile(currpath, 'Stimuli', sprintf('s%d.wav', i)); 
        audio = audioread(soundFilename)';
        if size(audio,1)==1
            audio = repmat(audio,2,1);
        end
        stim_dict(i) = {stim_name_dict(i), audio};
    end

    %% read in baseline sound
    baselinesound_name = 'baselinesound';
    audio = audioread(fullfile(currpath, 'Stimuli', [baselinesound_name, '.wav']))';
    if size(audio,1)==1
        audio = repmat(audio,2,1);
    end
    stim_dict(99) = {baselinesound_name, audio, ones(100, 100)};
    %add the baseline sound to stimulation list
    n_stim = length(sound_ids_subject);
    sound_ids_subject = [sound_ids_subject(randperm(n_stim)), repmat(99, 1, n_stim)];

    fprintf("\nLoaded %d auditory stimuli (%d controls), will play %s repetitions\n", ...
            length(sound_ids_subject), n_stim, S.max_repetitions)
    %% define log file here to pass later into thread
    logfile = fopen(fullfile(resultsFilePath, sprintf("%s_SART_logfile.log", S.subid)),"a");

    %% initialize psychtoolbox audio
    [S.audio_device_id, S.audio_fs] = chooseAudioOutputDevice();

    InitializePsychSound(1) % Chose 1 to enable very low latency    
    paBGDeviceHandle = PsychPortAudio('Open', S.audio_device_id, 1, 1, S.audio_fs, 2); 
    paSTIMDeviceHandle = PsychPortAudio('Open', S.audio_device_id, 1, 1, S.audio_fs, 2); 
    
    PsychPortAudio('Volume', paBGDeviceHandle , S.backgroundVolume);
    PsychPortAudio('Volume', paSTIMDeviceHandle , S.soundVolume);

    backgroundnoise = audioread(fullfile('Stimuli', 'noise.mp3'))';
    if size(backgroundnoise,1)==1
        backgroundnoise = repmat(backgroundnoise,2,1);
    end
    
    % FillBuffer for background Noise
    PsychPortAudio('FillBuffer', paBGDeviceHandle, backgroundnoise);
    PsychPortAudio('Start', paBGDeviceHandle, 0, 0, 1); % Start background noise on repeat

    % save some more variables in our cross-thread state structure
    % we need to use a structure to pass variables between the main 5
    % function and the fake 'thread' that plays the audio
    tState.stim_dict            = stim_dict; 
    tState.sound_ids_subject    = sound_ids_subject;
    tState.paSTIMDeviceHandle   = paSTIMDeviceHandle;
    tState.logfile              = logfile;
    tState.start_cues_after     = S.start_cues_after*60;  % dont do anything before this time is over
    tState.repetitions          = 0;
    tState.countstim            = 0;                        % index into order
    tState.max_repetitions      = S.max_repetitions;  % dont repeat list more than that
    tState.nIds                 = numel(sound_ids_subject);
    tState.order                = sound_ids_subject(randperm(tState.nIds)); % initial shuffle
    tState.is_training          = S.train;  % disable cueing for training
    tState.DEBUG = S.debug;
    
    tState.trigger_port = S.trigger_port;
    tState.trigger_duration = S.trigger_duration;


    % define a cue timer that runs a loop inside.
    % we're basically pretending that the timer is a thread.
    cueTimer = timer('UserData', tState, ...
                     'Period', S.stimdelay, ...
                     'StartDelay', drawNormal(2, 1), ...  % random jitter when cueing will exactly start
                     'ExecutionMode', 'fixedSpacing', ...  % fixed spacing makes sure between end of timer and beginning of next is 5s
                     'TimerFcn',@playCues);

    %% Setup Psychtoolbox Screen to Use Current Monitor
    screenNumber = max(Screen('Screens')); % Use the current monitor
    white = WhiteIndex(screenNumber);
    black = BlackIndex(screenNumber);
    if S.debug
        Screen('Preference', 'VisualDebugLevel', 3);
        Screen('Preference', 'SkipSyncTests', 0);
        warning('The DEBUG flag has been set in the config file. Please remove before running the study')
        PsychDebugWindowConfiguration(0, 0.8)
        debug_rect = [1920 100 3000 800]; % Adjust as needed=
        [win, rect] = Screen('OpenWindow', screenNumber, black, debug_rect);
    else
        clear Screen
        Screen('Preference', 'SkipSyncTests', 0);
        screenNumber = max(Screen('Screens')); % Use the current monitor
        white = WhiteIndex(screenNumber);
        black = BlackIndex(screenNumber);
        [win, rect] = Screen('OpenWindow', screenNumber, black); % Open full-screen window
    end
    S.screensize = rect;
    S.screencenter = [rect(3)/2, rect(4)/2];
    sizefactor = rect(3)/1920;
    ts = round(32*sizefactor);

    img = zeros(8,1);
    for i=1:8
        t = imread(fullfile("Stimuli", "sart" + num2str(i) + "_" + S.language +".png"));
        t = imresize(t, sizefactor);
        img(i) = Screen('MakeTexture', win, t);
    end
    probe_num = 8;

    Screen('TextSize', win, ts);

    %% Initialization
    rng('shuffle'); % Random seed based on current time

    % prepare trigger ports
    if ~S.debug
        triggerWriteDelay = 0.005;  % Trigger duration in s

    % Setup TriggerBox serial port
    S.trigger_port = serialport("COM3", 9600);  % Adjust COM port if needed
    S.trigger_duration = 0.01;  % Trigger pulse duration
    end

    %% prepare logfile
    %% 

    printf(logfile, "\n\nManyBeds - Lab %s (%s) %s\n",S.location, S.lab_id, S.study);
    printf(logfile, "%s\n", mfilename);
    printf(logfile, "Participant %s\n", S.subnr);
    if S.train
        printf(logfile, "Training\n");
    else
        printf(logfile, "Experiment\n");
    end
    printf(logfile, "%s\n", S.subid);
    printf(logfile, "%s\n\n", datetime);
    
    if S.train
        %% Display Instructions
        instructions = translate('instructions');
        
        % [
        %     'Instructions:\n\n' ...
        %     'You will now perform a numbers task. During this task,\n' ...
        %     'a number between 1 and 9 will be presented on the screen\n' ...
        %     'every few seconds. While performing the task, you must\n' ...
        %     'keep a finger or hand on the spacebar.\n\n' ...
        %     'When you see a number, you should press the spacebar\n' ...
        %     'as quickly as possible, except for when the number is 3.\n' ...
        %     'If the number is 3, you should do nothing.\n\n' ...
        %     'It is important that you respond as fast and accurately as possible.\n\n\n\n' ...
        %     'Press the spacebar to see an example…'                ];

        DrawFormattedText(win, instructions, 'center', 'center', white);
        Screen('Flip', win);
        waitForKeypress('space');

        displayMask;
        WaitSecs(drawNormal(S.mask_dur_mean, S.mask_dur_sd));
        displayStimulus(7);
        WaitSecs(S.stim_dur);
        displayMask;
        WaitSecs(drawNormal(S.mask_dur_mean, S.mask_dur_sd));
        displayStimulus(3);
        WaitSecs(S.stim_dur);
        displayMask;
        WaitSecs(drawNormal(S.mask_dur_mean, S.mask_dur_sd));
        % 'Press SPACE to continue'
        text = translate("space_continue");
        DrawFormattedText(win, text, 'center', 'center', white);
        Screen('Flip', win);
        waitForKeypress('space');

        for i=1:8
            displayProbe(i);
            pause(S.key_pause);
            KbWait; 
        end
        pause(S.key_pause);
        % 'Practice Trial\n\nPress SPACE when ready...'
        text = [translate('practice_trial'), '\n\n', translate('space_start')];
        DrawFormattedText(win, text, 'center', 'center', white);
        Screen('Flip', win);
        waitForKeypress('space'); 
    else
        % Now follows the number task \n\n press space to start
        text = [translate("number_task"), '\n\n', translate('space_start')];
        DrawFormattedText(win, text, 'center', 'center', white);
        Screen('Flip', win);
        waitForKeypress('space'); 
        % 'The task will begin in 10 seconds...'
        text = translate('task_countdown');
        DrawFormattedText(win, text, 'center', 'center', white);
        Screen('Flip', win);
        pause(10);   % Does wait just 1 second in OpenSesame
    end

    S.t0 = GetSecs;

    % only start the cueTimer after the instructions have finished
    UD = get(cueTimer,'UserData');
    UD.t0 = S.t0;  % synchronize t0 within the timer
    set(cueTimer,'UserData',UD);
    start(cueTimer);

    respKeys=zeros(1,256);
    respKeys(KbName('space'))=1;
    KbQueueCreate(-1, respKeys);
    KbQueueStart(-1);
    
    %% Begin Task Trials
    RES.RTnontarget = NaN(sum(S.targets==0),1);
    RES.proberesponses = NaN(sum(S.probes),1);
    RES.errors = [];
    RES.missed = [];
    n_nontarget = 0;
    n_target = 0;
    n_probe = 0;
    n_errors = 0;
    n_missed = 0;
    n_resp = 0;
    printf(logfile, '[%9.3f] START %s\n', GetSecs-S.t0, datetime);

    displayMask;
    pause(5);
        
    for i = 1:S.ntrials
        KbQueueFlush(); % clear any previous keypresses to prevent false detection

        if S.targets(i)   % target is number 3
            n_target = n_target + 1;
            tim = displayStimulus(3);
            tstim = tim;
            % log stimulus
            printf(logfile, '[%9.3f] TARGET %03d\n', tim - S.t0, n_target);
            sendTrigger(S.targets(i)+10);
            mask = false;
            started = GetSecs;
            curr_interval = drawNormal(S.mask_dur_mean, S.mask_dur_sd);
            while GetSecs-started < S.stim_dur + curr_interval
                if GetSecs-started > 0.450 && ~mask
                   tim = displayMask;
                   % log mask
                   printf(logfile, '[%9.3f] MASK %03d - interval %dms\n', tim - S.t0, i, round(curr_interval*1000));
                   mask = true;
                end
                [~, tims] = KbQueueCheck(-1);
                if tims(KbName('space'))
                    n_resp = n_resp + 1;
                    tim = tims(KbName('space'));
                    % log error
                    printf(logfile, '[%9.3f] ERROR %03d - %5.3f s\n', tim - S.t0, i, tim - tstim);
                    sendTrigger(200);
                    n_errors = n_errors + 1;
                    RES.errors(n_errors,1) = tim - tstim;
                    RES.errors(n_errors,2) = n_target;
                end
            end
        else    % non-target
            nontarget = randi(8);
            if nontarget>2, nontarget = nontarget + 1; end % 3 cannot occur (-> target)
            n_nontarget = n_nontarget + 1;

            tim = displayStimulus(nontarget);
            tstim = tim;
            % log stimulus
            printf(logfile, '[%9.3f] NON-TARGET %03d (%d)\n', tim - S.t0, n_nontarget, nontarget);
            sendTrigger(nontarget);
            keydown = false;
            mask = false;
            started = GetSecs;
            curr_interval = drawNormal(S.mask_dur_mean, S.mask_dur_sd);
            while GetSecs-started < S.stim_dur + curr_interval
                if GetSecs-started > 0.450 && ~mask
                   tim = displayMask;
                   % log mask
                   printf(logfile, '[%9.3f] MASK %03d - interval %dms\n', tim - S.t0, i, round(curr_interval*1000));
                   mask = true;
                end
                [~, tims] = KbQueueCheck(-1);
                if tims(KbName('space'))
                    n_resp = n_resp + 1;
                    % log time
                    tim = tims(KbName('space'));
                    printf(logfile, '[%9.3f] RT_NON-TARGET %03d - %5.3f s\n', tim - S.t0, n_nontarget, tim - tstim);
                    sendTrigger(100);
                    if isnan(RES.RTnontarget(n_nontarget))
                        RES.RTnontarget(n_nontarget) = tim - tstim;
                    else
                        RES.additionalnontarget(n_resp) = tim - tstim;
                    end
                    keydown = true;
                end
            end
            if ~keydown
                tim = GetSecs;
                n_missed = n_missed + 1;
                printf(logfile, '[%9.3f] MISSED %03d\n', tim - S.t0, n_missed);
                RES.missed(n_missed,1) = tim - S.t0;
                RES.missed(n_missed,2) = n_nontarget;
            end
        end

        if S.probes(i)
            % disable cueing
            stop(cueTimer)
            while strcmp(cueTimer.Running,'on')
                pause(0.01);     % brief yield until the callback completes
            end      
            n_probe = n_probe + 1;
            tim = displayProbe;

            printf(logfile, '[%9.3f] PROBE %03d\n', tim - S.t0, n_probe);
            sendTrigger(90);
            keyname = [];
            while isempty(keyname) | ~ismember(keyname(1), '12345') % 1-5, cross-OS style
                [tim, keys] = KbWait(-1,2);
                keyname = getKeyNum(keys);
            end
            printf(logfile, '[%9.3f] PROBE_RESPONSE %03d (%s)\n', tim - S.t0, n_probe, keyname);
            sendTrigger(90 + str2double(keyname));  % should send 91-95 depending on answer
            RES.proberesponses(n_probe) = str2double(keyname);

            tim = displayMask;
            printf(logfile, '[%9.3f] MASK %03d\n', tim - S.t0, i);
            pause(5);

            % resume cueing and add random delay
            cueTimer.StartDelay = drawNormal(2, 1);
            start(cueTimer)
        end

        if S.breaks(i)
            % disable cueing
            stop(cueTimer)
            while strcmp(cueTimer.Running,'on')
                pause(0.01);     % brief yield until the callback completes
            end    
            % 'Take a break\n\n '
            text = translate("break");
            DrawFormattedText(win, text, 'center', 'center', white);     % At least 30 seconds, this was not in the original
            tim = Screen('Flip', win);
            printf(logfile, '[%9.3f] BREAK %03d\n', tim - S.t0, i);
            pause(30);
            % 'Take a break\n\nPress SPACE when ready to continue...'
            text = [translate("break"), "\n\n", translate("space_continue")];
            DrawFormattedText(win, text, 'center', 'center', white);
            Screen('Flip', win);
            sendTrigger(254);
            waitForKeypress('space');
            sendTrigger(255);
            % The task will begin in 10 seconds...
            text = translate("task_countdown");
            DrawFormattedText(win, text, 'center', 'center', white);
            Screen('Flip', win);
            pause(10);
            tim = displayMask;
            printf(logfile, '[%9.3f] MASK %03d\n', tim - S.t0, i);
            pause(5);

            % resume cueing and add random delay
            cueTimer.StartDelay = drawNormal(2, 1);
            start(cueTimer)
        end
    end
    RES.nresp = n_resp;
    save(savefile, 'S', 'RES');
    printf(logfile, '[%9.3f] END %s\n', GetSecs-S.t0, datetime);

    % 'You have finished this task...'
    text = translate("finished");
    DrawFormattedText(win, text, 'center', 'center', white);
    Screen('Flip', win);
    pause(5);
    KbWait;
    Screen('CloseAll');

    try  % if no errors occured RES.errors will be empty
        n_errors_calc = length(unique(RES.errors(:,2)));
    catch
        n_errors_calc = 0;
    end

    fprintf("targets correct: %d/%d\n", sum(S.targets>0)-n_errors_calc, sum(S.targets>0));
    fprintf("non-targets correct: %d/%d\n", sum(RES.RTnontarget>0), sum(S.targets==0));
    stop(cueTimer)
    delete(cueTimer)
    PsychPortAudio('Close')
    fclose(logfile);

    %% subfunctions
    function waitForKeypress(name)
        % wait for specific keypress of key NAME; default name is space
        if nargin < 1
            name = 'space'; % Default value
        end
        % unify keyboards across OS
        KbName('UnifyKeyNames');

        spaceKey = KbName(name);
        while true
            [~, keyCode] = KbWait;
            Screen('Flip', win);
            if keyCode(spaceKey)
                break;
            end
        end
    end


    function tim = displayMask
        Screen('DrawDots', win, S.screencenter, 10*sizefactor, [255 255 255], [], 2);
        tim = Screen('Flip', win);
    end   

    function tim = displayStimulus(num, color)
        if nargin < 2
            color = white;
        end
        DrawFormattedText(win, num2str(num), 'center', 'center', color); 
        tim = Screen('Flip', win);
    end    

    function tim = displayProbe(num)
        if nargin < 1
            num = probe_num;
        end
        Screen('DrawTexture', win, img(num));
        tim = Screen('Flip', win);
    end

    function sendTrigger(trigger)
        if S.debug
            disp(['[DEBUG] would send trigger: ', num2str(trigger)]);
            return
        end
        if trigger <= 0 || trigger > 255
            warning('Trigger value %d out of bounds (must be 1-255)', trigger);
            return
        end
        write(S.trigger_port, trigger, "uint8");
        WaitSecs(S.trigger_duration);
        write(S.trigger_port, 0, "uint8");
    end   
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
    % this runs even if MBEDS_SART errors or is interrupted
    warning('Cleaning up PsychToolbox resources...');
    PsychPortAudio('Close');
    Screen('CloseAll');     
    allTimers = timerfindall;    % find all existing timers
    if ~isempty(allTimers)
        stop(allTimers);         % stop them running
        delete(allTimers);       % delete them from memory
    end
end

    function playCues(timerObj, ~)
    self  = get(timerObj, 'UserData');
    curr_time = GetSecs();

    if self.is_training
        return
    end
    if self.repetitions >= self.max_repetitions
        return
    end
    if (curr_time - (self.t0 + self.start_cues_after)) < -0.2
        printf(self.logfile, '[%9.3f] NO STIM ; buffer phase still active for %3.0f seconds\n', ...
              curr_time - self.t0, -(curr_time - (self.t0 + self.start_cues_after)));
        return;
    end

    self.countstim = self.countstim + 1;
    if self.countstim > self.nIds
        self.countstim    = 1;
        self.repetitions  = self.repetitions + 1;
        if self.repetitions >= self.max_repetitions
            printf(self.logfile, '[%9.3f] NO STIM ; max repetitions reached, stop cueing\n', ...
                    curr_time - self.t0);
            stop(timerObj);
            return;
        end
        self.order = self.sound_ids_subject(randperm(self.nIds));
    end

    idx = self.order(self.countstim);
    sendTrigger(100 + idx);

    stim = self.stim_dict(idx);
    PsychPortAudio('FillBuffer', self.paSTIMDeviceHandle, stim{2});
    lastStim = PsychPortAudio('Start', self.paSTIMDeviceHandle, 1, 0, 1);

    printf(self.logfile, '[%9.3f] STIM %02d (%s) - %d repetitions, cue count %03d\n', ...
            lastStim - self.t0, idx, stim{1}, self.repetitions, self.countstim);

    set(timerObj, 'UserData', self);

    %% nested trigger function
    function sendTrigger(trigger)
        if self.DEBUG
            disp(['[DEBUG] would send trigger: ', num2str(trigger)]);
            return
        end
        if trigger <= 0 || trigger > 255
            warning('Trigger value %d out of bounds (must be 1-255)', trigger);
            return
        end
        write(self.trigger_port, trigger, "uint8");
        WaitSecs(0.01);  % trigger duration
        write(self.trigger_port, 0, "uint8");
    end
end



function value = drawNormal(mean, sd)
    % draw from a normal distribution with mean and sd
    % truncate values at +- 1sd

    % Define the interval
    interval = [mean - sd, mean + sd];

    % Draw a value and truncate if necessary
    value = mean + sd * randn();
    % Truncate to within the interval
    value = max(min(value, interval(2)), interval(1));
end

function printf(fileID, varargin)
    % convenience function to print to file and also to console
    % simultaneously
    % Print to file
    fprintf(fileID, varargin{:});
    % Print to console
    fprintf(varargin{:});
end

function number = getKeyNum(keys)
    % convert from keycode to a number, truncate all else
    keycode = find(keys, 1);
    name = KbName(keycode);
    if ischar(name)
        number = name(1);
    else
        number = name;
    end
end

function out = translate(key)
%TRANSLATE  Fetch localised text for KEY from Translations/translations.json
%   Requires struct S with field S.language (e.g. 'en', 'de') in caller.

    % --- determine language (default = 'en') ------------------------------
    try
        lang = lower(string(evalin('caller','S.language')));
    catch
        lang = "en";
        warning("invalid language code in S.language");
    end

    % --- load & cache full dictionary once --------------------------------
    persistent dict
    if isempty(dict)
        here  = fileparts(mfilename('fullpath'));
        translation_json = fullfile(here, 'translations.json');
        fid   = fopen(translation_json, 'r','n','UTF-8');
        raw   = fread(fid, '*char')';
        fclose(fid);
        dict  = jsondecode(raw);          % struct: key → struct(lang → text)
    end

    % --- return translation or fallbacks ----------------------------------
    if isfield(dict,key) && isfield(dict.(key),lang)
        out = dict.(key).(lang);
    elseif isfield(dict,key) && isfield(dict.(key),'en')
        warning('translate:MissingLang','Missing "%s" for %s; using English.',key,lang);
        out = dict.(key).en;
    else
        warning('translate:MissingKey','Missing key "%s"; returning key.',key);
        out = key;
    end
end
