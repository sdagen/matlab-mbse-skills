function buildLogical()
% BUILDLOGICAL Build the GalacticSoup logical architecture.
%   Idempotent. Mirrors the functional topology with design-agnostic solution
%   role names, and decomposes CookingUnit into HeatingElement, HeatingController,
%   StirringMechanism, and RecipeExecutor.

    proj    = currentProject();
    archDir = fullfile(proj.RootFolder, 'architecture');

    modelName = "GalacticSoupLogical";
    dictFile  = fullfile(archDir, "GalacticSoupLogicalInterfaces.sldd");
    slxFile   = fullfile(archDir, char(modelName) + ".slx");

    if bdIsLoaded(modelName), close_system(modelName, 0); end
    Simulink.data.dictionary.closeAll("-discard");
    if isfile(dictFile), delete(dictFile); end
    if isfile(slxFile),  delete(slxFile);  end

    addpath(archDir);

    %% Interface dictionary (intermediate-level — typed, no datasheet specifics)
    dict = systemcomposer.createDictionary(char(dictFile));
    ifaces = {
      'RecipeCommand',        {{'recipeId','string'},{'batchSize','double'},{'priority','double'}}
      'RawIngredients',       {{'items','string'},{'quantities','double'}}
      'PreparedProduce',      {{'items','string'},{'cutSize','double'}}
      'PortionedIngredients', {{'items','string'},{'masses','double'}}
      'CookedSoup',           {{'batchId','string'},{'volume','double'},{'temperature','double'}}
      'InspectedSoup',        {{'batchId','string'},{'qualityStatus','string'},{'contamLevel','double'},{'temperature','double'}}
      'PackagedBatch',        {{'batchId','string'},{'containerCount','double'},{'destination','string'},{'sealStatus','string'}}
      'Manifest',             {{'batchId','string'},{'destination','string'},{'timestamp','string'},{'carrier','string'}}
      'InventoryState',       {{'stockLevels','string'},{'reorderFlags','string'}}
      'EnvironmentState',     {{'ambientGravity','double'},{'temperature','double'},{'humidity','double'}}
      'SystemStatus',         {{'componentStates','string'},{'alarms','string'},{'operatorLoad','double'}}
      'HeatSetpoint',         {{'targetTemp','double'}}
      'StirCommand',          {{'speed','double'},{'cadence','double'}}
      'HeatCommand',          {{'power','double'}}
      'Temperature',          {{'value','double'}}
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

    componentNames = {
        'StorageUnit','DispensingUnit','PrepProcessor','PortioningUnit', ...
        'CookingUnit','QualitySensingUnit','PackagingUnit','ShippingUnit', ...
        'InventoryTracker','EnvironmentSensor','ControlUnit'};
    comps = containers.Map;
    for i = 1:numel(componentNames)
        comps(componentNames{i}) = addComponent(arch, componentNames{i});
    end

    %% Top-level connections (same topology as functional, renamed components)
    conns = {
      'ControlUnit','RecipeStore',       'StorageUnit',        'RecipeIn',    'RecipeCommand'
      'ControlUnit','RecipeDisp',        'DispensingUnit',     'RecipeIn',    'RecipeCommand'
      'ControlUnit','RecipeProc',        'PrepProcessor',      'RecipeIn',    'RecipeCommand'
      'ControlUnit','RecipePort',        'PortioningUnit',     'RecipeIn',    'RecipeCommand'
      'ControlUnit','RecipeCook',        'CookingUnit',        'RecipeIn',    'RecipeCommand'
      'ControlUnit','RecipePkg',         'PackagingUnit',      'RecipeIn',    'RecipeCommand'
      'ControlUnit','RecipeShip',        'ShippingUnit',       'RecipeIn',    'RecipeCommand'
      'StorageUnit','RawOut',            'DispensingUnit',     'RawIn',       'RawIngredients'
      'DispensingUnit','ToProcess',      'PrepProcessor',      'RawIn',       'RawIngredients'
      'DispensingUnit','ToPortion',      'PortioningUnit',     'RawIn',       'RawIngredients'
      'PrepProcessor','PreparedOut',     'CookingUnit',        'PreparedIn',  'PreparedProduce'
      'PortioningUnit','PortionsOut',    'CookingUnit',        'PortionsIn',  'PortionedIngredients'
      'CookingUnit','CookedOut',         'QualitySensingUnit', 'CookedIn',    'CookedSoup'
      'QualitySensingUnit','InspectedOut','PackagingUnit',     'InspectedIn', 'InspectedSoup'
      'PackagingUnit','PackagedOut',     'ShippingUnit',       'PackagedIn',  'PackagedBatch'
      'ShippingUnit','ManifestOut',      'ControlUnit',        'ManifestIn',  'Manifest'
      'StorageUnit','InvOut',            'InventoryTracker',   'InvIn',       'InventoryState'
      'InventoryTracker','InvReport',    'ControlUnit',        'InvIn',       'InventoryState'
      'EnvironmentSensor','EnvOrch',     'ControlUnit',        'EnvIn',       'EnvironmentState'
      'EnvironmentSensor','EnvProc',     'PrepProcessor',      'EnvIn',       'EnvironmentState'
      'EnvironmentSensor','EnvPort',     'PortioningUnit',     'EnvIn',       'EnvironmentState'
      'EnvironmentSensor','EnvCook',     'CookingUnit',        'EnvIn',       'EnvironmentState'
      'EnvironmentSensor','EnvPkg',      'PackagingUnit',      'EnvIn',       'EnvironmentState'
    };

    outerCache = containers.Map;
    innerCache = containers.Map;
    for i = 1:size(conns,1)
        [sp, ~] = getOrAddPort(outerCache, innerCache, comps(conns{i,1}), conns{i,2}, 'out', dict.getInterface(conns{i,5}));
        [dp, ~] = getOrAddPort(outerCache, innerCache, comps(conns{i,3}), conns{i,4}, 'in',  dict.getInterface(conns{i,5}));
        connect(sp, dp);
    end

    %% Decompose CookingUnit
    cookArch = comps('CookingUnit').Architecture;
    subNames = {'HeatingElement','HeatingController','StirringMechanism','RecipeExecutor'};
    subs = containers.Map;
    for i = 1:numel(subNames)
        subs(subNames{i}) = addComponent(cookArch, subNames{i});
    end

    [~, recipeInInner]   = getOrAddPort(outerCache, innerCache, comps('CookingUnit'), 'RecipeIn',   'in',  dict.getInterface('RecipeCommand'));
    [~, preparedInInner] = getOrAddPort(outerCache, innerCache, comps('CookingUnit'), 'PreparedIn', 'in',  dict.getInterface('PreparedProduce'));
    [~, portionsInInner] = getOrAddPort(outerCache, innerCache, comps('CookingUnit'), 'PortionsIn', 'in',  dict.getInterface('PortionedIngredients'));
    [~, envInInner]      = getOrAddPort(outerCache, innerCache, comps('CookingUnit'), 'EnvIn',      'in',  dict.getInterface('EnvironmentState'));
    [~, cookedOutInner]  = getOrAddPort(outerCache, innerCache, comps('CookingUnit'), 'CookedOut',  'out', dict.getInterface('CookedSoup'));

    innerConns = {
      '<boundary>','RecipeIn',     'RecipeExecutor',   'RecipeIn',       'RecipeCommand',        'boundaryIn'
      '<boundary>','PreparedIn',   'RecipeExecutor',   'PreparedIn',     'PreparedProduce',      'boundaryIn'
      '<boundary>','PortionsIn',   'RecipeExecutor',   'PortionsIn',     'PortionedIngredients', 'boundaryIn'
      '<boundary>','EnvIn',        'HeatingController','EnvIn',          'EnvironmentState',     'boundaryIn'
      'RecipeExecutor','HeatCmdOut','HeatingController','HeatSetpointIn','HeatSetpoint',         ''
      'RecipeExecutor','StirCmdOut','StirringMechanism','StirCmdIn',     'StirCommand',          ''
      'HeatingController','HeatOut','HeatingElement',  'HeatCmdIn',      'HeatCommand',          ''
      'HeatingElement','TempOut',   'HeatingController','TempIn',        'Temperature',          ''
      'RecipeExecutor','CookedOut', '<boundary>',      'CookedOut',      'CookedSoup',           'boundaryOut'
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
        ifName  = innerConns{i,5};
        special = innerConns{i,6};
        if strcmp(special,'boundaryIn')
            sp = boundaryIn(innerConns{i,2});
            [dp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,3}), innerConns{i,4}, 'in', dict.getInterface(ifName));
        elseif strcmp(special,'boundaryOut')
            [sp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,1}), innerConns{i,2}, 'out', dict.getInterface(ifName));
            dp = boundaryOut(innerConns{i,4});
        else
            [sp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,1}), innerConns{i,2}, 'out', dict.getInterface(ifName));
            [dp, ~] = getOrAddPort(subOuterCache, subInnerCache, subs(innerConns{i,3}), innerConns{i,4}, 'in',  dict.getInterface(ifName));
        end
        connect(sp, dp);
    end

    Simulink.BlockDiagram.arrangeSystem(char(modelName));
    Simulink.BlockDiagram.arrangeSystem([char(modelName) '/CookingUnit']);
    save_system(char(modelName), char(fullfile(archDir, modelName)));

    fprintf('Top-level components : %d\n', numel(componentNames));
    fprintf('CookingUnit sub-roles: %d\n', numel(subNames));
    fprintf('Interfaces           : %d\n', size(ifaces,1));
    fprintf('Top-level connections: %d\n', size(conns,1));
    fprintf('CookingUnit inner    : %d\n', size(innerConns,1));

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
