function buildPhysical()
% BUILDPHYSICAL Build the GalacticSoup physical architecture + ComponentProperties profile.
%   Idempotent. Physical components map 1:1 to logical roles; CookingStation is
%   decomposed (InductionHeater, ThermalPID, MagneticStirrer, KitchenPLC).
%   Profile is created and applied at the end so initial estimates survive every rebuild.

    proj    = currentProject();
    archDir = fullfile(proj.RootFolder, 'architecture');

    modelName = "GalacticSoupPhysical";
    dictFile  = fullfile(archDir, "GalacticSoupPhysicalInterfaces.sldd");
    slxFile   = fullfile(archDir, char(modelName) + ".slx");

    profileName = 'GalacticSoupProfile';
    profileXml  = fullfile(archDir, [profileName, '.xml']);

    if bdIsLoaded(modelName), close_system(modelName, 0); end
    Simulink.data.dictionary.closeAll("-discard");
    systemcomposer.profile.Profile.closeAll();
    if isfile(dictFile),   delete(dictFile);   end
    if isfile(slxFile),    delete(slxFile);    end
    if isfile(profileXml), delete(profileXml); end
    if isfolder(profileXml), rmdir(profileXml, 's'); end

    addpath(archDir);

    %% Interface dictionary (implementation-level — same shape as logical)
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
        'CryoPantry','AugerDispenser','RoboPrepStation','PrecisionScale', ...
        'CookingStation','QualitySensorSuite','SealingLine','LoaderArm', ...
        'InventoryDB','GravityIMU','KitchenController'};
    comps = containers.Map;
    for i = 1:numel(componentNames)
        comps(componentNames{i}) = addComponent(arch, componentNames{i});
    end

    %% Top-level connections (same topology; renamed components)
    conns = {
      'KitchenController','RecipeStore',      'CryoPantry',         'RecipeIn',    'RecipeCommand'
      'KitchenController','RecipeDisp',       'AugerDispenser',     'RecipeIn',    'RecipeCommand'
      'KitchenController','RecipeProc',       'RoboPrepStation',    'RecipeIn',    'RecipeCommand'
      'KitchenController','RecipePort',       'PrecisionScale',     'RecipeIn',    'RecipeCommand'
      'KitchenController','RecipeCook',       'CookingStation',     'RecipeIn',    'RecipeCommand'
      'KitchenController','RecipePkg',        'SealingLine',        'RecipeIn',    'RecipeCommand'
      'KitchenController','RecipeShip',       'LoaderArm',          'RecipeIn',    'RecipeCommand'
      'CryoPantry','RawOut',                  'AugerDispenser',     'RawIn',       'RawIngredients'
      'AugerDispenser','ToProcess',           'RoboPrepStation',    'RawIn',       'RawIngredients'
      'AugerDispenser','ToPortion',           'PrecisionScale',     'RawIn',       'RawIngredients'
      'RoboPrepStation','PreparedOut',        'CookingStation',     'PreparedIn',  'PreparedProduce'
      'PrecisionScale','PortionsOut',         'CookingStation',     'PortionsIn',  'PortionedIngredients'
      'CookingStation','CookedOut',           'QualitySensorSuite', 'CookedIn',    'CookedSoup'
      'QualitySensorSuite','InspectedOut',    'SealingLine',        'InspectedIn', 'InspectedSoup'
      'SealingLine','PackagedOut',            'LoaderArm',          'PackagedIn',  'PackagedBatch'
      'LoaderArm','ManifestOut',              'KitchenController',  'ManifestIn',  'Manifest'
      'CryoPantry','InvOut',                  'InventoryDB',        'InvIn',       'InventoryState'
      'InventoryDB','InvReport',              'KitchenController',  'InvIn',       'InventoryState'
      'GravityIMU','EnvOrch',                 'KitchenController',  'EnvIn',       'EnvironmentState'
      'GravityIMU','EnvProc',                 'RoboPrepStation',    'EnvIn',       'EnvironmentState'
      'GravityIMU','EnvPort',                 'PrecisionScale',     'EnvIn',       'EnvironmentState'
      'GravityIMU','EnvCook',                 'CookingStation',     'EnvIn',       'EnvironmentState'
      'GravityIMU','EnvPkg',                  'SealingLine',        'EnvIn',       'EnvironmentState'
    };

    outerCache = containers.Map;
    innerCache = containers.Map;
    for i = 1:size(conns,1)
        [sp, ~] = getOrAddPort(outerCache, innerCache, comps(conns{i,1}), conns{i,2}, 'out', dict.getInterface(conns{i,5}));
        [dp, ~] = getOrAddPort(outerCache, innerCache, comps(conns{i,3}), conns{i,4}, 'in',  dict.getInterface(conns{i,5}));
        connect(sp, dp);
    end

    %% Decompose CookingStation
    cookArch = comps('CookingStation').Architecture;
    subNames = {'InductionHeater','ThermalPID','MagneticStirrer','KitchenPLC'};
    subs = containers.Map;
    for i = 1:numel(subNames)
        subs(subNames{i}) = addComponent(cookArch, subNames{i});
    end

    [~, recipeInInner]   = getOrAddPort(outerCache, innerCache, comps('CookingStation'), 'RecipeIn',   'in',  dict.getInterface('RecipeCommand'));
    [~, preparedInInner] = getOrAddPort(outerCache, innerCache, comps('CookingStation'), 'PreparedIn', 'in',  dict.getInterface('PreparedProduce'));
    [~, portionsInInner] = getOrAddPort(outerCache, innerCache, comps('CookingStation'), 'PortionsIn', 'in',  dict.getInterface('PortionedIngredients'));
    [~, envInInner]      = getOrAddPort(outerCache, innerCache, comps('CookingStation'), 'EnvIn',      'in',  dict.getInterface('EnvironmentState'));
    [~, cookedOutInner]  = getOrAddPort(outerCache, innerCache, comps('CookingStation'), 'CookedOut',  'out', dict.getInterface('CookedSoup'));

    innerConns = {
      '<boundary>','RecipeIn',    'KitchenPLC',      'RecipeIn',       'RecipeCommand',        'boundaryIn'
      '<boundary>','PreparedIn',  'KitchenPLC',      'PreparedIn',     'PreparedProduce',      'boundaryIn'
      '<boundary>','PortionsIn',  'KitchenPLC',      'PortionsIn',     'PortionedIngredients', 'boundaryIn'
      '<boundary>','EnvIn',       'ThermalPID',      'EnvIn',          'EnvironmentState',     'boundaryIn'
      'KitchenPLC','HeatCmdOut',  'ThermalPID',      'HeatSetpointIn', 'HeatSetpoint',         ''
      'KitchenPLC','StirCmdOut',  'MagneticStirrer', 'StirCmdIn',      'StirCommand',          ''
      'ThermalPID','HeatOut',     'InductionHeater', 'HeatCmdIn',      'HeatCommand',          ''
      'InductionHeater','TempOut','ThermalPID',      'TempIn',         'Temperature',          ''
      'KitchenPLC','CookedOut',   '<boundary>',      'CookedOut',      'CookedSoup',           'boundaryOut'
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
    Simulink.BlockDiagram.arrangeSystem([char(modelName) '/CookingStation']);

    %% Profile and initial estimates
    profile = systemcomposer.profile.Profile.createProfile(profileName);
    st = addStereotype(profile, 'ComponentProperties', AppliesTo="Component");
    addProperty(st, 'mass',            Type="double", Units="kg",         DefaultValue="0");
    addProperty(st, 'volume',          Type="double", Units="m^3",        DefaultValue="0");
    addProperty(st, 'power',           Type="double", Units="kW",         DefaultValue="0");
    addProperty(st, 'cost',            Type="double", Units="credits",    DefaultValue="0");
    addProperty(st, 'throughput',      Type="double", Units="bowls/hour", DefaultValue="0");
    addProperty(st, 'automationLevel', Type="double", Units="",           DefaultValue="0");
    profile.save(char(archDir));
    applyProfile(model, profileName);

    prefix = [profileName, '.ComponentProperties.'];
    %        component           mass  volume  power   cost  throughput  automation
    values = {
      'CryoPantry',           3000,   50,    30,  250000,   0,   0.90;
      'AugerDispenser',        500,    8,    15,   80000, 300,   0.95;
      'RoboPrepStation',      1200,   15,    40,  220000, 250,   0.90;
      'PrecisionScale',        200,    2,     5,   60000, 400,   0.98;
      'CookingStation',       4000,   60,   250,  500000, 220,   0.85;
      'QualitySensorSuite',    300,    4,     8,  140000, 400,   0.95;
      'SealingLine',          2000,   40,    60,  180000, 250,   0.90;
      'LoaderArm',            1500,   25,    30,  150000, 300,   0.90;
      'InventoryDB',           150,    2,     3,   40000,   0,   1.00;
      'GravityIMU',             50,  0.2,   0.5,   20000,   0,   1.00;
      'KitchenController',     400,    5,     8,   80000,   0,   0.70;
    };
    for i = 1:size(values,1)
        comp = arch.getComponent(values{i,1});
        applyStereotype(comp, [profileName, '.ComponentProperties']);
        setProperty(comp, [prefix, 'mass'],            num2str(values{i,2}));
        setProperty(comp, [prefix, 'volume'],          num2str(values{i,3}));
        setProperty(comp, [prefix, 'power'],           num2str(values{i,4}));
        setProperty(comp, [prefix, 'cost'],            num2str(values{i,5}));
        setProperty(comp, [prefix, 'throughput'],      num2str(values{i,6}));
        setProperty(comp, [prefix, 'automationLevel'], num2str(values{i,7}));
    end

    save_system(char(modelName), char(fullfile(archDir, modelName)));

    totMass   = sum([values{:,2}]);
    totVol    = sum([values{:,3}]);
    totPower  = sum([values{:,4}]);
    totCost   = sum([values{:,5}]);
    fprintf('Top-level components : %d\n', numel(componentNames));
    fprintf('CookingStation parts : %d\n', numel(subNames));
    fprintf('Interfaces           : %d\n', size(ifaces,1));
    fprintf('Top-level connections: %d\n', size(conns,1));
    fprintf('CookingStation inner : %d\n', size(innerConns,1));
    fprintf('Profile              : %s (6 properties)\n', profileName);
    fprintf('Roll-ups: mass=%.0f kg, volume=%.1f m^3, power=%.1f kW, cost=%.0f credits\n', ...
        totMass, totVol, totPower, totCost);

    registerWithProject({slxFile, char(dictFile), profileXml});
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
