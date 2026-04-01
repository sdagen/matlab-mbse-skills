function buildFCSAllocationSet()
% buildFCSAllocationSet  Map FCS functional architecture to physical components.
%
%   Creates an allocation set that formally links each logical function in
%   FCSFunctional.slx to the physical component(s) in FCSSystem.slx that
%   implement it.  This is the functional-to-physical allocation required by
%   ARP4754A and similar development assurance frameworks.
%
%   Generates:
%     FCSAllocation.mldatx  — allocation set with scenario "FunctionalToPhysical"
%
%   Allocation mapping:
%
%     Function (FCSFunctional)       Physical component(s) (FCSSystem)
%     ─────────────────────────────────────────────────────────────────
%     SenseAircraftState         →   SensorSuite
%     ComputeControlLaws         →   FlightComputer
%     CommandControlSurfaces     →   ActuatorSystem
%     DistributePower            →   PowerSystem
%     ProvideCrewInterface       →   PilotInterface
%     MonitorSystemHealth        →   FlightComputer  (BITE + failover logic)
%                                    DataBus         (maintenance bus)
%
%   MonitorSystemHealth maps to two physical components because fault
%   detection runs on the FlightComputer (DO-178C BITE) while the
%   maintenance interface is provided by the DataBus (ARINC 604).
%
%   Prerequisites: run buildFCSFunctional() (and thus buildFCSModel()) first.

    fcsDir   = fileparts(fileparts(mfilename('fullpath')));
    archDir  = fullfile(fcsDir, 'architecture');
    allocFile = fullfile(archDir, 'FCSAllocation.mldatx');

    %% Close any open allocation sets with the same name
    systemcomposer.allocation.AllocationSet.closeAll();
    if isfile(allocFile), delete(allocFile); end

    %% Open both models (architecture dir is already on path from prior steps)
    addpath(archDir);
    funcModel = systemcomposer.openModel('FCSFunctional');
    physModel = systemcomposer.openModel('FCSSystem');
    funcArch  = funcModel.Architecture;
    physArch  = physModel.Architecture;

    %% Create allocation set: source = functional, target = physical
    % Use a distinct in-memory name ('FCSAllocationSet') so that save(allocSet, allocFile)
    % does not see a name collision: SC derives 'FCSAllocation' from the file path and
    % checks uniqueness against all registered in-memory sets.  If the in-memory name
    % were also 'FCSAllocation' the check would flag the set against itself.
    allocSet = systemcomposer.allocation.createAllocationSet(...
        'FCSAllocationSet', funcModel, physModel);

    %% Create a named scenario for this allocation
    scenario = createScenario(allocSet, 'FunctionalToPhysical');

    %% Allocate functions to physical components

    % Helper: get components by name
    function comp = fn(name)
        comp = funcArch.getComponent(name);
    end
    function comp = ph(name)
        comp = physArch.getComponent(name);
    end

    allocate(scenario, fn('SenseAircraftState'),    ph('SensorSuite'));
    allocate(scenario, fn('ComputeControlLaws'),    ph('FlightComputer'));
    allocate(scenario, fn('CommandControlSurfaces'),ph('ActuatorSystem'));
    allocate(scenario, fn('DistributePower'),       ph('PowerSystem'));
    allocate(scenario, fn('ProvideCrewInterface'),  ph('PilotInterface'));

    % MonitorSystemHealth spans two physical components
    allocate(scenario, fn('MonitorSystemHealth'),   ph('FlightComputer'));
    allocate(scenario, fn('MonitorSystemHealth'),   ph('DataBus'));

    %% Save
    save(allocSet, allocFile);
    fprintf('Allocation set saved: %s\n', allocFile);

    %% Report
    fprintf('\nFunctional-to-Physical Allocation\n');
    fprintf('%s\n', repmat('-', 1, 68));
    fprintf('%-30s  %s\n', 'Function (FCSFunctional)', 'Component(s) (FCSSystem)');
    fprintf('%s\n', repmat('-', 1, 68));

    funcComps = { 'SenseAircraftState', 'ComputeControlLaws', ...
                  'CommandControlSurfaces', 'DistributePower', ...
                  'ProvideCrewInterface',   'MonitorSystemHealth' };

    for i = 1:numel(funcComps)
        srcComp    = funcArch.getComponent(funcComps{i});
        allocated  = getAllocatedTo(scenario, srcComp);
        physNames  = cell(1, numel(allocated));
        for j = 1:numel(allocated)
            physNames{j} = allocated(j).Name;
        end
        fprintf('%-30s  %s\n', funcComps{i}, strjoin(physNames, ', '));
    end

    fprintf('\nOpen Allocation Editor: systemcomposer.allocation.editor(''%s'')\n', ...
        allocFile);

    %% Register with project
    registerWithProject({allocFile});
end
