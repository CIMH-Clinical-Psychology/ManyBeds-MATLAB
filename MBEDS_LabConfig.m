function C = MBEDS_LabConfig
    % lab-specific configuration for ManyBeds MATLAB scripts
    % The information provided here will be used in both the
    % MBEDS_sleepstim and MBEDS_SART scripts.
    
    % 1) lab ID
    C.location = "C99_Mannheim";         % your lab ID + location
    C.lab_id   = "C99";                  % your lab ID       
    
    % 2) language of SART
    C.language = "en";            % options: 'de', 'en', 'fr', 'cn', 'jp'
    
    % 3) trigger setup
    C.trigger_interface = "parallel"; % parallel or serial port?
    C.trigger_port = '3FF8'; % e.g. LPT hex id or COM port
    C.trigger_duration = 0.01;  % Trigger pulse duration, usually 5ms
    C.baudrate = 2000000; % baudrate in case of serial COM port (2000000 is default for brainproducts Triggerbox Plus)

    % 4) debug mode
    C.debug_mode = true;       % set to false to send triggers

    % make sure no field is missing
    required = ["location","lab_id", "language", "lpt_hex","debug_mode", 
                "trigger_interface", "trigger_duration", "trigger_port"];
    assert(all(isfield(C, required)), 'Config file missing fields');
end
