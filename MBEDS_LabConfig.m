function C = MBEDS_LabConfig
    % lab-specific configuration for ManyBeds MATLAB scripts
    % The information provided here will be used in both the
    % MBEDS_sleepstim and MBEDS_SART scripts.
    
    % 1) lab ID
    C.location = "C99_Mannheim";         % your lab ID + location
    C.lab_id   = "C99";                  % your lab ID       
    
    % 2) language of SART
    C.language = "en";            % options: 'de', 'en', 'fr', 'cn', 'jp'
    
    % 3) parallel port hex address
    C.lpt_hex = '3FF8'; 


    % 4) debug mode MBEDS_sleepstim.m
    C.debug_sleepstim = true;       % set to false to send triggers

    % 5) debug mode MBEDS_SART.m
    C.usetrigger_SART = false;      % set to true to send triggers
    
end
