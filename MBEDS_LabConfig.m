%% CONFIG
function C = MBEDS_LabConfig

    % lab-specific configuration for ManyBeds MATLAB scripts
    % The information provided here will be used in both the
    % MBEDS_sleepstim and MBEDS_SART scripts.
    
    % 1) lab ID
    C.location = "C99_Mannheim";   % your lab ID + location
    C.lab_id   = "C99";            % your lab ID       
    
    % 2) language of SART
    C.language = "en";             % options: 'de', 'en', 'fr', 'cn', 'jp'

    % 3) type of noise
    C.noise_type = 'pink';        % can be either white or pink

    % 3) trigger setup
    C.trigger_interface = "parallel"; % parallel or serial
    C.trigger_port = '3FF8'; % e.g. LPT hex id or COM port
    C.trigger_duration = 0.01;  % Trigger pulse duration in seconds, usually 5 ms
    % baudrate in case of serial COM port (ignored for parallel ports)
    C.baudrate = 2000000;  %(2000000 is default for brainproducts Triggerbox Plus)

    % 4) debug mode
    C.debug_mode = true;       % set to false to send triggers
    %%%%%%%%%%%%%%%%%%%%%%%


    %%%%% sanity checks %%%
    % make sure no field is missing
    required = ["location","lab_id", "language", "debug_mode",  ...
                "trigger_interface", "trigger_duration", "trigger_port"];
    assert(all(isfield(C, required)), 'Config file missing fields');
    if C.debug_mode
          dlg = questdlg('DEBUG mode is ON – triggers will NOT be sent.  Continue?', ...
                   'Debug mode', 'Continue', 'Abort', 'Abort');
          if ~strcmp(dlg,'Continue'); error('Run aborted by operator'); end
    end
    if strcmp(string(C.trigger_interface), "serial")  & ~C.debug_mode
            list_serial_ports()
    end
    if ~ ismember(string(C.trigger_interface), ["parallel", "serial"])
                error('trigger_interface must be "parallel" or "serial".');
    end
    if ~ismember(string(C.noise_type), ["white", "pink"])
        error('noise_type must be "white" or "pink".');
    end
    if ~ismember(string(C.language), ["de", "en", "fr", "cn", "jp", "nl"])
                error("language must be 'de', 'en', 'fr', 'cn' or 'jp'");
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% other functions (not part of config)
function list_serial_ports()
    % Lists all serial ports and indicates availability without opening them
    % Ports are sorted in natural/human order (e.g., COM1, COM2, COM10)

    all_ports = serialportlist("all");
    available_ports = serialportlist("available");

    if isempty(all_ports)
        fprintf('No serial ports detected.\n');
        return;
    end

    % Natural sort
    sorted_ports = natsort(all_ports);

    fprintf('Serial Ports:\n');
    fprintf('----------------------\n');

    for i = 1:length(sorted_ports)
        port = sorted_ports{i};
        is_available = any(strcmp(port, available_ports));
        status = 'Available';
        if ~is_available
            status = 'In Use / Unavailable';
        end
        fprintf('%-20s : %s\n', port, status);
    end
    fprintf('----------------------\n');
end

function sorted = natsort(list)
    % Sorts strings in natural/human order (e.g., COM1, COM2, COM10)

    [~, idx] = sort_nat(list);
    sorted = list(idx);
end

function [sorted, index] = sort_nat(c)
    % Natural-order sort of cell array of strings
    expr = '(\d+)'; % Regular expression to extract numeric parts
    c = c(:);
    numParts = regexp(c, expr, 'match');
    numParts(cellfun(@isempty, numParts)) = {{'0'}};
    numVal = cellfun(@(x) sscanf(x{1}, '%f'), numParts);
    [~, index] = sortrows([numVal, (1:numel(c))']);
    sorted = c(index);
end