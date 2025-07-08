function RES = MBEDS_sleepstimGUI(S, fileNameBase, stim_dict, backgroundnoise)

cleanupObj = onCleanup(@() cleanUp());  % remove screen and audio playback in case of crash
%% Initialize experiment
RES = struct;                                   % contains results of current subject

lpt_hex = '3FF8'; % LPT1        Address of parallel port    ADJUST TO LOCAL SITUATION
% lpt_hex  = '4FF8'; % LPT2

%% Create UI
screenSize = get(0, 'ScreenSize');  % [left, bottom, width, height]

fig = figure('Name', ' TMR Sleep Stimulation', ...
    'Position', [ screenSize(3) - 900, screenSize(4) - 500, 800, 350], ...
    'Resize', 'off', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none',...
    'CloseRequestFcn', @CloseRequestHandler);
  % 'WindowButtonDownFcn', @mouseClickHandler, ...

% Add a title
uicontrol('Style', 'text', ...
    'Position', [200, 350, 400, 40], ...
    'FontSize', 16, ...
    'String', 'TMR Sleep Stimulation');

% Add a subtitle
uicontrol('Style', 'text', ...
    'Position', [300, 325, 200, 40], ...
    'FontSize', 8, ...
    'String', 'ManyBeds v0.2');

% Create Start and End Experiment buttons
stopExperiment = false;
start_exp_btn = uicontrol('Style', 'pushbutton', 'String', 'Start Experiment', ...
    'Position', [50, 280, 150, 40], ...
    'Callback', @startExperiment);

end_exp_btn = uicontrol('Style', 'pushbutton', 'String', 'End Experiment', ...
    'Position', [600, 280, 150, 40], ...
    'Callback', @endExperiment);
end_exp_btn.Enable = 'off';

% Create Start and Stop buttons for sound playback
playStimulationSounds = false;
start_snd_btn = uicontrol('Style', 'pushbutton', 'String', 'Start Stimulation', ...
    'Position', [50, 235, 150, 40], ...
    'Callback', @startSoundSeries);
start_snd_btn.Enable = 'off';

stop_snd_btn = uicontrol('Style', 'pushbutton', 'String', 'Stop Stimulation', ...
    'Position', [600, 235, 150, 40], ...
    'Callback', @stopSoundSeries);
stop_snd_btn.Enable = 'off';

% Label and slider for Sound Volume
uicontrol('Style', 'text', ...
    'Position', [260, 40, 80, 20], ...
    'String', 'Sound Volume:', ...
    'HorizontalAlignment', 'center');

RES.soundVolume = 0.1;  
RES.stepSize = 0.1; % granularity of changing sounds

soundVolumeLabel = uicontrol('Style', 'text', ...
    'Position', [260, 0, 80, 40], ...
    'String', sprintf('%.2f', RES.soundVolume), ...
    'FontSize', 16, ...
    'HorizontalAlignment', 'center');

% uicontrol('Style', 'slider', ...
%     'Min', 0, 'Max', 1, 'Value', 0.5, ...
%     'Callback', @(src, ~) updateSoundVolume(src, soundVolumeLabel), ...
%     'Position', [230, 20, 150, 20]);



% Label and slider for Background Volume
uicontrol('Style', 'text', ...
    'Position', [450, 40, 100, 20], ...
    'String', 'Background Volume:', ...
    'HorizontalAlignment', 'center');

RES.backgroundVolume = 0.9;
backgroundVolumeLabel = uicontrol('Style', 'text', ...
    'Position', [450, 0, 80, 40], ...
    'String', sprintf('%.2f', RES.backgroundVolume), ...
    'FontSize', 16, ...
    'HorizontalAlignment', 'center');

% uicontrol('Style', 'slider', ...
%     'Min', 0, 'Max', 1, 'Value', 0.1, ...
%     'Callback', @(src, ~) updateBackgroundVolume(src, backgroundVolumeLabel), ...
%     'Position', [420, 20, 150, 20]);

% Create Volume control buttons for the sound series
incSound_btn = uicontrol('Style', 'pushbutton', 'String', 'Increase Sound Volume', ...
    'Position', [600, 135, 150, 30], ...
    'Callback', @increaseSoundVolume);

decSound_btn = uicontrol('Style', 'pushbutton', 'String', 'Decrease Sound Volume', ...
    'Position', [50, 135, 150, 30], ...
    'Callback', @decreaseSoundVolume);

% Create Volume control buttons for background noise
incBg_btn = uicontrol('Style', 'pushbutton', 'String', 'Increase Background Volume', ...
    'Position', [600, 95, 150, 30], ...
    'Callback', @increaseBackgroundVolume);

decBg_btn = uicontrol('Style', 'pushbutton', 'String', 'Decrease Background Volume', ...
    'Position', [50, 95, 150, 30], ...
    'Callback', @decreaseBackgroundVolume);

% Stepsize selector
stepSizeGroup = uibuttongroup('Units','pixels','Position',[600, 175, 150, 40],'Title','Volume stepsize');
uicontrol(stepSizeGroup,'Style','radiobutton','String','0.1','Position',[2,5,100,20],...
    'Callback',@(~,~)setStepSize(0.1));
uicontrol(stepSizeGroup,'Style','radiobutton','String','0.05','Position',[52,5,100,20],...
    'Callback',@(~,~)setStepSize(0.05));
uicontrol(stepSizeGroup,'Style','radiobutton','String','0.01','Position',[102,5,100,20],...
    'Callback',@(~,~)setStepSize(0.01));


BgOn_btn = uicontrol('Style', 'pushbutton', 'String', 'BG On', ...
    'Position', [50, 55, 70, 30], ...
    'Callback', @startBackgroundTest);

BgOff_btn = uicontrol('Style', 'pushbutton', 'String', 'BG Off', ...
    'Position', [130, 55, 70, 30], ...
    'Callback', @stopBackgroundTest);

% Create Abort button
uicontrol('Style', 'pushbutton', 'String', 'Abort',...
    'Position', [750, 330, 50, 20], ...
    'FontSize', 10, ...
    'HorizontalAlignment', 'left', ...
    'Callback', @abortExperiment);

% label for stimulus count
countLabel = uicontrol('Style', 'text', ...
    'Position', [260, 270, 80, 40], ...
    'FontSize', 16, ...
    'String', '0');

% Create a bordered square for the image display
imagePanel = uipanel('Title', 'Current Sound Image', ...
    'Position', [0.35, 0.25, 0.3, 0.5]);

% Placeholder image axis
imageAxes = axes('Parent', imagePanel, ...
    'Position', [0.1, 0.1, 0.8, 0.8]);
imshow(ones(100, 100), 'Parent', imageAxes);  % Display a blank image initially

% Add a label to display the timer
timerLabel = uicontrol('Style', 'text', ...
    'Position', [600, 0, 150, 40], ...
    'FontSize', 16, ...
    'String', '00:00:00');

% Add a button to test the sound volume
testSoundVolumeBtn = uicontrol('Style', 'pushbutton', 'String', 'Test Sound Volume', ...
    'Position', [50, 10, 150, 40], ...
    'Callback', @testSoundVolume);

t = timer('ExecutionMode', 'fixedRate', ...
    'Period', 1, ... % Update every 1 second
    'TimerFcn', @(~,~) updateLabels(timerLabel));

%% prepare trigger ports
triggerWriteDelay = 0.005;  % Trigger duration in s

if (S.debug == false)

    ioObj = io64;
    ioStatus = io64(ioObj);
    if( ioStatus ~= 0 )
       error('inp/outp installation failed');
    end
    lpt_address = hex2dec(lpt_hex);
end
    
%% prepare audiobuffers
InitializePsychSound(1) % Chose 1 to enable very low latency

paBGDeviceHandle = PsychPortAudio('Open', S.audio_device_id, 1, 1, S.audio_fs, 2); 
paSTIMDeviceHandle = PsychPortAudio('Open', S.audio_device_id, 1, 1, S.audio_fs, 2); 

PsychPortAudio('Volume', paBGDeviceHandle , RES.backgroundVolume);
PsychPortAudio('Volume', paSTIMDeviceHandle , RES.soundVolume);

% FillBuffer for background Noise
PsychPortAudio('FillBuffer', paBGDeviceHandle, backgroundnoise);

printed_stop_message = false;
%% prepare logfile
logfile = fopen(fullfile(fileNameBase, sprintf('%s_sleepstim_logfile.log', S.subid)),"a");

printf(logfile, "\r\n\r\nManyBeds - Lab %s (%s)\r\n",S.location, S.lab_id);
printf(logfile, "%s\r\n", mfilename);
printf(logfile, "Participant %s\r\n", S.subnr);
printf(logfile, "%s\r\n", S.subid);
printf(logfile, '%s\r\n\r\n', datetime);

%% Main Execution Thread
RES.countstim = 0;
RES.repetitions = 0;
nstim = length(S.sound_ids_subject);
RES.sound_ids_list = [];
RES.stimtime = [];

stimTime = 0;
t0 = GetSecs;
t1 = NaN;
printf(logfile, '[%9.3f] START %s\r\n', GetSecs-t0, datetime);

sendTrigger(255)

while ~stopExperiment

    if playStimulationSounds == true
        %Play Stimulus Sound if 5 seconds passed since last one
        if (GetSecs-stimTime > S.stimdelay)
            RES.countstim = RES.countstim+1;
            countLabel.String = string(RES.countstim);
    
            % randomize order of stimulations for every 25+25 stims
            if mod(RES.countstim,50)==1
                if (RES.repetitions>=S.max_repetitions) && (~printed_stop_message)
                    stopSoundSeries;
                    fprintf('Maximum number of repetitions played (max_repetitions=%s)\n', num2str(S.max_repetitions));
                    printed_stop_message = true;
                    continue
                else
                    RES.sound_ids_list = [RES.sound_ids_list S.sound_ids_subject(randperm(nstim))];
                    RES.repetitions = RES.repetitions+1;
                end
            end
            % dont play more than MAX_REPTITIONS rounds of cueing


            stim_idx = RES.sound_ids_list(RES.countstim);
            stim = stim_dict(stim_idx);
            imagePanel.Title = stim{1};
            imshow(stim{3}, 'Parent', imageAxes);

            PsychPortAudio('FillBuffer', paSTIMDeviceHandle, stim{2});
            stimTime = PsychPortAudio('Start', paSTIMDeviceHandle, 1, 0, 1);

            sendTrigger(stim_idx)

            printf(logfile, '[%9.3f] STIM %02d (%s)\r\n', stimTime-t0, stim_idx, stim{1});
            RES.stimtime = [RES.stimtime stimTime-t0];
        end
    end
    drawnow;
end



%% UI Methods & Callbacks

    function startExperiment(~, ~)
        start(t);               % start GUI refresh timer

        fprintf('Start of experiment (lights off): %s\n', datetime);
        printf(logfile, '[%9.3f] LIGHTSOFF\r\n', GetSecs-t0);
        t1 = GetSecs;

        sendTrigger(254)

        start_exp_btn.Enable = 'off';
        start_snd_btn.Enable = 'on';
        % testSoundVolumeBtn.Enable = 'off';
        % incSound_btn.Enable = 'off';
        % decSound_btn.Enable = 'off';
        % incBg_btn.Enable = 'off';
        % decBg_btn.Enable = 'off';
        BgOn_btn.Enable = 'off';
        BgOff_btn.Enable = 'off';

        status = PsychPortAudio('GetStatus', paBGDeviceHandle);
        if status.Active 
            PsychPortAudio('Stop', paBGDeviceHandle, 2, 1);
        end
        PsychPortAudio('Start', paBGDeviceHandle, 0, 0, 1); % Start background noise on repeat
    end

    function startSoundSeries(~, ~)
        printed_stop_message = false
        fprintf('Start sound stimulation: %s\n', datetime);
        printf(logfile, '[%9.3f] STARTSTIM\r\n', GetSecs-t0);

        sendTrigger(251)

        testSoundVolumeBtn.Enable = 'off';
        start_snd_btn.Enable = 'off';
        start_snd_btn.Value = 1;
        stop_snd_btn.Enable = 'on';

        playStimulationSounds = true;
    end

    function stopSoundSeries(~, ~)
        fprintf('Stop sound stimulation: %s\n', datetime);
        printf(logfile, '[%9.3f] STOPSTIM\r\n', GetSecs-t0);

        sendTrigger(250)

        testSoundVolumeBtn.Enable = 'on';
        start_snd_btn.Enable = 'on';
        start_snd_btn.Value = 0;
        stop_snd_btn.Enable = 'off';

        playStimulationSounds = false;

        PsychPortAudio('Stop', paSTIMDeviceHandle, 1);
    end

    function setStepSize(val)
        RES.stepSize = val;
    end

    function increaseSoundVolume(~, ~)
        RES.soundVolume = min(RES.soundVolume+RES.stepSize, 1);
        soundVolumeLabel.String = sprintf('%.2f', RES.soundVolume);

        PsychPortAudio('Volume', paSTIMDeviceHandle , RES.soundVolume);
        if strcmp(t.Running, 'off')
           testSoundVolume;
        end

        printf(logfile, '[%9.3f] STIMVOL+ %.2f\r\n', GetSecs-t0, RES.soundVolume);
    end

    function decreaseSoundVolume(~, ~)
        RES.soundVolume = max(RES.soundVolume-RES.stepSize, 0);
        soundVolumeLabel.String = sprintf('%.2f', RES.soundVolume);

        PsychPortAudio('Volume', paSTIMDeviceHandle , RES.soundVolume);

        if strcmp(t.Running, 'off')
           testSoundVolume;
        end

        printf(logfile, '[%9.3f] STIMVOL- %.2f\r\n', GetSecs-t0, RES.soundVolume);
    end

    function increaseBackgroundVolume(~, ~)
        RES.backgroundVolume = min(RES.backgroundVolume+RES.stepSize, 1);
        backgroundVolumeLabel.String = sprintf('%.2f', RES.backgroundVolume);

        PsychPortAudio('Volume', paBGDeviceHandle , RES.backgroundVolume);

        printf(logfile, '[%9.3f] BGVOL+ %.2f\r\n', GetSecs-t0, RES.backgroundVolume);
    end

    function decreaseBackgroundVolume(~, ~)
        RES.backgroundVolume = max(RES.backgroundVolume-RES.stepSize, 0);
        backgroundVolumeLabel.String = sprintf('%.2f', RES.backgroundVolume);

        PsychPortAudio('Volume', paBGDeviceHandle , RES.backgroundVolume);

        printf(logfile, '[%9.3f] BGVOL- %.2f\r\n', GetSecs-t0, RES.backgroundVolume);
    end

    function startBackgroundTest(~, ~)

        sendTrigger(150)

        status = PsychPortAudio('GetStatus', paBGDeviceHandle);
        if ~status.Active 
            PsychPortAudio('Start', paBGDeviceHandle, 0, 0, 1); 
            printf(logfile, '[%9.3f] BACKGROUNDTESTON\r\n', GetSecs-t0);
        end
    end

    function stopBackgroundTest(~, ~)

        sendTrigger(151)

        PsychPortAudio('Stop', paBGDeviceHandle, 0);
        printf(logfile, '[%9.3f] BACKGROUNDTESTOFF\r\n', GetSecs-t0);
    end

    function testSoundVolume(~, ~)
        PsychPortAudio('Stop', paSTIMDeviceHandle, 0);
        stim = stim_dict(99);
        PsychPortAudio('FillBuffer', paSTIMDeviceHandle, stim{2});
        PsychPortAudio('Start', paSTIMDeviceHandle, 1, 0, 1);

        sendTrigger(199)

        printf(logfile, '[%9.3f] SOUNDTEST\r\n', GetSecs-t0);
    end

    % function mouseClickHandler(~, ~)
    %     mouseType = get(fig, 'SelectionType');
    % 
    %     switch mouseType
    %         case 'normal'  % Left click: Start/Resume
    %             if playStimulationSounds == false && beginExperiment == true
    %                 start_btn.Enable = 'off';
    %                 stop_btn.Enable = 'on';
    %                 testSoundVolumeBtn.Enable = 'off';
    % 
    %                 playStimulationSounds = true;
    %             end
    %         case 'alt'  % Right click: Pause
    %             if playStimulationSounds == true
    %                 start_btn.Enable = 'on';
    %                 stop_btn.Enable = 'off';
    %                 testSoundVolumeBtn.Enable = 'on';
    % 
    %                 PsychPortAudio('Stop', paSTIMDeviceHandle, 1);
    %                 playStimulationSounds = false;
    %             end
    %     end
    % end

    % function updateSoundVolume(slider, label) %#ok<INUSD>
    %     RES.soundVolume = round(slider.Value,2);
    %     label.String = sprintf('%.2f', RES.soundVolume);
    %     PsychPortAudio('Volume', paSTIMDeviceHandle , RES.soundVolume);
    % end

    % function updateBackgroundVolume(slider, label) %#ok<INUSD>
    %     RES.backgroundVolume = round(slider.Value,2);
    %     label.String = sprintf('%.2f', RES.backgroundVolume);
    %     PsychPortAudio('Volume', paBGDeviceHandle , RES.backgroundVolume);
    % end

    function updateLabels(timerLabel)
        elapsed = round(GetSecs-t1);
        hours = floor(elapsed / 3600);
        minutes = floor(mod(elapsed, 3600) / 60);
        seconds = floor(mod(elapsed, 60));
        formattedTime = sprintf('%02d:%02d:%02d', hours, minutes, seconds);

        timerLabel.String = formattedTime;

        if (elapsed > S.minsleepdur*60)
            timerLabel.ForegroundColor = 'red';
            end_exp_btn.Enable = 'on';
        end
    end

    function abortExperiment(~,~)
        choice = questdlg('You are about to cancel the experiment. Are you sure you want to continue?', ...
            'Cancel Experiment', ...
            'Yes', 'No', 'No');

        if strcmp(choice, 'Yes')
            if isfield(RES,"ABORTED") && RES.ABORTED==true
                choice2 = questdlg(sprintf('%s_sleepstim.mat should already be saved. Breaking hard now. Are you sure you want to continue?', S.subid), ...
                    'Cancel Experiment', ...
                    'Yes', 'No', 'No');
                if strcmp(choice2, 'Yes')
                    delete(fig);
                    error("HARD ABORT");
                end
            end
            RES.ABORTED = true;

            fprintf('EXPERIMENT WAS ABORTED PREMATURELY: %s\n', datetime);
            printf(logfile, '[%9.3f] ABORTED\r\n', GetSecs-t0);
            endExperiment;
        end
    end

    function endExperiment(~, ~)
        savefilename = fullfile(fileNameBase, sprintf('%s_sleepstim.mat', S.subid));
        if isfile(savefilename)     % create a backup if file already exists
            fileprop = dir(savefilename);
            bakdate = char(datetime(fileprop.datenum,'convertfrom','datenum','Format','yyyyMMdd_HHmmss'));
            movefile(savefilename, [savefilename{1}(1:end-4) '_' bakdate '.bak']);
        end
        save(fullfile(fileNameBase, sprintf('%s_sleepstim.mat', S.subid)), "S", "RES");
        stopExperiment = true;

        try
            if ~isempty(t)
                stop(t);    % Stop and delete the main timer
                delete(t);
                t = [];
            end
    
            if playStimulationSounds
                printf(logfile, '[%9.3f] STOPSTIM\r\n', GetSecs-t0);
                playStimulationSounds = false;
            end
    
            sendTrigger(250)
 
            fprintf('End of Experiment: %s\n', datetime);
            RES.sleepduration = GetSecs-t1;

            hours = floor(RES.sleepduration / 3600);
            minutes = floor(mod(RES.sleepduration, 3600) / 60);
            seconds = floor(mod(RES.sleepduration, 60));
            formattedTime = sprintf('%02d:%02d:%02d', hours, minutes, seconds);
            printf(logfile, '[%9.3f] SLEEPDURATION %s\r\n',GetSecs-t0, formattedTime);
            printf(logfile, '[%9.3f] END %s\r\n', GetSecs-t0, datetime);
    
            if logfile > 1
                fclose(logfile);
                logfile = 1;
            end
    
            sendTrigger(253)

            % Stop sound series and release audio buffers
            PsychPortAudio('Stop', paSTIMDeviceHandle, 1);
            PsychPortAudio('Stop', paBGDeviceHandle, 0);
            PsychPortAudio('Close', paSTIMDeviceHandle);
            PsychPortAudio('Close', paBGDeviceHandle);

            delete(fig);
        catch exception
            fprintf('Error during close operation: %s', exception.message);
        end
    end

    function CloseRequestHandler(~, ~)
        % prevent user from closing figure by doing nothing here
    end

    function sendTrigger(trigger)
        if S.debug
            disp(['[DEBUG] would send trigger: ', num2str(trigger)]);
            return
        end
    
        if S.usetrigger == true
            io64(ioObj, lpt_address, trigger);
            WaitSecs(triggerWriteDelay);
            io64(ioObj, lpt_address, 0);
        end
    end   
end

function cleanUp()
    % Runs no matter how you exit (error, CTRL-C, normal return)
    warning('Performing cleanup of GUI, timer, and audio.');
    PsychPortAudio('Close');
end



function printf(fileID, varargin)
    % convenience function to print to file and also to console
    % simultaneously
    % Print to file
    fprintf(fileID, varargin{:});
    % Print to console
    fprintf(varargin{:});
end

