function buildFCSFunctional()
% buildFCSFunctional  Create the FCS functional architecture and its interface dictionary.
%
%   Generates:
%     FCSFunctionalInterfaces.sldd — logical interface dictionary for the
%                                    functional architecture
%     FCSFunctional.slx            — logical functions of the Flight Control
%                                    System, independent of physical implementation
%
%   Functional interfaces (logical abstractions — no implementation detail):
%     PowerSignal       — abstract power flow: Power (W)
%     CrewInput         — pilot intent: RollRateCmd, PitchRateCmd, YawRateCmd (deg/s)
%     AircraftStateData — aircraft state: RollRate, PitchRate, YawRate (deg/s),
%                         Airspeed (m/s), AltitudeFt (ft), AngleOfAttack (deg)
%     ControlCommand    — surface demand: Elevator, LeftAileron, RightAileron, Rudder (deg)
%     ControlFeedback   — surface position: same elements as ControlCommand (deg, measured)
%     SystemStatus      — health information: StatusWord (double)
%
%   Six functions and their roles:
%     SenseAircraftState     — acquire aircraft state from the environment
%     ComputeControlLaws     — derive control commands from crew input and state
%     CommandControlSurfaces — drive control surfaces and report measured positions
%     DistributePower        — route power to all other functions
%     ProvideCrewInterface   — acquire and condition pilot inceptor inputs
%     MonitorSystemHealth    — fault detection and maintenance reporting
%
%   This script runs independently of buildFCSModel. Each architecture maintains
%   its own interface dictionary at the appropriate abstraction level.

    fcsDir    = fileparts(fileparts(mfilename('fullpath')));
    archDir   = fullfile(fcsDir, 'architecture');
    modelName = "FCSFunctional";
    dictFile  = fullfile(archDir, 'FCSFunctionalInterfaces.sldd');
    slxFile   = fullfile(archDir, char(modelName) + ".slx");

    %% Interface Dictionary

    if bdIsLoaded(modelName), close_system(modelName, 0); end
    Simulink.data.dictionary.closeAll("-discard");
    if isfile(dictFile), delete(dictFile); end
    if isfile(slxFile),  delete(slxFile);  end

    addpath(archDir);
    dict = systemcomposer.createDictionary(dictFile);

    % PowerSignal — abstract power flow; no Voltage/Current at functional level
    powerSignalIface = addInterface(dict, "PowerSignal");
    addElement(powerSignalIface, "Power", Type="double");            % W

    % CrewInput — pilot intent; rate channels are meaningful at functional level
    crewInputIface = addInterface(dict, "CrewInput");
    addElement(crewInputIface, "RollRateCmd",  Type="double");       % deg/s
    addElement(crewInputIface, "PitchRateCmd", Type="double");       % deg/s
    addElement(crewInputIface, "YawRateCmd",   Type="double");       % deg/s

    % AircraftStateData — full aircraft state vector
    aircraftStateIface = addInterface(dict, "AircraftStateData");
    addElement(aircraftStateIface, "RollRate",      Type="double");  % deg/s
    addElement(aircraftStateIface, "PitchRate",     Type="double");  % deg/s
    addElement(aircraftStateIface, "YawRate",       Type="double");  % deg/s
    addElement(aircraftStateIface, "Airspeed",      Type="double");  % m/s
    addElement(aircraftStateIface, "AltitudeFt",    Type="double");  % ft
    addElement(aircraftStateIface, "AngleOfAttack", Type="double");  % deg

    % ControlCommand — abstract surface demand
    controlCmdIface = addInterface(dict, "ControlCommand");
    addElement(controlCmdIface, "Elevator",     Type="double");      % deg
    addElement(controlCmdIface, "LeftAileron",  Type="double");      % deg
    addElement(controlCmdIface, "RightAileron", Type="double");      % deg
    addElement(controlCmdIface, "Rudder",       Type="double");      % deg

    % ControlFeedback — measured surface positions (same structure as ControlCommand)
    controlFbkIface = addInterface(dict, "ControlFeedback");
    addElement(controlFbkIface, "Elevator",     Type="double");      % deg (measured)
    addElement(controlFbkIface, "LeftAileron",  Type="double");      % deg (measured)
    addElement(controlFbkIface, "RightAileron", Type="double");      % deg (measured)
    addElement(controlFbkIface, "Rudder",       Type="double");      % deg (measured)

    % SystemStatus — abstract health and maintenance information
    systemStatusIface = addInterface(dict, "SystemStatus");
    addElement(systemStatusIface, "StatusWord", Type="double");      % encoded status

    dict.save();

    % Re-fetch interfaces after save (required before use in setInterface)
    powerSignalIface   = dict.getInterface("PowerSignal");
    crewInputIface     = dict.getInterface("CrewInput");
    aircraftStateIface = dict.getInterface("AircraftStateData");
    controlCmdIface    = dict.getInterface("ControlCommand");
    controlFbkIface    = dict.getInterface("ControlFeedback");
    systemStatusIface  = dict.getInterface("SystemStatus");

    %% Functional Architecture Model

    model = systemcomposer.createModel(modelName);
    arch  = model.Architecture;
    linkDictionary(model, strrep(dictFile, '\', '/'));

    %% Functions

    senseState     = addComponent(arch, 'SenseAircraftState');
    computeCL      = addComponent(arch, 'ComputeControlLaws');
    commandSurface = addComponent(arch, 'CommandControlSurfaces');
    distPower      = addComponent(arch, 'DistributePower');
    crewInterface  = addComponent(arch, 'ProvideCrewInterface');
    monitorHealth  = addComponent(arch, 'MonitorSystemHealth');

    %% Ports

    % SenseAircraftState: receives power; outputs aircraft state vector
    addTypedPort(senseState.Architecture, 'PowerIn',          'in',  powerSignalIface);
    addTypedPort(senseState.Architecture, 'AircraftStateOut', 'out', aircraftStateIface);

    % ComputeControlLaws: receives power, crew input, aircraft state, surface feedback,
    %   and maintenance information; outputs control commands and status
    addTypedPort(computeCL.Architecture, 'PowerIn',         'in',  powerSignalIface);
    addTypedPort(computeCL.Architecture, 'CrewInputIn',     'in',  crewInputIface);
    addTypedPort(computeCL.Architecture, 'AircraftStateIn', 'in',  aircraftStateIface);
    addTypedPort(computeCL.Architecture, 'ControlFbkIn',    'in',  controlFbkIface);
    addTypedPort(computeCL.Architecture, 'MaintenanceIn',   'in',  systemStatusIface);
    addTypedPort(computeCL.Architecture, 'ControlCmdOut',   'out', controlCmdIface);
    addTypedPort(computeCL.Architecture, 'StatusOut',       'out', systemStatusIface);

    % CommandControlSurfaces: receives power and control commands; outputs surface feedback
    addTypedPort(commandSurface.Architecture, 'PowerIn',       'in',  powerSignalIface);
    addTypedPort(commandSurface.Architecture, 'ControlCmdIn',  'in',  controlCmdIface);
    addTypedPort(commandSurface.Architecture, 'ControlFbkOut', 'out', controlFbkIface);

    % DistributePower: one output rail per powered function
    addTypedPort(distPower.Architecture, 'ComputePowerOut',   'out', powerSignalIface);
    addTypedPort(distPower.Architecture, 'SensePowerOut',     'out', powerSignalIface);
    addTypedPort(distPower.Architecture, 'ActuatorPowerOut',  'out', powerSignalIface);
    addTypedPort(distPower.Architecture, 'InterfacePowerOut', 'out', powerSignalIface);

    % ProvideCrewInterface: receives power; outputs conditioned crew input
    addTypedPort(crewInterface.Architecture, 'PowerIn',      'in',  powerSignalIface);
    addTypedPort(crewInterface.Architecture, 'CrewInputOut', 'out', crewInputIface);

    % MonitorSystemHealth: receives status; outputs maintenance information
    addTypedPort(monitorHealth.Architecture, 'StatusIn',      'in',  systemStatusIface);
    addTypedPort(monitorHealth.Architecture, 'MaintenanceOut','out', systemStatusIface);

    %% Connections

    % Power distribution
    connect(distPower.getPort('ComputePowerOut'),   computeCL.getPort('PowerIn'));
    connect(distPower.getPort('SensePowerOut'),     senseState.getPort('PowerIn'));
    connect(distPower.getPort('ActuatorPowerOut'),  commandSurface.getPort('PowerIn'));
    connect(distPower.getPort('InterfacePowerOut'), crewInterface.getPort('PowerIn'));

    % Primary control loop
    connect(crewInterface.getPort('CrewInputOut'),   computeCL.getPort('CrewInputIn'));
    connect(senseState.getPort('AircraftStateOut'),  computeCL.getPort('AircraftStateIn'));
    connect(computeCL.getPort('ControlCmdOut'),      commandSurface.getPort('ControlCmdIn'));
    connect(commandSurface.getPort('ControlFbkOut'), computeCL.getPort('ControlFbkIn'));

    % Health monitoring loop
    connect(computeCL.getPort('StatusOut'),        monitorHealth.getPort('StatusIn'));
    connect(monitorHealth.getPort('MaintenanceOut'), computeCL.getPort('MaintenanceIn'));

    %% Save and open
    Simulink.BlockDiagram.arrangeSystem(modelName);
    save_system(char(modelName), char(fullfile(archDir, modelName)));
    open_system(char(modelName));

    fprintf('FCS functional model created: %s\n', modelName);
    fprintf('Interfaces (logical): PowerSignal, CrewInput, AircraftStateData,\n');
    fprintf('                      ControlCommand, ControlFeedback, SystemStatus\n');
    fprintf('Functions: SenseAircraftState, ComputeControlLaws, CommandControlSurfaces,\n');
    fprintf('           DistributePower, ProvideCrewInterface, MonitorSystemHealth\n');

    %% Register with project
    registerWithProject({dictFile, slxFile});
end

% ── Helper ───────────────────────────────────────────────────────────────────

function addTypedPort(compArch, name, direction, iface)
    port = addPort(compArch, name, direction);
    port.setInterface(iface);
end
