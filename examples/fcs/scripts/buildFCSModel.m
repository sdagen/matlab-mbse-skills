function buildFCSModel()
% buildFCSModel  Build the FCS System Composer physical architecture model
%                and apply the FCSBudget stereotype profile.
%
%   Components:
%     FlightComputer  — primary control law computation (dual-redundant)
%     PilotInterface  — sidestick, rudder pedals, trim controls
%     SensorSuite     — IMU, air data computer, GPS/navigation
%     ActuatorSystem  — elevator, aileron, rudder, spoiler actuators
%     PowerSystem     — primary, secondary, and emergency power buses
%     DataBus         — ARINC 429 backbone; maintenance interface
%
%   Interfaces (all elements typed as double; units in comments):
%     ElectricalPower    — Voltage (V), Current (A)
%     PilotCommand       — RollRateCmd, PitchRateCmd, YawRateCmd (deg/s)
%     SensorData         — RollRate, PitchRate, YawRate (deg/s);
%                          Airspeed (m/s); AltitudeFt (ft); AngleOfAttack (deg)
%     ControlSurfaceCmd  — Elevator, LeftAileron, RightAileron, Rudder (deg)
%     ControlSurfaceFbk  — same elements as Cmd; actual measured positions (deg)
%     DataBusMsg         — Data (double); simplified ARINC 429 message
%
%   Profile (FCSBudget.xml):
%     Stereotype: BudgetProperties
%     Properties: PowerBudget_W, PowerEstimate_W, PowerMargin_W, Mass_kg
%     Applied to all 6 components with initial per-component estimates.

    fcsDir    = fileparts(fileparts(mfilename('fullpath')));
    archDir   = fullfile(fcsDir, 'architecture');
    modelName = "FCSSystem";
    dictFile  = fullfile(archDir, "FCSInterfaces.sldd");

    %% Interface Dictionary

    % Always close all open dictionaries before creating a new one.
    % A stale link file loaded in a prior step may have auto-opened a
    % same-named dictionary from a different workspace, which would block
    % systemcomposer.createDictionary even if dictFile itself is new.
    if bdIsLoaded(modelName), close_system(modelName, 0); end
    Simulink.data.dictionary.closeAll("-discard");
    if isfile(dictFile), delete(dictFile); end
    % Remove any existing .slx so createModel does not warn about shadowing
    slxFile = fullfile(archDir, char(modelName) + ".slx");
    if isfile(slxFile), delete(slxFile); end
    dict = systemcomposer.createDictionary(dictFile);

    % Interfaces — all elements typed as double; units documented in comments

    elecPowerIface = addInterface(dict, "ElectricalPower");
    addElement(elecPowerIface, "Voltage", Type="double");       % V
    addElement(elecPowerIface, "Current", Type="double");       % A

    pilotCmdIface = addInterface(dict, "PilotCommand");
    addElement(pilotCmdIface, "RollRateCmd",  Type="double");   % deg/s
    addElement(pilotCmdIface, "PitchRateCmd", Type="double");   % deg/s
    addElement(pilotCmdIface, "YawRateCmd",   Type="double");   % deg/s

    sensorDataIface = addInterface(dict, "SensorData");
    addElement(sensorDataIface, "RollRate",      Type="double");   % deg/s
    addElement(sensorDataIface, "PitchRate",     Type="double");   % deg/s
    addElement(sensorDataIface, "YawRate",       Type="double");   % deg/s
    addElement(sensorDataIface, "Airspeed",      Type="double");   % m/s
    addElement(sensorDataIface, "AltitudeFt",    Type="double");   % ft
    addElement(sensorDataIface, "AngleOfAttack", Type="double");   % deg

    ctrlSurfCmdIface = addInterface(dict, "ControlSurfaceCmd");
    addElement(ctrlSurfCmdIface, "Elevator",     Type="double");   % deg
    addElement(ctrlSurfCmdIface, "LeftAileron",  Type="double");   % deg
    addElement(ctrlSurfCmdIface, "RightAileron", Type="double");   % deg
    addElement(ctrlSurfCmdIface, "Rudder",       Type="double");   % deg

    ctrlSurfFbkIface = addInterface(dict, "ControlSurfaceFbk");
    addElement(ctrlSurfFbkIface, "Elevator",     Type="double");   % deg (measured)
    addElement(ctrlSurfFbkIface, "LeftAileron",  Type="double");   % deg (measured)
    addElement(ctrlSurfFbkIface, "RightAileron", Type="double");   % deg (measured)
    addElement(ctrlSurfFbkIface, "Rudder",       Type="double");   % deg (measured)

    dataBusMsgIface = addInterface(dict, "DataBusMsg");
    addElement(dataBusMsgIface, "Data", Type="double");            % ARINC 429 word

    dict.save();

    elecPowerIface   = dict.getInterface("ElectricalPower");
    pilotCmdIface    = dict.getInterface("PilotCommand");
    sensorDataIface  = dict.getInterface("SensorData");
    ctrlSurfCmdIface = dict.getInterface("ControlSurfaceCmd");
    ctrlSurfFbkIface = dict.getInterface("ControlSurfaceFbk");
    dataBusMsgIface  = dict.getInterface("DataBusMsg");

    %% Architecture Model

    % Add architecture folder to path so linkDictionary can locate the dict
    % by filename (in addition to the full path we provide).
    addpath(archDir);
    model = systemcomposer.createModel(modelName);
    arch  = model.Architecture;
    linkDictionary(model, strrep(dictFile, '\', '/'));

    %% Components

    flightComputer = addComponent(arch, "FlightComputer");
    pilotInterface = addComponent(arch, "PilotInterface");
    sensorSuite    = addComponent(arch, "SensorSuite");
    actuatorSystem = addComponent(arch, "ActuatorSystem");
    powerSystem    = addComponent(arch, "PowerSystem");
    dataBus        = addComponent(arch, "DataBus");

    %% Ports

    % FlightComputer: receives power, pilot commands, sensor data, surface
    %   feedback, and maintenance messages; outputs surface commands and status
    addTypedPort(flightComputer.Architecture, "ElecPowerIn",      "in",  elecPowerIface);
    addTypedPort(flightComputer.Architecture, "PilotCmdIn",       "in",  pilotCmdIface);
    addTypedPort(flightComputer.Architecture, "SensorDataIn",     "in",  sensorDataIface);
    addTypedPort(flightComputer.Architecture, "CtrlSurfFbkIn",    "in",  ctrlSurfFbkIface);
    addTypedPort(flightComputer.Architecture, "MaintenanceMsgIn", "in",  dataBusMsgIface);
    addTypedPort(flightComputer.Architecture, "CtrlSurfCmdOut",   "out", ctrlSurfCmdIface);
    addTypedPort(flightComputer.Architecture, "StatusMsgOut",     "out", dataBusMsgIface);

    % PilotInterface: receives power; outputs pilot commands
    addTypedPort(pilotInterface.Architecture, "ElecPowerIn", "in",  elecPowerIface);
    addTypedPort(pilotInterface.Architecture, "PilotCmdOut", "out", pilotCmdIface);

    % SensorSuite: receives power; outputs sensor data
    addTypedPort(sensorSuite.Architecture, "ElecPowerIn",   "in",  elecPowerIface);
    addTypedPort(sensorSuite.Architecture, "SensorDataOut", "out", sensorDataIface);

    % ActuatorSystem: receives power and surface commands; outputs surface feedback
    addTypedPort(actuatorSystem.Architecture, "ElecPowerIn",    "in",  elecPowerIface);
    addTypedPort(actuatorSystem.Architecture, "CtrlSurfCmdIn",  "in",  ctrlSurfCmdIface);
    addTypedPort(actuatorSystem.Architecture, "CtrlSurfFbkOut", "out", ctrlSurfFbkIface);

    % PowerSystem: four independent outputs — one per powered subsystem
    addTypedPort(powerSystem.Architecture, "FlightComputerPwrOut", "out", elecPowerIface);
    addTypedPort(powerSystem.Architecture, "ActuatorPwrOut",       "out", elecPowerIface);
    addTypedPort(powerSystem.Architecture, "SensorPwrOut",         "out", elecPowerIface);
    addTypedPort(powerSystem.Architecture, "InterfacePwrOut",      "out", elecPowerIface);

    % DataBus: receives status from FlightComputer; outputs maintenance messages
    addTypedPort(dataBus.Architecture, "StatusMsgIn",       "in",  dataBusMsgIface);
    addTypedPort(dataBus.Architecture, "MaintenanceMsgOut", "out", dataBusMsgIface);

    %% Connections

    % Power distribution
    connect(powerSystem.getPort("FlightComputerPwrOut"), flightComputer.getPort("ElecPowerIn"));
    connect(powerSystem.getPort("ActuatorPwrOut"),       actuatorSystem.getPort("ElecPowerIn"));
    connect(powerSystem.getPort("SensorPwrOut"),         sensorSuite.getPort("ElecPowerIn"));
    connect(powerSystem.getPort("InterfacePwrOut"),      pilotInterface.getPort("ElecPowerIn"));

    % Pilot commands
    connect(pilotInterface.getPort("PilotCmdOut"),    flightComputer.getPort("PilotCmdIn"));

    % Sensor data
    connect(sensorSuite.getPort("SensorDataOut"),     flightComputer.getPort("SensorDataIn"));

    % Control surface command and feedback loop
    connect(flightComputer.getPort("CtrlSurfCmdOut"), actuatorSystem.getPort("CtrlSurfCmdIn"));
    connect(actuatorSystem.getPort("CtrlSurfFbkOut"), flightComputer.getPort("CtrlSurfFbkIn"));

    % Data bus (status reporting and maintenance)
    connect(flightComputer.getPort("StatusMsgOut"),    dataBus.getPort("StatusMsgIn"));
    connect(dataBus.getPort("MaintenanceMsgOut"),      flightComputer.getPort("MaintenanceMsgIn"));

    %% Layout
    Simulink.BlockDiagram.arrangeSystem(modelName);

    %% Budget Profile

    profileName = 'FCSBudget';
    profileFile = fullfile(archDir, [profileName, '.xml']);

    systemcomposer.profile.Profile.closeAll();
    if isfile(profileFile), delete(profileFile); end
    if isfolder(profileFile), rmdir(profileFile, 's'); end   % clean up old bad saves

    profile = systemcomposer.profile.Profile.createProfile(profileName);
    st = addStereotype(profile, 'BudgetProperties', AppliesTo="Component");
    addProperty(st, 'PowerBudget_W',   Type="double", Units="W",  DefaultValue="0");
    addProperty(st, 'PowerEstimate_W', Type="double", Units="W",  DefaultValue="0");
    addProperty(st, 'PowerMargin_W',   Type="double", Units="W",  DefaultValue="0");
    addProperty(st, 'Mass_kg',         Type="double", Units="kg", DefaultValue="0");

    % Pass FOLDER to profile.save — passing a .xml file path creates a directory
    profile.save(archDir);

    applyProfile(model, profileName);

    %              Component            PowerBudget_W  PowerEstimate_W  Mass_kg
    budgets = {
        'FlightComputer',  150,  120,   3.5;
        'PilotInterface',   20,   15,   2.0;
        'SensorSuite',      50,   45,   4.0;
        'ActuatorSystem',  200,  180,  15.0;
        'PowerSystem',      50,   40,   8.0;
        'DataBus',          10,    8,   0.5;
    };

    prefix = [profileName, '.BudgetProperties.'];
    for i = 1:size(budgets, 1)
        comp = arch.getComponent(budgets{i, 1});
        applyStereotype(comp, [profileName, '.BudgetProperties']);
        setProperty(comp, [prefix, 'PowerBudget_W'],   num2str(budgets{i, 2}));
        setProperty(comp, [prefix, 'PowerEstimate_W'], num2str(budgets{i, 3}));
        setProperty(comp, [prefix, 'Mass_kg'],         num2str(budgets{i, 4}));
    end

    %% Save and open
    slxPath = fullfile(archDir, modelName);
    save_system(char(modelName), char(slxPath));
    open_system(char(modelName));   % show the System Composer editor

    fprintf('FCS physical model:  %s  (%d components, %d interfaces)\n', ...
        modelName, numel(arch.Components), numel(arch.Connectors));
    fprintf('Budget profile:      %s  (%d components)\n', profileName, size(budgets, 1));

    %% Register with project
    registerWithProject({dictFile, slxFile, profileFile});
end

% ── Helpers ──────────────────────────────────────────────────────────────────

function addTypedPort(compArch, name, direction, iface)
    port = addPort(compArch, name, direction);
    port.setInterface(iface);
end
