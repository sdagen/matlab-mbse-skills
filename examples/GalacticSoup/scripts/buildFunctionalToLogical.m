function buildFunctionalToLogical()
% BUILDFUNCTIONALTOLOGICAL Allocate functions to logical elements.
%   Idempotent — closes and recreates the allocation set file on every run.

    proj      = currentProject();
    archDir   = fullfile(proj.RootFolder, 'architecture');
    allocFile = fullfile(archDir, 'GalacticSoupFunctionalToLogical.mldatx');

    systemcomposer.allocation.AllocationSet.closeAll();
    bdclose('all');
    Simulink.data.dictionary.closeAll("-discard");
    if isfile(allocFile), delete(allocFile); end

    addpath(archDir);

    [~, allocBase] = fileparts(char(allocFile));
    allocSet = systemcomposer.allocation.createAllocationSet( ...
        [allocBase, 'Set'], 'GalacticSoupFunctional', 'GalacticSoupLogical');

    funcModel = systemcomposer.openModel('GalacticSoupFunctional');
    logModel  = systemcomposer.openModel('GalacticSoupLogical');
    funcArch  = funcModel.Architecture;
    logArch   = logModel.Architecture;
    cookFunc  = funcArch.getComponent('CookSoup').Architecture;
    cookLog   = logArch.getComponent('CookingUnit').Architecture;
    scenario = createScenario(allocSet, 'FunctionalToLogical');

    % Top-level mapping
    topMap = {
        'StoreIngredients',      'StorageUnit';
        'DispenseIngredients',   'DispensingUnit';
        'ProcessProduce',        'PrepProcessor';
        'PortionIngredients',    'PortioningUnit';
        'CookSoup',              'CookingUnit';
        'InspectQuality',        'QualitySensingUnit';
        'PackageSoup',           'PackagingUnit';
        'ShipSoup',              'ShippingUnit';
        'TrackInventory',        'InventoryTracker';
        'MonitorEnvironment',    'EnvironmentSensor';
        'OrchestrateOperations', 'ControlUnit';
    };
    for i = 1:size(topMap,1)
        allocate(scenario, funcArch.getComponent(topMap{i,1}), logArch.getComponent(topMap{i,2}));
    end

    % CookSoup sub-function -> CookingUnit sub-role
    subMap = {
        'ApplyHeat',       'HeatingElement';
        'ControlHeating',  'HeatingController';
        'StirContents',    'StirringMechanism';
        'ExecuteRecipe',   'RecipeExecutor';
    };
    for i = 1:size(subMap,1)
        allocate(scenario, cookFunc.getComponent(subMap{i,1}), cookLog.getComponent(subMap{i,2}));
    end

    save(allocSet, allocFile);

    fprintf('F->L allocations: %d top + %d sub = %d total\n', ...
        size(topMap,1), size(subMap,1), size(topMap,1)+size(subMap,1));

    registerWithProject({allocFile});
end
