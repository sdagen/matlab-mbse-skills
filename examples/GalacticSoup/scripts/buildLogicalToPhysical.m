function buildLogicalToPhysical()
% BUILDLOGICALTOPHYSICAL Allocate logical elements to physical components.
%   Idempotent — closes and recreates the allocation set file on every run.

    proj      = currentProject();
    archDir   = fullfile(proj.RootFolder, 'architecture');
    allocFile = fullfile(archDir, 'GalacticSoupLogicalToPhysical.mldatx');

    systemcomposer.allocation.AllocationSet.closeAll();
    bdclose('all');
    Simulink.data.dictionary.closeAll("-discard");
    if isfile(allocFile), delete(allocFile); end

    addpath(archDir);

    [~, allocBase] = fileparts(char(allocFile));
    allocSet = systemcomposer.allocation.createAllocationSet( ...
        [allocBase, 'Set'], 'GalacticSoupLogical', 'GalacticSoupPhysical');
    scenario = createScenario(allocSet, 'LogicalToPhysical');

    logModel  = systemcomposer.openModel('GalacticSoupLogical');
    physModel = systemcomposer.openModel('GalacticSoupPhysical');
    logArch   = logModel.Architecture;
    physArch  = physModel.Architecture;
    cookLog   = logArch.getComponent('CookingUnit').Architecture;
    cookPhys  = physArch.getComponent('CookingStation').Architecture;

    topMap = {
        'StorageUnit',         'CryoPantry';
        'DispensingUnit',      'AugerDispenser';
        'PrepProcessor',       'RoboPrepStation';
        'PortioningUnit',      'PrecisionScale';
        'CookingUnit',         'CookingStation';
        'QualitySensingUnit',  'QualitySensorSuite';
        'PackagingUnit',       'SealingLine';
        'ShippingUnit',        'LoaderArm';
        'InventoryTracker',    'InventoryDB';
        'EnvironmentSensor',   'GravityIMU';
        'ControlUnit',         'KitchenController';
    };
    for i = 1:size(topMap,1)
        allocate(scenario, logArch.getComponent(topMap{i,1}), physArch.getComponent(topMap{i,2}));
    end

    subMap = {
        'HeatingElement',     'InductionHeater';
        'HeatingController',  'ThermalPID';
        'StirringMechanism',  'MagneticStirrer';
        'RecipeExecutor',     'KitchenPLC';
    };
    for i = 1:size(subMap,1)
        allocate(scenario, cookLog.getComponent(subMap{i,1}), cookPhys.getComponent(subMap{i,2}));
    end

    save(allocSet, allocFile);

    fprintf('L->P allocations: %d top + %d sub = %d total\n', ...
        size(topMap,1), size(subMap,1), size(topMap,1)+size(subMap,1));

    registerWithProject({allocFile});
end
