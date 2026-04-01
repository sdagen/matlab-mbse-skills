function buildFCSProfile()
% buildFCSProfile  Create and apply a budget profile to the FCS architecture.
%
%   Defines a "BudgetProperties" stereotype with per-component power and mass
%   estimates and budgets, then applies it to all FCS components.
%
%   Properties per component:
%     PowerBudget_W    — allocated power budget (W)
%     PowerEstimate_W  — current best estimate of power consumption (W)
%     Mass_kg          — estimated component mass (kg)
%
%   Run buildFCSModel() first (or call this script which does so internally).
%   Run rollupAnalysis() afterwards to see system-level budget summaries.

    archDir     = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'architecture');
    profileName = 'FCSBudget';
    modelName   = 'FCSSystem';

    %% Rebuild model from scratch (ensures clean profile application)
    buildFCSModel();

    %% Create profile
    systemcomposer.profile.Profile.closeAll();
    profileFile = fullfile(archDir, [profileName, '.xml']);
    if isfile(profileFile), delete(profileFile); end
    if isfolder(profileFile), rmdir(profileFile, 's'); end

    profile = systemcomposer.profile.Profile.createProfile(profileName);
    st = addStereotype(profile, 'BudgetProperties', AppliesTo="Component");
    addProperty(st, 'PowerBudget_W',   Type="double", Units="W",  DefaultValue="0");
    addProperty(st, 'PowerEstimate_W', Type="double", Units="W",  DefaultValue="0");
    addProperty(st, 'PowerMargin_W',   Type="double", Units="W",  DefaultValue="0");
    addProperty(st, 'Mass_kg',         Type="double", Units="kg", DefaultValue="0");
    profile.save(archDir);   % pass FOLDER — save(file.xml) creates a directory, not a file

    %% Apply profile to model and set per-component values
    addpath(archDir);
    model = systemcomposer.openModel(modelName);
    applyProfile(model, profileName);
    arch  = model.Architecture;

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

    slxPath = fullfile(archDir, modelName);
    save_system(char(modelName), char(slxPath));
    fprintf('Profile "%s" applied to %s with budget estimates.\n', ...
        profileName, modelName);
end
