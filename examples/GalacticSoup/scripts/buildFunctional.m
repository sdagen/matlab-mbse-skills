function buildFunctional()
% BUILDFUNCTIONAL Build the GalacticSoup functional architecture.
%   Idempotent: recreates the functional interface dictionary and model on each run.
%   Includes decomposition of CookSoup into 4 sub-functions (ApplyHeat,
%   ControlHeating, StirContents, ExecuteRecipe).

    proj    = currentProject();
    archDir = fullfile(proj.RootFolder, 'architecture');

    modelName = "GalacticSoupFunctional";
    dictFile  = fullfile(archDir, "GalacticSoupFunctionalInterfaces.sldd");
    slxFile   = fullfile(archDir, char(modelName) + ".slx");

    if bdIsLoaded(modelName), close_system(modelName, 0); end
    Simulink.data.dictionary.closeAll("-discard");
    if isfile(dictFile), delete(dictFile); end
    if isfile(slxFile),  delete(slxFile);  end

    addpath(archDir);

    %% Interface dictionary (abstract — no physical units)
    dict = systemcomposer.createDictionary(char(dictFile));
    ifaces = {
      'RecipeCommand',           {{'recipeId','string'},{'batchSize','double'}}
      'RawIngredients',          {{'items','string'}}
      'PreparedProduce',         {{'items','string'}}
      'PortionedIngredients',    {{'items','string'}}
      'CookedSoup',              {{'batchId','string'},{'volume','double'}}
      'InspectedSoup',           {{'batchId','string'},{'qualityStatus','string'}}
      'PackagedBatch',           {{'batchId','string'},{'containerCount','double'},{'destination','string'}}
      'Manifest',                {{'batchId','string'},{'destination','string'},{'timestamp','string'}}
      'InventoryState',          {{'stockLevels','string'}}
      'EnvironmentState',        {{'ambientGravity','double'},{'ambientConditions','string'}}
      'SystemStatus',            {{'componentStates','string'}}
      % CookSoup internal interfaces
      'HeatSetpoint',            {{'targetTemp','double'}}
      'StirCommand',             {{'speed','double'},{'cadence','double'}}
      'HeatCommand',             {{'power','double'}}
      'Temperature',             {{'value','double'}}
    };
    for i = 1:size(ifaces,1)
        iface = addInterface(dict, ifaces{i,1});
        fields = ifaces{i,2};
        for j = 1:numel(fields)
            addElement(iface, fields{j}{1}, Type=fields{j}{2});
        end
    end
    dict.save();

    %% Model + top-level components
    model = systemcomposer.createModel(modelName);
    arch  = model.Architecture;
    linkDictionary(model, strrep(char(dictFile), '\', '/'));

    functionNames = {
        'StoreIngredients','DispenseIngredients','ProcessProduce','PortionIngredients', ...
        'CookSoup','InspectQuality','PackageSoup','ShipSoup', ...
        'TrackInventory','MonitorEnvironment','OrchestrateOperations'};
    comps = containers.Map;
    for i = 1:numel(functionNames)
        comps(functionNames{i}) = addComponent(arch, functionNames{i});
    end

    %% Top-level connections
    conns = {
      'OrchestrateOperations','RecipeStore',   'StoreIngredients',    'RecipeIn',     'RecipeCommand'
      'OrchestrateOperations','RecipeDisp',    'DispenseIngredients', 'RecipeIn',     'RecipeCommand'
      'OrchestrateOperations','RecipeProc',    'ProcessProduce',      'RecipeIn',     'RecipeCommand'
      'OrchestrateOperations','RecipePort',    'PortionIngredients',  'RecipeIn',     'RecipeCommand'
      'OrchestrateOperations','RecipeCook',    'CookSoup',            'RecipeIn',     'RecipeCommand'
      'OrchestrateOperations','RecipePkg',     'PackageSoup',         'RecipeIn',     'RecipeCommand'
      'OrchestrateOperations','RecipeShip',    'ShipSoup',            'RecipeIn',     'RecipeCommand'
      'StoreIngredients',    'RawOut',         'DispenseIngredients', 'RawIn',        'RawIngredients'
      'DispenseIngredients', 'ToProcess',      'ProcessProduce',      'RawIn',        'RawIngredients'
      'DispenseIngredients', 'ToPortion',      'PortionIngredients',  'RawIn',        'RawIngredients'
      'ProcessProduce',      'PreparedOut',    'CookSoup',            'PreparedIn',   'PreparedProduce'
      'PortionIngredients',  'PortionsOut',    'CookSoup',            'PortionsIn',   'PortionedIngredients'
      'CookSoup',            'CookedOut',      'InspectQuality',      'CookedIn',     'CookedSoup'
      'InspectQuality',      'InspectedOut',   'PackageSoup',         'InspectedIn',  'InspectedSoup'
      'PackageSoup',         'PackagedOut',    'ShipSoup',            'PackagedIn',   'PackagedBatch'
      'ShipSoup',            'ManifestOut',    'OrchestrateOperations','ManifestIn',  'Manifest'
      'StoreIngredients',    'InvOut',         'TrackInventory',      'InvIn',        'InventoryState'
      'TrackInventory',      'InvReport',      'OrchestrateOperations','InvIn',       'InventoryState'
      'MonitorEnvironment',  'EnvOrch',        'OrchestrateOperations','EnvIn',       'EnvironmentState'
      'MonitorEnvironment',  'EnvProc',        'ProcessProduce',      'EnvIn',        'EnvironmentState'
      'MonitorEnvironment',  'EnvPort',        'PortionIngredients',  'EnvIn',        'EnvironmentState'
      'MonitorEnvironment',  'EnvCook',        'CookSoup',            'EnvIn',        'EnvironmentState'
      'MonitorEnvironment',  'EnvPkg',         'PackageSoup',         'EnvIn',        'EnvironmentState'
    };

    outerCache = containers.Map;  % outside-facing ComponentPort for connect()
    innerCache = containers.Map;  % inside-boundary ArchitecturePort for internal wiring
    for i = 1:size(conns,1)
        [sp, ~] = getOrAddPort(outerCache, innerCache, comps(conns{i,1}), conns{i,2}, 'out', dict.getInterface(conns{i,5}));
        [dp, ~] = getOrAddPort(outerCache, innerCache, comps(conns{i,3}), conns{i,4}, 'in',  dict.getInterface(conns{i,5}));
        connect(sp, dp);
    end

    %% Decompose CookSoup into sub-functions
    cookArch = comps('CookSoup').Architecture;
    subNames = {'ApplyHeat','ControlHeating','StirContents','ExecuteRecipe'};
    subs = containers.Map;
    for i = 1:numel(subNames)
        subs(subNames{i}) = addComponent(cookArch, subNames{i});
    end

    % Retrieve CookSoup boundary inner ports (reverse-direction sources/sinks inside)
    [~, recipeInInner]   = getOrAddPort(outerCache, innerCache, comps('CookSoup'), 'RecipeIn',   'in',  dict.getInterface('RecipeCommand'));
    [~, preparedInInner] = getOrAddPort(outerCache, innerCache, comps('CookSoup'), 'PreparedIn', 'in',  dict.getInterface('PreparedProduce'));
    [~, portionsInInner] = getOrAddPort(outerCache, innerCache, comps('CookSoup'), 'PortionsIn', 'in',  dict.getInterface('PortionedIngredients'));
    [~, envInInner]      = getOrAddPort(outerCache, innerCache, comps('CookSoup'), 'EnvIn',      'in',  dict.getInterface('EnvironmentState'));
    [~, cookedOutInner]  = getOrAddPort(outerCache, innerCache, comps('CookSoup'), 'CookedOut',  'out', dict.getInterface('CookedSoup'));

    % Sub-component ports and internal connections
    innerConns = {
      % srcName         srcPort     dstName           dstPort     interface          special
      '<boundary>','RecipeIn',   'ExecuteRecipe','RecipeIn',    'RecipeCommand',        'boundaryIn'
      '<boundary>','PreparedIn', 'ExecuteRecipe','PreparedIn',  'PreparedProduce',      'boundaryIn'
      '<boundary>','PortionsIn', 'ExecuteRecipe','PortionsIn',  'PortionedIngredients', 'boundaryIn'
      '<boundary>','EnvIn',      'ControlHeating','EnvIn',      'EnvironmentState',     'boundaryIn'
      'ExecuteRecipe','HeatCmdOut', 'ControlHeating','HeatSetpointIn', 'HeatSetpoint',  ''
      'ExecuteRecipe','StirCmdOut', 'StirContents',  'StirCmdIn',      'StirCommand',   ''
      'ControlHeating','HeatOut',   'ApplyHeat',     'HeatCmdIn',      'HeatCommand',   ''
      'ApplyHeat',     'TempOut',   'ControlHeating','TempIn',         'Temperature',   ''
      'ExecuteRecipe','CookedOut',  '<boundary>','CookedOut',      'CookedSoup',        'boundaryOut'
    };

    boundaryIn  = containers.Map('KeyType','char','ValueType','any');
    boundaryIn('RecipeIn')   = recipeInInner;
    boundaryIn('PreparedIn') = preparedInInner;
    boundaryIn('PortionsIn') = portionsInInner;
    boundaryIn('EnvIn')      = envInInner;
    boundaryOut = containers.Map('KeyType','char','ValueType','any');
    boundaryOut('CookedOut') = cookedOutInner;

    subOuterCache = containers.Map;
    subInnerCache = containers.Map;
    for i = 1:size(innerConns,1)
        ifName = innerConns{i,5};
        special = innerConns{i,6};
        if strcmp(special,'boundaryIn')
            sp = boundaryIn(innerConns{i,2});  % CookSoup 'in' boundary acts as source inside
            [dp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,3}), innerConns{i,4}, 'in', dict.getInterface(ifName));
        elseif strcmp(special,'boundaryOut')
            [sp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,1}), innerConns{i,2}, 'out', dict.getInterface(ifName));
            dp = boundaryOut(innerConns{i,4});  % CookSoup 'out' boundary acts as sink inside
        else
            [sp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,1}), innerConns{i,2}, 'out', dict.getInterface(ifName));
            [dp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,3}), innerConns{i,4}, 'in',  dict.getInterface(ifName));
        end
        connect(sp, dp);
    end

    Simulink.BlockDiagram.arrangeSystem(char(modelName));
    Simulink.BlockDiagram.arrangeSystem([char(modelName) '/CookSoup']);
    save_system(char(modelName), char(fullfile(archDir, modelName)));

    fprintf('Top-level functions : %d\n', numel(functionNames));
    fprintf('CookSoup sub-funcs  : %d\n', numel(subNames));
    fprintf('Interfaces          : %d\n', size(ifaces,1));
    fprintf('Top-level connections: %d\n', size(conns,1));
    fprintf('CookSoup inner conns : %d\n', size(innerConns,1));

    registerWithProject({slxFile, char(dictFile)});
end

function [outer, inner] = getOrAddPort(outerCache, innerCache, comp, name, dir, iface)
    key = sprintf('%s|%s|%s', comp.Name, name, dir);
    if isKey(outerCache, key)
        outer = outerCache(key);
        inner = innerCache(key);
        return;
    end
    inner = addPort(comp.Architecture, name, dir);
    inner.setInterface(iface);
    outer = comp.getPort(name);
    outerCache(key) = outer;
    innerCache(key) = inner;
end
