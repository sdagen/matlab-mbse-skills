function buildFCSFunctional()
% buildFCSFunctional  Create the FCS functional architecture model.
%
%   Generates:
%     FCSFunctional.slx  — logical functions of the Flight Control System,
%                          independent of physical implementation.
%
%   Six functions and their roles:
%
%     SenseAircraftState    — acquire roll/pitch/yaw rates, airspeed,
%                             altitude, and angle of attack from sensors
%     ComputeControlLaws    — compute control surface commands from pilot
%                             inputs and aircraft state; dual-redundant
%     CommandControlSurfaces— drive actuators to commanded positions and
%                             report measured surface feedback
%     DistributePower       — regulate and route electrical power to all
%                             other functions
%     ProvideCrewInterface  — acquire and condition pilot inceptor inputs
%                             (sidestick, rudder pedals, trim)
%     MonitorSystemHealth   — BITE, fault detection, and maintenance bus
%
%   Interfaces are taken from the shared FCSInterfaces.sldd dictionary.
%   Prerequisite: run buildFCSModel() first (creates the dictionary).

    fcsDir    = fileparts(fileparts(mfilename('fullpath')));
    archDir   = fullfile(fcsDir, 'architecture');
    modelName = "FCSFunctional";
    dictFile  = fullfile(archDir, 'FCSInterfaces.sldd');

    %% Open the shared interface dictionary via the physical model
    % (FCSSystem is already in memory from buildFCSProfile)
    addpath(archDir);
    physModel = systemcomposer.openModel('FCSSystem');
    dict = physModel.InterfaceDictionary;
    elecPowerIface   = dict.getInterface('ElectricalPower');
    pilotCmdIface    = dict.getInterface('PilotCommand');
    sensorDataIface  = dict.getInterface('SensorData');
    ctrlSurfCmdIface = dict.getInterface('ControlSurfaceCmd');
    ctrlSurfFbkIface = dict.getInterface('ControlSurfaceFbk');
    dataBusMsgIface  = dict.getInterface('DataBusMsg');

    %% Create model (clean slate each run)
    if bdIsLoaded(modelName), close_system(modelName, 0); end
    slxFile = fullfile(archDir, char(modelName) + ".slx");
    if isfile(slxFile), delete(slxFile); end
    model = systemcomposer.createModel(modelName);
    arch  = model.Architecture;
    linkDictionary(model, strrep(dictFile, '\', '/'));

    %% Functional components

    senseState     = addComponent(arch, 'SenseAircraftState');
    computeCL      = addComponent(arch, 'ComputeControlLaws');
    commandSurface = addComponent(arch, 'CommandControlSurfaces');
    distPower      = addComponent(arch, 'DistributePower');
    crewInterface  = addComponent(arch, 'ProvideCrewInterface');
    monitorHealth  = addComponent(arch, 'MonitorSystemHealth');

    %% Ports

    % SenseAircraftState: powered; outputs aircraft state vector
    addTypedPort(senseState.Architecture, 'ElecPowerIn',    'in',  elecPowerIface);
    addTypedPort(senseState.Architecture, 'SensorDataOut',  'out', sensorDataIface);

    % ComputeControlLaws: powered; processes pilot commands + state;
    %   outputs surface commands, receives feedback and maintenance messages
    addTypedPort(computeCL.Architecture, 'ElecPowerIn',      'in',  elecPowerIface);
    addTypedPort(computeCL.Architecture, 'PilotCmdIn',       'in',  pilotCmdIface);
    addTypedPort(computeCL.Architecture, 'SensorDataIn',     'in',  sensorDataIface);
    addTypedPort(computeCL.Architecture, 'CtrlSurfFbkIn',    'in',  ctrlSurfFbkIface);
    addTypedPort(computeCL.Architecture, 'MaintenanceMsgIn', 'in',  dataBusMsgIface);
    addTypedPort(computeCL.Architecture, 'CtrlSurfCmdOut',   'out', ctrlSurfCmdIface);
    addTypedPort(computeCL.Architecture, 'StatusMsgOut',     'out', dataBusMsgIface);

    % CommandControlSurfaces: powered; drives actuators and reports positions
    addTypedPort(commandSurface.Architecture, 'ElecPowerIn',    'in',  elecPowerIface);
    addTypedPort(commandSurface.Architecture, 'CtrlSurfCmdIn',  'in',  ctrlSurfCmdIface);
    addTypedPort(commandSurface.Architecture, 'CtrlSurfFbkOut', 'out', ctrlSurfFbkIface);

    % DistributePower: four independent output rails
    addTypedPort(distPower.Architecture, 'ComputePwrOut',   'out', elecPowerIface);
    addTypedPort(distPower.Architecture, 'SensePwrOut',     'out', elecPowerIface);
    addTypedPort(distPower.Architecture, 'SurfacePwrOut',   'out', elecPowerIface);
    addTypedPort(distPower.Architecture, 'InterfacePwrOut', 'out', elecPowerIface);

    % ProvideCrewInterface: powered; captures and conditions inceptor inputs
    addTypedPort(crewInterface.Architecture, 'ElecPowerIn', 'in',  elecPowerIface);
    addTypedPort(crewInterface.Architecture, 'PilotCmdOut', 'out', pilotCmdIface);

    % MonitorSystemHealth: receives status; outputs maintenance messages
    addTypedPort(monitorHealth.Architecture, 'StatusMsgIn',       'in',  dataBusMsgIface);
    addTypedPort(monitorHealth.Architecture, 'MaintenanceMsgOut', 'out', dataBusMsgIface);

    %% Connections

    % Power rails to each function
    connect(distPower.getPort('ComputePwrOut'),   computeCL.getPort('ElecPowerIn'));
    connect(distPower.getPort('SensePwrOut'),     senseState.getPort('ElecPowerIn'));
    connect(distPower.getPort('SurfacePwrOut'),   commandSurface.getPort('ElecPowerIn'));
    connect(distPower.getPort('InterfacePwrOut'), crewInterface.getPort('ElecPowerIn'));

    % Primary control loop
    connect(crewInterface.getPort('PilotCmdOut'),      computeCL.getPort('PilotCmdIn'));
    connect(senseState.getPort('SensorDataOut'),       computeCL.getPort('SensorDataIn'));
    connect(computeCL.getPort('CtrlSurfCmdOut'),       commandSurface.getPort('CtrlSurfCmdIn'));
    connect(commandSurface.getPort('CtrlSurfFbkOut'),  computeCL.getPort('CtrlSurfFbkIn'));

    % Health monitoring loop
    connect(computeCL.getPort('StatusMsgOut'),          monitorHealth.getPort('StatusMsgIn'));
    connect(monitorHealth.getPort('MaintenanceMsgOut'), computeCL.getPort('MaintenanceMsgIn'));

    %% Save
    Simulink.BlockDiagram.arrangeSystem(modelName);
    slxPath = fullfile(archDir, modelName);
    save_system(char(modelName), char(slxPath));
    fprintf('FCS functional model created: %s\n', modelName);
    fprintf('Functions: SenseAircraftState, ComputeControlLaws, CommandControlSurfaces,\n');
    fprintf('           DistributePower, ProvideCrewInterface, MonitorSystemHealth\n');
end

% ── Helper ───────────────────────────────────────────────────────────────────

function addTypedPort(compArch, name, direction, iface)
    port = addPort(compArch, name, direction);
    port.setInterface(iface);
end
